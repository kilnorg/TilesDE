#include <QElapsedTimer>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSize>
#include "AppModel.h"
#include "AppStore.h"
#include "Sys.h"
#include "ImBridge.h"
#include "Personalise.h"
#include "Session.h"
#include "Services.h"

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("flowde-shell");
    // Compositor mode: the shell is the Wayland compositor and owns the session (QtWayland.Compositor, see qml/CompositorLayer.qml).
    // Default: on whenever Qt is not itself a Wayland/X11/desktop client (eglfs/linuxfb on a phone). TILES_COMPOSITOR=1 forces it
    // (nested inside Sway for development), TILES_COMPOSITOR=0 forces the Sway-hosted mode (tiles-wm.py).
    const QString plat = QGuiApplication::platformName(), forced = qEnvironmentVariable("TILES_COMPOSITOR");
    const bool hosted = plat == "wayland" || plat == "wayland-egl" || plat == "xcb" || plat == "cocoa" || plat == "windows" || plat == "offscreen" || plat == "minimal";
    const bool compositorMode = forced == "1" || (forced != "0" && !hosted);
    const QString socket = qEnvironmentVariable("TILES_SOCKET", "tiles-0");
    if (compositorMode) {
        qputenv("TILES_COMPOSITOR_ACTIVE", "1");
        qputenv("WAYLAND_DISPLAY", socket.toUtf8());        // children (Sys.launch / AppModel.launch) connect to the shell
    }
    // personalisation store (QML singleton "Personalise"); created here so env overrides apply before the UI loads.
    // FLOWDE_PRESET=<preset>, FLOWDE_SCHEME=dark|amoled|light override the stored values (and are saved like any change).
    Personalise *pers = Personalise::instance();
    if (qEnvironmentVariableIsSet("FLOWDE_PRESET")) pers->applyPreset(qEnvironmentVariable("FLOWDE_PRESET"));
    if (qEnvironmentVariableIsSet("FLOWDE_SCHEME")) pers->setScheme(qEnvironmentVariable("FLOWDE_SCHEME"));
    Services services;
    AppModel apps;
    AppStore appStore;
    Sys sys;
    Session session(compositorMode);
    ImBridge imBridge;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Services", &services);
    engine.rootContext()->setContextProperty("Apps", &apps);
    engine.rootContext()->setContextProperty("AppStore", &appStore);
    engine.rootContext()->setContextProperty("Sys", &sys);
    engine.rootContext()->setContextProperty("Session", &session);
    engine.rootContext()->setContextProperty("ImBridge", &imBridge);
    engine.rootContext()->setContextProperty("CompositorMode", compositorMode);
    engine.rootContext()->setContextProperty("CompositorSocket", socket);
    engine.rootContext()->setContextProperty("StartPage", qEnvironmentVariable("FLOWDE_START", "lock"));
    engine.rootContext()->setContextProperty("StartTheme", qEnvironmentVariable("FLOWDE_THEME", "Tiles"));
    // FLOWDE_SIZE=WxH: window size (default 540x1170, the design size). The UI scales to the window width.
    QSize startSize(540, 1170);
    const QStringList wh = qEnvironmentVariable("FLOWDE_SIZE").split('x');
    if (wh.size() == 2 && wh[0].toInt() >= 100 && wh[1].toInt() >= 100) startSize = QSize(wh[0].toInt(), wh[1].toInt());
    engine.rootContext()->setContextProperty("StartSize", startSize);
    engine.rootContext()->setContextProperty("StartDark", pers->scheme() != "light");
    engine.loadFromModule("FlowShell", "Main");
    if (engine.rootObjects().isEmpty()) return 1;

    // frame-time stats (FLOWDE_FPS=1): print avg/max ms per 120 frames of continuous rendering
    if (qEnvironmentVariable("FLOWDE_FPS") == "1") {
        auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        static QElapsedTimer t; static qint64 last = 0, sum = 0, mx = 0; static int n = 0;
        t.start();
        QObject::connect(w, &QQuickWindow::frameSwapped, w, [] {
            qint64 now = t.nsecsElapsed(); if (last) { qint64 d = now - last; sum += d; mx = qMax(mx, d); ++n; }
            last = now;
            if (n == 120) { qInfo("frametime avg %.1f ms max %.1f ms (%d frames)", sum / n / 1e6, mx / 1e6, n); sum = mx = 0; n = 0; }
        });
    }
    return app.exec();
}
