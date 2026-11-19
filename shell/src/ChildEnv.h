#pragma once
#include <QProcessEnvironment>

// Environment for third-party apps started by the shell (Sys.launch, AppModel.launch).
// In compositor mode apps must connect to the shell's own Wayland socket, not to a parent compositor, and must not
// inherit the shell's own Qt platform settings (eglfs).
inline QProcessEnvironment childEnv() {
    QProcessEnvironment e = QProcessEnvironment::systemEnvironment();
    e.insert("TILES_MANAGED", "1"); e.insert("MOZ_ENABLE_WAYLAND", "1"); e.insert("MOZ_USE_XINPUT2", "1");
    e.insert("GTK_CSD", "0"); e.insert("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1");
    if (qEnvironmentVariable("TILES_COMPOSITOR_ACTIVE") == "1") {
        e.insert("QT_QPA_PLATFORM", "wayland");
        e.insert("GDK_BACKEND", "wayland");
        e.insert("SDL_VIDEODRIVER", "wayland");
        e.insert("XDG_SESSION_TYPE", "wayland");
        e.insert("XDG_CURRENT_DESKTOP", "TilesDE");
        for (const char *k : {"QT_QPA_EGLFS_INTEGRATION", "QT_QPA_EGLFS_KMS_ATOMIC", "QT_QPA_EGLFS_ALWAYS_SET_MODE",
                              "QT_QPA_EGLFS_HIDECURSOR", "QT_QPA_EGLFS_KMS_CONFIG", "QSG_RHI_BACKEND", "SWAYSOCK"})
            e.remove(k);
    }
    return e;
}
