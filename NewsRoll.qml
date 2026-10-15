import QtQuick 2.3

/* ============================================================================
   NewsRoll.qml — титровальный элемент QML для ПО «Форвард Т»
   (FDTitle Designer / FDOnAir, СофтЛаб-НСК)

   Назначение:
     постраничный показ новостных сообщений из текстового файла
     (по мотивам скрипт-объекта TS1_NewsRollCrawl).

   Формат текстового файла (Задание), кодировка UTF-8 или UTF-16 LE с BOM:
     #Заголовок источника        <- строка, начинающаяся с '#'
     Предложение 1               <- каждое предложение с новой строки
     Предложение 2
     Предложение 3
     Предложение 4
     Предложение 5
     (пустая строка — разделитель, необязательна)
     #Следующий источник         <- новый блок: заголовок заменяется
     ...

   Сценарий показа:
     1. Заголовок '#...' выводится в фиксированном месте (полоса сверху)
        и держится, пока показываются все предложения своего блока.
     2. Предложения показываются постранично: сначала 3 строки
        (каждая с новой строки), затем эффект смены страницы —
        и следующие 2–3 строки.
     3. Когда блок закончился и в файле идёт новый '#...' — заголовок
        меняется (анимация затемнения), показ блока повторяется.
     4. После последнего блока показ начинается заново (loopPlayback).

   ВЫХОД В ЭФИР: задание движок загружает заранее, поэтому скрипт следит
   за статусом SLRunTime.statusElement (4 = «Running») и при КАЖДОМ
   входе в эфир начинает цикл заново — первая страница всегда показывается
   полное время. По желанию включается заставка splashDurationMs
   (по типу WeatherRoll; 0 — выключена).

   Вариант смены страниц задаётся свойством transitionStyle:
     "flip"       — переворот вокруг горизонтальной оси (по умолчанию);
     "slideLeft"  — слайд влево: старая страница уходит влево,
                    новая приезжает справа;
     "slideRight" — слайд вправо: старая уходит вправо, новая слева;
     "slideUp"    — слайд вверх: старая уходит вверх, новая снизу;
     "slideDown"  — слайд вниз: старая уходит вниз, новая сверху.

   Все времена и оформление регулируются свойствами в блоке «НАСТРОЙКИ».
   ============================================================================ */

