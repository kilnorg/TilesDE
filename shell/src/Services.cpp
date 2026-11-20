#include "Services.h"
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusError>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QDebug>
#include <algorithm>
#include <cmath>

// ---------------------------------------------------------------- notification model
static QString notifFile() { return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/tilesde/notifications.json"; }

NotifModel::NotifModel(QObject *p) : QAbstractListModel(p) {
    load();
    m_ageTimer.setInterval(30000);
    connect(&m_ageTimer, &QTimer::timeout, this, [this] { if (!m_items.isEmpty()) emit dataChanged(index(0), index(m_items.size() - 1), {TimeRole}); });
    m_ageTimer.start();
    m_saveTimer.setSingleShot(true); m_saveTimer.setInterval(500);
    connect(&m_saveTimer, &QTimer::timeout, this, &NotifModel::save);
}
QHash<int, QByteArray> NotifModel::roleNames() const {
    return {{AppRole, "app"}, {TitleRole, "title"}, {BodyRole, "body"}, {TimeRole, "time"}, {IdRole, "nid"}, {UrgencyRole, "urgency"}};
}
QVariant NotifModel::data(const QModelIndex &i, int r) const {
    if (!i.isValid() || i.row() >= m_items.size()) return {};
    const N &n = m_items[i.row()];
    switch (r) {
    case AppRole: return n.app; case TitleRole: return n.title; case BodyRole: return n.body;
    case IdRole: return n.id; case UrgencyRole: return n.urgency;
    case TimeRole: {
        const qint64 s = (QDateTime::currentMSecsSinceEpoch() - n.ts) / 1000;
        if (s < 60) return "now";
        if (s < 3600) return QString::number(s / 60) + "m";
        if (s < 86400) return QString::number(s / 3600) + "h";
        return QString::number(s / 86400) + "d";
    }
    }
    return {};
}
QVariantMap NotifModel::counts() const {
    QVariantMap m;
    for (const N &n : m_items) { const QString k = n.app.toLower(); m[k] = m.value(k).toInt() + 1; }
    return m;
}
int NotifModel::countFor(const QString &app) const {
    int c = 0; const QString a = app.toLower();
    for (const N &n : m_items) if (n.app.toLower() == a) ++c;
    return c;
}
QString NotifModel::latestTitle(const QString &app) const {
    const QString a = app.toLower();
    for (const N &n : m_items) if (n.app.toLower() == a) return n.title;
    return {};
}
QString NotifModel::latestBody(const QString &app) const {
    const QString a = app.toLower();
    for (const N &n : m_items) if (n.app.toLower() == a) return n.body;
    return {};
}
QString NotifModel::plain(const QString &m) {
    QString s = m;
    s.replace(QRegularExpression("<[^>]*>"), "");
    s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&apos;", "'").replace("&amp;", "&");
    return s.trimmed();
}
void NotifModel::dismiss(int row) {
    if (row < 0 || row >= m_items.size()) return;
    const uint id = m_items[row].id;
    beginRemoveRows({}, row, row); m_items.removeAt(row); endRemoveRows();
    emit countChanged(); emit closed(id, 2); m_saveTimer.start();
}
void NotifModel::clear() {
    QVector<uint> ids; for (const N &n : std::as_const(m_items)) ids << n.id;
    beginResetModel(); m_items.clear(); endResetModel();
    emit countChanged(); for (uint id : ids) emit closed(id, 2);
    m_saveTimer.start();
}
bool NotifModel::remove(uint id) {
    for (int i = 0; i < m_items.size(); ++i) if (m_items[i].id == id) {
        beginRemoveRows({}, i, i); m_items.removeAt(i); endRemoveRows();
        emit countChanged(); emit closed(id, 3); m_saveTimer.start(); return true;
    }
    return false;
}
uint NotifModel::post(const QString &app, const QString &title, const QString &body, int urgency, uint replacesId) {
    const QString a = app.trimmed().isEmpty() ? QString("System") : app.trimmed();
    N n{0, a, plain(title), plain(body), QDateTime::currentMSecsSinceEpoch(), urgency};
    for (int i = 0; replacesId && i < m_items.size(); ++i) if (m_items[i].id == replacesId) {
        n.id = replacesId; m_items[i] = n;
        emit dataChanged(index(i), index(i)); emit countChanged(); m_saveTimer.start();
        return n.id;
    }
    n.id = m_nextId++;
    beginInsertRows({}, 0, 0); m_items.prepend(n); endInsertRows();
    if (m_items.size() > 100) { beginRemoveRows({}, 100, m_items.size() - 1); m_items.resize(100); endRemoveRows(); }
    emit countChanged(); m_saveTimer.start();
    return n.id;
}
void NotifModel::add(const QString &a, const QString &t, const QString &b) { post(a, t, b, 1, 0); }
void NotifModel::save() {
    QJsonArray a;
    for (const N &n : std::as_const(m_items))
        a << QJsonObject{{"id", int(n.id)}, {"app", n.app}, {"title", n.title}, {"body", n.body}, {"ts", double(n.ts)}, {"urgency", n.urgency}};
    QDir().mkpath(QFileInfo(notifFile()).absolutePath());
    QFile f(notifFile());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) f.write(QJsonDocument(a).toJson(QJsonDocument::Compact));
}
void NotifModel::load() {
    QFile f(notifFile());
    if (!f.open(QIODevice::ReadOnly)) return;
    const auto a = QJsonDocument::fromJson(f.readAll()).array();
    for (const auto &v : a) {
        const auto o = v.toObject();
        N n{uint(o["id"].toInt()), o["app"].toString(), o["title"].toString(), o["body"].toString(), qint64(o["ts"].toDouble()), o["urgency"].toInt(1)};
        if (!n.id) continue;
        m_items << n; m_nextId = std::max(m_nextId, n.id + 1);
    }
}

