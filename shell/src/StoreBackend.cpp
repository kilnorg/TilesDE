#include "StoreBackend.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QPointer>
#include <QProcessEnvironment>
#include <QSharedPointer>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>
#include <QUrlQuery>
#include <algorithm>
#include <unistd.h>

namespace {
const char *kApi = "https://flathub.org/api/v2";

bool validApt(const QString &s) {
    static const QRegularExpression re("^[a-z0-9][a-z0-9+.\\-]{0,100}$");
    return re.match(s).hasMatch();
}
bool validFlat(const QString &s) {
    static const QRegularExpression re("^[A-Za-z0-9][A-Za-z0-9._\\-]{0,200}$");
    return re.match(s).hasMatch();
}
bool validId(const QString &src, const QString &id) { return src == "apt" ? validApt(id) : (src == "flathub" && validFlat(id)); }

// curated apt packages per category (looked up in the real apt index; absent ones are simply not shown)
const QHash<QString, QStringList> &aptCurated() {
    static const QHash<QString, QStringList> m = {
        {"internet", {"firefox-esr", "chromium", "thunderbird", "transmission-gtk", "newsboat", "epiphany-browser", "links2", "irssi", "weechat"}},
        {"media", {"vlc", "mpv", "cmus", "audacity", "ffmpeg", "rhythmbox", "kodi", "obs-studio", "handbrake"}},
        {"graphics", {"gimp", "inkscape", "krita", "imagemagick", "darktable", "blender", "scribus", "gthumb"}},
        {"office", {"libreoffice", "evince", "calcurse", "abiword", "gnumeric", "okular", "zathura"}},
        {"utilities", {"keepassxc", "htop", "mc", "tmux", "neofetch", "ncdu", "ranger", "btop", "file-roller"}},
        {"development", {"git", "geany", "vim", "python3", "nodejs", "neovim", "gcc", "cmake", "golang"}},
        {"games", {"supertux", "extremetuxracer", "gnuchess", "frozen-bubble", "0ad", "minetest", "neverball", "supertuxkart"}},
        {"system", {"gparted", "synaptic", "timeshift", "bleachbit", "baobab", "gnome-disk-utility"}},
        {"education", {"stellarium", "gcompris-qt", "geogebra", "kalzium", "kgeography"}},
        {"science", {"octave", "kalgebra", "celestia", "gnuplot", "r-base"}},
    };
    return m;
}
const QHash<QString, QString> &flatCat() {
    static const QHash<QString, QString> m = {{"internet", "network"}, {"media", "audiovideo"}, {"graphics", "graphics"}, {"office", "office"},
        {"utilities", "utility"}, {"development", "development"}, {"games", "game"}, {"system", "system"}, {"education", "education"}, {"science", "science"}};
    return m;
}

QString baseCache() {
    QString root = qEnvironmentVariable("XDG_CACHE_HOME");
    if (root.isEmpty()) root = QDir::homePath() + "/.cache";
    return root + "/tilesde/store";
}

QString stripHtml(QString h) {
    h.replace(QRegularExpression("</(p|ul|ol|div)>", QRegularExpression::CaseInsensitiveOption), "\n\n");
    h.replace(QRegularExpression("<li[^>]*>", QRegularExpression::CaseInsensitiveOption), "\n- ");
    h.replace(QRegularExpression("<br\\s*/?>", QRegularExpression::CaseInsensitiveOption), "\n");
    h.remove(QRegularExpression("<[^>]*>"));
    h.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&apos;", "'");
    h.replace(QRegularExpression("[ \\t]+\\n"), "\n");
    h.replace(QRegularExpression("\\n{3,}"), "\n\n");
    // collapse whitespace the appstream XML indentation leaves inside paragraphs
    QStringList paras = h.split("\n\n");
    for (QString &p : paras) { QStringList ls = p.split('\n'); for (QString &l : ls) l = l.simplified(); p = ls.join('\n'); }
    return paras.join("\n\n").trimmed();
}

QVariantMap flatItem(const QJsonObject &h) {
    QVariantMap m;
    m["source"] = "flathub";
    m["id"] = h["app_id"].toString().isEmpty() ? h["id"].toString().replace('_', '.') : h["app_id"].toString();
    m["name"] = h["name"].toString();
    m["summary"] = h["summary"].toString();
    m["icon"] = h["icon"].toString();
    m["category"] = h["main_categories"].isArray() ? h["main_categories"].toArray().first().toString() : h["main_categories"].toString();
    m["developer"] = h["developer_name"].toString();
    m["version"] = "";
    return m;
}
}

