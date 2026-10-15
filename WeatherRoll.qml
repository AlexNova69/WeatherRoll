import QtQuick 2.3

/* ============================================================================
   WeatherRoll.qml — полноэкранный скрипт погоды в городе
   (по мотивам NewsRoll.qml; ПО «Форвард Т» FDTitle Designer / FDOnAir,
    а также автономный запуск: qml.exe WeatherRollStandalone.qml)

   Назначение:
     полноэкранный показ погоды по секциям из текстового файла.
     Название города (первая строка файла) — вверху страницы.
     Погода секции — ЧЕТЫРЕ КВАДРАТА с данными внутри (например,
     температуры ночи/утра/дня/вечера) и текстовая строка с описанием
     ниже квадратов (например: «днем пасмурно, ветер З-ЮЗ 2-3 м/сек.»).

   Формат текстового файла (Задание), кодировка UTF-8 или UTF-16 LE с BOM:

     Прогноз погоды в Тихвине           <- строка ДО первого '#': город/титул
     #Сейчас                             <- заголовок секции
     ночью +8°C, утром +6°C, днем +9°C, вечером +7°C, днем пасмурно, ветер З-ЮЗ 2-3 м/сек
     #Сегодня
     Температура: +3…+11°C, Ветер: ЗЮЗ до 6 м/с, Осадки: 0 мм, Солнце: 07:12–18:04, без существенных осадков
     #Завтра
     ночью +5°C, утром +3°C, днем +8°C, вечером +6°C, днем облачно с прояснениями, ветер Ю 4 м/сек

   Источник данных показывается мелкой подписью внизу страницы (свойство
   sourceNote; пустая строка скрывает подпись). Секции в файле полностью
   описывают экраны показа.

   Правила разбора (строки секции объединяются, элементы разделяются запятой):
     • «ночью +8°C» / «утром +6С» …   -> квадрат: подпись времени суток
                                        + нормализованная температура;
     • «Подпись: значение» (метка     -> квадрат «Подпись / значение»;
       до 24 символов до двоеточия)
     • всё остальное                  -> описание ПОД квадратами (через «, »).
     Первые cardsMax (4) подходящих элемента образуют сетку 2x2, лишние —
     в описание.

   Сценарий показа:
     1. Заставка: видеофайл introVideoUrl (если движок собран с
        QtMultimedia — см. WeatherRollAV.qml) либо статическая анимированная
        заставка на splashDurationMs (ограничение 3000..8000 мс).
     2. Показ секций: город вверху; на каждом слайде — КРУПНЫЙ заголовок
        секции («СЕЙЧАС», «СЕГОДНЯ», «ЗАВТРА»), ЧЕТЫРЕ КВАДРАТА с данными,
        анимационная погодная иконка (рисуется самим QML, загрузка
        локальная; две иконки — слева и справа от квадрата с температурой,
        сетка квадратов остаётся по центру)
        и текстовая строка описания под квадратами.
        Смена секций — «переворот» или «слайд» (transitionStyle):
        автоматически по таймеру, а также вручную — стрелками клавиатуры,
        колесом мыши или свайпом (влево/вверх — следующая, вправо/вниз —
        предыдущая).
     3. Музыка musicUrl (wav/mp3) играет по кругу во время показа.
     4. loopPlayback=false — после последней секции проигрывается конечная
        заставка (outroVideoUrl либо плавное затемнение). Esc/Q — вызвать
        досрочно; в автономном режиме повторное нажатие закрывает окно.

   ДЛИТЕЛЬНОСТЬ ЗАДАНИЯ. Корневое свойство duration скрипт вычисляет сам:
   заставка + время всех секций (sectionShowTimeMs / sectionTimes) +
   переходы (+ конечное затемнение при показе не по кругу); при старте
   значение печатается в консоль дизайнера («показ начат, длительность
   задания = N мс»). ПРОВЕРЕНО ОПЫТОМ: QML-элемент ForwardT не отдаёт
   длительность задания в расписание автоматически (GetTaskInfo без
   дизайн-инициализации всегда возвращает 0) — так же устроены и
   референсные виджеты Яндекс/Гисметео. Поэтому для FDAir3 длительность
   задаётся ШТАТНО на стороне дизайнера: в поле «Длительность» элемента
   (Задание -> Длительность, формат чч:мм:сс.мс) впишите значение из
   консоли, и/или включите «Зациклить задание» (Loop) — задание будет
   повторяться циклами до конца отведённого окна в расписании.

   Фон: backgroundImageUrl (jpg/png; tga — если сборка Qt содержит плагин
   TGA; при ошибке загрузки используется тёмно-синий градиент).

   Если QtMultimedia недоступен (типично для FDTitle), видео и музыка
   автоматически отключаются, заставка остаётся статической — показ
   продолжается.

   НАСТРОЙКИ БЕЗ ПРАВКИ QML. FDTitle Designer не выводит пользовательские
   свойства QML-элемента в свою панель, поэтому все параметры из блока
   «НАСТРОЙКИ» дублируются в файле WeatherRoll.ini, лежащем рядом со
   WeatherRoll.qml (путь к нему — свойство settingsUrl). Формат ini —
   строки «ключ = значение»; имена ключей совпадают с именами свойств
   (weatherFileUrl, backgroundImageUrl, introVideoUrl, outroVideoUrl,
   musicUrl, musicVolume, splashDurationMs, sectionShowTimeMs,
   sectionTimes, autoAdvance, loopPlayback, transitionStyle,
   transitionDurationMs, reloadIntervalMs, cardsMax, cardsColumns,
   showWeatherIcon, sourceNote, fontFamily,
   цвета bgColorTop/cardColor/accentColor/…, enableOutline). Пустое значение или отсутствующий ключ — используется
   значение свойства из QML. После значения можно писать пояснение,
   отделяя его « ; » (пробел-точка с запятой-пробел) — всё после него
   игнорируется. Строки с «;» в начале и «[...]» — комментарии.
   ini перечитывается вместе с данными каждые reloadIntervalMs — правки
   применяются к показу без перезапуска (видео/музыка требуют перевывода
   элемента).
   ============================================================================ */

