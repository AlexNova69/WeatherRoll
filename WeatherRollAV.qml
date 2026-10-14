import QtQuick 2.3
import QtMultimedia 5.6

/* ============================================================================
   WeatherRollAV.qml — опциональная мультимедиа-обёртка для WeatherRoll.qml

   Загружается главным скриптом через Loader. Если движок QML собран БЕЗ
   QtMultimedia (типично для FDTitle Designer), загрузка этого файла
   завершается ошибкой — Loader сообщает об этом, и WeatherRoll переходит
   на статическую заставку без музыки. Благодаря выносу в отдельный файл
   основной скрипт остаётся работоспособным в любой сборке Qt.

   Интерфейс (вызывается из WeatherRoll.qml):
     playIntro(url)      — видео-заставка в начале показа;
     playOutro(url)      — видео в конце показа;
     startMusic(url, vol) — музыка по кругу (wav/mp3);
     stopMusic()         — остановить музыку.
   Сигналы:
     introFinished()     — начальное видео закончилось;
     outroFinished()     — конечное видео закончилось;
     mediaError(tag, message) — ошибка (tag: "intro" | "outro" | "music").
   ============================================================================ */

Item {
    id: av

    signal introFinished()
    signal outroFinished()
    signal mediaError(string tag, string message)

    property string mode: ""            // "" | "intro" | "outro"
    property real videoVolume: 1.0      // громкость видео-заставок 0..1

    function playIntro(url) {
        mode = "intro"
        splashVideo.visible = true
        splashVideo.volume = videoVolume
        splashVideo.source = url
        splashVideo.play()
    }

    function playOutro(url) {
        mode = "outro"
        splashVideo.visible = true
        splashVideo.volume = videoVolume
        splashVideo.source = url
        splashVideo.play()
    }

    function startMusic(url, vol) {
        music.stop()
        music.source = url
        music.volume = vol
        music.loops = Audio.Infinite
        music.play()
    }

    function stopMusic() {
        music.stop()
    }

    Video {
        id: splashVideo
        anchors.fill: parent
        autoPlay: false
        fillMode: VideoOutput.PreserveAspectCrop
        visible: false

        onStatusChanged: {
            if (status === MediaPlayer.EndOfMedia) {
                var wasIntro = (av.mode === "intro")
                av.mode = ""
                visible = false
                if (wasIntro) av.introFinished()
                else av.outroFinished()
            }
        }

        onError: {
            if (error !== MediaPlayer.NoError)
                av.mediaError(av.mode || "video", errorString)
        }
    }

    Audio {
        id: music
        autoLoad: true
        loops: Audio.Infinite

        onError: {
            if (error !== MediaPlayer.NoError)
                av.mediaError("music", errorString)
        }
    }
}
