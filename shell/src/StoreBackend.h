#pragma once
#include <QHash>
#include <QList>
#include <QNetworkAccessManager>
#include <QObject>
#include <QProcess>
#include <QSet>
#include <QTimer>
#include <QVariant>
#include <functional>
#include <QtQml/qqmlregistration.h>

// Backend for StoreApp.qml. Everything is asynchronous (QProcess / QNetworkAccessManager); nothing blocks the UI.
// Sources: "apt" (apt-cache / apt-get / dpkg-query) and "flathub" (https://flathub.org/api/v2 + flatpak CLI).
// Items are maps {source, id, name, summary, icon, category, version, developer}.
// API JSON and images are cached under ~/.cache/tilesde/store (api/ img/), API cache is the offline fallback.
// Only validated package names / app ids ever reach a process (argument vector, never a shell string).
class StoreBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool online READ online NOTIFY onlineChanged)             // last Flathub request reached the network
    Q_PROPERTY(bool busy READ busy NOTIFY opChanged)                     // an install/remove/upgrade is running
    Q_PROPERTY(QString opTitle READ opTitle NOTIFY opChanged)
    Q_PROPERTY(QString opLine READ opLine NOTIFY opChanged)              // last output line of the running op
    Q_PROPERTY(double opProgress READ opProgress NOTIFY opChanged)       // 0..1, -1 = indeterminate
    Q_PROPERTY(QString opSource READ opSource NOTIFY opChanged)
    Q_PROPERTY(QString opId READ opId NOTIFY opChanged)
    Q_PROPERTY(QString escalation READ escalation NOTIFY capsChanged)    // root | sudo | pkexec | none
    Q_PROPERTY(bool hasFlatpak READ hasFlatpak NOTIFY capsChanged)
    Q_PROPERTY(QVariantMap installedKeys READ installedKeys NOTIFY installedChanged)  // "apt:pkg" / "flathub:id" -> version
public:
    explicit StoreBackend(QObject *p = nullptr);
    bool online() const { return m_online; }
    bool busy() const { return m_busy; }
    QString opTitle() const { return m_opTitle; }
    QString opLine() const { return m_opLine; }
    double opProgress() const { return m_opProgress; }
    QString opSource() const { return m_opSource; }
    QString opId() const { return m_opId; }
    QString escalation() const { return m_escalation; }
    bool hasFlatpak() const { return m_hasFlatpak; }
    QVariantMap installedKeys() const { return m_installed; }

    Q_INVOKABLE void refresh();                                       // probe capabilities + installed list
    Q_INVOKABLE void browse(int token, const QString &category, int page = 1);
    Q_INVOKABLE void search(int token, const QString &query);
    Q_INVOKABLE void details(const QString &source, const QString &id);
    Q_INVOKABLE void loadInstalled();
    Q_INVOKABLE void checkUpdates(bool refreshIndex);
    Q_INVOKABLE QString cachedImage(const QString &url);             // local path if cached, else "" (and starts fetch)
    Q_INVOKABLE void install(const QString &source, const QString &id);
    Q_INVOKABLE void remove(const QString &source, const QString &id);
    Q_INVOKABLE void upgradeAll();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE bool openApp(const QString &source, const QString &id);
    Q_INVOKABLE bool openInTerminal(const QString &source, const QString &id, const QString &action);
    Q_INVOKABLE QString cacheDir() const;
    Q_INVOKABLE static QStringList categories();

signals:
    void onlineChanged();
    void opChanged();
    void capsChanged();
    void installedChanged();
    void results(int token, const QString &source, const QVariantList &items, int page, bool hasMore, bool offline);
    void searchFailed(int token, const QString &source, const QString &message);
    void detailsReady(const QVariantMap &d);
    void detailsFailed(const QString &source, const QString &id, const QString &message);
    void installedListReady(const QVariantList &items);
    void updatesReady(const QVariantList &items, bool aptIndexRefreshed, const QString &note);
    void imageReady(const QString &url, const QString &path);
    void opFinished(bool ok, const QString &title, const QString &message);

private:
    struct Job { QString program; QStringList args; bool root; QString kind; };   // kind: apt | flatpak | plain
    using ProcCb = std::function<void(int code, const QString &out)>;
    void runProc(const QString &prog, const QStringList &args, ProcCb cb, int timeoutMs = 30000);
    using JsonCb = std::function<void(bool ok, bool cached, const QJsonDocument &)>;
    void getJson(const QUrl &url, const QByteArray &body, JsonCb cb);
    void setOnline(bool v);
    void startOp(const QString &title, const QString &source, const QString &id, const QList<Job> &jobs);
    void nextJob();
    void feed(const QByteArray &chunk);
    void handleLine(const QString &line);
    QStringList privPrefix() const;
    void finishOp(bool ok, const QString &msg);
    void aptSummaries(const QStringList &pkgs, std::function<void(QVariantList)> cb);
    void listFlatpakUpdates(bool aptRefreshed, QVariantList apt, const QString &note);
    void fetchImage(const QString &url);
    QString imagePath(const QString &url) const;

    QNetworkAccessManager m_nam;
    bool m_online = false;
    bool m_busy = false;
    QString m_opTitle, m_opLine, m_opSource, m_opId;
    double m_opProgress = -1;
    QString m_escalation = "none";
    bool m_hasFlatpak = false;
    QVariantMap m_installed;
    QSet<QString> m_fetching;
    QSet<QString> m_failedImages;
    QList<Job> m_jobs;
    int m_jobIdx = 0;
    QProcess *m_proc = nullptr;
    QByteArray m_buf;
    double m_dlPct = 0, m_pmPct = 0;
    QString m_lastErr;
    bool m_cancelled = false;
    QString m_arch;
};