// ---------------------------------------------------------------- org.freedesktop.Notifications (spec 1.2)
class NotificationAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
public:
    NotificationAdaptor(QObject *parent, NotifModel *m) : QDBusAbstractAdaptor(parent), m_model(m) {
        connect(m, &NotifModel::closed, this, &NotificationAdaptor::NotificationClosed);
    }
public slots:
    // Honest capability list: the shade shows plain title/body only (no actions UI yet, markup is stripped).
    QStringList GetCapabilities() { return {"body", "persistence"}; }
    uint Notify(const QString &app, uint replaces, const QString &, const QString &summary, const QString &body,
                const QStringList &, const QVariantMap &hints, int) {
        return m_model->post(app, summary, body, hints.value("urgency", 1).toInt(), replaces);
    }
    void CloseNotification(uint id) { m_model->remove(id); }
    QString GetServerInformation(QString &vendor, QString &version, QString &spec) {
        vendor = "TilesDE"; version = "0.1"; spec = "1.2"; return "flowde-shell";
    }
signals:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &key);
private:
    NotifModel *m_model;
};

// ---------------------------------------------------------------- Services
static QString readFile(const QString &p) { QFile f(p); return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()).trimmed() : QString(); }

void Services::run(const QString &prog, const QStringList &args, std::function<void(int, const QString &)> cb) {
    auto *p = new QProcess(this);
    auto *t = new QTimer(p);
    t->setSingleShot(true);
    connect(t, &QTimer::timeout, p, [p] { p->kill(); });
    connect(p, &QProcess::finished, this, [p, cb](int code, QProcess::ExitStatus st) {
        if (cb) cb(st == QProcess::NormalExit ? code : -1, QString::fromUtf8(p->readAllStandardOutput()));
        p->deleteLater();
    });
    connect(p, &QProcess::errorOccurred, this, [p, cb](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) { if (cb) cb(-2, {}); p->deleteLater(); }
    });
    auto env = QProcessEnvironment::systemEnvironment(); env.insert("LC_ALL", "C"); p->setProcessEnvironment(env);
    p->start(prog, args);
    t->start(4000);
}

