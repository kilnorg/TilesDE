#include "AppStore.h"
#include <QDir>
#include <QFile>
#include <QJSValue>
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
bool AppStore::save(const QString &app, const QVariant &value) {
    QDir().mkpath(dir());
    QSaveFile f(dir() + "/" + safe(app) + ".json");
    if (!f.open(QIODevice::WriteOnly)) return false;
    QJsonDocument d;
    // a JS object/array handed over as QJSValue must be unwrapped first, else it serialises as {}
    const QVariant v = value.metaType() == QMetaType::fromType<QJSValue>() ? value.value<QJSValue>().toVariant() : value;
    const QJsonValue jv = QJsonValue::fromVariant(v);
    d = jv.isArray() ? QJsonDocument(jv.toArray()) : QJsonDocument(jv.toObject());
    f.write(d.toJson(QJsonDocument::Compact));
    const bool ok = f.commit();
    if (ok) emit saved(app);
    return ok;
}