StoreBackend::StoreBackend(QObject *p) : QObject(p) {
    const QString a = QSysInfo::currentCpuArchitecture();
    m_arch = a == "arm64" ? "aarch64" : a;
    QDir().mkpath(baseCache() + "/api");
    QDir().mkpath(baseCache() + "/img");
    // prune the image cache when it grows past ~200 MB (oldest first)
    QFileInfoList imgs = QDir(baseCache() + "/img").entryInfoList(QDir::Files, QDir::Time | QDir::Reversed);
    qint64 total = 0; for (const auto &f : imgs) total += f.size();
    for (const auto &f : imgs) { if (total < 200LL * 1024 * 1024) break; total -= f.size(); QFile::remove(f.filePath()); }
}

QString StoreBackend::cacheDir() const { return baseCache(); }
QStringList StoreBackend::categories() { return {"all", "internet", "media", "graphics", "office", "utilities", "development", "games", "system", "education", "science"}; }

void StoreBackend::setOnline(bool v) { if (m_online != v) { m_online = v; emit onlineChanged(); } }

// ---------------------------------------------------------------- processes
void StoreBackend::runProc(const QString &prog, const QStringList &args, ProcCb cb, int timeoutMs) {
    auto *pr = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    pr->setProcessEnvironment(env);
    pr->setProcessChannelMode(QProcess::SeparateChannels);
    auto *guard = new QTimer(pr);
    guard->setSingleShot(true);
    connect(guard, &QTimer::timeout, pr, [pr] { pr->kill(); });
    connect(pr, &QProcess::errorOccurred, this, [pr, cb](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) { cb(-1, QString()); pr->deleteLater(); }
    });
    connect(pr, &QProcess::finished, this, [pr, cb](int code, QProcess::ExitStatus st) {
        cb(st == QProcess::NormalExit ? code : -2, QString::fromUtf8(pr->readAllStandardOutput()));
        pr->deleteLater();
    });
    pr->start(prog, args);
    guard->start(timeoutMs);
}

