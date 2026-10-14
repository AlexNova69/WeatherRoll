import QtQuick 2.3
import QtQuick.Window 2.2

/* ============================================================================
   WeatherRollStandalone.qml — автономный полноэкранный запуск WeatherRoll.

   Запуск (Qt, входящий в состав установленного ПО, либо любой Qt >= 5.6):
       qml.exe WeatherRollStandalone.qml
   или
       qmlscene WeatherRollStandalone.qml        (Linux)

   Все настройки (файлы, фон, видео, музыка, переходы) — в WeatherRoll.qml.
   Клавиши во время показа: <-/↑ — предыдущая секция, →/↓/Пробел — следующая,
   Esc/Q — конечная заставка, повторное нажатие — выход (allowQuit: true).
   ============================================================================ */

Window {
    id: win
    visible: true
    width: 1280
    height: 720
    visibility: Window.FullScreen
    title: "WeatherRoll — прогноз погоды"
    color: "#0B1B33"

    WeatherRoll {
        anchors.fill: parent
        focus: true
        allowQuit: true
    }
}
