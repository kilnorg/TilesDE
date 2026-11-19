#include "Session.h"
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDir>
#include <QEvent>
#include <QFile>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QSettings>
#include <QDebug>

static const char *LD = "org.freedesktop.login1";

Session::Session(bool active, QObject *p) : QObject(p), m_active(active) {
    QSettings s;   // idle timeout is kept across runs
    m_idleSec = s.value("session/idleTimeout", 60).toInt();
    m_idleTimer.setSingleShot(true);
    connect(&m_idleTimer, &QTimer::timeout, this, [this] { if (!m_idleInhibited && m_screenOn) emit idle(); else armIdle(); });
    m_holdTimer.setSingleShot(true); m_holdTimer.setInterval(1200);
    connect(&m_holdTimer, &QTimer::timeout, this, [this] { m_holdFired = true; emit powerHeld(); });
    if (!m_active) return;
    qApp->installEventFilter(this);
    setupLogind();
    setupSensors();
    armIdle();
}

void Session::setIdleTimeout(int s) {
    if (s == m_idleSec) return;
    m_idleSec = s; QSettings().setValue("session/idleTimeout", s);
    armIdle(); emit idleTimeoutChanged();
}
void Session::armIdle() { if (m_active && m_idleSec > 0 && m_screenOn) m_idleTimer.start(m_idleSec * 1000); else m_idleTimer.stop(); }

bool Session::eventFilter(QObject *, QEvent *e) {
    switch (e->type()) {
    case QEvent::KeyPress: case QEvent::KeyRelease: {
        auto *k = static_cast<QKeyEvent *>(e);
        const bool down = e->type() == QEvent::KeyPress;
        if (k->key() == Qt::Key_PowerOff || k->key() == Qt::Key_Sleep || k->key() == Qt::Key_Suspend) {
            if (k->isAutoRepeat()) return true;
            if (down) { m_holdFired = false; m_holdTimer.start(); }
            else { m_holdTimer.stop(); if (!m_holdFired) emit powerPressed(); }
            return true;
        }
        if (k->key() == Qt::Key_VolumeUp || k->key() == Qt::Key_VolumeDown) {
            if (down) emit volumeKey(k->key() == Qt::Key_VolumeUp ? 1 : -1);
            return true;
        }
        armIdle();
        break; }
    case QEvent::TouchBegin: case QEvent::TouchUpdate: case QEvent::TouchEnd:
    case QEvent::MouseButtonPress: case QEvent::MouseMove: armIdle(); break;
    default: break;
    }
    return false;
}

// ---- logind -----------------------------------------------------------------------------------------------------
void Session::setupLogind() {
    QDBusConnection sys = QDBusConnection::systemBus();
    if (!sys.isConnected()) { qWarning() << "Session: no system bus"; return; }
    // the shell owns the hardware keys: logind must not power off / suspend on them (held for the life of the process)
    QDBusInterface mgr(LD, "/org/freedesktop/login1", "org.freedesktop.login1.Manager", sys);
    QDBusReply<QDBusUnixFileDescriptor> r = mgr.call("Inhibit", "handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch",
                                                     "TilesDE", "the shell handles the power button and lid", "block");
    if (r.isValid()) m_inhibitFd = r.value(); else qWarning() << "Session: logind Inhibit failed:" << r.error().message();
    sys.connect(LD, "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "PrepareForSleep", this, SLOT(onPrepareForSleep(bool)));
    // Lock/Unlock are sent to our session object (loginctl lock-session)
    QDBusReply<QDBusObjectPath> sp = mgr.call("GetSession", qEnvironmentVariable("XDG_SESSION_ID", "auto"));
    const QString path = sp.isValid() ? sp.value().path() : QStringLiteral("/org/freedesktop/login1/session/auto");
    sys.connect(LD, path, "org.freedesktop.login1.Session", "Lock", this, SIGNAL(lockRequested()));
    // backlight device
    const QStringList bl = QDir("/sys/class/backlight").entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    if (!bl.isEmpty()) {
        m_backlight = bl.first();
        QFile f("/sys/class/backlight/" + m_backlight + "/max_brightness");
        if (f.open(QIODevice::ReadOnly)) m_maxBright = f.readAll().trimmed().toInt();
    }
}