// ---------------------------------------------------------------- JSON + cache
void StoreBackend::getJson(const QUrl &url, const QByteArray &body, JsonCb cb) {
    const QString key = baseCache() + "/api/" + QString::fromLatin1(QCryptographicHash::hash(url.toEncoded() + body, QCryptographicHash::Sha1).toHex()) + ".json";
    QNetworkRequest rq(url);
    rq.setHeader(QNetworkRequest::UserAgentHeader, "tilesde-store/0.1");
    rq.setTransferTimeout(15000);
    QNetworkReply *r;
    if (body.isEmpty()) r = m_nam.get(rq);
    else { rq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json"); r = m_nam.post(rq, body); }
    connect(r, &QNetworkReply::finished, this, [this, r, key, cb] {
        const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool netErr = r->error() != QNetworkReply::NoError && status == 0;
        const QByteArray data = r->readAll();
        r->deleteLater();
        QJsonParseError pe;
        QJsonDocument doc = QJsonDocument::fromJson(data, &pe);
        if (!netErr && status >= 200 && status < 300 && pe.error == QJsonParseError::NoError) {
            setOnline(true);
            QFile f(key); if (f.open(QIODevice::WriteOnly)) f.write(data);
            cb(true, false, doc);
            return;
        }
        if (netErr) setOnline(false);
        QFile f(key);
        if (netErr && f.open(QIODevice::ReadOnly)) {
            doc = QJsonDocument::fromJson(f.readAll());
            if (!doc.isNull()) { cb(true, true, doc); return; }
        }
        cb(false, false, QJsonDocument());
    });
}

// ---------------------------------------------------------------- images
QString StoreBackend::imagePath(const QString &url) const {
    QString ext = QFileInfo(QUrl(url).path()).suffix().toLower();
    if (!QStringList{"png", "jpg", "jpeg", "webp", "svg", "gif"}.contains(ext)) ext = "png";
    return baseCache() + "/img/" + QString::fromLatin1(QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex()) + "." + ext;
}

QString StoreBackend::cachedImage(const QString &url) {
    if (url.isEmpty()) return QString();
    const QString p = imagePath(url);
    if (QFileInfo::exists(p)) return p;
    fetchImage(url);
    return QString();
}

void StoreBackend::fetchImage(const QString &url) {
    const QUrl u(url);
    if (u.scheme() != "https" || m_fetching.contains(url) || m_failedImages.contains(url)) return;
    m_fetching.insert(url);
    QNetworkRequest rq(u);
    rq.setHeader(QNetworkRequest::UserAgentHeader, "tilesde-store/0.1");
    rq.setTransferTimeout(20000);
    rq.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *r = m_nam.get(rq);
    connect(r, &QNetworkReply::finished, this, [this, r, url] {
        m_fetching.remove(url);
        const QByteArray data = r->readAll();
        const bool ok = r->error() == QNetworkReply::NoError && !data.isEmpty();
        r->deleteLater();
        if (!ok) { if (r->error() != QNetworkReply::HostNotFoundError && r->error() != QNetworkReply::TimeoutError) m_failedImages.insert(url); return; }
        const QString p = imagePath(url);
        QFile f(p + ".part");
        if (f.open(QIODevice::WriteOnly)) { f.write(data); f.close(); QFile::remove(p); f.rename(p); emit imageReady(url, p); }
    });
}

// ---------------------------------------------------------------- capabilities + installed
void StoreBackend::refresh() {
    m_hasFlatpak = !QStandardPaths::findExecutable("flatpak").isEmpty();
    if (geteuid() == 0) { m_escalation = "root"; emit capsChanged(); }
    else {
        m_escalation = "none";
        if (!QStandardPaths::findExecutable("pkexec").isEmpty()) m_escalation = "pkexec";
        emit capsChanged();
        if (!QStandardPaths::findExecutable("sudo").isEmpty())
            runProc("sudo", {"-n", "true"}, [this](int code, const QString &) {
                if (code == 0) m_escalation = "sudo";
                emit capsChanged();
            }, 5000);
    }
    loadInstalled();
}

void StoreBackend::loadInstalled() {
    QString fmt = QStringLiteral("${Package}\t${db:Status-Abbrev}\t${Version}\t${binary:Summary}\n");
    runProc("dpkg-query", {"-W", "-f=" + fmt}, [this](int, const QString &out) {
        struct Pkg { QString ver, sum; };
        auto pkgs = QSharedPointer<QHash<QString, Pkg>>::create();
        for (const QString &l : out.split('\n', Qt::SkipEmptyParts)) {
            const QStringList f = l.split('\t');
            if (f.size() < 3 || !f[1].startsWith("ii")) continue;
            (*pkgs)[f[0]] = {f[2], f.value(3)};
        }
        runProc("apt-mark", {"showmanual"}, [this, pkgs](int, const QString &mout) {
            const QStringList ml = mout.split('\n', Qt::SkipEmptyParts);
            const QSet<QString> manual(ml.begin(), ml.end());
            auto finish = [this, pkgs, manual](const QVariantList &flat) {
                QVariantMap inst;
                QVariantList list;
                static const QRegularExpression noise("^(lib|linux-|firmware-|python3-|gir1\\.2-|fonts-|task-|locales)|(-dev|-dbg|-doc|-data|-common)$");
                for (auto it = pkgs->constBegin(); it != pkgs->constEnd(); ++it) {
                    inst["apt:" + it.key()] = it->ver;
                    if (manual.contains(it.key()) && !noise.match(it.key()).hasMatch())
                        list.append(QVariantMap{{"source", "apt"}, {"id", it.key()}, {"name", it.key()}, {"summary", it->sum}, {"version", it->ver}, {"icon", ""}});
                }
                std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) { return a.toMap()["name"].toString() < b.toMap()["name"].toString(); });
                for (const QVariant &v : flat) { const QVariantMap m = v.toMap(); inst["flathub:" + m["id"].toString()] = m["version"].toString(); list.append(m); }
                m_installed = inst;
                emit installedChanged();
                emit installedListReady(list);
            };
            if (!m_hasFlatpak) { finish({}); return; }
            runProc("flatpak", {"list", "--app", "--columns=application,name,version,installation"}, [finish](int, const QString &fout) {
                QVariantList flat;
                for (const QString &l : fout.split('\n', Qt::SkipEmptyParts)) {
                    const QStringList f = l.split('\t');
                    if (f.size() < 2 || !validFlat(f[0].trimmed())) continue;
                    flat.append(QVariantMap{{"source", "flathub"}, {"id", f[0].trimmed()}, {"name", f[1].trimmed()}, {"summary", "flatpak " + f.value(3).trimmed()},
                        {"version", f.value(2).trimmed()}, {"icon", ""}, {"installation", f.value(3).trimmed()}});
                }
                finish(flat);
            }, 15000);
        }, 15000);
    }, 15000);
}

