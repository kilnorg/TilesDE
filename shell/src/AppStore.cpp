#include "AppStore.h"
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

QString AppStore::dir() const {
    QString base = qEnvironmentVariable("TILESDE_CONFIG");
    if (!base.isEmpty()) base = QFileInfo(base).isDir() ? base : QFileInfo(base).absolutePath();
    else base = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/tilesde";
    return base + "/apps";
}
static QString safe(const QString &a) { QString s = a; s.replace(QRegularExpression("[^A-Za-z0-9_-]"), "_"); return s; }

QVariant AppStore::load(const QString &app, const QVariant &fallback) const {
    QFile f(dir() + "/" + safe(app) + ".json");
    if (!f.open(QIODevice::ReadOnly)) return fallback;
    QJsonParseError e; const auto d = QJsonDocument::fromJson(f.readAll(), &e);
    if (e.error != QJsonParseError::NoError || d.isNull()) return fallback;
    return d.isArray() ? QVariant(d.array().toVariantList()) : QVariant(d.object().toVariantMap());
}
bool AppStore::save(const QString &app, const QVariant &value) const {
    QDir().mkpath(dir());
    QSaveFile f(dir() + "/" + safe(app) + ".json");
    if (!f.open(QIODevice::WriteOnly)) return false;
    QJsonDocument d;
    const QJsonValue jv = QJsonValue::fromVariant(value);
    d = jv.isArray() ? QJsonDocument(jv.toArray()) : QJsonDocument(jv.toObject());
    f.write(d.toJson(QJsonDocument::Compact));
    return f.commit();
}