Item {
    id: root

    /* ==================== НАСТРОЙКИ ==================== */

    // Полный путь к текстовому файлу новостей.
    // Используйте прямые слэши: file:///D:/Project/newsroll/пикалево.txt
    // (рекомендуется указывать здесь тот же файл, что и в поле «Задание»
    //  титровального элемента QML)
    property string newsFileUrl: "file:///D:/Project/newsroll/пикалево.txt"

    // Время показа ПЕРВОЙ страницы блока (3 предложения), мс
    property int showTimeFirstMs: 12000

    // Время показа СЛЕДУЮЩИХ страниц блока (2–3 предложения), мс
    property int showTimeRestMs: 9000

    // Вариант смены страниц: "flip" | "slideLeft" | "slideRight" |
    //                        "slideUp" | "slideDown"
    property string transitionStyle: "flip"

    // Длительность эффекта смены страниц (переворот/слайд), мс
    property int transitionDurationMs: 700

    // Длительность анимации смены заголовка '#...', мс
    property int headerSwapMs: 300

    // Зацикливание показа (по кругу); false — остаться на последней странице
    property bool loopPlayback: true

    // Предложений на первой странице блока
    property int sentencesOnFirstPage: 3

    // Предложений на следующих страницах блока
    property int sentencesOnNextPage: 3

    // Периодическое перечитывание файла, мс (0 — выключено).
    // Имеет смысл только в режиме «Реальное время»; в режиме «Файл»
    // кадры готовятся заранее и перечитывание бессмысленно.
    property int reloadIntervalMs: 0

    // Заставка в начале цикла показа, мс (по типу WeatherRoll).
    // 0 — выключена; включённая ограничивается диапазоном 3000..8000.
    property int splashDurationMs: 3000

    // Файл настроек NewsRoll.ini (ищется рядом с NewsRoll.qml).
    // Значения из ini переопределяют значения по умолчанию, заданные
    // свойствами ниже; пустое значение или отсутствие файла — используются
    // свойства QML. Позволяет менять настройки без правки QML (FDTitle
    // Designer пользовательские свойства QML-элемента не показывает).
    property string settingsUrl: Qt.resolvedUrl("NewsRoll.ini")

    /* --- Оформление --- */

    property color panelColor:      "#B3202740"   // фон панели (AARRGGBB)
    property color panelBorderColor:"#FF3D6DA6"   // рамка панели
    property int    panelBorderBasePx: 2
    property color headerBgColor:   "#FF16406B"   // фон полосы заголовка
    property color headerTextColor: "#FFFFFFFF"   // цвет текста заголовка
    property color textColor:       "#FFF4F4F4"   // цвет текста предложений
    property color accentColor:     "#FFE2543B"   // акцентная полоса слева
    property color errorColor:      "#FFFF6A4D"
    property string fontFamily:     "Arial"
    property bool   enableOutline:  true          // обводка текста для читаемости на видео
    property color outlineColor:    "#CC101010"

    /* --- Размеры (автоматически масштабируются от высоты региона).
           Значения по умолчанию рассчитаны на регион designHeight x designWidth
           (например 560x420 при SD 720x576 или 1280x960 при HD). --- */

    property int designHeight: 420
    property int headerFontBasePx: 30    // кегль заголовка '#...'
    property int textFontBasePx: 25      // кегль предложений
    property int marginBasePx: 18        // внутренние поля
    property int spacingBasePx: 14       // интервал между предложениями
    property int radiusBasePx: 10        // скругление углов
    property int accentBasePx: 8         // толщина акцентной полосы

    readonly property real k: height > 0 ? (height / designHeight) : 1
    property int headerFontPx:  Math.round(headerFontBasePx * k)
    property int textFontPx:    Math.round(textFontBasePx * k)
    property int marginPx:      Math.round(marginBasePx * k)
    property int spacingPx:     Math.round(spacingBasePx * k)
    property int radiusPx:      Math.round(radiusBasePx * k)
    property int accentPx:      Math.round(accentBasePx * k)
    property int panelBorderPx: Math.round(panelBorderBasePx * k)

    /* ==================== СОСТОЯНИЕ ==================== */

    property var schedule: []          // [{header, lines:[...], rest}]
    property int currentIdx: -1
    property string currentHeader: ""
    property string loadError: ""
    property string _pendingHeader: ""
    property string _summary: "не загружено"
    property bool _transitionActive: false
    property bool splashActive: false

    // ДЛИТЕЛЬНОСТЬ ЗАДАНИЯ — один цикл показа, мс: заставка (если
    // включена) + страницы и переходы.
    property int duration: {
        var total = (splashDurationMs > 0)
                    ? Math.min(8000, Math.max(3000, splashDurationMs)) : 0
        for (var i = 0; i < schedule.length; i++)
            total += holdTimeFor(schedule[i])
        if (schedule.length > 1)
            total += (loopPlayback ? schedule.length : schedule.length - 1)
                     * transitionDurationMs
        return total
    }

    /* ---------- ВЫХОД В ЭФИР: цикл каждый раз с первой страницы ---------- */

    // Задание движок загружает ЗАРАНЕЕ, поэтому таймеры скрипта стартуют
    // до эфира и первая страница «проскакивает». Скрипт опрашивает статус
    // SLRunTime.statusElement (4 = «Running», как в референсных элементах
    // SoftLab) и при КАЖДОМ входе в эфир перезапускает цикл с начала.
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
                _airStarted = true
                restartForAir()
            }
        } catch (e) { }
    }

    function restartForAir() {
        console.log("NewsRoll: выход в эфир — цикл с первой страницы," +
                    " длительность задания = " + duration + " мс")
        startShow()
    }

    // Сводка для диагностики (видно в консоли FDTitle Designer)
    readonly property string debugSummary: _summary

    function holdTimeFor(step) {
        return (step && step.rest) ? showTimeRestMs : showTimeFirstMs
    }

    /* ==================== РАЗБОР ФАЙЛА ==================== */

    // Приводит строку, полученную от XMLHttpRequest, к корректному виду:
    // учитывает BOM UTF-8/UTF-16 и случай, когда UTF-16 LE был прочитан
    // побайтово как Latin-1 ('ÿþ' в начале).
    function decodeText(raw) {
        if (raw.length > 0 && raw.charCodeAt(0) === 0xFEFF)
            raw = raw.substring(1)                       // корректно раскодированный BOM
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
            raw = s2
            if (raw.length > 0 && raw.charCodeAt(0) === 0xFEFF) raw = s2.substring(1)
        }
        return raw
    }

    function trimLine(s) {
        return s.replace(/^\s+/, "").replace(/\s+$/, "")
    }

    // Строит расписание: блоки '#...' -> страницы по sentencesOnFirstPage /
    // sentencesOnNextPage предложений.
    function parseNews(raw) {
        var text = decodeText(raw)
        var lines = text.split(/\r\n|\n|\r/)
        var blocks = []
        var cur = null
        for (var i = 0; i < lines.length; i++) {
            var ln = trimLine(lines[i])
            if (ln === "")
                continue
            if (ln.charAt(0) === "#") {
                var h = trimLine(ln.replace(/^#+/, ""))
                cur = { header: h, lines: [] }
                blocks.push(cur)
            } else if (cur !== null) {
                cur.lines.push(ln)      // строки до первого '#' пропускаются
            }
        }

        var sch = []
        var total = 0
        for (var b = 0; b < blocks.length; b++) {
            var blk = blocks[b]
            var idx = 0
            var first = true
            while (idx < blk.lines.length) {
                var n = first ? sentencesOnFirstPage : sentencesOnNextPage
                var chunk = blk.lines.slice(idx, idx + n)
                sch.push({ header: blk.header, lines: chunk, rest: !first })
                total += chunk.length
                idx += n
                first = false
            }
        }
        _summary = "блоков=" + blocks.length + "; страниц=" + sch.length +
                   "; предложений=" + total
        return sch
    }

    /* ==================== ЗАГРУЗКА ==================== */

    function normalizedUrl() {
        return encodeURI(newsFileUrl.replace(/\\/g, "/"))
    }

    // Если движок ForwardT передаёт содержимое файла «Задание» в QML
    // через свойство контекста — используем его (пробуем типовые имена;
    // отсутствие свойства не является ошибкой).
    function injectedTaskText() {
        var v
        try { v = Data;       if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = Task;       if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = TaskText;   if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = TitleData;  if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = Content;    if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        try { v = Ads;        if (typeof v === "string" && v.length > 0) return v } catch (e) {}
        return ""
    }

    function loadNews(keepPage) {
        var injected = injectedTaskText()
        if (injected !== "") {
            loadError = ""
            var sch0 = parseNews(injected)
            if (!keepPage || JSON.stringify(sch0) !== JSON.stringify(schedule)) {
                schedule = sch0
                startShow()
            }
            return
        }

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var txt = xhr.responseText || ""
                if (txt.length === 0) {
                    loadError = "Файл не найден или пуст: " + newsFileUrl +
                                " (для Qt >= 6.5 задайте переменную окружения" +
                                " QML_XHR_ALLOW_FILE_READ=1)"
                    if (!keepPage) { schedule = []; startShow() }
                    return
                }
                loadError = ""
                var newSch = parseNews(txt)
                if (!keepPage) {
                    schedule = newSch
                    startShow()
                } else if (JSON.stringify(newSch) !== JSON.stringify(schedule)) {
                    // перечитывание по таймеру: если содержимое изменилось —
                    // показ начинается заново, иначе продолжается как было
                    console.log("NewsRoll: файл изменён, показ перезапущен")
                    schedule = newSch
                    startShow()
                }
            }
        }
        try {
            xhr.open("GET", normalizedUrl())
            xhr.send()
        } catch (e) {
            loadError = "Не удалось открыть файл: " + e
            schedule = []
            if (!keepPage) startShow()
        }
    }

    /* ==================== НАСТРОЙКИ ИЗ NewsRoll.ini ==================== */

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
    // Комментарий после значения отделяется « ; » (пробел-;-пробел).
    function applySettingsIni(raw) {
        var types = {
            newsFileUrl: "string",
            showTimeFirstMs: "int",    showTimeRestMs: "int",
            transitionStyle: "string", transitionDurationMs: "int",
            headerSwapMs: "int",       loopPlayback: "bool",
            sentencesOnFirstPage: "int", sentencesOnNextPage: "int",
            reloadIntervalMs: "int",   splashDurationMs: "int",
            fontFamily: "string",      enableOutline: "bool",
            panelColor: "color",       panelBorderColor: "color",
            headerBgColor: "color",    headerTextColor: "color",
            textColor: "color",        accentColor: "color",
            errorColor: "color",       outlineColor: "color"
        }
        var lines = decodeText(raw).split(/\r\n|\n|\r/)
        var applied = 0
        for (var i = 0; i < lines.length; i++) {
            var ln = trimLine(lines[i])
            if (ln === "" || ln.charAt(0) === ";" || ln.charAt(0) === "[")
                continue
            var eq = ln.indexOf("=")
            if (eq < 1) continue
            var key = trimLine(ln.substring(0, eq))
            var val = trimLine(ln.substring(eq + 1))
            var ci = val.search(/\s;\s/)
            if (ci >= 0)
                val = trimLine(val.substring(0, ci))
            if (val.charAt(0) === ";")
                val = ""                 // значение — только комментарий
            if (val === "" || !(key in types)) continue
            var t = types[key]
            if (t === "bool") {
                root[key] = /^(1|true|да|yes|on)$/i.test(val)
            } else if (t === "int") {
                var n = parseInt(val, 10)
                if (!isNaN(n)) root[key] = n
            } else {
                root[key] = val
            }
            applied++
        }
        if (applied > 0)
            console.log("NewsRoll: из NewsRoll.ini применено значений: " + applied)
    }

    function loadSettings() {
        console.log("NewsRoll: настройки " + settingsUrl)
        readTextAsync(settingsUrl,
            function (txt) {
                try { applySettingsIni(txt) } catch (e) {
                    console.log("NewsRoll: ошибка NewsRoll.ini: " + e)
                }
                loadNews(false)
            },
            function () {
                console.log("NewsRoll: NewsRoll.ini не найден или пуст —" +
                            " используются значения свойств из QML")
                loadNews(false)
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

    // Начало показа: заставка (если включена), затем первая страница
    function startShow() {
        if (splashDurationMs > 0) {
            showSplash()
            return
        }
        beginShow()
    }

    function showSplash() {
        holdTimer.stop()
        flipAnim.stop()
        slideAnim.stop()
        _transitionActive = false
        introAnim.restart()      // проявить корень: заставка внутри него,
        splashActive = true      // иначе она невидима при opacity: 0
        splashTimer.restart()
    }

    function beginShow() {
        splashActive = false
        splashTimer.stop()
        holdTimer.stop()
        flipAnim.stop()
        slideAnim.stop()
        _transitionActive = false
        frontIsA = true
        pageA.x = 0; pageA.y = 0
        pageB.x = 0; pageB.y = 0
        rotA.angle = 0
        rotB.angle = -90
        pageB.visible = false
        pageA.visible = true
        currentIdx = -1
        if (schedule.length === 0) {
            currentHeader = (loadError !== "") ? "НЕТ ДАННЫХ" : ""
            headerText.text = currentHeader
            _summary = (loadError !== "") ? ("ошибка: " + loadError) : "файл не содержит блоков '#'"
            return
        }
        applyStep(0)
        introAnim.restart()
    }

    // Немедленно показать шаг idx (без анимации)
    function applyStep(idx) {
        var step = schedule[idx]
        currentIdx = idx
        currentHeader = step.header
        headerText.text = step.header
        pageA.setLines(step.lines)
        holdTimer.interval = holdTimeFor(step)
        holdTimer.restart()
    }

    /* ==================== СМЕНА СТРАНИЦ ==================== */

    function advance() {
        if (schedule.length === 0 || _transitionActive)
            return
        var next = currentIdx + 1
        if (next >= schedule.length) {
            if (!loopPlayback)
                return                          // остаёмся на последней странице
            next = 0
        }
        doTransition(next)
    }

    function doTransition(nextIdx) {
        var step = schedule[nextIdx]
        var outPage = frontIsA ? pageA : pageB
        var inPage  = frontIsA ? pageB : pageA
        var outRot  = frontIsA ? rotA  : rotB
        var inRot   = frontIsA ? rotB  : rotA

        _pendingHeader = step.header
        inPage.setLines(step.lines)
        inPage.visible = true

        var style = String(transitionStyle).toLowerCase()
        var half = Math.max(1, transitionDurationMs / 2)

        if (style === "slideleft" || style === "slideright" ||
            style === "slideup"   || style === "slidedown") {
            // Слайд: старая и новая страницы едут одновременно.
            // Направление — куда движется контент:
            //   slideLeft  -> старая уходит влево (x: 0 -> -w), новая справа (x: +w -> 0)
            //   slideRight -> старая уходит вправо, новая слева
            //   slideUp    -> старая уходит вверх  (y: 0 -> -h), новая снизу
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
            inRot.angle  = 0
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

    // Вызывается посередине смены: меняем заголовок, если начался
    // новый блок (новая строка '#...').
    function transitionMidpoint() {
        if (_pendingHeader !== "" && _pendingHeader !== currentHeader) {
            headerSwapAnim.restart()
        }
    }

    // Вызывается по завершении смены страницы
    function transitionFinished() {
        if (!_transitionActive)
            return
        _transitionActive = false
        var outPage = frontIsA ? pageA : pageB
        outPage.visible = false
        frontIsA = !frontIsA
        currentIdx = (currentIdx + 1) % schedule.length
        var step = schedule[currentIdx]
        currentHeader = step.header
        holdTimer.interval = holdTimeFor(step)
        holdTimer.restart()
    }

    property bool frontIsA: true

    /* ==================== ВИЗУАЛЬНАЯ ЧАСТЬ ==================== */

    opacity: 0     // элемент проявляется после загрузки данных (introAnim)

    // фон панели
    Rectangle {
        anchors.fill: parent
        color: panelColor
        radius: radiusPx
        border.color: panelBorderColor
        border.width: panelBorderPx
    }

    // Полоса заголовка '#...' — фиксированное место вверху панели
    Rectangle {
        id: headerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: marginPx
        height: Math.round(headerFontPx * 1.75)
        radius: radiusPx
        color: headerBgColor

        // акцентная полоса слева
        Rectangle {
            id: accentBar
            width: accentPx
            radius: accentPx / 2
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: radiusPx / 2
            color: accentColor
        }

        Text {
            id: headerText
            text: ""
            anchors.left: accentBar.right
            anchors.leftMargin: marginPx
            anchors.right: parent.right
            anchors.rightMargin: marginPx
            anchors.verticalCenter: parent.verticalCenter
            font.family: fontFamily
            font.pixelSize: headerFontPx
            font.bold: true
            color: (root.schedule.length === 0) ? root.errorColor : headerTextColor
            elide: Text.ElideRight
            style: enableOutline ? Text.Outline : Text.Normal
            styleColor: outlineColor
        }
    }

    // Слот страницы A (область показа с отсечением) и сама страница.
    // Слот позиционируется якорями, страница внутри имеет свободные x/y
    // (для слайдов) и трансформацию вращения (для переворота).
    Item {
        id: pageSlotA
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: marginPx
        anchors.rightMargin: marginPx
        anchors.topMargin: spacingPx
        anchors.bottomMargin: marginPx
        clip: true

        Item {
            id: pageA
            width: pageSlotA.width
            height: pageSlotA.height
            x: 0
            y: 0
            antialiasing: true
            visible: true

            property var lines: []
            function setLines(ls) { lines = ls }

            transform: Rotation {
                id: rotA
                axis { x: 1; y: 0; z: 0 }    // переворот вокруг горизонтальной оси
                origin.x: pageA.width / 2
                origin.y: pageA.height / 2
                angle: 0
            }

            Column {
                anchors.centerIn: parent
                spacing: spacingPx
                Repeater {
                    model: pageA.lines
                    Text {
                        width: pageA.width
                        text: modelData
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        font.family: root.fontFamily
                        font.pixelSize: root.textFontPx
                        color: root.textColor
                        style: root.enableOutline ? Text.Outline : Text.Normal
                        styleColor: root.outlineColor
                    }
                }
            }
        }
    }

    Item {
        id: pageSlotB
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: marginPx
        anchors.rightMargin: marginPx
        anchors.topMargin: spacingPx
        anchors.bottomMargin: marginPx
        clip: true

        Item {
            id: pageB
            width: pageSlotB.width
            height: pageSlotB.height
            x: 0
            y: 0
            antialiasing: true
            visible: false

            property var lines: []
            function setLines(ls) { lines = ls }

            transform: Rotation {
                id: rotB
                axis { x: 1; y: 0; z: 0 }
                origin.x: pageB.width / 2
                origin.y: pageB.height / 2
                angle: -90
            }

            Column {
                anchors.centerIn: parent
                spacing: spacingPx
                Repeater {
                    model: pageB.lines
                    Text {
                        width: pageB.width
                        text: modelData
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        font.family: root.fontFamily
                        font.pixelSize: root.textFontPx
                        color: root.textColor
                        style: root.enableOutline ? Text.Outline : Text.Normal
                        styleColor: root.outlineColor
                    }
                }
            }
        }
    }

    // Сообщение об ошибке загрузки — вместо предложений
    Text {
        visible: root.schedule.length === 0 && root.loadError !== ""
        anchors.centerIn: parent
        width: parent.width - 2 * marginPx
        text: root.loadError
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        font.family: fontFamily
        font.pixelSize: Math.round(textFontPx * 0.8)
        color: errorColor
    }

    // --- заставка (по типу WeatherRoll) ---
    Item {
        id: staticSplash
        anchors.fill: parent
        visible: root.splashActive
        z: 10

        Rectangle { anchors.fill: parent; color: "#FF0B1B33"; radius: radiusPx }

        Column {
            anchors.centerIn: parent
            spacing: Math.round(26 * root.k)

            Rectangle {
                id: pulseRing
                width: Math.round(120 * root.k)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#00000000"
                border.color: root.accentColor
                border.width: Math.max(2, Math.round(5 * root.k))

                SequentialAnimation {
                    id: pulseAnim
                    running: root.splashActive
                    loops: Animation.Infinite
                    NumberAnimation { target: pulseRing; property: "scale"; from: 0.85; to: 1.15; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: pulseRing; property: "scale"; from: 1.15; to: 0.85; duration: 900; easing.type: Easing.InOutQuad }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u2739"
                    color: root.accentColor
                    font.pixelSize: Math.round(48 * root.k)
                }
            }

            Text {
                text: "\u041D\u041E\u0412\u041E\u0421\u0422\u0418"   // «НОВОСТИ»
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.fontFamily
                font.pixelSize: Math.round(52 * root.k)
                font.bold: true
                color: "#FFFFFFFF"
                style: Text.Outline
                styleColor: root.outlineColor
            }
        }
    }

    /* ==================== АНИМАЦИИ И ТАЙМЕРЫ ==================== */

    // Проявление элемента после загрузки файла
    SequentialAnimation {
        id: introAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 400 }
    }

    // Переворот: текущая страница складывается вверх, следующая
    // разворачивается на её месте; в середине меняется заголовок
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

    // Слайд: старая и новая страницы едут одновременно, заголовок
    // меняется посередине движения
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
            PauseAnimation { id: slidePause; duration: 350 }
            ScriptAction { script: root.transitionMidpoint() }
        }
        onStopped: root.transitionFinished()
    }

    // Смена заголовка '#...' — затемнение и появление нового текста
    SequentialAnimation {
        id: headerSwapAnim
        NumberAnimation {
            target: headerText; property: "opacity"
            to: 0; duration: Math.max(1, headerSwapMs / 2)
        }
        ScriptAction { script: { headerText.text = root._pendingHeader; root.currentHeader = root._pendingHeader } }
        NumberAnimation {
            target: headerText; property: "opacity"
            to: 1; duration: Math.max(1, headerSwapMs / 2)
        }
    }

    // Время удержания текущей страницы
    Timer {
        id: holdTimer
        interval: showTimeFirstMs
        repeat: false
        onTriggered: root.advance()
    }

    // Статическая заставка (3–8 секунд, ограничение как в WeatherRoll)
    Timer {
        id: splashTimer
        interval: Math.min(8000, Math.max(3000, splashDurationMs))
        onTriggered: root.beginShow()
    }

    // Периодическое перечитывание (reloadIntervalMs > 0):
    // вместе с данными обновляются и настройки NewsRoll.ini
    Timer {
        id: reloadTimer
        interval: Math.max(1000, reloadIntervalMs)
        running: reloadIntervalMs > 0 && root.opacity > 0.99
        repeat: true
        onTriggered: root.reloadAll()
    }

    Component.onCompleted: {
        console.log("NewsRoll: загрузка " + newsFileUrl)
        loadSettings()      // ini -> загрузка данных
    }
}