// ---------------------------------------------------------------- browse / search
void StoreBackend::aptSummaries(const QStringList &pkgs, std::function<void(QVariantList)> cb) {
    // one anchored regex search: tolerates packages missing from the index (apt-cache show would fail for the whole batch)
    QStringList names;
    for (const QString &p : pkgs) if (validApt(p)) names << QRegularExpression::escape(p);
    if (names.isEmpty()) { cb({}); return; }
    runProc("apt-cache", {"search", "--names-only", "^(" + names.join('|') + ")$"}, [cb, pkgs](int, const QString &out) {
        QHash<QString, QString> sums;
        for (const QString &l : out.split('\n', Qt::SkipEmptyParts)) {
            const int i = l.indexOf(" - ");
            if (i > 0) sums[l.left(i)] = l.mid(i + 3);
        }
        QVariantList items;
        for (const QString &p : pkgs)   // keep curated order
            if (sums.contains(p)) items.append(QVariantMap{{"source", "apt"}, {"id", p}, {"name", p}, {"summary", sums[p]}, {"icon", ""}, {"category", ""}, {"version", ""}, {"developer", ""}});
        cb(items);
    });
}

void StoreBackend::browse(int token, const QString &category, int page) {
    const QString cat = categories().contains(category) ? category : "all";
    if (page <= 1) {
        QStringList pk;
        if (cat == "all") { for (const char *c : {"internet", "media", "graphics", "office", "utilities", "development", "games"}) pk << aptCurated().value(c).mid(0, 3); }
        else pk = aptCurated().value(cat);
        aptSummaries(pk, [this, token, cat](QVariantList items) {
            for (QVariant &v : items) { QVariantMap m = v.toMap(); m["category"] = cat; v = m; }
            emit results(token, "apt", items, 1, false, false);
        });
    }
    QUrl u(QString(kApi) + (cat == "all" ? "/collection/popular" : "/collection/category/" + flatCat().value(cat)));
    QUrlQuery q; q.addQueryItem("page", QString::number(qMax(1, page))); q.addQueryItem("per_page", "30"); u.setQuery(q);
    getJson(u, {}, [this, token, page](bool ok, bool cached, const QJsonDocument &d) {
        if (!ok) { emit searchFailed(token, "flathub", "flathub unreachable"); return; }
        QVariantList items;
        for (const QJsonValue &v : d.object()["hits"].toArray()) {
            const QJsonObject h = v.toObject();
            const QJsonArray ar = h["arches"].toArray();
            if (!ar.isEmpty() && !ar.contains(m_arch)) continue;
            if (h["type"].toString() != "desktop-application" && !h["type"].toString().isEmpty() && h["type"].toString() != "desktop") continue;
            items.append(flatItem(h));
        }
        emit results(token, "flathub", items, page, page < d.object()["totalPages"].toInt(), cached);
    });
}

