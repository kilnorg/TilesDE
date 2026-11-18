.pragma library
// Settings pages that the Settings home merges into its list.
// component: a QML file path relative to the qml root, to load with Loader.source from a file in shell/qml/.
// Example: Loader { source: "settings2/SettingsDisplay.qml" }

var entries = [
    { key: "display", title: "display", subtitle: "brightness, motion and glass", component: "settings2/SettingsDisplay.qml" },
    { key: "notifications", title: "notifications+actions", subtitle: "recent alerts and quick toggles", component: "settings2/SettingsNotifications.qml" },
    { key: "battery", title: "battery saver", subtitle: "usage and saver options", component: "settings2/SettingsBattery.qml" },
    { key: "network", title: "network+", subtitle: "wi-fi, bluetooth and data", component: "settings2/SettingsNetwork.qml" },
    { key: "sound", title: "sound", subtitle: "volume, ringtone and quiet", component: "settings2/SettingsSound.qml" },
    { key: "email", title: "email+accounts", subtitle: "sync and mail accounts", component: "settings2/SettingsEmail.qml" },
    { key: "devices", title: "device hub", subtitle: "connect to and manage your devices", component: "settings2/SettingsDevices.qml" },
    { key: "about", title: "extras+info", subtitle: "details about this phone", component: "settings2/SettingsAbout.qml" }
]
