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

TermSession::TermSession(QObject *p) : QObject(p) {
    m_proc.setProcessChannelMode(QProcess::MergedChannels);
    connect(&m_proc, &QProcess::readyRead, this, [this] { emit output(QString::fromUtf8(m_proc.readAll())); });
    connect(&m_proc, &QProcess::stateChanged, this, [this] { emit runningChanged(); });
    connect(&m_proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this](int c, QProcess::ExitStatus) { emit finished(c); });
}
TermSession::~TermSession() { stop(); }
bool TermSession::start() {
    if (running()) return true;
    auto env = QProcessEnvironment::systemEnvironment();
    env.insert("TERM", "xterm-256color"); env.insert("COLUMNS", QString::number(m_cols)); env.insert("LINES", QString::number(m_rows));
    m_proc.setProcessEnvironment(env);
    m_proc.setWorkingDirectory(QDir::homePath());
    // util-linux script allocates the pty; -q quiet, -f flush, -c command, /dev/null = no typescript file
    m_proc.start("script", {"-qfc", "stty cols " + QString::number(m_cols) + " rows " + QString::number(m_rows) + "; exec " + m_shell + " -i", "/dev/null"});
    return m_proc.waitForStarted(2000);
}
void TermSession::write(const QString &t) { if (running()) m_proc.write(t.toUtf8()); }
void TermSession::interrupt() { write(QString(QChar(3))); }
void TermSession::stop() { if (running()) { m_proc.terminate(); if (!m_proc.waitForFinished(500)) m_proc.kill(); } }
