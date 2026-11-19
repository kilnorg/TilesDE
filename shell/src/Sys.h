#pragma once
#include <QObject>
#include <QProcess>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

// Small system bridge for the native apps. Context property "Sys".
//   Sys.launch("firefox-esr", ["https://..."])  detached launch, true if started
//   Sys.openUrl(url)  xdg-open;  Sys.home();  Sys.exists(path);  Sys.readText(path, maxBytes);  Sys.listDir(path, exts)
//   Sys.run(prog, args, timeoutMs)  blocking short command -> {code, out, err}  (use sparingly)
class Sys : public QObject {
    Q_OBJECT
public:
    // true in dev builds (cmake -DTILES_DEMO_DATA=ON) or when env TILES_DEMO=1: apps may seed demo mail/contacts/notes etc.
    // Release builds (default) start empty and the apps show their empty states.
    Q_PROPERTY(bool demoData READ demoData CONSTANT)
    explicit Sys(QObject *p = nullptr) : QObject(p) {}
    bool demoData() const;
    Q_INVOKABLE bool launch(const QString &prog, const QStringList &args = {}) const;
    Q_INVOKABLE bool openUrl(const QString &url) const;
    Q_INVOKABLE QString home() const;
    Q_INVOKABLE QString runtimeDir() const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE QString readText(const QString &path, int maxBytes = 262144) const;
    Q_INVOKABLE QVariantList listDir(const QString &path, const QStringList &exts = {}, bool recursive = false, int limit = 2000) const;
    Q_INVOKABLE QVariantMap run(const QString &prog, const QStringList &args = {}, int timeoutMs = 3000) const;
};
