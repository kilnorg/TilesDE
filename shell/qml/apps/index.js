.pragma library
// Native TilesDE apps: AppPage name (tile label) -> QML file under apps/. Names not listed fall back to the prototype pages.
// App contract: root Item filling the page below the status bar; `signal closeRequested`; uses Theme, Pivot/PivotPage,
// MetroListRow, MetroTextField, AppBar, TileGlyph; persists via AppStore.load(key, fallback) / AppStore.save(key, value).
var entries = {
    "Clock": "ClockApp.qml",
    "Calendar": "CalendarApp.qml",
    "Notes": "NotesApp.qml",
    "Phone": "PhoneApp.qml",
    "Messages": "MessagesApp.qml",
    "Weather": "WeatherApp.qml",
    "Calculator": "CalculatorApp.qml",
    "Files": "FilesApp.qml",
    "Music": "MusicApp.qml",
    "People": "PeopleApp.qml",
    "Mail": "MailApp.qml",
    "Terminal": "TerminalApp.qml",
    "Browser": "BrowserApp.qml",
    "Photos": "PhotosApp.qml",
    "Camera": "CameraApp.qml",
    "Videos": "VideosApp.qml",
    "Maps": "MapsApp.qml",
    "Store": "StoreApp.qml",
    "Wallet": "WalletApp.qml",
    "Reminders": "RemindersApp.qml",
    "Voice Recorder": "RecorderApp.qml",
    "Games": "GamesApp.qml",
    "Podcasts": "PodcastsApp.qml",
    "Radio": "RadioApp.qml",
    "Noxal": "NoxalApp.qml",
    "Contacts": "PeopleApp.qml",
    "Alarms": "ClockApp.qml",
    "Stopwatch": "ClockApp.qml"
}
function source(name) { return entries[name] ? "apps/" + entries[name] : "" }