Services::Services(QObject *p) : QObject(p) {
    m_mock = qEnvironmentVariable("FLOWDE_MOCK", "0") == "1";
    m_glass = qEnvironmentVariable("FLOWDE_GLASS", "full");
    m_reduceTransp = qEnvironmentVariable("FLOWDE_REDUCE_TRANSPARENCY") == "1";
    m_reduceMotion = qEnvironmentVariable("FLOWDE_REDUCE_MOTION") == "1";

    // notification server on the session bus (never claims the name twice; falls back to history only)
    auto bus = QDBusConnection::sessionBus();
    new NotificationAdaptor(this, &m_notifs);
    if (bus.isConnected() && bus.registerObject("/org/freedesktop/Notifications", this, QDBusConnection::ExportAdaptors)
        && bus.registerService("org.freedesktop.Notifications")) {
        m_notifs.setServerActive(true);
        qInfo() << "notification server registered on the session bus";
    } else {
        qWarning() << "org.freedesktop.Notifications not served:" << bus.lastError().message();
    }
    if (m_mock && m_notifs.rowCount() == 0) {
        m_notifs.add("Messages", "Mara (demo)", "Are we still on for tonight? I booked the table.");
        m_notifs.add("Calendar", "Design review in 15 min (demo)", "Room 4 / video link attached");
    }

    connect(&m_volTimer, &QTimer::timeout, this, [this] {
        run("wpctl", {"set-mute", "@DEFAULT_AUDIO_SINK@", m_volume > 0.005 ? "0" : "1"});
        run("wpctl", {"set-volume", "@DEFAULT_AUDIO_SINK@", QString::number(m_volume, 'f', 2)});
    });
    connect(&m_brightTimer, &QTimer::timeout, this, [this] {
        run("brightnessctl", {"-d", m_backlight, "set", QString::number(std::max(1, int(std::round(m_brightness * 100)))) + "%"});
    });
    m_volTimer.setSingleShot(true); m_volTimer.setInterval(80);
    m_brightTimer.setSingleShot(true); m_brightTimer.setInterval(80);
    poll();
    connect(&m_pollTimer, &QTimer::timeout, this, &Services::poll);
    m_pollTimer.start(10000);

    QString path = qEnvironmentVariable("FLOWDE_SHELL_SOCKET");
    if (path.isEmpty()) {
        QString rt = qEnvironmentVariable("XDG_RUNTIME_DIR", "/tmp");
        path = rt + "/flowde-shell.sock";
    }
    QLocalServer::removeServer(path);
    if (m_server.listen(path)) qInfo() << "flowde-shell control socket" << path;
    connect(&m_server, &QLocalServer::newConnection, this, [this] {
        while (auto *s = m_server.nextPendingConnection()) {
            m_clients << s;
            connect(s, &QLocalSocket::readyRead, this, [this, s] {
                while (s->canReadLine()) onLine(s->readLine());
            });
            connect(s, &QLocalSocket::disconnected, this, [this, s] { m_clients.removeOne(s); s->deleteLater(); });
        }
    });
}

void Services::setWifi(bool v) {
    m_wifi = v; hold(); emit changed();
    if (m_wifiAvail) run("nmcli", {"radio", "wifi", v ? "on" : "off"});
}
void Services::setBluetooth(bool v) {
    m_bt = v; hold(); emit changed();
    if (m_btAvail) run("bluetoothctl", {"power", v ? "on" : "off"});
}
void Services::setAirplane(bool v) {
    m_airplane = v; m_wifi = !v; m_bt = !v; hold(); emit changed();
    if (m_wifiAvail) run("nmcli", {"radio", "all", v ? "off" : "on"});
    if (m_btAvail) run("bluetoothctl", {"power", v ? "off" : "on"});
}
void Services::setBrightness(double v) {
    m_brightness = std::clamp(v, 0.0, 1.0); hold(); emit changed();
    if (m_brightAvail) m_brightTimer.start();
}
void Services::setVolume(double v) {
    m_volume = std::clamp(v, 0.0, 1.0); hold(); emit changed();
    if (m_volAvail) m_volTimer.start();
}