void StoreBackend::search(int token, const QString &query) {
    const QString q = query.trimmed();
    if (q.size() < 2) { emit results(token, "apt", {}, 1, false, false); emit results(token, "flathub", {}, 1, false, false); return; }
    QStringList args = {"search", "--names-only"};
    const QStringList words = q.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
    for (const QString &w : words) args << QRegularExpression::escape(w);
    const bool wantLib = q.startsWith("lib");
    runProc("apt-cache", args, [this, token, q, wantLib](int code, const QString &out) {
        if (code == -1) { emit searchFailed(token, "apt", "apt-cache not available"); emit results(token, "apt", {}, 1, false, false); return; }
        struct R { QString n, s; int rank; };
        QList<R> rs;
        static const QRegularExpression noise("(-dev|-dbg|-doc|-data|-common|-dbgsym)$");
        const QString lq = q.toLower();
        for (const QString &l : out.split('\n', Qt::SkipEmptyParts)) {
            const int i = l.indexOf(" - ");
            if (i <= 0) continue;
            const QString n = l.left(i);
            if (!wantLib && (n.startsWith("lib") || noise.match(n).hasMatch())) continue;
            rs.append({n, l.mid(i + 3), n == lq ? 0 : (n.startsWith(lq) ? 1 : 2)});
        }
        std::stable_sort(rs.begin(), rs.end(), [](const R &a, const R &b) { return a.rank != b.rank ? a.rank < b.rank : a.n.size() < b.n.size(); });
        QVariantList items;
        for (const R &r : rs.mid(0, 40))
            items.append(QVariantMap{{"source", "apt"}, {"id", r.n}, {"name", r.n}, {"summary", r.s}, {"icon", ""}, {"category", ""}, {"version", ""}, {"developer", ""}});
        emit results(token, "apt", items, 1, false, false);
    });
    QJsonObject body{{"query", q}};
    getJson(QUrl(QString(kApi) + "/search"), QJsonDocument(body).toJson(QJsonDocument::Compact), [this, token](bool ok, bool cached, const QJsonDocument &d) {
        if (!ok) { emit searchFailed(token, "flathub", "flathub unreachable"); return; }
        QVariantList items;
        for (const QJsonValue &v : d.object()["hits"].toArray()) {
            const QJsonObject h = v.toObject();
            const QJsonArray ar = h["arches"].toArray();
            if (!ar.isEmpty() && !ar.contains(m_arch)) continue;
            items.append(flatItem(h));
        }
        emit results(token, "flathub", items, 1, false, cached);
    });
}

// ---------------------------------------------------------------- details
void StoreBackend::details(const QString &source, const QString &id) {
    if (!validId(source, id)) { emit detailsFailed(source, id, "invalid package id"); return; }
    if (source == "apt") {
        runProc("apt-cache", {"show", "--no-all-versions", id}, [this, id](int code, const QString &out) {
            if (code != 0 || out.trimmed().isEmpty()) { emit detailsFailed("apt", id, "package not found in the apt index"); return; }
            QVariantMap d{{"source", "apt"}, {"id", id}, {"name", id}, {"icon", ""}, {"screenshots", QVariantList()}};
            QString desc, key; QStringList longDesc;
            bool inDesc = false;
            for (const QString &l : out.split('\n')) {
                if (l.isEmpty()) break;   // first stanza only
                if (l.startsWith(' ') && inDesc) { const QString t = l.trimmed(); longDesc << (t == "." ? QString() : t); continue; }
                inDesc = false;
                const int c = l.indexOf(": ");
                if (c < 0) continue;
                const QString k = l.left(c), v = l.mid(c + 2).trimmed();
                if (k == "Description") { desc = v; inDesc = true; }
                else if (k == "Version") d["version"] = v;
                else if (k == "Homepage") d["homepage"] = v;
                else if (k == "Section") d["category"] = v;
                else if (k == "Maintainer") d["developer"] = v;
                else if (k == "Installed-Size") d["installedSize"] = v.toLongLong() * 1024;
                else if (k == "Size") d["downloadSize"] = v.toLongLong();
                else if (k == "Depends") d["depends"] = v;
            }
            QString text;
            for (const QString &l : longDesc) text += l.isEmpty() ? "\n\n" : (text.isEmpty() || text.endsWith("\n\n") ? "" : " ") + l;
            d["summary"] = desc;
            d["description"] = text.trimmed();
            emit detailsReady(d);
        });
        return;
    }
    getJson(QUrl(QString(kApi) + "/appstream/" + id), {}, [this, id](bool ok, bool cached, const QJsonDocument &doc) {
        if (!ok) { emit detailsFailed("flathub", id, "flathub unreachable and no cached copy"); return; }
        const QJsonObject o = doc.object();
        QVariantMap d{{"source", "flathub"}, {"id", id}, {"name", o["name"].toString()}, {"summary", o["summary"].toString()},
            {"description", stripHtml(o["description"].toString())}, {"icon", o["icon"].toString()}, {"developer", o["developer_name"].toString()},
            {"license", o["project_license"].toString()}, {"homepage", o["urls"].toObject()["homepage"].toString()}, {"offline", cached}};
        const QJsonArray rel = o["releases"].toArray();
        if (!rel.isEmpty()) d["version"] = rel.first().toObject()["version"].toString();
        QStringList cats; for (const QJsonValue &c : o["categories"].toArray()) cats << c.toString();
        d["category"] = cats.join(", ");
        QVariantList shots;
        for (const QJsonValue &sv : o["screenshots"].toArray()) {
            QString best; int bw = 0;
            for (const QJsonValue &z : sv.toObject()["sizes"].toArray()) {
                const int w = z.toObject()["width"].toString().toInt();
                const bool better = best.isEmpty() || (bw < 600 && w > bw) || (w >= 600 && w < bw);
                if (better) { best = z.toObject()["src"].toString(); bw = w; }
            }
            if (!best.isEmpty()) shots << best;
            if (shots.size() >= 6) break;
        }
        d["screenshots"] = shots;
        emit detailsReady(d);
    });
}

