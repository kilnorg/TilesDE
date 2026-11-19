#pragma once
#include <QObject>
#include <QVariant>

// Per-app JSON persistence for the built-in TilesDE apps: ~/.config/tilesde/apps/<app>.json
// (TILESDE_CONFIG dir override honoured). QML: AppStore.load("notes", {}) / AppStore.save("notes", obj).
class AppStore : public QObject {
    Q_OBJECT
public:
    explicit AppStore(QObject *p = nullptr) : QObject(p) {}
    Q_INVOKABLE QVariant load(const QString &app, const QVariant &fallback = {}) const;
    Q_INVOKABLE bool save(const QString &app, const QVariant &value);
    Q_INVOKABLE QString dir() const;
signals:
    void saved(const QString &app);   // after every successful save (LiveTiles refreshes on it)
};