Item {
    id: root

    /* ==================== НАСТРОЙКИ: файлы ==================== */

    // Полный путь к текстовому файлу погоды (пишет WeatherCollector)
    property string weatherFileUrl: "file:///D:/Project/WeatherRoll/weather.txt"

    // Файл настроек WeatherRoll.ini (ищется рядом с WeatherRoll.qml).
    // Значения из ini переопределяют значения по умолчанию, заданные
    // свойствами ниже; пустое значение или отсутствие файла — используются
    // свойства QML. Это основной способ менять настройки без правки QML:
    // FDTitle Designer пользовательские свойства QML-элемента не показывает.
    property string settingsUrl: Qt.resolvedUrl("WeatherRoll.ini")

    // Фоновое изображение: jpg, png (tga — при поддержке сборкой Qt).
    // Пусто — тёмно-синий градиент. Пример:
    //   "file:///D:/Project/WeatherRoll/backgrounds/city.jpg"
    property string backgroundImageUrl: ""

    // Видео-заставка в начале (форматы — по возможностям кодеков Qt)
    property string introVideoUrl: ""

    // Видео в конце показа (после последней секции при loopPlayback=false)
    property string outroVideoUrl: ""

    // Музыка во время показа (wav / mp3), играется по кругу
    property string musicUrl: ""
    property real   musicVolume: 0.7        // 0..1

    /* ==================== НАСТРОЙКИ: заставка ==================== */

    // Длительность СТАТИЧЕСКОЙ заставки, мс (авто-ограничение 3000..8000).
    // Видеозаставка играет целиком, до конца файла.
    property int splashDurationMs: 5000

    /* ==================== НАСТРОЙКИ: показ ==================== */

    // Время показа одной секции, мс
    property int sectionShowTimeMs: 9000

    // Индивидуальное время показа секции по названию, мс.
    // СТРОКА вида "Сейчас=8000;Завтра=12000" (пусто — везде sectionShowTimeMs)
    property string sectionTimes: ""

    property bool autoAdvance: true          // автопереключение секций
    property bool loopPlayback: true         // показ по кругу
    property bool allowQuit: false           // true — только в автономном режиме

    // Вариант смены секций: "flip" | "slideLeft" | "slideRight" |
    //                        "slideUp" | "slideDown"
    property string transitionStyle: "flip"
    property int transitionDurationMs: 800

    // Периодическое перечитывание файла, мс (0 — выключено).
    // Имеет смысл только в режиме «Реальное время».
    property int reloadIntervalMs: 300000

    // Квадраты: максимум карточек и колонок в сетке
    property int cardsMax: 4
    property int cardsColumns: 2

    // Анимационные погодные иконки: рисуются самим QML (загрузка полностью
    // локальная — ни файлов, ни сети); вид подбирается по тексту прогноза:
    // ясно (солнце/луна), переменная облачность, пасмурно, дождь, ливень,
    // снег, гроза, туман. Две иконки встают СЛЕВА И СПРАВА от квадрата
    // с температурой; сетка квадратов остаётся по центру экрана.
    property bool showWeatherIcon: true

    // Мелкая подпись с источником данных внизу страницы слева
    // (пусто — скрыть). Сборщик погоды не пишет источник в файл.
    property string sourceNote: "\u0414\u0430\u043D\u043D\u044B\u0435: Open-Meteo"   // «Данные: Open-Meteo»

    /* ==================== НАСТРОЙКИ: оформление ==================== */

    property color bgColorTop:       "#FF0B1B33"   // градиент фона (верх)
    property color bgColorBottom:    "#FF14335C"   // градиент фона (низ)
    property color cityTextColor:    "#FFFFFFFF"
    property color cardColor:        "#B3164067"   // фон квадрата (AARRGGBB)
    property color cardBorderColor:  "#FF3D6DA6"
    property color cardLabelColor:   "#FFAFC4E0"
    property color cardValueColor:   "#FFFFFFFF"
    property color descTextColor:    "#FFF4F4F4"
    property color accentColor:      "#FFE2543B"
    property color errorColor:       "#FFFF6A4D"
    property string fontFamily:      "Arial"
    property bool   enableOutline:   true          // обводка текста для читаемости
    property color outlineColor:     "#CC101010"

    /* --- Размеры: масштабируются от designWidth x designHeight (1920x1080);
           при размещении в регионе иного размера всё пропорционально
           масштабируется коэффициентом k. --- */

    property int designWidth: 1920
    property int designHeight: 1080

    readonly property real k: (width > 0 && height > 0)
                              ? Math.min(width / designWidth, height / designHeight)
                              : 1

    property int cityFontPx:    Math.round(68 * k)
    property int sectionFontPx: Math.round(52 * k)   // крупный заголовок секции
    property int labelFontPx:   Math.round(25 * k)
    // кегль значения квадрата не задан константой: максимум 0.85 стороны
    // квадрата, Text.Fit уменьшает до вместимости
    property int descFontPx:    Math.round(33 * k)   // минимум/ошибки
    property int footerFontPx:  Math.round(21 * k)
    property int marginPx:      Math.round(38 * k)
    property int gapPx:         Math.round(26 * k)
    property int radiusPx:      Math.round(16 * k)
    property int cardBorderPx:  Math.round(2 * k)
    property int descBandPx:    Math.round(150 * k)

    /* ==================== СОСТОЯНИЕ ==================== */

    // ДЛИТЕЛЬНОСТЬ ЗАДАНИЯ — один цикл показа, мс. Движок «Форвард Т»
    // читает это свойство у корневого элемента QML (как у референсных
    // элементов SoftLab: поле «Длительность» задания в дизайнере и
    // расписании, GetTaskInfo): заставка + время всех секций + переходы
    // + конечное затемнение, если показ не по кругу.
    property int duration: {
        var total = Math.min(8000, Math.max(3000, splashDurationMs))
        if (sections.length > 0) {
            for (var i = 0; i < sections.length; i++)
                total += holdTimeFor(sections[i])
            if (autoAdvance)
                total += (loopPlayback ? sections.length : sections.length - 1)
                         * transitionDurationMs
        }
        if (!loopPlayback)
            total += 900      // конечное затемнение без видео
        return total
    }

    // Состояние от движка «Форвард Т»: SLRunTime.statusElement == 4 —
    // элемент в эфире (eRunning). Задание загружается заранее, поэтому
    // скрипт опрашивает статус и при КАЖДОМ входе в эфир запускает цикл
    // заново (заставка + первая секция) — показ не «проскакивает».
    // В автономном запуске SLRunTime нет — показ идёт сразу.
    property bool elementRunning: false      // диагностика
    property bool _airStarted: false

    Timer {
        id: airPollTimer
        interval: 400
        repeat: true
        running: true
        onTriggered: root.pollRuntime()
    }

    function pollRuntime() {
        try {
            if (typeof SLRunTime === "undefined") return
            if (!SLRunTime.hasOwnProperty("statusElement")) return
            var r = (SLRunTime.statusElement === 4)
            elementRunning = r
            if (!r) {
                _airStarted = false              // вышли из эфира
            } else if (!_airStarted) {
                restartForAir()
            }
        } catch (e) { }
    }

    function restartForAir() {
        _airStarted = true
        console.log("WeatherRoll: выход в эфир — цикл с начала," +
                    " длительность задания = " + duration + " мс")
        phase = "boot"
        avTried = true
        maybeStartSplash()      // заставка/видео -> startShow() с секции 0
    }

    // sections: [{title, cards:[{label,value}], desc}]
    property var sections: []
    property string cityLine: ""       // первая строка файла (город/титул)
    property string footerText: ""     // содержимое секции «#Обновлено»
    property int currentIdx: 0
    property string loadError: ""
    property string phase: "boot"      // boot | splash | show | outro | end
    property string _summary: "не загружено"
    property bool _transitionActive: false
    property int _pendingIdx: 0
    property bool frontIsA: true

    // Мультимедиа доступно только если движок собран с QtMultimedia;
    // проверяется загрузкой WeatherRollAV.qml через Loader
    property bool avAvailable: false
    property bool avTried: false

    readonly property string debugSummary: _summary

    function frontSection() {
        return (sections.length > currentIdx) ? sections[currentIdx] : null
    }

    /* ---------- подбор анимационной иконки по тексту прогноза ---------- */

    // kind: clear | partly | overcast | rain | heavyrain | snow | storm | fog
    function iconKindFor(sec) {
        if (sec === null) return ""
        var s = sec.desc.toLowerCase()
        for (var i = 0; i < sec.cards.length; i++)
            s += " " + sec.cards[i].label.toLowerCase() +
                 " " + sec.cards[i].value.toLowerCase()
        var noPrecip = s.indexOf("без существенных осадков") >= 0
        if (s.indexOf("гроза") >= 0)                       return "storm"
        if (s.indexOf("ливень") >= 0)                      return "heavyrain"
        if (!noPrecip && (s.indexOf("дожд") >= 0 ||
                          s.indexOf("морось") >= 0 ||
                          s.indexOf("ледян") >= 0 ||
                          s.indexOf("осадк") >= 0))        return "rain"
        if (s.indexOf("снег") >= 0 || s.indexOf("зёрна") >= 0 ||
            s.indexOf("зерна") >= 0)                       return "snow"
        if (s.indexOf("туман") >= 0 || s.indexOf("измороз") >= 0)
                                                           return "fog"
        if (s.indexOf("пасмурн") >= 0 || s.indexOf("облачн") >= 0)
                                                           return "overcast"
        if (s.indexOf("переменн") >= 0 || s.indexOf("преимущественно") >= 0 ||
            s.indexOf("просвет") >= 0)                     return "partly"
        if (s.indexOf("ясн") >= 0)                         return "clear"
        return "partly"
    }

    // Ночная иконка (луна/звёзды) — только для секции «Сейчас» в тёмное время
    function iconNightFor(sec) {
        if (sec === null) return false
        if (sec.title.toLowerCase() === "сейчас") {
            var h = (new Date()).getHours()
            return h < 7 || h >= 21
        }
        return false
    }

    // Индекс квадрата с температурой (возле него ставятся иконки):
    // метка «Температура» → квадрат «Днем» → первый квадрат
    function tempCardIndex(sec) {
        if (sec === null || sec.cards.length === 0) return -1
        for (var i = 0; i < sec.cards.length; i++) {
            if (sec.cards[i].label.toLowerCase().indexOf("температур") >= 0)
                return i
        }
        for (var j = 0; j < sec.cards.length; j++) {
            var l = sec.cards[j].label.toLowerCase()
            if (l === "днем" || l === "днём")
                return j
        }
        return 0
    }

    function holdTimeFor(sec) {
        // sectionTimes: "Сейчас=8000;Завтра=12000"
        if (sec && sectionTimes !== "") {
            var parts = sectionTimes.split(";")
            for (var i = 0; i < parts.length; i++) {
                var kv = parts[i].split("=")
                if (kv.length === 2 && trimLine(kv[0]) === sec.title) {
                    var t = parseInt(trimLine(kv[1]), 10)
                    if (!isNaN(t) && t > 0)
                        return t
                }
            }
        }
        return sectionShowTimeMs
    }

    /* ==================== РАЗБОР ФАЙЛА ==================== */

    // Приводит строку, полученную от XMLHttpRequest, к корректному виду:
    // учитывает BOM UTF-8/UTF-16 и случай, когда UTF-16 LE был прочитан
    // побайтово как Latin-1 ('ÿþ' в начале).
    function decodeText(raw) {
        if (raw.length > 0 && raw.charCodeAt(0) === 0xFEFF)
            raw = raw.substring(1)
        if (raw.length >= 2 && raw.charCodeAt(0) === 0xFF && raw.charCodeAt(1) === 0xFE) {
            var s = ""
            for (var i = 2; i + 1 < raw.length; i += 2)
                s += String.fromCharCode(raw.charCodeAt(i) | (raw.charCodeAt(i + 1) << 8))
            raw = s
            if (raw.length > 0 && raw.charCodeAt(0) === 0xFEFF) raw = raw.substring(1)
        } else if (raw.length >= 2 && raw.charCodeAt(0) === 0xFE && raw.charCodeAt(1) === 0xFF) {
            var s2 = ""
            for (var j = 2; j + 1 < raw.length; j += 2)
                s2 += String.fromCharCode((raw.charCodeAt(j) << 8) | raw.charCodeAt(j + 1))
            if (s2.length > 0 && s2.charCodeAt(0) === 0xFEFF) s2 = s2.substring(1)
            raw = s2
        }
        return raw
    }

    function trimLine(s) {
        return s.replace(/^\s+/, "").replace(/\s+$/, "")
    }

    function capFirst(s) {
        return (s.length > 0) ? (s.charAt(0).toUpperCase() + s.substring(1)) : s
    }

    // Похожа ли строка на температуру: "+8", "-3", "+8С", "+8 °C", "12°"
    function isTempLike(s) {
        return /^[+\-\u2212\u2013]?\s*\d{1,3}([.,]\d+)?\s*(\u00B0?\s*[Cc\u0421\u0441]|[Cc\u0421\u0441]\s*\u00B0?|\u00B0)?$/.test(s)
    }

    // Нормализует температуру к виду "+8°" / "-3°" / "0°" (компактно,
    // чтобы цифра занимала почти весь квадрат)
    function normTemp(s) {
        var t = trimLine(s)
        var m = /^([+\-\u2212\u2013]?\s*\d{1,3}(?:[.,]\d+)?)\s*(\u00B0?\s*[Cc\u0421\u0441]|[Cc\u0421\u0441]\s*\u00B0?|\u00B0)?$/.exec(t)
        if (!m) return t
        var num = m[1].replace(",", ".").replace(/[\u2212\u2013]/g, "-").replace("+", "").replace(/\s+/g, "")
        var v = Math.round(parseFloat(num))
        var sign = v > 0 ? "+" : ""
        return sign + v + "\u00B0"
    }

    // Элемент строки -> карточка квадрата, либо null (тогда в описание)
    function asCard(item) {
        // «ночью +8С» — время суток + температура
        var m = /^(\u043D\u043E\u0447\u044C|\u043D\u043E\u0447\u044C\u044E|\u043D\u043E\u0447\u0438|\u0443\u0442\u0440\u043E\u043C|\u0434\u043D\u0435\u043C|\u0434\u043D\u0451\u043C|\u0432\u0435\u0447\u0435\u0440\u043E\u043C)\s+(.+)$/.exec(item)
        if (m && isTempLike(m[2]))
            return { label: capFirst(m[1]), value: normTemp(m[2]) }
        // «Подпись: значение» (температурное значение нормализуется)
        var m2 = /^([^:]{1,24}?)\s*:\s*(.+)$/.exec(item)
        if (m2) {
            var v2 = trimLine(m2[2])
            return { label: capFirst(trimLine(m2[1])),
                     value: isTempLike(v2) ? normTemp(v2) : v2 }
        }
        return null
    }

    // Строит секцию: карточки (до cardsMax) + описание из остатка
    function buildSection(title, lines) {
        var cards = []
        var desc = []
        for (var i = 0; i < lines.length; i++) {
            var chunks = lines[i].split(",")
            for (var j = 0; j < chunks.length; j++) {
                var it = trimLine(chunks[j])
                if (it === "") continue
                var c = asCard(it)
                if (c !== null && cards.length < cardsMax)
                    cards.push(c)
                else
                    desc.push(it)
            }
        }
        return { title: title, cards: cards, desc: desc.join(", ") }
    }

    function parseWeather(raw) {
        var text = decodeText(raw)
        var lines = text.split(/\r\n|\n|\r/)
        var rawSecs = []
        var cityCandidate = ""
        var cur = null
        for (var i = 0; i < lines.length; i++) {
            var ln = trimLine(lines[i])
            if (ln === "") continue
            if (ln.charAt(0) === "#") {
                cur = { title: trimLine(ln.replace(/^#+/, "")), lines: [] }
                rawSecs.push(cur)
            } else if (cur !== null) {
                cur.lines.push(ln)
            } else if (cityCandidate === "") {
                cityCandidate = ln          // строки до первого '#' — титул/город
            }
        }

        var secs = []
        var footer = ""
        var nCards = 0
        for (var s = 0; s < rawSecs.length; s++) {
            var t = rawSecs[s].title
            if (t === "\u041E\u0431\u043D\u043E\u0432\u043B\u0435\u043D\u043E") {   // «Обновлено»
                footer = rawSecs[s].lines.join(", ")
                continue
            }
            var sec = buildSection(t, rawSecs[s].lines)
            nCards += sec.cards.length
            secs.push(sec)
        }

        _summary = "секций=" + secs.length + "; карточек=" + nCards +
                   "; город=\u00AB" + cityCandidate + "\u00BB"
        return { sections: secs, cityLine: cityCandidate, footer: footer }
    }

    /* ==================== ЗАГРУЗКА ==================== */

    function normalizedUrl() {
        return encodeURI(weatherFileUrl.replace(/\\/g, "/"))
    }

    // Если движок ForwardT передаёт содержимое «Задания» свойством контекста —
    // используем его (отсутствие свойства не является ошибкой)
    function injectedTaskText() {
        var v
        try { v = Data;      if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = Task;      if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = TaskText;  if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = TitleData; if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = Content;   if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = Ads;       if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        return ""
    }

    function loadNews(keepPage) {
        var injected = injectedTaskText()
        if (injected !== "") {
            loadError = ""
            applyParsed(parseWeather(injected), keepPage)
            return
        }

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var txt = xhr.responseText || ""
                if (txt.length === 0) {
                    loadError = "Файл не найден или пуст: " + weatherFileUrl +
                                " (для Qt >= 6.5 задайте переменную окружения" +
                                " QML_XHR_ALLOW_FILE_READ=1)"
                    if (!keepPage) applyParsed({ sections: [], cityLine: "", footer: "" }, false)
                    return
                }
                loadError = ""
                applyParsed(parseWeather(txt), keepPage)
            }
        }
        try {
            xhr.open("GET", normalizedUrl())
            xhr.send()
        } catch (e) {
            loadError = "Не удалось открыть файл: " + e
            applyParsed({ sections: [], cityLine: "", footer: "" }, false)
        }
    }

    /* ==================== НАСТРОЙКИ ИЗ WeatherRoll.ini ==================== */

    // Читает локальный файл асинхронно; okCb(text) / failCb()
    function readTextAsync(url, okCb, failCb) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var txt = xhr.responseText || ""
                if (txt.length === 0) { if (failCb) failCb(); return }
                okCb(txt)
            }
        }
        try {
            xhr.open("GET", url)
            xhr.send()
        } catch (e) {
            if (failCb) failCb()
        }
    }

    // Применяет «ключ = значение» из ini к одноимённым свойствам.
    // Пустое значение пропускается (остаётся значение свойства из QML).
    function applySettingsIni(raw) {
        var types = {
            weatherFileUrl: "string",  backgroundImageUrl: "string",
            introVideoUrl: "string",   outroVideoUrl: "string",
            musicUrl: "string",        musicVolume: "real",
            splashDurationMs: "int",   sectionShowTimeMs: "int",
            sectionTimes: "string",    autoAdvance: "bool",
            loopPlayback: "bool",      transitionStyle: "string",
            transitionDurationMs: "int", reloadIntervalMs: "int",
            cardsMax: "int",           cardsColumns: "int",
            showWeatherIcon: "bool",
            sourceNote: "string",      fontFamily: "string",
            bgColorTop: "color",   bgColorBottom: "color", cityTextColor: "color",
            cardColor: "color",    cardBorderColor: "color", cardLabelColor: "color",
            cardValueColor: "color", descTextColor: "color", accentColor: "color",
            errorColor: "color", outlineColor: "color",
            enableOutline: "bool"
        }
        var lines = decodeText(raw).split(/\r\n|\n|\r/)
        var applied = 0
        for (var i = 0; i < lines.length; i++) {
            var ln = trimLine(lines[i])
            if (ln === "" || ln.charAt(0) === ";" || ln.charAt(0) === "[" )
                continue
            var eq = ln.indexOf("=")
            if (eq < 1) continue
            var key = trimLine(ln.substring(0, eq))
            var val = trimLine(ln.substring(eq + 1))
            // инлайн-комментарий: всё после « ; » (пробел-;-пробел)
            // игнорируется; «;» без пробелов вокруг — часть значения
            // (например разделитель в sectionTimes)
            var ci = val.search(/\s;\s/)
            if (ci >= 0)
                val = trimLine(val.substring(0, ci))
            if (val.charAt(0) === ";")
                val = ""
            if (val === "" || !(key in types)) continue
            var t = types[key]
            if (t === "bool") {
                root[key] = /^(1|true|да|yes|on)$/i.test(val)
            } else if (t === "int") {
                var n = parseInt(val, 10)
                if (!isNaN(n)) root[key] = n
            } else if (t === "real") {
                var r = parseFloat(val)
                if (!isNaN(r)) root[key] = r
            } else {
                root[key] = val
            }
            applied++
        }
        if (applied > 0)
            console.log("WeatherRoll: из WeatherRoll.ini применено значений: " + applied)
    }

    // Запуск после применения настроек: медиа-компонент + первые данные
    function bootAfterSettings() {
        if (introVideoUrl !== "" || outroVideoUrl !== "" || musicUrl !== "") {
            avBootTimer.interval = 1500
            avLoader.source = "WeatherRollAV.qml"
        } else {
            avTried = true
            avBootTimer.interval = 60
            if (!avBootTimer.running)
                avBootTimer.start()
        }
        loadNews(false)
    }

    function loadSettings() {
        console.log("WeatherRoll: настройки " + settingsUrl)
        readTextAsync(settingsUrl,
            function (txt) {
                try { applySettingsIni(txt) } catch (e) {
                    console.log("WeatherRoll: ошибка WeatherRoll.ini: " + e)
                }
                bootAfterSettings()
            },
            function () {
                console.log("WeatherRoll: WeatherRoll.ini не найден или пуст —" +
                            " используются значения свойств из QML")
                bootAfterSettings()
            })
    }

    // Периодическое обновление: сначала настройки, затем данные
    function reloadAll() {
        readTextAsync(settingsUrl,
            function (txt) {
                try { applySettingsIni(txt) } catch (e) {}
                loadNews(true)
            },
            function () { loadNews(true) })
    }

    // Применяет разобранные данные; при перечитывании (keepPage) остаёмся
    // на той же секции (по названию), показ обновляется без анимации
    function applyParsed(parsed, keepPage) {
        var changed = JSON.stringify([parsed.sections, parsed.cityLine, parsed.footer]) !==
                      JSON.stringify([sections, cityLine, footerText])
        if (!changed) return
        if (keepPage) console.log("WeatherRoll: файл изменён, данные обновлены")

        var oldTitle = (sections.length > currentIdx) ? sections[currentIdx].title : ""
        sections = parsed.sections
        cityLine = parsed.cityLine
        footerText = parsed.footer
        headerText.text = (cityLine !== "") ? cityLine : "\u041F\u041E\u0413\u041E\u0414\u0410"   // «ПОГОДА»

        if (sections.length === 0 || _transitionActive) return

        var idx = 0
        for (var i = 0; i < sections.length; i++)
            if (sections[i].title === oldTitle) { idx = i; break }
        if (idx >= sections.length) idx = sections.length - 1
        currentIdx = idx
        if (phase === "show") applyImmediate(idx)
    }

    /* ==================== УПРАВЛЕНИЕ ПОКАЗОМ ==================== */

    // Немедленно показать секцию idx (без анимации)
    function applyImmediate(idx) {
        holdTimer.stop()
        flipAnim.stop()
        slideAnim.stop()
        _transitionActive = false
        frontIsA = true
        currentIdx = idx
        pageA.x = 0; pageA.y = 0
        pageB.x = 0; pageB.y = 0
        rotA.angle = 0
        rotB.angle = -90
        pageB.visible = false
        pageA.visible = true
        if (sections.length === 0) {
            pageA.setSection(null)
            return
        }
        pageA.setSection(sections[idx])
        if (autoAdvance) {
            holdTimer.interval = holdTimeFor(sections[idx])
            holdTimer.restart()
        }
    }

    function startShow() {
        if (phase === "show") return
        phase = "show"
        staticSplash.visible = false
        staticSplash.stopPulse()
        applyImmediate(0)
        contentRoot.opacity = 0
        introAnim.restart()
        console.log("WeatherRoll: показ начат, длительность задания = " +
                    duration + " мс")
        if (avAvailable && musicUrl !== "")
            avLoader.item.startMusic(musicUrl, musicVolume)
    }

    function startOutro() {
        if (phase === "outro" || phase === "end") return
        phase = "outro"
        holdTimer.stop()
        if (avAvailable && musicUrl !== "")
            avLoader.item.stopMusic()
        if (avAvailable && outroVideoUrl !== "")
            avLoader.item.playOutro(outroVideoUrl)
        else
            fadeOutAnim.restart()
    }

    function outroFinished() {
        phase = "end"
        endOverlay.opacity = 1
    }

    function quitRequested() {
        if (!allowQuit) return
        if (phase === "end" || phase === "outro") Qt.quit()
    }

    /* ==================== СМЕНА СЕКЦИЙ ==================== */

    function next() { goTo(currentIdx + 1) }
    function prev() { goTo(currentIdx - 1) }

    function goTo(idx) {
        if (phase !== "show" || _transitionActive || sections.length === 0)
            return
        var n = sections.length
        var target = ((idx % n) + n) % n
        if (target === currentIdx) return
        doTransition(target)
    }

    function doTransition(nextIdx) {
        var outPage = frontIsA ? pageA : pageB
        var inPage  = frontIsA ? pageB : pageA
        var outRot  = frontIsA ? rotA  : rotB
        var inRot   = frontIsA ? rotB  : rotA

        _pendingIdx = nextIdx
        inPage.setSection(sections[nextIdx])
        inPage.visible = true

        var style = String(transitionStyle).toLowerCase()
        var half = Math.max(1, transitionDurationMs / 2)

        if (style === "slideleft" || style === "slideright" ||
            style === "slideup"   || style === "slidedown") {
            // Направление — куда движется контент:
            //   slideLeft  -> старая уходит влево, новая справа
            //   slideRight -> старая уходит вправо, новая слева
            //   slideUp    -> старая уходит вверх, новая снизу
            //   slideDown  -> старая уходит вниз, новая сверху
            var horiz  = (style === "slideleft"  || style === "slideright")
            var sign   = (style === "slideleft"  || style === "slideup") ? -1 : 1
            var extent = horiz ? inPage.width : inPage.height
            slideOut.target = outPage
            slideIn.target  = inPage
            slideOut.property = horiz ? "x" : "y"
            slideIn.property  = horiz ? "x" : "y"
            slideOut.from = 0
            slideOut.to   = sign * extent
            slideIn.from  = -sign * extent
            slideIn.to    = 0
            outRot.angle = 0
            inRot.angle = 0
            slidePause.duration = half
            _transitionActive = true
            slideAnim.restart()
        } else {
            // Переворот вокруг горизонтальной оси (по умолчанию)
            outPage.x = 0; outPage.y = 0
            inPage.x = 0;  inPage.y = 0
            inRot.angle = -90
            flipOut.target = outRot
            flipIn.target  = inRot
            _transitionActive = true
            flipAnim.restart()
        }
    }

    // Середина смены: обновляем индекс (вкладки/подсветка)
    function transitionMidpoint() {
        currentIdx = _pendingIdx
    }

    function transitionFinished() {
        if (!_transitionActive)
            return
        _transitionActive = false
        var outPage = frontIsA ? pageA : pageB
        outPage.visible = false
        frontIsA = !frontIsA
        if (autoAdvance && sections.length > 0) {
            holdTimer.interval = holdTimeFor(sections[currentIdx])
            holdTimer.restart()
        }
    }

    function holdElapsed() {
        if (!loopPlayback && currentIdx >= sections.length - 1) {
            startOutro()
            return
        }
        next()
    }

    /* ==================== АНИМАЦИОННЫЕ ПОГОДНЫЕ ИКОНКИ ====================
       Рисуются целиком средствами QML (локально, без файлов и сети).
       Система координат — «дизайн-блок» 200x260, масштабируется под
       отведённое место. kind: clear | partly | overcast | rain | heavyrain |
       snow | storm | fog; night — луна и звёзды вместо солнца. */

    Component {
        id: cloudComp      // облако 130x66 (заливка цветом по типу погоды)

        Item {
            id: croot
            width: 130
            height: 66
            property bool back: false

            function blobColor() {
                if (back) return "#B5C0D2"
                if (wicon.kind === "storm")    return "#8E9AB0"
                if (wicon.kind === "overcast") return "#CBD3DF"
                return "#ECEFF7"
            }

            Rectangle { x: 8;  y: 26; width: 114; height: 40; radius: 20; color: croot.blobColor() }
            Rectangle { x: 14; y: 8;  width: 46;  height: 46; radius: 23; color: croot.blobColor() }
            Rectangle { x: 40; y: 0;  width: 58;  height: 58; radius: 29; color: croot.blobColor() }
            Rectangle { x: 82; y: 14; width: 44;  height: 44; radius: 22; color: croot.blobColor() }
        }
    }

    Component {
        id: weatherIconComp

        Item {
            id: wicon
            anchors.fill: parent

            property string kind: "partly"
            property bool night: false

            readonly property bool isClear:  kind === "clear"
            readonly property bool isPartly: kind === "partly"
            readonly property bool hasCloud: kind !== "clear"
            readonly property bool hasPrecip: kind === "rain" || kind === "heavyrain" || kind === "storm"
            readonly property bool isSnow:   kind === "snow"
            readonly property bool isFog:    kind === "fog"
            readonly property bool isStorm:  kind === "storm"

            Item {
                id: ib
                width: 200
                height: 260
                anchors.centerIn: parent
                scale: Math.min(wicon.width / 200, wicon.height / 260)

                // ---- солнце с вращающимися лучами (день: ясно/переменная) ----
                Item {
                    visible: !wicon.night && (wicon.isClear || wicon.isPartly)
                    x: wicon.isPartly ? 22 : 55
                    y: wicon.isPartly ? 12 : 46
                    width: 90; height: 90

                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 24000
                        loops: Animation.Infinite
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 58; height: 58; radius: 29
                        color: "#FFFFD75E"
                    }
                    Repeater {
                        model: 8
                        Rectangle {
                            width: 7; height: 24; radius: 3.5
                            color: "#FFFFD75E"
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            // поворот луча вокруг центра солнца (90x90)
                            transform: Rotation { angle: index * 45; origin.x: 3.5; origin.y: 45 }
                        }
                    }
                }

                // ---- луна с кратерами (ночь: ясно/переменная) ----
                Rectangle {
                    visible: wicon.night && (wicon.isClear || wicon.isPartly)
                    x: 55; y: 40
                    width: 90; height: 90; radius: 45
                    color: "#FFE9EDF7"
                    Rectangle { x: 18; y: 20; width: 16; height: 16; radius: 8;  color: "#FFC9D2E4" }
                    Rectangle { x: 44; y: 42; width: 12; height: 12; radius: 6;  color: "#FFC9D2E4" }
                    Rectangle { x: 30; y: 58; width: 9;  height: 9;  radius: 4.5; color: "#FFD5DCEA" }
                }

                // ---- мерцающие звёзды (ночь) ----
                Repeater {
                    model: 4
                    Item {
                        property var starPos: [
                            { x: 18,  y: 22 }, { x: 168, y: 30 },
                            { x: 150, y: 88 }, { x: 34,  y: 98 }
                        ]
                        x: starPos[index].x
                        y: starPos[index].y
                        visible: wicon.night && (wicon.isClear || wicon.isPartly)
                        Rectangle { width: 11; height: 2.6; radius: 1.3; color: "#FFDDE7F5"; anchors.centerIn: parent }
                        Rectangle { width: 2.6; height: 11; radius: 1.3; color: "#FFDDE7F5"; anchors.centerIn: parent }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.25; to: 1.0; duration: 700 + index * 260 }
                            NumberAnimation { from: 1.0; to: 0.25; duration: 700 + index * 260 }
                        }
                    }
                }

                // ---- задняя туча (пасмурно/гроза) ----
                Item {
                    visible: wicon.kind === "overcast" || wicon.isStorm
                    x: 64; y: 18; width: 130; height: 66
                    opacity: 0.9
                    Loader {
                        anchors.fill: parent
                        sourceComponent: cloudComp
                        onLoaded: item.back = true
                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: -16; duration: 8000; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: -16; to: 0; duration: 8000; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // ---- передняя туча (дрейфует) ----
                Item {
                    visible: wicon.hasCloud
                    x: wicon.isPartly ? 46 : 34
                    y: wicon.isPartly ? 88 : 40
                    width: 130; height: 66
                    Loader {
                        anchors.fill: parent
                        scale: wicon.isPartly ? 0.85 : 1
                        sourceComponent: cloudComp
                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 14; duration: 6500; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 14; to: 0; duration: 6500; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // ---- капли дождя (дождь/ливень/гроза) ----
                Repeater {
                    model: (wicon.kind === "heavyrain" || wicon.isStorm) ? 10 : 7
                    Rectangle {
                        visible: wicon.hasPrecip
                        x: 36 + (index * 61) % 126
                        y: 104
                        width: 5; height: 16; radius: 2.5
                        color: wicon.isStorm ? "#FF9FC8FF" : "#FF7CC0FF"
                        SequentialAnimation on y {
                            loops: Animation.Infinite
                            PauseAnimation { duration: (index * 137) % 700 }
                            NumberAnimation { from: 104; to: 232; duration: 700 + (index % 4) * 120 }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            PauseAnimation { duration: (index * 137) % 700 }
                            NumberAnimation { from: 0.95; to: 0; duration: 700 + (index % 4) * 120 }
                        }
                    }
                }

                // ---- снежинки (снег: падают с покачиванием) ----
                Repeater {
                    model: 8
                    Item {
                        visible: wicon.isSnow
                        x: 38 + (index * 53) % 118
                        y: 104
                        SequentialAnimation on y {
                            loops: Animation.Infinite
                            PauseAnimation { duration: (index * 211) % 1200 }
                            NumberAnimation { from: 104; to: 228; duration: 2600 + (index % 3) * 500 }
                        }
                        Item {
                            width: 10; height: 10
                            Rectangle { anchors.fill: parent; radius: 5; color: "#FFFFFFFF" }
                            SequentialAnimation on x {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0; to: 12; duration: 900; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 12; to: -12; duration: 1800; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: -12; to: 0; duration: 900; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }

                // ---- молния (гроза, мигает) ----
                Item {
                    visible: wicon.isStorm
                    x: 86; y: 100
                    opacity: 0
                    Rectangle { x: 0; y: 0;  width: 10; height: 30; radius: 2; color: "#FFFFE38A"
                                transform: Rotation { angle: 18;  origin.x: 5;   origin.y: 0 } }
                    Rectangle { x: 2; y: 26; width: 10; height: 34; radius: 2; color: "#FFFFE38A"
                                transform: Rotation { angle: -14; origin.x: 5;   origin.y: 0 } }
                    Rectangle { x: 4; y: 56; width: 9;  height: 22; radius: 2; color: "#FFFFE38A"
                                transform: Rotation { angle: 16;  origin.x: 4.5; origin.y: 0 } }
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: 1200 }
                        NumberAnimation { from: 0; to: 1; duration: 70 }
                        PauseAnimation { duration: 140 }
                        NumberAnimation { from: 1; to: 0.35; duration: 60 }
                        NumberAnimation { from: 0.35; to: 1; duration: 60 }
                        NumberAnimation { from: 1; to: 0; duration: 220 }
                    }
                }

                // ---- полосы тумана (туман, скользят) ----
                Repeater {
                    model: 4
                    Item {
                        visible: wicon.isFog
                        x: 16 + (index * 19) % 28
                        y: 118 + index * 27
                        width: 154 - (index % 2) * 26
                        height: 14
                        Rectangle { anchors.fill: parent; radius: 7; color: "#FFD8DFEA"; opacity: 0.78 }
                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 22; duration: 2600 + index * 500; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 22; to: 0; duration: 2600 + index * 500; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }
    }

    /* ==================== ВИЗУАЛЬНАЯ ЧАСТЬ ==================== */

    // --- фон: градиент + необязательное изображение ---
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.bgColorTop }
            GradientStop { position: 1.0; color: root.bgColorBottom }
        }
    }

    Image {
        id: bgImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: (root.backgroundImageUrl !== "") ? root.backgroundImageUrl : ""
        visible: status === Image.Ready
        onStatusChanged: {
            if (status === Image.Error)
                console.log("WeatherRoll: фон не загружен (" + root.backgroundImageUrl +
                            ") — используется градиент. Формат TGA требует плагина TGA в сборке Qt.")
        }
    }

    // лёгкое затемнение для читаемости текста поверх фотографии
    Rectangle {
        anchors.fill: parent
        visible: bgImage.visible
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#660B1B33" }
            GradientStop { position: 0.5; color: "#300B1B33" }
            GradientStop { position: 1.0; color: "#880B1B33" }
        }
    }

    // --- область ввода: свайп и колесо мыши ---
    // объявлена РАНЬШЕ контента: элементы поверх неё (вкладки)
    // получают свои события мыши первыми
    MouseArea {
        id: navMouse
        anchors.fill: parent
        enabled: root.phase === "show"
        property real px: 0
        property real py: 0
        onPressed: { px = mouse.x; py = mouse.y }
        onReleased: {
            var dx = mouse.x - px
            var dy = mouse.y - py
            var th = Math.max(60, root.width * 0.1)
            if (Math.abs(dx) < th && Math.abs(dy) < th) return
            if (Math.abs(dx) > Math.abs(dy))
                (dx < 0) ? root.next() : root.prev()
            else
                (dy < 0) ? root.next() : root.prev()
        }
        onWheel: {
            var d = wheel.angleDelta.y + wheel.angleDelta.x
            ;(d < 0) ? root.next() : root.prev()
        }
    }

    // --- контент ---
    Item {
        id: contentRoot
        anchors.fill: parent
        opacity: 0        // проявляется после заставки (introAnim)

        // Шапка: название города (название секции — крупно на каждом слайде)
        Text {
            id: headerText
            text: ""
            anchors.top: parent.top
            anchors.topMargin: root.marginPx
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: root.fontFamily
            font.pixelSize: root.cityFontPx
            font.bold: true
            color: (root.sections.length === 0) ? root.errorColor : root.cityTextColor
            style: root.enableOutline ? Text.Outline : Text.Normal
            styleColor: root.outlineColor
        }

        // Область страниц (заголовок секции, иконка, квадраты, описание)
        Item {
            id: contentArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerText.bottom
            anchors.bottom: parent.bottom
            anchors.margins: root.marginPx
            clip: true

            // ---------- страница A ----------
            Item {
                id: pageA
                width: contentArea.width
                height: contentArea.height
                x: 0; y: 0
                antialiasing: true
                visible: true

                property var sec: null
                property var positions: []
                property var iconRectL: ({ show: false, x: 0, y: 0, w: 0, h: 0 })
                property var iconRectR: ({ show: false, x: 0, y: 0, w: 0, h: 0 })
                property string iconKind: ""
                property bool iconNight: false
                property bool hasDesc: sec !== null && sec.desc !== ""

                function setSection(s) {
                    sec = s
                    iconKind = root.iconKindFor(s)
                    iconNight = root.iconNightFor(s)
                    if (iconLoaderLA.item) {
                        iconLoaderLA.item.kind = iconKind
                        iconLoaderLA.item.night = iconNight
                    }
                    if (iconLoaderRA.item) {
                        iconLoaderRA.item.kind = iconKind
                        iconLoaderRA.item.night = iconNight
                    }
                    layoutCards()
                }

                function layoutCards() {
                    var n = (sec !== null) ? sec.cards.length : 0
                    var pos = []
                    var irL = { show: false, x: 0, y: 0, w: 0, h: 0 }
                    var irR = { show: false, x: 0, y: 0, w: 0, h: 0 }
                    if (n > 0 && width > 0 && height > 0) {
                        var cols = Math.max(1, Math.min(root.cardsColumns, n))
                        var rows = Math.ceil(n / cols)
                        var gap = root.gapPx
                        var titleH = (sec !== null && sec.title !== "")
                                     ? Math.round(96 * root.k) : 0
                        var areaH = height - titleH -
                                    (hasDesc ? root.descBandPx + root.gapPx : 0)
                        areaH = Math.max(0, areaH)
                        // сетка квадратов — по центру, без учёта иконок
                        var side = Math.min((width - gap * (cols - 1)) / cols,
                                            (areaH - gap * (rows - 1)) / rows)
                        side = Math.max(0, side)
                        var gridH = rows * side + (rows - 1) * gap
                        var gy0 = titleH + (areaH - gridH) / 2
                        for (var i = 0; i < n; i++) {
                            var r = Math.floor(i / cols)
                            var c = i % cols
                            var inRow = (r === rows - 1) ? (n - r * cols) : cols
                            var rowW = inRow * side + (inRow - 1) * gap
                            pos.push({ x: (width - rowW) / 2 + c * (side + gap),
                                       y: gy0 + r * (side + gap),
                                       side: side })
                        }
                        // иконки слева и справа от строки квадрата с
                        // температурой — строго ВНЕ сетки (никогда не
                        // накладываются на соседние квадраты)
                        if (root.showWeatherIcon && iconKind !== "") {
                            var ti = root.tempCardIndex(sec)
                            if (ti >= 0 && ti < pos.length) {
                                var p = pos[ti]
                                var minGX = width
                                var maxGX = 0
                                for (var q = 0; q < pos.length; q++) {
                                    if (pos[q].x < minGX) minGX = pos[q].x
                                    if (pos[q].x + pos[q].side > maxGX)
                                        maxGX = pos[q].x + pos[q].side
                                }
                                var iw = Math.round(p.side * 0.9)
                                iw = Math.max(0, Math.min(iw, minGX - gap,
                                                          width - maxGX - gap))
                                if (iw > 8) {
                                    irL = { show: true, x: minGX - gap - iw,
                                            y: p.y, w: iw, h: p.side }
                                    irR = { show: true, x: maxGX + gap,
                                            y: p.y, w: iw, h: p.side }
                                }
                            }
                        }
                    }
                    positions = pos
                    iconRectL = irL
                    iconRectR = irR
                }

                onWidthChanged: layoutCards()
                onHeightChanged: layoutCards()

                transform: Rotation {
                    id: rotA
                    axis { x: 1; y: 0; z: 0 }    // переворот вокруг горизонтальной оси
                    origin.x: pageA.width / 2
                    origin.y: pageA.height / 2
                    angle: 0
                }

                // Крупный заголовок секции — по одному на каждом слайде
                Text {
                    id: pageTitleA
                    visible: pageA.sec !== null && pageA.sec.title !== ""
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(2 * root.k)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pageA.sec !== null ? pageA.sec.title.toUpperCase() : ""
                    font.family: root.fontFamily
                    font.pixelSize: root.sectionFontPx
                    font.bold: true
                    color: root.cityTextColor
                    style: root.enableOutline ? Text.Outline : Text.Normal
                    styleColor: root.outlineColor
                }

                Rectangle {
                    visible: pageTitleA.visible
                    anchors.top: pageTitleA.bottom
                    anchors.topMargin: Math.round(6 * root.k)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(110 * root.k)
                    height: Math.round(6 * root.k)
                    radius: height / 2
                    color: root.accentColor
                }

                // Анимационные погодные иконки — слева и справа от квадрата
                // с температурой (сетка квадратов остаётся по центру)
                Loader {
                    id: iconLoaderLA
                    sourceComponent: weatherIconComp
                    visible: pageA.iconRectL.show
                    x: pageA.iconRectL.x
                    y: pageA.iconRectL.y
                    width: pageA.iconRectL.w
                    height: pageA.iconRectL.h
                    onLoaded: {
                        item.kind = pageA.iconKind
                        item.night = pageA.iconNight
                    }
                }

                Loader {
                    id: iconLoaderRA
                    sourceComponent: weatherIconComp
                    visible: pageA.iconRectR.show
                    x: pageA.iconRectR.x
                    y: pageA.iconRectR.y
                    width: pageA.iconRectR.w
                    height: pageA.iconRectR.h
                    onLoaded: {
                        item.kind = pageA.iconKind
                        item.night = pageA.iconNight
                    }
                }

                Repeater {
                    model: pageA.sec !== null ? pageA.sec.cards : 0
                    Rectangle {
                        property var p: (index < pageA.positions.length)
                                        ? pageA.positions[index] : { x: 0, y: 0, side: 0 }
                        x: p.x; y: p.y
                        width: p.side; height: p.side
                        visible: p.side > 0
                        radius: root.radiusPx
                        color: root.cardColor
                        border.color: root.cardBorderColor
                        border.width: root.cardBorderPx

                        Text {
                            id: lbl
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Math.round(16 * root.k)
                            text: modelData.label
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: root.fontFamily
                            font.pixelSize: root.labelFontPx
                            font.capitalization: Font.AllUppercase
                            color: root.cardLabelColor
                        }

                        Text {
                            id: val
                            anchors.top: lbl.bottom
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Math.round(6 * root.k)
                            anchors.rightMargin: Math.round(6 * root.k)
                            anchors.topMargin: Math.round(4 * root.k)
                            anchors.bottomMargin: Math.round(8 * root.k)
                            text: modelData.value
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            fontSizeMode: Text.Fit
                            minimumPixelSize: Math.round(20 * root.k)
                            font.pixelSize: Math.round(p.side * 0.85)
                            font.bold: true
                            color: root.cardValueColor
                            style: root.enableOutline ? Text.Outline : Text.Normal
                            styleColor: root.outlineColor
                        }
                    }
                }

                // Полоса описания внизу страницы («днем пасмурно, ветер…»)
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: pageA.hasDesc ? root.descBandPx : 0
                    visible: pageA.hasDesc
                    radius: root.radiusPx
                    color: root.cardColor
                    border.color: root.cardBorderColor
                    border.width: root.cardBorderPx

                    Text {
                        anchors.fill: parent
                        anchors.margins: Math.round(14 * root.k)
                        text: pageA.sec !== null ? pageA.sec.desc : ""
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        fontSizeMode: Text.Fit
                        minimumPixelSize: Math.round(24 * root.k)
                        font.family: root.fontFamily
                        font.pixelSize: Math.round(root.descBandPx * 0.44)
                        font.bold: true
                        color: root.descTextColor
                        style: root.enableOutline ? Text.Outline : Text.Normal
                        styleColor: root.outlineColor
                    }
                }
            }

            // ---------- страница B ----------
            Item {
                id: pageB
                width: contentArea.width
                height: contentArea.height
                x: 0; y: 0
                antialiasing: true
                visible: false

                property var sec: null
                property var positions: []
                property var iconRectL: ({ show: false, x: 0, y: 0, w: 0, h: 0 })
                property var iconRectR: ({ show: false, x: 0, y: 0, w: 0, h: 0 })
                property string iconKind: ""
                property bool iconNight: false
                property bool hasDesc: sec !== null && sec.desc !== ""

                function setSection(s) {
                    sec = s
                    iconKind = root.iconKindFor(s)
                    iconNight = root.iconNightFor(s)
                    if (iconLoaderLB.item) {
                        iconLoaderLB.item.kind = iconKind
                        iconLoaderLB.item.night = iconNight
                    }
                    if (iconLoaderRB.item) {
                        iconLoaderRB.item.kind = iconKind
                        iconLoaderRB.item.night = iconNight
                    }
                    layoutCards()
                }

                function layoutCards() {
                    var n = (sec !== null) ? sec.cards.length : 0
                    var pos = []
                    var irL = { show: false, x: 0, y: 0, w: 0, h: 0 }
                    var irR = { show: false, x: 0, y: 0, w: 0, h: 0 }
                    if (n > 0 && width > 0 && height > 0) {
                        var cols = Math.max(1, Math.min(root.cardsColumns, n))
                        var rows = Math.ceil(n / cols)
                        var gap = root.gapPx
                        var titleH = (sec !== null && sec.title !== "")
                                     ? Math.round(96 * root.k) : 0
                        var areaH = height - titleH -
                                    (hasDesc ? root.descBandPx + root.gapPx : 0)
                        areaH = Math.max(0, areaH)
                        // сетка квадратов — по центру, без учёта иконок
                        var side = Math.min((width - gap * (cols - 1)) / cols,
                                            (areaH - gap * (rows - 1)) / rows)
                        side = Math.max(0, side)
                        var gridH = rows * side + (rows - 1) * gap
                        var gy0 = titleH + (areaH - gridH) / 2
                        for (var i = 0; i < n; i++) {
                            var r = Math.floor(i / cols)
                            var c = i % cols
                            var inRow = (r === rows - 1) ? (n - r * cols) : cols
                            var rowW = inRow * side + (inRow - 1) * gap
                            pos.push({ x: (width - rowW) / 2 + c * (side + gap),
                                       y: gy0 + r * (side + gap),
                                       side: side })
                        }
                        // иконки слева и справа от строки квадрата с
                        // температурой — строго ВНЕ сетки (никогда не
                        // накладываются на соседние квадраты)
                        if (root.showWeatherIcon && iconKind !== "") {
                            var ti = root.tempCardIndex(sec)
                            if (ti >= 0 && ti < pos.length) {
                                var p = pos[ti]
                                var minGX = width
                                var maxGX = 0
                                for (var q = 0; q < pos.length; q++) {
                                    if (pos[q].x < minGX) minGX = pos[q].x
                                    if (pos[q].x + pos[q].side > maxGX)
                                        maxGX = pos[q].x + pos[q].side
                                }
                                var iw = Math.round(p.side * 0.9)
                                iw = Math.max(0, Math.min(iw, minGX - gap,
                                                          width - maxGX - gap))
                                if (iw > 8) {
                                    irL = { show: true, x: minGX - gap - iw,
                                            y: p.y, w: iw, h: p.side }
                                    irR = { show: true, x: maxGX + gap,
                                            y: p.y, w: iw, h: p.side }
                                }
                            }
                        }
                    }
                    positions = pos
                    iconRectL = irL
                    iconRectR = irR
                }

                onWidthChanged: layoutCards()
                onHeightChanged: layoutCards()

                transform: Rotation {
                    id: rotB
                    axis { x: 1; y: 0; z: 0 }
                    origin.x: pageB.width / 2
                    origin.y: pageB.height / 2
                    angle: -90
                }

                // Крупный заголовок секции — по одному на каждом слайде
                Text {
                    id: pageTitleB
                    visible: pageB.sec !== null && pageB.sec.title !== ""
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(2 * root.k)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pageB.sec !== null ? pageB.sec.title.toUpperCase() : ""
                    font.family: root.fontFamily
                    font.pixelSize: root.sectionFontPx
                    font.bold: true
                    color: root.cityTextColor
                    style: root.enableOutline ? Text.Outline : Text.Normal
                    styleColor: root.outlineColor
                }

                Rectangle {
                    visible: pageTitleB.visible
                    anchors.top: pageTitleB.bottom
                    anchors.topMargin: Math.round(6 * root.k)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(110 * root.k)
                    height: Math.round(6 * root.k)
                    radius: height / 2
                    color: root.accentColor
                }

                // Анимационные погодные иконки — слева и справа от квадрата
                // с температурой (сетка квадратов остаётся по центру)
                Loader {
                    id: iconLoaderLB
                    sourceComponent: weatherIconComp
                    visible: pageB.iconRectL.show
                    x: pageB.iconRectL.x
                    y: pageB.iconRectL.y
                    width: pageB.iconRectL.w
                    height: pageB.iconRectL.h
                    onLoaded: {
                        item.kind = pageB.iconKind
                        item.night = pageB.iconNight
                    }
                }

                Loader {
                    id: iconLoaderRB
                    sourceComponent: weatherIconComp
                    visible: pageB.iconRectR.show
                    x: pageB.iconRectR.x
                    y: pageB.iconRectR.y
                    width: pageB.iconRectR.w
                    height: pageB.iconRectR.h
                    onLoaded: {
                        item.kind = pageB.iconKind
                        item.night = pageB.iconNight
                    }
                }

                Repeater {
                    model: pageB.sec !== null ? pageB.sec.cards : 0
                    Rectangle {
                        property var p: (index < pageB.positions.length)
                                        ? pageB.positions[index] : { x: 0, y: 0, side: 0 }
                        x: p.x; y: p.y
                        width: p.side; height: p.side
                        visible: p.side > 0
                        radius: root.radiusPx
                        color: root.cardColor
                        border.color: root.cardBorderColor
                        border.width: root.cardBorderPx

                        Text {
                            id: lbl
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Math.round(16 * root.k)
                            text: modelData.label
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: root.fontFamily
                            font.pixelSize: root.labelFontPx
                            font.capitalization: Font.AllUppercase
                            color: root.cardLabelColor
                        }

                        Text {
                            id: val
                            anchors.top: lbl.bottom
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Math.round(6 * root.k)
                            anchors.rightMargin: Math.round(6 * root.k)
                            anchors.topMargin: Math.round(4 * root.k)
                            anchors.bottomMargin: Math.round(8 * root.k)
                            text: modelData.value
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            fontSizeMode: Text.Fit
                            minimumPixelSize: Math.round(20 * root.k)
                            font.pixelSize: Math.round(p.side * 0.85)
                            font.bold: true
                            color: root.cardValueColor
                            style: root.enableOutline ? Text.Outline : Text.Normal
                            styleColor: root.outlineColor
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: pageB.hasDesc ? root.descBandPx : 0
                    visible: pageB.hasDesc
                    radius: root.radiusPx
                    color: root.cardColor
                    border.color: root.cardBorderColor
                    border.width: root.cardBorderPx

                    Text {
                        anchors.fill: parent
                        anchors.margins: Math.round(14 * root.k)
                        text: pageB.sec !== null ? pageB.sec.desc : ""
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        fontSizeMode: Text.Fit
                        minimumPixelSize: Math.round(24 * root.k)
                        font.family: root.fontFamily
                        font.pixelSize: Math.round(root.descBandPx * 0.44)
                        font.bold: true
                        color: root.descTextColor
                        style: root.enableOutline ? Text.Outline : Text.Normal
                        styleColor: root.outlineColor
                    }
                }
            }
        }

        // Ошибка загрузки — по центру
        Text {
            visible: root.sections.length === 0 && root.loadError !== "" && root.phase === "show"
            anchors.centerIn: parent
            width: parent.width - 2 * root.marginPx
            text: root.loadError
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.descFontPx * 0.8)
            color: root.errorColor
        }

        // Мелкая подпись с источником — внизу страницы слева
        Text {
            visible: root.sourceNote !== "" && root.phase !== "end"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(10 * root.k)
            text: root.sourceNote
            font.family: root.fontFamily
            font.pixelSize: root.footerFontPx
            color: "#8CD7E2F2"
            style: root.enableOutline ? Text.Outline : Text.Normal
            styleColor: root.outlineColor
        }

        // Совместимость: секция «#Обновлено» в файле (если добавлена руками)
        // выводится мелко в правом нижнем углу и не занимает экрана
        Text {
            visible: root.footerText !== "" && root.phase !== "end"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(10 * root.k)
            text: root.footerText
            font.family: root.fontFamily
            font.pixelSize: root.footerFontPx
            color: "#B8D7E2F2"
            style: root.enableOutline ? Text.Outline : Text.Normal
            styleColor: root.outlineColor
        }
    }

    // --- статическая заставка (нет видео или QtMultimedia недоступен) ---
    Item {
        id: staticSplash
        anchors.fill: parent
        visible: false

        function stopPulse() { pulseAnim.stop() }

        Rectangle { anchors.fill: parent; color: "#FF0B1B33" }

        Column {
            anchors.centerIn: parent
            spacing: Math.round(26 * root.k)

            Rectangle {
                id: pulseRing
                width: Math.round(140 * root.k)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#00000000"
                border.color: root.accentColor
                border.width: Math.max(2, Math.round(5 * root.k))

                SequentialAnimation {
                    id: pulseAnim
                    running: false
                    loops: Animation.Infinite
                    NumberAnimation { target: pulseRing; property: "scale"; from: 0.85; to: 1.15; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: pulseRing; property: "scale"; from: 1.15; to: 0.85; duration: 900; easing.type: Easing.InOutQuad }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u2739"
                    color: root.accentColor
                    font.pixelSize: Math.round(56 * root.k)
                }
            }

            Text {
                // «ПРОГНОЗ ПОГОДЫ»
                text: "\u041F\u0420\u041E\u0413\u041D\u041E\u0417 \u041F\u041E\u0413\u041E\u0414\u042B"
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.fontFamily
                font.pixelSize: Math.round(72 * root.k)
                font.bold: true
                color: "#FFFFFFFF"
                style: Text.Outline
                styleColor: root.outlineColor
            }

            Text {
                text: root.cityLine
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.fontFamily
                font.pixelSize: Math.round(40 * root.k)
                color: "#FFAFC4E0"
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(18 * root.k)
            anchors.horizontalCenter: parent.horizontalCenter
            text: "WeatherRoll"
            font.family: root.fontFamily
            font.pixelSize: Math.round(24 * root.k)
            color: "#66FFFFFF"
        }
    }

    // --- финальное затемнение (конец показа без конечного видео) ---
    Rectangle {
        id: endOverlay
        anchors.fill: parent
        color: "#FF05080F"
        opacity: 0
        visible: opacity > 0.001
    }

    // --- мультимедиа (видео-заставка и музыка), опционально ---
    Loader {
        id: avLoader
        anchors.fill: parent
        source: ""
        onStatusChanged: {
            if (status === Loader.Ready) {
                avAvailable = true
                avTried = true
                avBootTimer.interval = 50
                avBootTimer.restart()
            } else if (status === Loader.Error) {
                avAvailable = false
                avTried = true
                console.log("WeatherRoll: QtMultimedia недоступен — видео/музыка отключены," +
                            " заставка будет статической")
                avBootTimer.interval = 50
                avBootTimer.restart()
            }
        }
    }

    /* ==================== АНИМАЦИИ И ТАЙМЕРЫ ==================== */

    // Проявление контента после заставки
    SequentialAnimation {
        id: introAnim
        NumberAnimation { target: contentRoot; property: "opacity"; from: 0; to: 1; duration: 450 }
    }

    // Финальное затемнение (когда нет конечного видео)
    SequentialAnimation {
        id: fadeOutAnim
        NumberAnimation { target: endOverlay; property: "opacity"; from: 0; to: 1; duration: 900 }
        ScriptAction { script: root.outroFinished() }
    }

    // Переворот: текущая страница складывается вверх, следующая разворачивается
    SequentialAnimation {
        id: flipAnim
        NumberAnimation {
            id: flipOut
            property: "angle"
            from: 0; to: 90
            duration: Math.max(1, transitionDurationMs / 2)
            easing.type: Easing.InQuad
        }
        ScriptAction { script: root.transitionMidpoint() }
        NumberAnimation {
            id: flipIn
            property: "angle"
            from: -90; to: 0
            duration: Math.max(1, transitionDurationMs / 2)
            easing.type: Easing.OutQuad
        }
        onStopped: root.transitionFinished()
    }

    // Слайд: обе страницы едут одновременно
    ParallelAnimation {
        id: slideAnim
        NumberAnimation {
            id: slideOut
            property: "x"
            duration: Math.max(1, transitionDurationMs)
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            id: slideIn
            property: "x"
            duration: Math.max(1, transitionDurationMs)
            easing.type: Easing.InOutQuad
        }
        SequentialAnimation {
            PauseAnimation { id: slidePause; duration: 400 }
            ScriptAction { script: root.transitionMidpoint() }
        }
        onStopped: root.transitionFinished()
    }

    // Время удержания секции
    Timer {
        id: holdTimer
        interval: sectionShowTimeMs
        repeat: false
        onTriggered: root.holdElapsed()
    }

    // Статическая заставка: 3–8 секунд (ограничение по заданию)
    Timer {
        id: splashTimer
        interval: Math.min(8000, Math.max(3000, splashDurationMs))
        onTriggered: root.startShow()
    }

    // Ожидание загрузки мультимедиа-компонента (не более 1.5 с)
    Timer {
        id: avBootTimer
        interval: 1500
        onTriggered: maybeStartSplash()
    }

    // Периодическое перечитывание файла (reloadIntervalMs > 0):
    // вместе с данными обновляются и настройки WeatherRoll.ini
    Timer {
        id: reloadTimer
        interval: Math.max(1000, reloadIntervalMs)
        running: reloadIntervalMs > 0 && root.phase === "show"
        repeat: true
        onTriggered: root.reloadAll()
    }

    // Сигналы от мультимедиа-обёртки WeatherRollAV.qml
    Connections {
        target: avLoader.item
        onIntroFinished: root.startShow()
        onOutroFinished: root.outroFinished()
        onMediaError: {
            console.log("WeatherRoll: ошибка мультимедиа (" + tag + "): " + message)
            if (tag === "intro" && root.phase === "splash")
                startStaticSplash()     // отказ видеозаставки — статическая
        }
    }

    function startStaticSplash() {
        if (!staticSplash.visible) {
            staticSplash.visible = true
            pulseAnim.restart()
        }
        splashTimer.restart()
    }

    function maybeStartSplash() {
        if (phase !== "boot" || !avTried) return
        phase = "splash"
        if (avAvailable && introVideoUrl !== "")
            avLoader.item.playIntro(introVideoUrl)      // конец видео -> startShow()
        else
            startStaticSplash()
    }

    /* ==================== КЛАВИАТУРА ==================== */

    Keys.onPressed: {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            if (phase === "show") startOutro()
            else if (phase === "end") quitRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down ||
                   event.key === Qt.Key_Space || event.key === Qt.Key_PageDown) {
            next()
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up ||
                   event.key === Qt.Key_PageUp) {
            prev()
            event.accepted = true
        }
    }

    Component.onCompleted: {
        console.log("WeatherRoll: загрузка " + weatherFileUrl)
        loadSettings()         // ini -> bootAfterSettings() -> данные
    }
}