// ---------------------------------------------------------------- updates
void StoreBackend::checkUpdates(bool refreshIndex) {
    auto list = [this](bool refreshed, const QString &note) {
        runProc("apt", {"list", "--upgradable"}, [this, refreshed, note](int, const QString &out) {
            QVariantList apt;
            for (const QString &l : out.split('\n', Qt::SkipEmptyParts)) {
                const int s = l.indexOf('/');
                if (s <= 0 || l.startsWith("Listing")) continue;
                const QString name = l.left(s);
                if (!validApt(name)) continue;
                const QStringList parts = l.split(' ');
                const int f = l.indexOf("upgradable from: ");
                QString from = f >= 0 ? l.mid(f + 17).remove(']').trimmed() : QString();
                apt.append(QVariantMap{{"source", "apt"}, {"id", name}, {"name", name}, {"text", (from.isEmpty() ? QString() : from + " > ") + parts.value(1)}});
            }
            listFlatpakUpdates(refreshed, apt, note);
        }, 30000);
    };
    if (refreshIndex && m_escalation != "none") {
        const QStringList pre = privPrefix();
        QStringList args = pre.mid(1); args << "apt-get" << "update" << "-q";
        runProc(pre.isEmpty() ? "apt-get" : pre.first(), pre.isEmpty() ? QStringList{"update", "-q"} : args, [list](int code, const QString &) {
            list(code == 0, code == 0 ? QString() : "could not refresh the apt index (offline?); showing the last known state");
        }, 120000);
    } else list(false, refreshIndex ? "no privilege to refresh the apt index (needs passwordless sudo or root)" : QString());
}

void StoreBackend::listFlatpakUpdates(bool refreshed, QVariantList apt, const QString &note) {
    if (!m_hasFlatpak) { emit updatesReady(apt, refreshed, note); return; }
    runProc("flatpak", {"remote-ls", "--updates", "--app", "--columns=application,name,version"}, [this, refreshed, apt, note](int, const QString &out) {
        QVariantList all = apt;
        for (const QString &l : out.split('\n', Qt::SkipEmptyParts)) {
            const QStringList f = l.split('\t');
            if (f.size() < 2 || !validFlat(f[0].trimmed())) continue;
            all.append(QVariantMap{{"source", "flathub"}, {"id", f[0].trimmed()}, {"name", f[1].trimmed()}, {"text", "flatpak " + f.value(2).trimmed()}});
        }
        emit updatesReady(all, refreshed, note);
    }, 60000);
}

