#include "Session.h"
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
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

void Session::onPrepareForSleep(bool start) {
    if (start) { emit lockRequested(); }       // lock before the machine sleeps so the lock screen is what wakes up
    else { emit resumed(); if (m_screenOn) armIdle(); }
}
void Session::manager(const char *method) {
    QDBusInterface mgr(LD, "/org/freedesktop/login1", "org.freedesktop.login1.Manager", QDBusConnection::systemBus());
    QDBusMessage r = mgr.call(method, false);      // interactive = false
    if (r.type() == QDBusMessage::ErrorMessage) qWarning() << "Session:" << method << r.errorMessage();
}
void Session::suspend() { manager("Suspend"); }
void Session::powerOff() { manager("PowerOff"); }
void Session::reboot() { manager("Reboot"); }
void Session::lockSession() { emit lockRequested(); }

bool Session::writeBacklight(int value) {
    if (m_backlight.isEmpty()) return false;
    QDBusInterface s(LD, "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", QDBusConnection::systemBus());
    QDBusMessage r = s.call("SetBrightness", "backlight", m_backlight, uint(qMax(0, value)));
    if (r.type() == QDBusMessage::ErrorMessage) { qWarning() << "Session: SetBrightness" << r.errorMessage(); return false; }
    return true;
}
void Session::setBacklight(double f) {
    if (m_maxBright <= 0) return;
    writeBacklight(qBound(1, int(f * m_maxBright + 0.5), m_maxBright));
}
// "Screen off" is backlight 0 plus the shell swallowing input, not DPMS: on some DSI panels (Redmi K20 Pro) the panel does not
// always come back after a DPMS off.
void Session::screenOff() {
    if (!m_screenOn) return;
    QFile f("/sys/class/backlight/" + m_backlight + "/brightness");
    if (f.open(QIODevice::ReadOnly)) m_savedBright = f.readAll().trimmed().toInt();
    writeBacklight(0);
    m_screenOn = false; m_idleTimer.stop(); emit screenOnChanged();
}
void Session::screenWake() {
    if (m_screenOn) return;
    writeBacklight(m_savedBright > 0 ? m_savedBright : qMax(1, m_maxBright / 2));
    m_screenOn = true; armIdle(); emit screenOnChanged();
}

// ---- iio-sensor-proxy ---------------------------------------------------------------------------------------------
void Session::setupSensors() {
    QDBusConnection sys = QDBusConnection::systemBus();
    QDBusInterface sp("net.hadess.SensorProxy", "/net/hadess/SensorProxy", "net.hadess.SensorProxy", sys);
    if (!sp.isValid()) return;
    m_hasAccel = sp.property("HasAccelerometer").toBool();
    if (!m_hasAccel) return;
    sp.call("ClaimAccelerometer");
    m_orient = sp.property("AccelerometerOrientation").toString();
    if (m_orient.isEmpty() || m_orient == "undefined") m_orient = "normal";
    sys.connect("net.hadess.SensorProxy", "/net/hadess/SensorProxy", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                this, SLOT(onSensorProps(QString, QVariantMap, QStringList)));
    emit orientationChanged();
}
void Session::onSensorProps(const QString &, const QVariantMap &changed, const QStringList &) {
    if (!changed.contains("AccelerometerOrientation")) return;
    const QString o = changed.value("AccelerometerOrientation").toString();
    if (o.isEmpty() || o == "undefined" || o == m_orient) return;
    m_orient = o; emit orientationChanged();
}
