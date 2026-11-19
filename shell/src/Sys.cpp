#include "Sys.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QDateTime>

bool Sys::launch(const QString &prog, const QStringList &args) const { return QProcess::startDetached(prog, args); }
bool Sys::openUrl(const QString &url) const { return QProcess::startDetached("xdg-open", {url}); }
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