// ---------------------------------------------------------------- install / remove / upgrade
QStringList StoreBackend::privPrefix() const {
    if (m_escalation == "sudo") return {"sudo", "-n"};
    if (m_escalation == "pkexec") return {"pkexec"};
    return {};
}

void StoreBackend::install(const QString &source, const QString &id) {
    if (m_busy || !validId(source, id)) return;
    QList<Job> jobs;
    if (source == "apt") jobs << Job{"apt-get", {"install", "-y", "--no-install-recommends", id}, true, "apt"};
    else {
        if (!m_hasFlatpak) { emit opFinished(false, "install " + id, "flatpak is not installed (apt install flatpak)"); return; }
        jobs << Job{"flatpak", {"remote-add", "--user", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"}, false, "plain"}
             << Job{"flatpak", {"install", "--user", "-y", "--noninteractive", "flathub", id}, false, "flatpak"};
    }
    startOp("installing " + id, source, id, jobs);
}

void StoreBackend::remove(const QString &source, const QString &id) {
    if (m_busy || !validId(source, id)) return;
    QList<Job> jobs;
    if (source == "apt") jobs << Job{"apt-get", {"remove", "-y", id}, true, "apt"};
    else {
        jobs << Job{"flatpak", {"uninstall", "--user", "-y", "--noninteractive", id}, false, "flatpak"};
    }
    startOp("removing " + id, source, id, jobs);
}

void StoreBackend::upgradeAll() {
    if (m_busy) return;
    QList<Job> jobs;
    jobs << Job{"apt-get", {"upgrade", "-y", "-o", "Dpkg::Options::=--force-confold"}, true, "apt"};
    if (m_hasFlatpak) jobs << Job{"flatpak", {"update", "--user", "-y", "--noninteractive"}, false, "flatpak"};
    startOp("updating all apps", "", "", jobs);
}

void StoreBackend::startOp(const QString &title, const QString &source, const QString &id, const QList<Job> &jobs) {
    bool needRoot = false; for (const Job &j : jobs) needRoot = needRoot || j.root;
    if (needRoot && m_escalation == "none") {
        emit opFinished(false, title, "needs administrator rights: passwordless sudo, pkexec or root is not available. use the terminal option.");
        return;
    }
    m_jobs = jobs; m_jobIdx = 0; m_busy = true; m_cancelled = false;
    m_opTitle = title; m_opSource = source; m_opId = id; m_opLine = "starting..."; m_opProgress = -1; m_lastErr.clear();
    emit opChanged();
    nextJob();
}

void StoreBackend::nextJob() {
    if (m_jobIdx >= m_jobs.size()) { finishOp(true, QString()); return; }
    const Job j = m_jobs[m_jobIdx];
    m_dlPct = m_pmPct = 0; m_buf.clear();
    QString prog = j.program; QStringList args = j.args;
    if (j.root) {
        const QStringList pre = privPrefix();
        QStringList full = pre.mid(1);
        full << "env" << "DEBIAN_FRONTEND=noninteractive" << "LC_ALL=C" << j.program;
        if (j.kind == "apt") full << "-o" << "APT::Status-Fd=1" << "-o" << "Dpkg::Use-Pty=0";
        full << j.args;
        prog = pre.isEmpty() ? "env" : pre.first();
        args = pre.isEmpty() ? full.mid(1) : full;
    }
    m_proc = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    m_proc->setProcessEnvironment(env);
    m_proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_proc, &QProcess::readyRead, this, [this] { feed(m_proc->readAll()); });
    connect(m_proc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) { QProcess *p = m_proc; m_proc = nullptr; p->deleteLater(); finishOp(false, "could not start " + m_jobs[m_jobIdx].program); }
    });
    connect(m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus st) {
        QProcess *p = m_proc; m_proc = nullptr;
        feed(p->readAll()); p->deleteLater();
        if (m_cancelled) { finishOp(false, "cancelled"); return; }
        if (st != QProcess::NormalExit || code != 0) { finishOp(false, m_lastErr.isEmpty() ? QString("command failed (exit %1)").arg(code) : m_lastErr); return; }
        ++m_jobIdx; nextJob();
    });
    m_proc->start(prog, args);
}

