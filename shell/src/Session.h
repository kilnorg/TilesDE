#pragma once
#include <QDBusUnixFileDescriptor>
#include <QElapsedTimer>
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Native session integration (context property "Session"): logind (power button, suspend, lock, idle, backlight),
// iio-sensor-proxy (screen orientation). Only active when the shell is the compositor; under Sway the shell leaves
// these to Sway and the session scripts.
class Session : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active CONSTANT)
    Q_PROPERTY(bool screenOn READ screenOn NOTIFY screenOnChanged)
    Q_PROPERTY(int idleTimeout READ idleTimeout WRITE setIdleTimeout NOTIFY idleTimeoutChanged)   // seconds, 0 = never
    Q_PROPERTY(bool idleInhibited MEMBER m_idleInhibited NOTIFY idleInhibitedChanged)             // e.g. while video plays
    Q_PROPERTY(QString orientation READ orientation NOTIFY orientationChanged)                    // normal|left-up|right-up|bottom-up
    Q_PROPERTY(bool hasAccelerometer READ hasAccelerometer NOTIFY orientationChanged)
public:
    explicit Session(bool active, QObject *p = nullptr);
    bool active() const { return m_active; }
    bool screenOn() const { return m_screenOn; }
    int idleTimeout() const { return m_idleSec; }
    void setIdleTimeout(int s);
    QString orientation() const { return m_orient; }
    bool hasAccelerometer() const { return m_hasAccel; }
    Q_INVOKABLE void screenOff();
    Q_INVOKABLE void screenWake();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void powerOff();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void lockSession();       // loginctl lock-session equivalent: emits lockRequested for every listener
    Q_INVOKABLE void setBacklight(double fraction);   // 0..1 through logind (no helper process, no root)
    bool eventFilter(QObject *o, QEvent *e) override;
signals:
    void screenOnChanged();
    void idleTimeoutChanged();
    void idleInhibitedChanged();
    void orientationChanged();
    void powerPressed();                  // short press of the power button
    void powerHeld();                     // held ~1.2 s: power menu
    void lockRequested();                 // logind Lock, or the machine is about to sleep
    void resumed();
    void volumeKey(int dir);              // +1 / -1
    void idle();                          // no input for idleTimeout seconds
private slots:
    void onPrepareForSleep(bool start);
    void onSensorProps(const QString &iface, const QVariantMap &changed, const QStringList &);
private:
    void setupLogind();
    void setupSensors();
    void armIdle();
    void manager(const char *method);
    bool writeBacklight(int value);
    bool m_active, m_screenOn = true, m_hasAccel = false, m_idleInhibited = false;
    int m_idleSec = 60, m_savedBright = -1;
    QString m_orient = "normal", m_backlight;
    int m_maxBright = 0;
    QDBusUnixFileDescriptor m_inhibitFd;
    QTimer m_idleTimer, m_holdTimer;
    bool m_holdFired = false;
};
