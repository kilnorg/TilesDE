#pragma once
#include <QAbstractListModel>
#include <QDateTime>
#include <QLocalServer>
#include <QLocalSocket>
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include <functional>

class QProcess;

// Notification history. Fed by the freedesktop notification server (NotificationServer in Services.cpp),
// the control socket {"notify":..} verb, or demo seeds when FLOWDE_MOCK=1. Persisted in
// ~/.local/share/tilesde/notifications.json.
class NotifModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QVariantMap counts READ counts NOTIFY countChanged)   // lowercase app name -> number of notifications
    Q_PROPERTY(bool serverActive READ serverActive NOTIFY countChanged)
public:
    enum Roles { AppRole = Qt::UserRole + 1, TitleRole, BodyRole, TimeRole, IdRole, UrgencyRole };
    explicit NotifModel(QObject *p = nullptr);
    int rowCount(const QModelIndex & = {}) const override { return m_items.size(); }
    QVariant data(const QModelIndex &i, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    QVariantMap counts() const;
    bool serverActive() const { return m_serverActive; }
    void setServerActive(bool v) { m_serverActive = v; emit countChanged(); }
    Q_INVOKABLE void dismiss(int row);
    Q_INVOKABLE void clear();
    Q_INVOKABLE int countFor(const QString &app) const;
    Q_INVOKABLE QString latestTitle(const QString &app) const;
    Q_INVOKABLE QString latestBody(const QString &app) const;
    Q_INVOKABLE void add(const QString &app, const QString &title, const QString &body);
    // used by the D-Bus server: returns the id (replacesId reused when it exists)
    uint post(const QString &app, const QString &title, const QString &body, int urgency, uint replacesId);
    bool remove(uint id);
signals:
    void countChanged();
    void closed(uint id, uint reason);   // 2 = dismissed by the user, 3 = closed by CloseNotification
private:
    struct N { uint id; QString app, title, body; qint64 ts; int urgency; };
    void save();
    void load();
    static QString plain(const QString &markup);
    QVector<N> m_items;
    uint m_nextId = 1;
    bool m_serverActive = false;
    QTimer m_ageTimer, m_saveTimer;
};

// Real device services (each has an `...Available` companion; unavailable hardware keeps a local value)
// plus the shell control socket (JSON lines).
// The compositor connects as a client and sends {"event":"gesture","name":"home"} etc.
// Sources: wifi/airplane nmcli, bluetooth bluetoothctl, volume wpctl, brightness /sys/class/backlight + brightnessctl,
// battery /sys/class/power_supply (what UPower reads), clock the system clock.
class Services : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool wifi READ wifi WRITE setWifi NOTIFY changed)
    Q_PROPERTY(bool bluetooth READ bluetooth WRITE setBluetooth NOTIFY changed)
    Q_PROPERTY(bool airplane READ airplane WRITE setAirplane NOTIFY changed)
    Q_PROPERTY(bool rotationLock MEMBER m_rotLock NOTIFY changed)
    Q_PROPERTY(bool dnd MEMBER m_dnd NOTIFY changed)
    Q_PROPERTY(double brightness READ brightness WRITE setBrightness NOTIFY changed)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY changed)
    Q_PROPERTY(int battery READ battery NOTIFY changed)
    Q_PROPERTY(bool charging MEMBER m_charging NOTIFY changed)
    Q_PROPERTY(int signal MEMBER m_signal NOTIFY changed)
    Q_PROPERTY(QString wifiName MEMBER m_wifiName NOTIFY changed)
    Q_PROPERTY(bool wifiAvailable MEMBER m_wifiAvail NOTIFY changed)
    Q_PROPERTY(bool bluetoothAvailable MEMBER m_btAvail NOTIFY changed)
    Q_PROPERTY(bool batteryAvailable MEMBER m_battAvail NOTIFY changed)
    Q_PROPERTY(bool volumeAvailable MEMBER m_volAvail NOTIFY changed)
    Q_PROPERTY(bool brightnessAvailable MEMBER m_brightAvail NOTIFY changed)
    Q_PROPERTY(QString glassQuality MEMBER m_glass NOTIFY changed)
    Q_PROPERTY(bool reduceTransparency MEMBER m_reduceTransp NOTIFY changed)
    Q_PROPERTY(bool reduceMotion MEMBER m_reduceMotion NOTIFY changed)
    Q_PROPERTY(NotifModel *notifications READ notifications CONSTANT)
    Q_PROPERTY(bool mock READ mock CONSTANT)
    Q_PROPERTY(bool asleep READ asleep NOTIFY asleepChanged)   // screen off: pollers stopped
public:
    explicit Services(QObject *p = nullptr);
    NotifModel *notifications() { return &m_notifs; }
    int battery() const { return m_battery; }
    bool mock() const { return m_mock; }
    bool asleep() const { return m_asleep; }
    bool wifi() const { return m_wifi; }
    bool bluetooth() const { return m_bt; }
    bool airplane() const { return m_airplane; }
    double brightness() const { return m_brightness; }
    double volume() const { return m_volume; }
    void setWifi(bool v);
    void setBluetooth(bool v);
    void setAirplane(bool v);
    void setBrightness(double v);
    void setVolume(double v);
    Q_INVOKABLE void send(const QString &json);   // shell -> compositor
signals:
    void asleepChanged();
    void changed();
    void gesture(const QString &name);            // home|back|switcher|shade|qs|rotate
    void command(const QString &key, const QString &value);  // test/theme hook
private:
    void onLine(const QByteArray &line);
    void poll();
    void pollSys();
    void run(const QString &prog, const QStringList &args, std::function<void(int, const QString &)> cb = {});
    bool held() const { return QDateTime::currentMSecsSinceEpoch() < m_holdUntil; }
    void hold() { m_holdUntil = QDateTime::currentMSecsSinceEpoch() + 2500; }
    bool m_wifi = true, m_bt = true, m_airplane = false, m_rotLock = true, m_dnd = false;
    double m_brightness = 0.7, m_volume = 0.45;
    int m_battery = 78, m_signal = 3;
    bool m_charging = false, m_mock = false, m_reduceTransp = false, m_reduceMotion = false;
    bool m_wifiAvail = false, m_btAvail = false, m_battAvail = false, m_volAvail = false, m_brightAvail = false;
    QString m_glass = "full", m_wifiName, m_backlight;
    qint64 m_holdUntil = 0;
    bool m_asleep = false;
    NotifModel m_notifs;
    QLocalServer m_server;
    QList<QLocalSocket *> m_clients;
    QTimer m_pollTimer, m_volTimer, m_brightTimer;
};
