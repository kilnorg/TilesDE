#include <QElapsedTimer>
#include <QGuiApplication>
#ifdef HAVE_WEBENGINE
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
#endif
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSize>
#include <QTimer>
#include "AppModel.h"
#include "AppStore.h"
#include "Sys.h"
#include "Personalise.h"
#include "Services.h"

int main(int argc, char **argv) {
#ifdef HAVE_WEBENGINE
    QtWebEngineQuick::initialize();   // must run before the QGuiApplication exists
#endif
    QGuiApplication app(argc, argv);
    app.setApplicationName("flowde-shell");
    // personalisation store (QML singleton "Personalise"); created here so env overrides apply before the UI loads.
    // FLOWDE_PRESET=<preset>, FLOWDE_SCHEME=dark|amoled|light override the stored values (and are saved like any change).
    Personalise *pers = Personalise::instance();
    if (qEnvironmentVariableIsSet("FLOWDE_PRESET")) pers->applyPreset(qEnvironmentVariable("FLOWDE_PRESET"));
    if (qEnvironmentVariableIsSet("FLOWDE_SCHEME")) pers->setScheme(qEnvironmentVariable("FLOWDE_SCHEME"));
    Services services;
    AppModel apps;
    AppStore appStore;
    Sys sys;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Services", &services);
    engine.rootContext()->setContextProperty("Apps", &apps);
    engine.rootContext()->setContextProperty("AppStore", &appStore);
    engine.rootContext()->setContextProperty("Sys", &sys);
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

    // frame-time stats (FLOWDE_FPS=1): every 2 s with activity print frames, frames >25/>40 ms (dropped vsyncs) and max.
    // Gaps >250 ms are idle (nothing animating) and ignored, so only animation frames count.
    if (qEnvironmentVariable("FLOWDE_FPS") == "1") {
        auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        static QElapsedTimer t; static qint64 last = 0, mx = 0; static int n = 0, j25 = 0, j40 = 0;
        t.start();
        QObject::connect(w, &QQuickWindow::frameSwapped, w, [] {
            qint64 now = t.nsecsElapsed();
            if (last) { qint64 d = now - last; if (d < 250000000LL) { ++n; mx = qMax(mx, d); if (d > 25000000LL) ++j25; if (d > 40000000LL) ++j40; } }
            last = now;
        });
        auto *rep = new QTimer(w); rep->setInterval(2000);
        QObject::connect(rep, &QTimer::timeout, w, [] {
            if (n) qInfo("frames %d jank25 %d jank40 %d max %.1f ms", n, j25, j40, mx / 1e6);
            n = j25 = j40 = 0; mx = 0;
        });
        rep->start();
    }
    return app.exec();
}
