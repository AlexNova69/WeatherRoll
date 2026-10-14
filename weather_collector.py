#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WeatherCollector — сборщик данных о погоде для полноэкранного скрипта
WeatherRoll.qml (ПО «Форвард Т» FDTitle Designer / FDOnAir; автономно).

Что делает:
  * запрашивает погоду в заданном городе из открытых источников
    (Open-Meteo: геокодинг + прогноз, ключи API не требуются);
  * для городов РФ по умолчанию усредняет несколько глобальных моделей
    (best_match + GFS + ICON) — прогноз точнее, чем одна модель;
  * каждые 10–60 минут пишет текстовый файл формата WeatherRoll
    (UTF-16 LE с BOM, атомарная замена — скрипт никогда не видит полуфайл).

Формат выходного файла:

    Прогноз погоды в Тихвине
    #Сейчас
    Температура: +9°C, Ощущается: +7°C, Ветер: ЗЮЗ 3-6 м/с, Давление: 761 мм рт.ст., пасмурно, влажность 87 %
    #Сегодня
    ночью +8°C, утром +6°C, днем +9°C, вечером +7°C, днем пасмурно, ветер ЗЮЗ до 6 м/сек, без существенных осадков
    #Завтра
    ночью +5°C, утром +3°C, днем +8°C, вечером +6°C, днем облачно с прояснениями, ветер Ю до 4 м/сек, осадки: 2 мм (60%)

Использование:
    WeatherCollector.exe                          # цикл по WeatherCollector.ini
    WeatherCollector.exe --city "Тихвин"          # город (создаёт/обновляет ini)
    WeatherCollector.exe --city Тихвин --interval 15 --out D:\\погода\\weather.txt
    WeatherCollector.exe --once                   # одно обновление и выход
    WeatherCollector.exe --search "тихв"          # поиск города (проверка имени)
    python weather_collector.py ...               # то же самое без exe

СЛУЖБА WINDOWS (автозапуск после перезагрузки), команды от администратора:
    WeatherCollector.exe install --startup auto   # установить (автозапуск)
    WeatherCollector.exe start                    # запустить
    WeatherCollector.exe stop                     # остановить
    WeatherCollector.exe restart                  # перезапустить
    WeatherCollector.exe remove                   # удалить службу
    WeatherCollector.exe debug                    # запуск службы в консоли
или готовыми install_service.bat / uninstall_service.bat.
У службы нет консоли, поэтому журнал пишется в weather_collector.log
рядом с WeatherCollector.exe; настройки — тот же WeatherCollector.ini.

