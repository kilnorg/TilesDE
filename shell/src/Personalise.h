#pragma once
#include <QJSEngine>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;

// Persisted personalisation store (QML singleton "Personalise", module FlowShell).
// One JSON file: $TILESDE_CONFIG, else $XDG_CONFIG_HOME/tilesde/theme.json, else ~/.config/tilesde/theme.json.
// Every setter validates and clamps, emits its NOTIFY signal (live apply) and schedules a debounced save (600 ms).
// A missing or corrupt file yields defaults (status "missing" / "corrupt"; a corrupt file is copied to theme.json.bad).
// Schema, see docs/tiles-spec.md "Personalisation".
class Personalise : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString preset READ preset WRITE setPreset NOTIFY presetChanged)
    Q_PROPERTY(QString scheme READ scheme WRITE setScheme NOTIFY schemeChanged)              // dark | amoled | light
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY accentChanged)              // "#rrggbb"
    Q_PROPERTY(double tileOpacity READ tileOpacity WRITE setTileOpacity NOTIFY tileOpacityChanged)  // 0.2 .. 1
    Q_PROPERTY(int tileRadius READ tileRadius WRITE setTileRadius NOTIFY tileRadiusChanged)  // 0 .. 40 px
    Q_PROPERTY(int gap READ gap WRITE setGap NOTIFY gapChanged)                              // 0 .. 12 px
    Q_PROPERTY(int columns READ columns WRITE setColumns NOTIFY columnsChanged)              // 3 | 4
    Q_PROPERTY(bool tilesOverWallpaper READ tilesOverWallpaper WRITE setTilesOverWallpaper NOTIFY tilesOverWallpaperChanged)
    Q_PROPERTY(double grain READ grain WRITE setGrain NOTIFY grainChanged)                   // 0 .. 1
    Q_PROPERTY(bool labels READ labels WRITE setLabels NOTIFY labelsChanged)
    Q_PROPERTY(bool badges READ badges WRITE setBadges NOTIFY badgesChanged)
    Q_PROPERTY(int flipSpeed READ flipSpeed WRITE setFlipSpeed NOTIFY flipSpeedChanged)      // 0 off, 1 normal, 2 fast
    Q_PROPERTY(int fontWeight READ fontWeight WRITE setFontWeight NOTIFY fontWeightChanged)  // 100 .. 900, hundreds
    Q_PROPERTY(QString titleCase READ titleCase WRITE setTitleCase NOTIFY titleCaseChanged)  // lower | upper
    Q_PROPERTY(QString motion READ motion WRITE setMotion NOTIFY motionChanged)              // off | low | normal | high
    Q_PROPERTY(QVariantList groups READ groups WRITE setGroups NOTIFY groupsChanged)         // [{name, collapsed}]
    Q_PROPERTY(QVariantMap tileColors READ tileColors WRITE setTileColors NOTIFY tileColorsChanged)  // {tileId: "#rrggbb"}
    Q_PROPERTY(QString startPhoto READ startPhoto WRITE setStartPhoto NOTIFY startPhotoChanged)
    Q_PROPERTY(QVariantMap customPresets READ customPresets WRITE setCustomPresets NOTIFY customPresetsChanged)
    // read-only
    Q_PROPERTY(QStringList presetNames READ presetNames NOTIFY presetListChanged)            // built-in then custom
    Q_PROPERTY(QStringList builtinPresetNames READ builtinPresetNames CONSTANT)
    Q_PROPERTY(QVariantMap currentPreset READ currentPreset NOTIFY currentPresetChanged)     // definition of `preset`
    Q_PROPERTY(QStringList accentColours READ accentColours CONSTANT)                        // 12 accent swatches
    Q_PROPERTY(QStringList accentNames READ accentNames CONSTANT)
    Q_PROPERTY(QString path READ path CONSTANT)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)                              // ok | missing | corrupt
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged)                                    // unsaved changes pending
public:
    explicit Personalise(QObject *parent = nullptr, const QString &path = QString());
    ~Personalise() override;
    static Personalise *instance();
    static Personalise *create(QQmlEngine *, QJSEngine *) {
        auto *p = instance(); QJSEngine::setObjectOwnership(p, QJSEngine::CppOwnership); return p;
    }

    QString preset() const { return m_preset; }
    QString scheme() const { return m_scheme; }
    QString accent() const { return m_accent; }
    double tileOpacity() const { return m_tileOpacity; }
    int tileRadius() const { return m_tileRadius; }
    int gap() const { return m_gap; }
    int columns() const { return m_columns; }
    bool tilesOverWallpaper() const { return m_tilesOverWallpaper; }
    double grain() const { return m_grain; }
    bool labels() const { return m_labels; }
    bool badges() const { return m_badges; }
    int flipSpeed() const { return m_flipSpeed; }
    int fontWeight() const { return m_fontWeight; }
    QString titleCase() const { return m_titleCase; }
    QString motion() const { return m_motion; }
    QVariantList groups() const { return m_groups; }
    QVariantMap tileColors() const { return m_tileColors; }
    QString startPhoto() const { return m_startPhoto; }
    QVariantMap customPresets() const { return m_custom; }
    QStringList presetNames() const;
    QStringList builtinPresetNames() const;
    QVariantMap currentPreset() const { return presetData(m_preset); }
    QStringList accentColours() const;
    QStringList accentNames() const;
    QString path() const { return m_path; }
    QString status() const { return m_status; }
    bool dirty() const { return m_save.isActive(); }

    void setPreset(const QString &v) { applyPreset(v); }
    void setScheme(const QString &v);
    void setAccent(const QString &v);
    void setTileOpacity(double v);
    void setTileRadius(int v);
    void setGap(int v);
    void setColumns(int v);
    void setTilesOverWallpaper(bool v);
    void setGrain(double v);
    void setLabels(bool v);
    void setBadges(bool v);
    void setFlipSpeed(int v);
    void setFontWeight(int v);
    void setTitleCase(const QString &v);
    void setMotion(const QString &v);
    void setGroups(const QVariantList &v);
    void setTileColors(const QVariantMap &v);
    void setStartPhoto(const QString &v);
    void setCustomPresets(const QVariantMap &v);

    // ---- generic access (QML and the control socket) ----
    Q_INVOKABLE bool set(const QString &key, const QVariant &value);     // schema key -> value, false if unknown/invalid
    Q_INVOKABLE QVariant get(const QString &key) const;                  // schema key (or "all") -> value
    Q_INVOKABLE bool command(const QString &key, const QString &value); // control socket: aliases + string parsing, see docs
    Q_INVOKABLE QString toJson() const;                                  // whole schema as compact JSON
    Q_INVOKABLE QVariantMap toMap() const;
    Q_INVOKABLE bool applyPreset(const QString &name);                   // switch preset and copy its defaults into the settings
    Q_INVOKABLE QVariantMap presetData(const QString &name) const;       // built-in or custom definition, {} if unknown
    Q_INVOKABLE bool savePreset(const QString &name);                    // snapshot current look as custom preset
    Q_INVOKABLE bool deletePreset(const QString &name);                  // custom only
    Q_INVOKABLE void reset();                                            // factory defaults (custom presets kept)
    Q_INVOKABLE bool reload();                                           // re-read the file
    Q_INVOKABLE bool saveNow();                                          // flush the debounce timer
    Q_INVOKABLE void setTileColor(const QString &id, const QString &colour);  // "" clears
    Q_INVOKABLE void clearTileColors();
    Q_INVOKABLE void addGroup(const QString &name);
    Q_INVOKABLE void removeGroup(int index);
    Q_INVOKABLE void renameGroup(int index, const QString &name);
    Q_INVOKABLE void setGroupCollapsed(int index, bool collapsed);
    Q_INVOKABLE void toggleGroup(int index);
    Q_INVOKABLE void moveGroup(int from, int to);