void StoreBackend::feed(const QByteArray &chunk) {
    m_buf += chunk;
    int i;
    while ((i = m_buf.indexOf('\n')) >= 0 || (i = m_buf.indexOf('\r')) >= 0) {
        const QString l = QString::fromUtf8(m_buf.left(i)).trimmed();
        m_buf.remove(0, i + 1);
        if (!l.isEmpty()) handleLine(l);
    }
}

void StoreBackend::handleLine(const QString &l) {
    double pct = -2;   // -2 = no progress info in this line
    QString shown = l;
    if (l.startsWith("pmstatus:") || l.startsWith("dlstatus:")) {
        const QStringList f = l.split(':');
        const double v = f.value(2).toDouble();
        if (l.startsWith("dlstatus:")) m_dlPct = qMax(m_dlPct, v); else m_pmPct = qMax(m_pmPct, v);
        pct = (m_dlPct * 0.4 + m_pmPct * 0.6) / 100.0;
        shown = f.mid(3).join(':');
    } else {
        static const QRegularExpression pc("(\\d{1,3})%");
        QRegularExpressionMatchIterator it = pc.globalMatch(l);
        QString last; while (it.hasNext()) last = it.next().captured(1);
        if (!last.isEmpty() && m_jobs.value(m_jobIdx).kind == "flatpak") pct = qMin(100, last.toInt()) / 100.0;
        if (l.startsWith("E:") || l.startsWith("error", Qt::CaseInsensitive) || l.startsWith("Error")) m_lastErr = l;
        if (l.contains("Permission denied") || l.contains("a password is required")) m_lastErr = l;
    }
    if (pct >= 0) {
        const double n = m_jobs.size();
        m_opProgress = qBound(0.0, (m_jobIdx + pct) / n, 1.0);
    }
    if (!shown.isEmpty()) m_opLine = shown.left(160);
    emit opChanged();
}

void StoreBackend::finishOp(bool ok, const QString &msg) {
    m_busy = false; m_opProgress = ok ? 1 : -1;
    const QString title = m_opTitle;
    if (!ok) m_opLine = msg;
    emit opChanged();
    emit opFinished(ok, title, msg);
    loadInstalled();
}

void StoreBackend::cancel() {
    if (!m_busy || !m_proc) return;
    m_cancelled = true;
    m_proc->terminate();
    QTimer::singleShot(4000, m_proc, [p = QPointer<QProcess>(m_proc)] { if (p) p->kill(); });
}

bool StoreBackend::openApp(const QString &source, const QString &id) {
    if (!validId(source, id)) return false;
    if (source == "flathub") return QProcess::startDetached("flatpak", {"run", id});
    runProc("dpkg-query", {"-L", id}, [](int, const QString &out) {
        for (const QString &l : out.split('\n', Qt::SkipEmptyParts)) {
            if (!l.startsWith("/usr/share/applications/") || !l.endsWith(".desktop")) continue;
            QFile f(l); if (!f.open(QIODevice::ReadOnly)) continue;
            for (const QByteArray &ln : f.readAll().split('\n')) {
                if (!ln.startsWith("Exec=")) continue;
                QString ex = QString::fromUtf8(ln.mid(5)).trimmed();
                ex.remove(QRegularExpression("%[a-zA-Z]"));
                QStringList parts = QProcess::splitCommand(ex);
                if (parts.isEmpty()) continue;
                QProcess::startDetached(parts.takeFirst(), parts);
                return;
            }
        }
    });
    return true;
}

bool StoreBackend::openInTerminal(const QString &source, const QString &id, const QString &action) {
    if (!validId(source, id) && !(id.isEmpty() && action == "upgrade")) return false;
    QString cmd;
    if (action == "upgrade") cmd = "sudo apt-get upgrade" + QString(m_hasFlatpak ? "; flatpak update --user" : "");
    else if (source == "apt") cmd = QString("sudo apt-get %1 %2").arg(action == "remove" ? "remove" : "install", id);
    else cmd = QString("flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; flatpak %1 --user %2").arg(action == "remove" ? "uninstall" : "install flathub", id);
    return QProcess::startDetached("foot", {"-e", "sh", "-c", cmd + "; echo; printf 'done. press enter to close'; read _x"});
}