void Services::poll() {
    pollSys();
    run("nmcli", {"-t", "radio"}, [this](int code, const QString &out) {
        const QStringList f = out.trimmed().split(':');
        const bool avail = code == 0 && f.size() >= 2 && f[0] != "missing";
        if (avail != m_wifiAvail) { m_wifiAvail = avail; emit changed(); }
        if (avail && !held() && m_wifi != (f[1] == "enabled")) { m_wifi = f[1] == "enabled"; emit changed(); }
        if (!avail) return;
        run("nmcli", {"-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi"}, [this](int, const QString &o) {
            int sig = 0; QString name;
            for (const QString &l : o.split('\n')) if (l.startsWith("yes:")) {
                const int c = l.lastIndexOf(':');
                name = l.mid(4, c - 4); sig = std::clamp(int(std::ceil(l.mid(c + 1).toInt() / 25.0)), 0, 4); break;
            }
            if (sig != m_signal || name != m_wifiName) { m_signal = sig; m_wifiName = name; emit changed(); }
        });
    });
    run("wpctl", {"get-volume", "@DEFAULT_AUDIO_SINK@"}, [this](int code, const QString &out) {
        const bool avail = code == 0 && out.startsWith("Volume:");
        if (avail != m_volAvail) { m_volAvail = avail; emit changed(); }
        if (!avail || held()) return;
        const double v = out.split(' ').value(1).toDouble();
        const double eff = out.contains("[MUTED]") ? 0.0 : std::clamp(v, 0.0, 1.0);
        if (std::abs(eff - m_volume) > 0.004) { m_volume = eff; emit changed(); }
    });
}

void Services::pollSys() {
    // battery: first power_supply of type Battery
    const QDir d("/sys/class/power_supply");
    bool found = false;
    for (const QString &n : d.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (readFile(d.filePath(n + "/type")) != "Battery") continue;
        const QString cap = readFile(d.filePath(n + "/capacity"));
        if (cap.isEmpty()) continue;
        m_battery = cap.toInt();
        const QString st = readFile(d.filePath(n + "/status"));
        m_charging = st == "Charging" || st == "Full";
        found = true; break;
    }
    if (!found && m_mock) { found = true; }
    if (!found) { m_charging = false; }
    m_battAvail = found;
    // backlight
    const QDir b("/sys/class/backlight");
    const QStringList bl = b.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    m_brightAvail = !bl.isEmpty();
    if (m_brightAvail) {
        m_backlight = bl.first();
        const double mx = readFile(b.filePath(m_backlight + "/max_brightness")).toDouble();
        const double cur = readFile(b.filePath(m_backlight + "/brightness")).toDouble();
        if (mx > 0 && !held()) m_brightness = std::clamp(cur / mx, 0.0, 1.0);
    }
    // bluetooth: adapter present in sysfs, then ask bluetoothctl for its power state
    const bool btA = !QDir("/sys/class/bluetooth").entryList({"hci*"}).isEmpty();
    m_btAvail = btA;
    if (btA) run("bluetoothctl", {"show"}, [this](int, const QString &out) {
        if (held() || !out.contains("Controller")) return;
        const bool on = out.contains("Powered: yes");
        if (on != m_bt) { m_bt = on; emit changed(); }
    });
    emit changed();
}

void Services::send(const QString &json) {
    for (auto *c : std::as_const(m_clients)) c->write(json.toUtf8() + "\n");
}

// Protocol (JSON lines):
//   {"event":"gesture","name":"home|back|switcher|shade|qs"}
//   {"set":"theme|scheme|glass|reduceTransparency|reduceMotion|screen","value":"..."}
//   {"get":"config|<key>"}  -> one JSON line reply {"get":..,"value":..}
//   {"notify":{"app":..,"title":..,"body":..}}
void Services::onLine(const QByteArray &line) {
    const auto o = QJsonDocument::fromJson(line).object();
    if (o["event"].toString() == "gesture") emit gesture(o["name"].toString());
    else if (o.contains("set")) {
        const QString k = o["set"].toString(), v = o["value"].toVariant().toString();
        if (k == "glass") { m_glass = v; emit changed(); }
        else if (k == "reduceTransparency") { m_reduceTransp = v == "1" || v == "true"; emit changed(); }
        else if (k == "reduceMotion") { m_reduceMotion = v == "1" || v == "true"; emit changed(); }
        else if (k == "screen" && (v == "sleep" || v == "wake")) {
            const bool a = v == "sleep";
            if (a != m_asleep) {
                m_asleep = a; emit asleepChanged();
                if (a) m_pollTimer.stop(); else { poll(); m_pollTimer.start(10000); }
            }
        }
        emit command(k, v);
    } else if (o.contains("get")) {   // {"get":"config"|<key>}: reply comes back from QML via send()
        emit command("get", o["get"].toVariant().toString());
    } else if (o.contains("notify")) {
        const auto n = o["notify"].toObject();
        m_notifs.add(n["app"].toString(), n["title"].toString(), n["body"].toString());
    }
}

#include "Services.moc"