signals:
    void presetChanged(); void schemeChanged(); void accentChanged(); void tileOpacityChanged(); void tileRadiusChanged();
    void gapChanged(); void columnsChanged(); void tilesOverWallpaperChanged(); void grainChanged(); void labelsChanged();
    void badgesChanged(); void flipSpeedChanged(); void fontWeightChanged(); void titleCaseChanged(); void motionChanged();
    void groupsChanged(); void tileColorsChanged(); void startPhotoChanged(); void customPresetsChanged();
    void presetListChanged(); void currentPresetChanged(); void statusChanged(); void dirtyChanged();
    void changed(const QString &key);       // any key, after validation
private:
    void touch(const QString &key);
    void setStatus(const QString &s);
    void load();
    bool applyObject(const QVariantMap &o);
    void defaults();
    static QString normColour(const QString &c);
    static QVariantList normGroups(const QVariant &v, bool *ok);

    QString m_path, m_status = "missing";
    QString m_preset, m_scheme, m_accent, m_titleCase, m_motion, m_startPhoto;
    double m_tileOpacity = 1.0, m_grain = 0.0;
    int m_tileRadius = 0, m_gap = 6, m_columns = 4, m_flipSpeed = 1, m_fontWeight = 300;
    bool m_tilesOverWallpaper = false, m_labels = true, m_badges = true;
    QVariantList m_groups;
    QVariantMap m_tileColors, m_custom;
    QTimer m_save;
    bool m_loading = false;
};
