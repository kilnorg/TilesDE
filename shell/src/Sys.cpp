#include "Sys.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QDateTime>

// Third-party apps run inside the phone window (tools/tiles-wm.py places them): native Wayland, no client-side decorations.
static bool startApp(const QString &prog, const QStringList &args) {
    QProcess p;
    QProcessEnvironment e = QProcessEnvironment::systemEnvironment();
    e.insert("TILES_MANAGED", "1"); e.insert("MOZ_ENABLE_WAYLAND", "1"); e.insert("MOZ_USE_XINPUT2", "1");
    e.insert("GTK_CSD", "0"); e.insert("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1");
    p.setProcessEnvironment(e); p.setProgram(prog); p.setArguments(args);
    return p.startDetached();
}
bool Sys::launch(const QString &prog, const QStringList &args) const { return startApp(prog, args); }
bool Sys::openUrl(const QString &url) const { return startApp("xdg-open", {url}); }
QString Sys::home() const { return QDir::homePath(); }
bool Sys::exists(const QString &path) const { return QFileInfo::exists(path); }
QString Sys::readText(const QString &path, int maxBytes) const {
    QFile f(path); if (!f.open(QIODevice::ReadOnly)) return {};
    return QString::fromUtf8(f.read(maxBytes));
}
QVariantList Sys::listDir(const QString &path, const QStringList &exts, bool recursive, int limit) const {
    QVariantList out;
    QStringList filters; for (const auto &e : exts) filters << "*." + e;
    QDirIterator it(path, filters, QDir::Files | QDir::Readable, recursive ? QDirIterator::Subdirectories : QDirIterator::NoIteratorFlags);
    while (it.hasNext() && out.size() < limit) {
        it.next(); const QFileInfo fi = it.fileInfo();
        out << QVariantMap{{"path", fi.absoluteFilePath()}, {"name", fi.fileName()}, {"size", fi.size()},
                           {"modified", fi.lastModified().toMSecsSinceEpoch()}};
    }
    return out;
}
QVariantMap Sys::run(const QString &prog, const QStringList &args, int timeoutMs) const {
    QProcess p; p.start(prog, args);
    if (!p.waitForFinished(timeoutMs)) { p.kill(); p.waitForFinished(200); return {{"code", -1}, {"out", ""}, {"err", "timeout"}}; }
    return {{"code", p.exitCode()}, {"out", QString::fromUtf8(p.readAllStandardOutput())}, {"err", QString::fromUtf8(p.readAllStandardError())}};
}