Все параметры хранятся в WeatherCollector.ini рядом с программой;
аргументы командной строки имеют приоритет над ini.
"""

import argparse
import configparser
import datetime as dt
import json
import os
import sys
import time
import urllib.parse
import urllib.request

# Модули службы Windows (pywin32). Если их нет, программа работает
# как обычное консольное приложение, сервисные команды сообщат об ошибке.
try:
    import servicemanager
    import win32event
    import win32service
    import win32serviceutil
    PYWIN32 = True
except ImportError:
    PYWIN32 = False

VERSION = "1.1 (14.10.2026)"
UA = "WeatherRoll-WeatherCollector/1.0"

GEO_URL = "https://geocoding-api.open-meteo.com/v1/search"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"

CURRENT_VARS = ",".join([
    "temperature_2m", "apparent_temperature", "relative_humidity_2m",
    "weather_code", "cloud_cover", "pressure_msl",
    "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
])
DAILY_VARS = ",".join([
    "weather_code", "temperature_2m_max", "temperature_2m_min",
    "precipitation_sum", "precipitation_probability_max",
    "wind_speed_10m_max", "wind_gusts_10m_max", "wind_direction_10m_dominant",
    "sunrise", "sunset",
])

# Модели для усреднения по городам РФ (Open-Meteo, без ключей)
RF_MODELS = ["gfs_seamless", "icon_seamless"]

WMO_RU = {
    0: "ясно", 1: "преимущественно ясно", 2: "переменная облачность", 3: "пасмурно",
    45: "туман", 48: "туман с изморозью",
    51: "слабая морось", 53: "морось", 55: "сильная морось",
    56: "ледяная морось", 57: "сильная ледяная морось",
    61: "небольшой дождь", 63: "дождь", 65: "сильный дождь",
    66: "ледяной дождь", 67: "сильный ледяной дождь",
    71: "небольшой снег", 73: "снег", 75: "сильный снег", 77: "снежные зёрна",
    80: "небольшой ливень", 81: "ливень", 82: "сильный ливень",
    85: "снегопад", 86: "сильный снегопад",
    95: "гроза", 96: "гроза с градом", 99: "сильная гроза с градом",
}

COMPASS_16 = ["С", "ССВ", "СВ", "ВСВ", "В", "ВЮВ", "ЮВ", "ЮЮВ",
              "Ю", "ЮЮЗ", "ЮЗ", "ЗЮЗ", "З", "ЗСЗ", "СЗ", "ССЗ"]

MIN_INTERVAL, MAX_INTERVAL = 10, 60   # минут


def log_path():
    base = os.path.dirname(sys.executable if getattr(sys, "frozen", False)
                           else os.path.abspath(__file__))
    return os.path.join(base, "weather_collector.log")


# Настройки журнала (обновляются из ini в collector_loop):
#   file — писать ли файл-журнал (у службы консоли нет, но можно отключить,
#          чтобы файл не разрастался);
#   days — хранить записи не старше N дней (0 — не чистить); чистка
#          выполняется один раз в сутки при первой записи.
LOG_SETTINGS = {"file": True, "days": 3}
_LOG_DAY = [None]


def _parse_log_date(line):
    """Дата в начале строки журнала («dd.mm.yyyy  …») или None."""
    try:
        return dt.datetime.strptime(line[:10], "%d.%m.%Y").date()
    except ValueError:
        return None


def _purge_log(path, days):
    """Перезаписывает журнал без записей старше days дней."""
    try:
        if not os.path.exists(path):
            return
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        cutoff = dt.date.today() - dt.timedelta(days=max(1, days))
        kept = [ln for ln in lines
                if _parse_log_date(ln) is None or _parse_log_date(ln) >= cutoff]
        if len(kept) != len(lines):
            tmp = path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                f.writelines(kept)
            os.replace(tmp, path)
    except Exception:
        pass


def log(msg):
    """Журнал: консоль (если есть) + файл рядом с программой (для службы)."""
    line = "%s  %s" % (dt.datetime.now().strftime("%d.%m.%Y %H:%M:%S"), msg)
    try:
        print(line, flush=True)
    except Exception:
        pass                      # у службы консоли нет
    if not LOG_SETTINGS["file"]:
        return
    try:
        p = log_path()
        # раз в сутки (и при первом запуске) убираем записи старше log_days
        today = dt.date.today()
        if _LOG_DAY[0] != today:
            _LOG_DAY[0] = today
            if LOG_SETTINGS["days"] > 0:
                _purge_log(p, LOG_SETTINGS["days"])
        if os.path.exists(p) and os.path.getsize(p) > 1000000:
            try:
                os.remove(p + ".old")
            except OSError:
                pass
            os.replace(p, p + ".old")
        with open(p, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass                      # каталог без права записи — остаётся консоль


def wmo_desc(code):
    return WMO_RU.get(int(code), "неопределённая погода")


def compass(deg):
    if deg is None:
        return ""
    return COMPASS_16[int((deg % 360) / 22.5 + 0.5) % 16]


def ft(v):
    """Температура в виде '+12' / '-3' / '0'."""
    r = int(round(v))
    return "+%d" % r if r > 0 else str(r)


def hpa_to_mmhg(hpa):
    return int(round(hpa * 0.750061563))


def http_json(url, retries=3, timeout=25):
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            last_err = e
            if attempt < retries:
                log("  попытка %d не удалась (%s), повтор через 15 с…" % (attempt, e))
                time.sleep(15)
    raise RuntimeError("не удалось получить %s: %s" % (url.split("?")[0], last_err))


def geocode(city):
    q = urllib.parse.urlencode({"name": city, "count": 1,
                                "language": "ru", "format": "json"})
    data = http_json("%s?%s" % (GEO_URL, q))
    results = data.get("results") or []
    if not results:
        raise RuntimeError("город «%s» не найден (проверьте написание или "
                           "подберите через --search)" % city)
    g = results[0]
    return {
        "name": g.get("name", city),
        "latitude": g["latitude"],
        "longitude": g["longitude"],
        "country": g.get("country", ""),
        "country_code": g.get("country_code", ""),
        "admin1": g.get("admin1", ""),
        "timezone": g.get("timezone", "auto"),
    }


def search_cities(query):
    q = urllib.parse.urlencode({"name": query, "count": 10,
                                "language": "ru", "format": "json"})
    data = http_json("%s?%s" % (GEO_URL, q))
    results = data.get("results") or []
    if not results:
        print("Ничего не найдено по запросу «%s»" % query)
        return
    print("Результаты поиска «%s» (используйте точное имя для --city):" % query)
    for i, g in enumerate(results, 1):
        print("  %2d. %-30s %-20s %-20s  %.3f, %.3f" % (
            i, g.get("name", "?"),
            (g.get("admin1") or "")[:20], (g.get("country") or "")[:20],
            g["latitude"], g["longitude"]))


def fetch(lat, lon, model=None):
    q = urllib.parse.urlencode({
        "latitude": lat, "longitude": lon,
        "current": CURRENT_VARS,
        "hourly": "temperature_2m",
        "daily": DAILY_VARS,
        "timezone": "auto", "forecast_days": 3,
        "temperature_unit": "celsius", "windspeed_unit": "ms",
    })
    if model:
        q += "&models=" + model
    return http_json("%s?%s" % (FORECAST_URL, q))


# ------------------------- усреднение моделей -------------------------

CURRENT_AVG_KEYS = ["temperature_2m", "apparent_temperature", "pressure_msl",
                    "relative_humidity_2m", "cloud_cover",
                    "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m"]
DAILY_AVG_KEYS = ["temperature_2m_max", "temperature_2m_min",
                  "precipitation_sum", "precipitation_probability_max",
                  "wind_speed_10m_max", "wind_gusts_10m_max",
                  "wind_direction_10m_dominant"]


def _avg(vals):
    vals = [v for v in vals if isinstance(v, (int, float))]
    return sum(vals) / len(vals) if vals else None


def merge_models(datas):
    """datas[0] — основная выборка (best_match); остальные усредняются с ней."""
    if len(datas) == 1:
        return datas[0]
    out = dict(datas[0])
    cur = dict(datas[0].get("current") or {})
    for k in CURRENT_AVG_KEYS:
        a = _avg([d["current"].get(k) for d in datas if d.get("current")])
        if a is not None:
            cur[k] = a
    out["current"] = cur

    daily = {k: list(v) for k, v in (datas[0].get("daily") or {}).items()}
    ndays = len(daily.get("time", []))
    for k in DAILY_AVG_KEYS:
        if k not in daily:
            continue
        for i in range(ndays):
            a = _avg([d["daily"][k][i] for d in datas
                      if d.get("daily") and i < len(d["daily"].get(k, []))])
            if a is not None:
                daily[k][i] = a
    out["daily"] = daily

    hourly = dict(datas[0].get("hourly") or {})
    temps = hourly.get("temperature_2m")
    if temps:
        for i in range(len(temps)):
            a = _avg([d["hourly"]["temperature_2m"][i] for d in datas
                      if d.get("hourly") and i < len(d["hourly"].get("temperature_2m", []))])
            if a is not None:
                temps[i] = a
    out["hourly"] = hourly
    return out


# ------------------------- формирование текста -------------------------

def temp_at(data, day_idx, hour, prefer_next=False):
    """Температура часа hour дня day_idx (0=сегодня) из hourly; None, если нет.

    prefer_next=True — сначала берётся тот же час следующего дня
    (для «ночи» после 06:00 — прогноз ближайшей ночи, а не прошедшей)."""
    hours = (data.get("hourly") or {}).get("time") or []
    temps = (data.get("hourly") or {}).get("temperature_2m") or []
    days = (data.get("daily") or {}).get("time") or []

    def lookup(d, h):
        stamp = "%sT%02d:00" % (days[d], h)
        return temps[hours.index(stamp)] if stamp in hours else None

    if day_idx >= len(days) or not hours:
        return None
    if prefer_next and day_idx + 1 < len(days):
        v = lookup(day_idx + 1, hour)
        if v is not None:
            return v
    v = lookup(day_idx, hour)
    if v is not None:
        return v
    if day_idx + 1 < len(days):
        return lookup(day_idx + 1, hour)
    return None


def fmt_wind(speed, gusts):
    s = int(round(speed or 0))
    g = int(round(gusts or 0))
    if g > s + 1:
        return "%d-%d м/с" % (s, g)
    return "%d м/с" % s


def build_document(geo, data, title_override):
    cur = data["current"]
    daily = data["daily"]
    offset = data.get("utc_offset_seconds") or 0
    now_local = dt.datetime.now(dt.timezone.utc) + dt.timedelta(seconds=offset)

    lines = []
    if title_override:
        lines.append(title_override)
    else:
        where = geo["name"]
        region = geo.get("admin1") or ""
        if region and region != where:
            where = "%s (%s)" % (where, region)
        lines.append("Прогноз погоды — %s" % where)

    # --- Сейчас ---
    wind_txt = "%s %s" % (compass(cur.get("wind_direction_10m")),
                          fmt_wind(cur.get("wind_speed_10m"), cur.get("wind_gusts_10m")))
    cur_items = [
        "Температура: %s°C" % ft(cur["temperature_2m"]),
        "Ощущается: %s°C" % ft(cur["apparent_temperature"]),
        "Ветер: %s" % wind_txt,
        "Давление: %d мм рт.ст." % hpa_to_mmhg(cur["pressure_msl"]),
    ]
    cur_desc = "%s, влажность %d %%" % (wmo_desc(cur["weather_code"]),
                                        int(round(cur["relative_humidity_2m"])))
    lines.append("#Сейчас")
    lines.append(", ".join(cur_items) + ", " + cur_desc)

    # --- Сегодня / Завтра ---
    now_hour = now_local.hour
    for day_idx, name in ((0, "Сегодня"), (1, "Завтра")):
        parts = {
            "ночью": temp_at(data, day_idx, 3,
                             prefer_next=(day_idx == 0 and now_hour >= 6)),
            "утром": temp_at(data, day_idx, 9),
            "днем": temp_at(data, day_idx, 15),
            "вечером": temp_at(data, day_idx, 21),
        }
        tods = ", ".join("%s %s°C" % (p, ft(t)) for p, t in parts.items()
                         if t is not None)

        code = daily["weather_code"][day_idx]
        wmax = daily["wind_speed_10m_max"][day_idx]
        wdir = daily["wind_direction_10m_dominant"][day_idx]
        psum = daily.get("precipitation_sum", [None] * 3)[day_idx]
        prob = None
        if "precipitation_probability_max" in daily:
            prob = daily["precipitation_probability_max"][day_idx]

        desc = "днем %s, ветер %s до %d м/сек" % (wmo_desc(code), compass(wdir),
                                                  int(round(wmax or 0)))
        if isinstance(psum, (int, float)) and psum >= 0.5:
            desc += ", осадки: %g мм" % round(psum, 1)
            if isinstance(prob, (int, float)):
                desc += " (%d%%)" % int(round(prob))
        else:
            desc += ", без существенных осадков"

        lines.append("#" + name)
        lines.append((tods + ", " + desc) if tods else desc)

    return "\n".join(lines) + "\n"


def write_atomic(path, text):
    tmp = path + ".tmp"
    # utf-16 = UTF-16 LE с BOM (родная endian-ность Windows);
    # decodeText() в WeatherRoll.qml понимает и LE, и BE с BOM
    with open(tmp, "w", encoding="utf-16", newline="\n") as f:
        f.write(text)
    os.replace(tmp, path)


# ------------------------- конфигурация -------------------------

def default_ini_path():
    base = os.path.dirname(sys.executable if getattr(sys, "frozen", False)
                           else os.path.abspath(__file__))
    return os.path.join(base, "WeatherCollector.ini")


def load_config(path, create_if_missing=True):
    cp = configparser.ConfigParser()
    if os.path.exists(path):
        cp.read(path, encoding="utf-8-sig")
        return cp
    if not create_if_missing:
        return cp
    cp["general"] = {
        "city": "Тихвин",
        "interval_min": "30",
        "output": os.path.join(os.path.dirname(path), "weather.txt"),
        "title": "",
        "russia_multimodel": "auto",   # auto | on | off
        "log_file": "on",              # on | off — файл-журнал weather_collector.log
        "log_days": "3",               # хранить записи не старше N дней (0 — вечно)
    }
    with open(path, "w", encoding="utf-8-sig") as f:
        f.write("; WeatherCollector — настройки сборщика погоды WeatherRoll\n"
                "; city              — город (точно как в --search)\n"
                "; interval_min      — период опроса, минут (10..60)\n"
                "; output            — полный путь к текстовому файлу погоды\n"
                "; title             — своя первая строка (пусто = «Прогноз погоды — Город»)\n"
                "; russia_multimodel — auto: для городов РФ усреднять GFS+ICON (точнее)\n"
                "; log_file          — on/off: писать ли файл-журнал weather_collector.log\n"
                "; log_days          — хранить журнал N дней, старое удаляется (0 — вечно)\n")
        cp.write(f)
    return cp


def collect_once(city_geo, cfg, out_path):
    lat, lon = city_geo["latitude"], city_geo["longitude"]
    multi = cfg.get("general", "russia_multimodel", fallback="auto")
    use_multi = (multi == "on") or (multi == "auto"
                                    and city_geo.get("country_code") == "RU")

    datas = [fetch(lat, lon)]                      # best_match
    models_used = ["best_match"]
    if use_multi:
        for m in RF_MODELS:
            try:
                datas.append(fetch(lat, lon, model=m))
                models_used.append(m)
            except Exception as e:
                log("  модель %s пропущена: %s" % (m, e))

    merged = merge_models(datas)
    text = build_document(city_geo, merged,
                          cfg.get("general", "title", fallback="").strip())
    write_atomic(out_path, text)
    cur = merged["current"]
    log("обновлено [%s]: t=%s°C, %s, ветер %s %s" % (
        "+".join(models_used),
        ft(cur["temperature_2m"]), wmo_desc(cur["weather_code"]),
        compass(cur["wind_direction_10m"]),
        fmt_wind(cur["wind_speed_10m"], cur["wind_gusts_10m"])))


def stoppable_sleep(seconds, stop_event=None):
    """Ожидание; True — если поступил запрос остановки (служба/Ctrl+C)."""
    if stop_event is not None:
        return win32event.WaitForSingleObject(
            stop_event, max(0, int(seconds * 1000))) == win32event.WAIT_OBJECT_0
    try:
        time.sleep(seconds)
    except KeyboardInterrupt:
        return True
    return False


def collector_loop(overrides, stop_event=None, once=False):
    """Общий цикл сборщика (консоль и служба Windows).

    overrides — dict с ключами city / interval / out / title / config /
    russia_multimodel; None означает «не переопределять, взять из ini»."""
    ov = overrides or {}
    ini_path = ov.get("config") or default_ini_path()
    cfg = load_config(ini_path)
    if not cfg.has_section("general"):
        cfg.add_section("general")
    g = cfg["general"]

    dirty = [False]

    def ov_set(key, val):
        if val is None:
            return
        sval = str(val)
        if g.get(key, "") != sval:
            g[key] = sval
            dirty[0] = True

    ov_set("city", ov.get("city"))
    ov_set("interval_min", ov.get("interval"))
    ov_set("output", ov.get("out"))
    ov_set("title", ov.get("title"))
    ov_set("russia_multimodel", ov.get("russia_multimodel"))

    city = g.get("city", "Тихвин").strip()
    interval = max(MIN_INTERVAL, min(MAX_INTERVAL, g.getint("interval_min", 30)))
    out_path = os.path.abspath(g.get("output",
                          os.path.join(os.path.dirname(ini_path), "weather.txt")))
    multi_mode = g.get("russia_multimodel", "auto")

    # настройки журнала (log_file: on/off; log_days: хранить N дней, 0 — вечно)
    try:
        LOG_SETTINGS["file"] = g.getboolean("log_file", fallback=True)
    except ValueError:
        LOG_SETTINGS["file"] = True
    try:
        LOG_SETTINGS["days"] = g.getint("log_days", fallback=3)
    except ValueError:
        LOG_SETTINGS["days"] = 3

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    if dirty[0]:
        with open(ini_path, "w", encoding="utf-8-sig") as f:
            cfg.write(f)

    log("WeatherCollector %s | город: %s | период: %d мин | файл: %s | РФ-мультимодель: %s"
        % (VERSION, city, interval, out_path, multi_mode))

    while True:
        try:
            geo = geocode(city)
            break
        except Exception as e:
            log("ОШИБКА геокодинга: %s" % e)
            if once:
                return 2
            if stoppable_sleep(300, stop_event):
                log("остановлено")
                return 0
    log("координаты: %.4f, %.4f — %s, %s"
        % (geo["latitude"], geo["longitude"], geo.get("admin1") or "",
           geo.get("country") or ""))

    while True:
        try:
            collect_once(geo, cfg, out_path)
        except Exception as e:
            log("ОШИБКА обновления (старый файл сохранён): %s" % e)
        if once:
            return 0
        log("следующее обновление через %d мин…" % interval)
        if stoppable_sleep(interval * 60, stop_event):
            log("остановлено")
            return 0


# ------------------------- служба Windows (pywin32) -------------------------

SERVICE_COMMANDS = {"install", "update", "remove", "start", "stop",
                    "restart", "debug"}

# опции HandleCommandLine, требующие значения
_SVC_OPTS_WITH_VALUE = {"--password", "--username", "--startup",
                        "--perfmonini", "--perfmondll", "--wait"}


def _find_service_command(argv):
    """Индекс аргумента-команды службы или None.

    Первое «голое» слово, не являющееся значением опции, должно быть
    сервисной командой — иначе считаем, что это обычный вызов argparse."""
    i = 1
    while i < len(argv):
        a = argv[i]
        if a.startswith("-"):
            i += 2 if (a.split("=")[0] in _SVC_OPTS_WITH_VALUE
                       and "=" not in a) else 1
            continue
        return i if a.lower() in SERVICE_COMMANDS else None
    return None

if PYWIN32:

    class WeatherCollectorService(win32serviceutil.ServiceFramework):
        _svc_name_ = "WeatherCollector"
        _svc_display_name_ = "WeatherCollector — сборщик погоды (WeatherRoll)"
        _svc_description_ = (
            "Каждые 10–60 минут собирает прогноз погоды из открытых источников "
            "Open-Meteo и записывает weather.txt для полноэкранного скрипта "
            "WeatherRoll.qml. Настройки — WeatherCollector.ini рядом с "
            "WeatherCollector.exe, журнал — weather_collector.log там же.")

        def __init__(self, args):
            win32serviceutil.ServiceFramework.__init__(self, args)
            self.stop_event = win32event.CreateEvent(None, 0, 0, None)

        def SvcStop(self):
            self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
            win32event.SetEvent(self.stop_event)

        def SvcDoRun(self):
            servicemanager.LogMsg(servicemanager.EVENTLOG_INFORMATION_TYPE,
                                  servicemanager.PYS_SERVICE_STARTED,
                                  (self._svc_name_, ""))
            try:
                collector_loop(None, stop_event=self.stop_event)
            except Exception:
                import traceback
                servicemanager.LogErrorMsg(traceback.format_exc())


def main():
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    ap = argparse.ArgumentParser(
        description="WeatherCollector %s — сборщик погоды для WeatherRoll" % VERSION,
        epilog="Служба Windows (от администратора): install --startup auto, "
               "start, stop, restart, remove, debug; либо install_service.bat")
    ap.add_argument("--city", help="город (точно как в --search)")
    ap.add_argument("--interval", type=int, metavar="MIN",
                    help="период опроса в минутах, 10..60")
    ap.add_argument("--out", help="полный путь к выходному текстовому файлу")
    ap.add_argument("--title", help="своя первая строка файла (название города)")
    ap.add_argument("--config", default=None, help="путь к ini (по умолчанию рядом с программой)")
    ap.add_argument("--once", action="store_true", help="одно обновление и выход")
    ap.add_argument("--search", metavar="ЗАПРОС", help="поиск города и выход")
    ap.add_argument("--russia-multimodel", choices=["auto", "on", "off"],
                    help="усреднение моделей для РФ (по умолчанию auto)")
    args = ap.parse_args()

    if args.search:
        search_cities(args.search)
        return 0

    overrides = {
        "city": args.city,
        "interval": args.interval,
        "out": args.out,
        "title": args.title,
        "config": args.config,
        "russia_multimodel": args.russia_multimodel,
    }
    return collector_loop(overrides, once=args.once)


if __name__ == "__main__":
    _idx = _find_service_command(sys.argv)
    if _idx is not None:
        if not PYWIN32:
            print("Сервисный режим недоступен: нет модулей pywin32.\n"
                  "Установите их и пересоберите exe: python -m pip install pywin32")
            sys.exit(2)
        # pywin32 ждёт опции ДО команды — переставляем команду в конец,
        # поэтому работают оба написания: «install --startup auto» и
        # «--startup auto install»
        _argv = (sys.argv[0:1] + sys.argv[1:_idx] + sys.argv[_idx + 1:] +
                 [sys.argv[_idx]])
        win32serviceutil.HandleCommandLine(WeatherCollectorService, argv=_argv)
        sys.exit(0)
    if len(sys.argv) == 1 and PYWIN32:
        # Без аргументов: если процесс запущен менеджером служб — работаем
        # как служба; иначе (двойной клик, консоль) — обычный цикл.
        try:
            servicemanager.Initialize()
            servicemanager.PrepareToHostSingle(WeatherCollectorService)
            servicemanager.StartServiceCtrlDispatcher()
        except Exception:
            sys.exit(main())
        sys.exit(0)
    sys.exit(main())
