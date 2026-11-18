#include "Personalise.h"
#include <QColor>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QtMath>

namespace {
const QStringList kBuiltin = {"glaze", "classic", "colourful", "mono", "paper"};
const QStringList kAccentColours = {"#D97757", "#E5484D", "#E8508C", "#A855D6", "#6E56CF", "#3E63DD",
                                    "#0F8BD6", "#12A594", "#30A46C", "#7D9A2E", "#E5A100", "#7A7A7A"};
const QStringList kAccentNames = {"terracotta", "red", "pink", "purple", "indigo", "blue",
                                  "cyan", "teal", "green", "lime", "amber", "steel"};
// settings a preset may carry (copied into the live settings by applyPreset)
const QStringList kPresetSettings = {"scheme", "accent", "tileOpacity", "tileRadius", "gap", "columns", "grain",
                                     "labels", "badges", "fontWeight", "titleCase", "tilesOverWallpaper"};
// look-only keys of a preset definition (read by Theme.qml)
const QStringList kPresetLook = {"label", "palette", "bgDark", "bgLight", "cardDark", "cardLight", "textDark", "dimDark", "base", "custom"};
const QStringList kSchemaKeys = {"preset", "scheme", "accent", "tileOpacity", "tileRadius", "gap", "columns", "tilesOverWallpaper",
                                 "grain", "labels", "badges", "flipSpeed", "fontWeight", "titleCase", "motion", "groups",
                                 "tileColors", "startPhoto", "customPresets"};

QVariantList list(const QStringList &l) { QVariantList r; for (const auto &s : l) r << s; return r; }

QVariantMap builtin(const QString &n) {
    QVariantMap m;
    if (n == "glaze")        // terracotta / ink / paper tiles on dark paper, from the Glaze start menu
        m = {{"label", "glaze"}, {"scheme", "amoled"}, {"accent", "#d97757"}, {"palette", list({"#d97757", "#22211f", "#d8d6cf"})},
             {"bgDark", "#363532"}, {"bgLight", "#ffffff"}, {"cardDark", "#2a2927"}, {"cardLight", "#f0f0f0"},
             {"textDark", "#f4f2ec"}, {"dimDark", "#a8a59c"}, {"tileRadius", 0}, {"gap", 6}, {"tileOpacity", 1.0}, {"grain", 0.6}};
    else if (n == "classic") // four-colour phone palette on black
        m = {{"label", "classic"}, {"scheme", "amoled"}, {"accent", "#1ba1e2"}, {"palette", list({"#e8a900", "#1ba1e2", "#339933", "#a20025"})},
             {"bgDark", "#000000"}, {"bgLight", "#ffffff"}, {"cardDark", "#1b1b1b"}, {"cardLight", "#f0f0f0"},
             {"textDark", "#ffffff"}, {"dimDark", "#9a9a9a"}, {"tileRadius", 0}, {"gap", 6}, {"tileOpacity", 1.0}, {"grain", 0.0}};
    else if (n == "colourful") // vivid multi-colour tiles on pure black
        m = {{"label", "colourful"}, {"scheme", "amoled"}, {"accent", "#0050ef"}, {"palette", list({"#d80073", "#0050ef", "#60a917", "#fa6800", "#aa00ff", "#00aba9", "#e51400", "#a4c400"})},
             {"bgDark", "#000000"}, {"bgLight", "#ffffff"}, {"cardDark", "#1b1b1b"}, {"cardLight", "#f0f0f0"},
             {"textDark", "#ffffff"}, {"dimDark", "#9a9a9a"}, {"tileRadius", 0}, {"gap", 6}, {"tileOpacity", 1.0}, {"grain", 0.0}};
    else if (n == "mono")
        m = {{"label", "mono"}, {"scheme", "amoled"}, {"accent", "#8a8a8a"}, {"palette", list({"#3a3a3a", "#5a5a5a", "#8a8a8a", "#b5b5b5"})},
             {"bgDark", "#000000"}, {"bgLight", "#ffffff"}, {"cardDark", "#1b1b1b"}, {"cardLight", "#f0f0f0"},
             {"textDark", "#ffffff"}, {"dimDark", "#9a9a9a"}, {"tileRadius", 0}, {"gap", 6}, {"tileOpacity", 1.0}, {"grain", 0.0}};
    else if (n == "paper")   // light glaze
        m = {{"label", "paper"}, {"scheme", "light"}, {"accent", "#d97757"}, {"palette", list({"#d97757", "#22211f", "#d8d6cf"})},
             {"bgDark", "#363532"}, {"bgLight", "#efeee8"}, {"cardDark", "#2a2927"}, {"cardLight", "#e2e0d8"},
             {"textDark", "#f4f2ec"}, {"dimDark", "#a8a59c"}, {"tileRadius", 0}, {"gap", 6}, {"tileOpacity", 1.0}, {"grain", 0.4}};
    return m;
}

bool toBool(const QVariant &v, bool *ok) {
    *ok = true;
    if (v.typeId() == QMetaType::Bool) return v.toBool();
    const QString s = v.toString().trimmed().toLower();
    if (s == "true" || s == "1" || s == "on" || s == "yes") return true;
    if (s == "false" || s == "0" || s == "off" || s == "no") return false;
    *ok = false; return false;
}
int toInt(const QVariant &v, bool *ok) { double d = v.toString().trimmed().toDouble(ok); if (v.typeId() != QMetaType::QString) d = v.toDouble(ok); return qRound(d); }
double toDouble(const QVariant &v, bool *ok) { return v.typeId() == QMetaType::QString ? v.toString().trimmed().toDouble(ok) : v.toDouble(ok); }
QVariantMap fromJsonVariant(const QVariant &v, bool *ok) {
    *ok = true;
    if (v.typeId() == QMetaType::QVariantMap) return v.toMap();
    if (v.typeId() == QMetaType::QString) {
        const auto d = QJsonDocument::fromJson(v.toString().toUtf8());
        if (d.isObject()) return d.object().toVariantMap();
    }
    *ok = false; return {};
}
}  // namespace

Personalise *Personalise::instance() {
    static Personalise *s = new Personalise(qApp);
    return s;
}

QStringList Personalise::accentColours() const { return kAccentColours; }
QStringList Personalise::accentNames() const { return kAccentNames; }
QStringList Personalise::builtinPresetNames() const { return kBuiltin; }
QStringList Personalise::presetNames() const { QStringList l = kBuiltin; l << m_custom.keys(); return l; }

Personalise::Personalise(QObject *parent, const QString &path) : QObject(parent) {
    m_path = path;
    if (m_path.isEmpty()) m_path = qEnvironmentVariable("TILESDE_CONFIG");
    if (m_path.isEmpty()) {
        QString base = qEnvironmentVariable("XDG_CONFIG_HOME");
        if (base.isEmpty()) base = QDir::homePath() + "/.config";
        m_path = base + "/tilesde/theme.json";
    }
    m_save.setSingleShot(true);
    m_save.setInterval(600);
    connect(&m_save, &QTimer::timeout, this, [this] { saveNow(); });
    if (auto *a = QCoreApplication::instance()) connect(a, &QCoreApplication::aboutToQuit, this, [this] { saveNow(); });
    defaults();
    load();
}

Personalise::~Personalise() { if (m_save.isActive()) saveNow(); }

void Personalise::defaults() {
    m_preset = "glaze";
    const QVariantMap d = builtin("glaze");
    m_scheme = "amoled"; m_accent = "#d97757"; m_tileOpacity = 1.0; m_tileRadius = 0; m_gap = 6; m_columns = 4;
    m_grain = d["grain"].toDouble(); m_tilesOverWallpaper = false; m_labels = true; m_badges = true;
    m_flipSpeed = 1; m_fontWeight = 300; m_titleCase = "lower"; m_motion = "normal"; m_startPhoto.clear();
    m_groups = {QVariantMap{{"name", "Productivity"}, {"collapsed", false}}, QVariantMap{{"name", "Explore"}, {"collapsed", false}}};
    m_tileColors.clear();
}

void Personalise::setStatus(const QString &s) { if (s != m_status) { m_status = s; emit statusChanged(); } }

void Personalise::touch(const QString &key) {
    emit changed(key);
    if (!m_loading) { m_save.start(); emit dirtyChanged(); }
}

QString Personalise::normColour(const QString &c) {
    const QString s = c.trimmed();
    if (s.isEmpty()) return {};
    const QColor q(s);
    if (!q.isValid()) return {};
    return q.alpha() == 255 ? q.name(QColor::HexRgb) : q.name(QColor::HexArgb);
}

// ---------- setters ----------
#define PERS_SET_STR(Fn, Member, Sig, Key, Valid) \
    void Personalise::Fn(const QString &v) { const QString n = v.trimmed().toLower(); if (!(Valid) || n == Member) return; Member = n; emit Sig(); touch(Key); }
PERS_SET_STR(setScheme, m_scheme, schemeChanged, "scheme", n == "dark" || n == "amoled" || n == "light")
PERS_SET_STR(setTitleCase, m_titleCase, titleCaseChanged, "titleCase", n == "lower" || n == "upper")
PERS_SET_STR(setMotion, m_motion, motionChanged, "motion", n == "off" || n == "low" || n == "normal" || n == "high")
#undef PERS_SET_STR

void Personalise::setAccent(const QString &v) {
    const QString n = normColour(v);
    if (n.isEmpty() || n == m_accent) return;
    m_accent = n; emit accentChanged(); touch("accent");
}
void Personalise::setTileOpacity(double v) {
    v = qRound(qBound(0.2, v, 1.0) * 100) / 100.0;
    if (qFuzzyCompare(v, m_tileOpacity)) return;
    m_tileOpacity = v; emit tileOpacityChanged(); touch("tileOpacity");
}
void Personalise::setTileRadius(int v) { v = qBound(0, v, 40); if (v == m_tileRadius) return; m_tileRadius = v; emit tileRadiusChanged(); touch("tileRadius"); }
void Personalise::setGap(int v) { v = qBound(0, v, 12); if (v == m_gap) return; m_gap = v; emit gapChanged(); touch("gap"); }
void Personalise::setColumns(int v) { if ((v != 3 && v != 4) || v == m_columns) return; m_columns = v; emit columnsChanged(); touch("columns"); }
void Personalise::setTilesOverWallpaper(bool v) { if (v == m_tilesOverWallpaper) return; m_tilesOverWallpaper = v; emit tilesOverWallpaperChanged(); touch("tilesOverWallpaper"); }
void Personalise::setGrain(double v) {
    v = qRound(qBound(0.0, v, 1.0) * 100) / 100.0;
    if (qFuzzyCompare(v + 1, m_grain + 1)) return;
    m_grain = v; emit grainChanged(); touch("grain");
}
void Personalise::setLabels(bool v) { if (v == m_labels) return; m_labels = v; emit labelsChanged(); touch("labels"); }
void Personalise::setBadges(bool v) { if (v == m_badges) return; m_badges = v; emit badgesChanged(); touch("badges"); }
void Personalise::setFlipSpeed(int v) { v = qBound(0, v, 2); if (v == m_flipSpeed) return; m_flipSpeed = v; emit flipSpeedChanged(); touch("flipSpeed"); }
void Personalise::setFontWeight(int v) {
    v = qBound(100, qRound(v / 100.0) * 100, 900);
    if (v == m_fontWeight) return;
    m_fontWeight = v; emit fontWeightChanged(); touch("fontWeight");
}
void Personalise::setStartPhoto(const QString &v) { if (v == m_startPhoto) return; m_startPhoto = v; emit startPhotoChanged(); touch("startPhoto"); }

QVariantList Personalise::normGroups(const QVariant &v, bool *ok) {
    *ok = true;
    QVariantList in;
    if (v.typeId() == QMetaType::QString) {
        const auto d = QJsonDocument::fromJson(v.toString().toUtf8());
        if (!d.isArray()) { *ok = false; return {}; }
        in = d.array().toVariantList();
    } else if (v.canConvert<QVariantList>()) in = v.toList();
    else { *ok = false; return {}; }
    QVariantList out; QStringList seen;
    for (const QVariant &e : std::as_const(in)) {
        QString name; bool col = false;
        if (e.typeId() == QMetaType::QString) name = e.toString();
        else if (e.canConvert<QVariantMap>()) { const auto m = e.toMap(); name = m["name"].toString(); col = m["collapsed"].toBool(); }
        name = name.trimmed().left(40);
        if (name.isEmpty() || seen.contains(name) || out.size() >= 32) continue;
        seen << name; out << QVariantMap{{"name", name}, {"collapsed", col}};
    }
    return out;
}
void Personalise::setGroups(const QVariantList &v) {
    bool ok; const QVariantList n = normGroups(v, &ok);
    if (!ok || n == m_groups) return;
    m_groups = n; emit groupsChanged(); touch("groups");
}
void Personalise::addGroup(const QString &name) { QVariantList l = m_groups; l << QVariantMap{{"name", name}, {"collapsed", false}}; setGroups(l); }
void Personalise::removeGroup(int i) { QVariantList l = m_groups; if (i < 0 || i >= l.size()) return; l.removeAt(i); setGroups(l); }
void Personalise::renameGroup(int i, const QString &name) {
    QVariantList l = m_groups; if (i < 0 || i >= l.size()) return;
    QVariantMap m = l[i].toMap(); m["name"] = name; l[i] = m; setGroups(l);
}
void Personalise::setGroupCollapsed(int i, bool c) {
    QVariantList l = m_groups; if (i < 0 || i >= l.size()) return;
    QVariantMap m = l[i].toMap(); m["collapsed"] = c; l[i] = m; setGroups(l);
}
void Personalise::toggleGroup(int i) { if (i >= 0 && i < m_groups.size()) setGroupCollapsed(i, !m_groups[i].toMap()["collapsed"].toBool()); }
void Personalise::moveGroup(int from, int to) {
    QVariantList l = m_groups;
    if (from < 0 || from >= l.size() || to < 0 || to >= l.size() || from == to) return;
    l.move(from, to); setGroups(l);
}

void Personalise::setTileColors(const QVariantMap &v) {
    QVariantMap n;
    for (auto it = v.constBegin(); it != v.constEnd(); ++it) {
        const QString c = normColour(it.value().toString());
        if (!it.key().isEmpty() && !c.isEmpty()) n[it.key()] = c;
    }
    if (n == m_tileColors) return;
    m_tileColors = n; emit tileColorsChanged(); touch("tileColors");
}
void Personalise::setTileColor(const QString &id, const QString &colour) {
    QVariantMap m = m_tileColors;
    if (colour.isEmpty()) m.remove(id); else m[id] = colour;
    setTileColors(m);
}
void Personalise::clearTileColors() { setTileColors({}); }

// ---------- presets ----------
QVariantMap Personalise::presetData(const QString &name) const {
    if (kBuiltin.contains(name)) return builtin(name);
    return m_custom.value(name).toMap();
}

bool Personalise::applyPreset(const QString &name) {
    const QVariantMap d = presetData(name);
    if (d.isEmpty()) return false;
    const bool was = m_loading;
    m_loading = true;
    if (m_preset != name) { m_preset = name; emit presetChanged(); }
    for (const QString &k : kPresetSettings) if (d.contains(k)) set(k, d[k]);
    emit currentPresetChanged();
    m_loading = was;
    touch("preset");
    return true;
}

bool Personalise::savePreset(const QString &nameIn) {
    const QString name = nameIn.trimmed().left(32);
    if (name.isEmpty() || kBuiltin.contains(name.toLower())) return false;
    QVariantMap base = presetData(m_preset), snap;
    for (const QString &k : kPresetLook) if (base.contains(k)) snap[k] = base[k];
    const QString oldAcc = normColour(base["accent"].toString());
    QVariantList pal;
    for (const QVariant &c : base["palette"].toList()) pal << (normColour(c.toString()) == oldAcc ? m_accent : normColour(c.toString()));
    if (pal.isEmpty()) pal << m_accent;
    snap["palette"] = pal; snap["label"] = name; snap["custom"] = true;
    snap["base"] = base.value("base", m_preset);
    snap["scheme"] = m_scheme; snap["accent"] = m_accent; snap["tileOpacity"] = m_tileOpacity; snap["tileRadius"] = m_tileRadius;
    snap["gap"] = m_gap; snap["columns"] = m_columns; snap["grain"] = m_grain; snap["labels"] = m_labels; snap["badges"] = m_badges;
    snap["fontWeight"] = m_fontWeight; snap["titleCase"] = m_titleCase; snap["tilesOverWallpaper"] = m_tilesOverWallpaper;
    m_custom[name] = snap;
    emit customPresetsChanged(); emit presetListChanged();
    m_preset = name; emit presetChanged(); emit currentPresetChanged();
    touch("customPresets");
    return true;
}

bool Personalise::deletePreset(const QString &name) {
    if (!m_custom.contains(name)) return false;
    m_custom.remove(name);
    emit customPresetsChanged(); emit presetListChanged();
    if (m_preset == name) { m_preset = "glaze"; emit presetChanged(); }
    emit currentPresetChanged();
    touch("customPresets");
    return true;
}

void Personalise::setCustomPresets(const QVariantMap &v) {
    QVariantMap n;
    for (auto it = v.constBegin(); it != v.constEnd(); ++it) {
        const QString name = it.key().trimmed().left(32);
        if (name.isEmpty() || kBuiltin.contains(name.toLower()) || !it.value().canConvert<QVariantMap>()) continue;
        QVariantMap src = it.value().toMap(), p;
        QVariantList pal;
        for (const QVariant &c : src["palette"].toList()) { const QString q = normColour(c.toString()); if (!q.isEmpty()) pal << q; }
        if (pal.isEmpty()) continue;
        p["palette"] = pal;
        for (const QString &k : {"bgDark", "bgLight", "cardDark", "cardLight", "textDark", "dimDark", "accent"}) {
            const QString q = normColour(src[k].toString()); if (!q.isEmpty()) p[k] = q;
        }
        for (const QString &k : {"scheme", "titleCase"}) if (src.contains(k)) p[k] = src[k].toString();
        for (const QString &k : {"tileOpacity", "grain"}) if (src.contains(k)) p[k] = src[k].toDouble();
        for (const QString &k : {"tileRadius", "gap", "columns", "fontWeight"}) if (src.contains(k)) p[k] = src[k].toInt();
        for (const QString &k : {"labels", "badges", "tilesOverWallpaper"}) if (src.contains(k)) p[k] = src[k].toBool();
        p["label"] = name; p["custom"] = true; p["base"] = src["base"].toString();
        n[name] = p;
    }
    if (n == m_custom) return;
    m_custom = n;
    emit customPresetsChanged(); emit presetListChanged();
    if (!kBuiltin.contains(m_preset) && !m_custom.contains(m_preset)) { m_preset = "glaze"; emit presetChanged(); }
    emit currentPresetChanged();
    touch("customPresets");
}

// ---------- generic access ----------
bool Personalise::set(const QString &key, const QVariant &v) {
    bool ok = true;
    auto S = [&] { return v.toString(); };
    if (key == "preset") return applyPreset(S().trimmed());
    if (key == "scheme") { const QString n = S().trimmed().toLower(); if (n != "dark" && n != "amoled" && n != "light") return false; setScheme(n); return true; }
    if (key == "accent") { if (normColour(S()).isEmpty()) return false; setAccent(S()); return true; }
    if (key == "tileOpacity") { double d = toDouble(v, &ok); if (!ok) return false; setTileOpacity(d); return true; }
    if (key == "grain") { double d = toDouble(v, &ok); if (!ok) return false; setGrain(d); return true; }
    if (key == "tileRadius") { int i = toInt(v, &ok); if (!ok) return false; setTileRadius(i); return true; }
    if (key == "gap") { int i = toInt(v, &ok); if (!ok) return false; setGap(i); return true; }
    if (key == "columns") { int i = toInt(v, &ok); if (!ok || (i != 3 && i != 4)) return false; setColumns(i); return true; }
    if (key == "flipSpeed") { int i = toInt(v, &ok); if (!ok) return false; setFlipSpeed(i); return true; }
    if (key == "fontWeight") { int i = toInt(v, &ok); if (!ok) return false; setFontWeight(i); return true; }
    if (key == "tilesOverWallpaper") { bool b = toBool(v, &ok); if (!ok) return false; setTilesOverWallpaper(b); return true; }
    if (key == "labels") { bool b = toBool(v, &ok); if (!ok) return false; setLabels(b); return true; }
    if (key == "badges") { bool b = toBool(v, &ok); if (!ok) return false; setBadges(b); return true; }
    if (key == "titleCase") { const QString n = S().trimmed().toLower(); if (n != "lower" && n != "upper") return false; setTitleCase(n); return true; }
    if (key == "motion") { const QString n = S().trimmed().toLower(); if (n != "off" && n != "low" && n != "normal" && n != "high") return false; setMotion(n); return true; }
    if (key == "startPhoto") { setStartPhoto(S()); return true; }
    if (key == "groups") { QVariantList l = normGroups(v, &ok); if (!ok) return false; setGroups(l); return true; }
    if (key == "tileColors") { QVariantMap m = fromJsonVariant(v, &ok); if (!ok) return false; setTileColors(m); return true; }
    if (key == "customPresets") { QVariantMap m = fromJsonVariant(v, &ok); if (!ok) return false; setCustomPresets(m); return true; }
    return false;
}

QVariant Personalise::get(const QString &key) const {
    if (key == "all") return toMap();
    if (!kSchemaKeys.contains(key)) return {};
    return property(key.toUtf8().constData());
}

QVariantMap Personalise::toMap() const {
    QVariantMap m;
    for (const QString &k : kSchemaKeys) m[k] = property(k.toUtf8().constData());
    return m;
}
QString Personalise::toJson() const { return QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(toMap())).toJson(QJsonDocument::Compact)); }

bool Personalise::command(const QString &key, const QString &v) {
    static const QHash<QString, QString> alias = {
        {"opacity", "tileOpacity"}, {"radius", "tileRadius"}, {"wallpaper", "tilesOverWallpaper"}, {"flip", "flipSpeed"},
        {"weight", "fontWeight"}, {"case", "titleCase"}, {"photo", "startPhoto"}};
    const QString k = alias.value(key, key);
    bool ok = true;
    if (k == "flush") return saveNow();
    if (k == "reload") return reload();
    if (k == "reset") { reset(); return true; }
    if (k == "loadPreset") return applyPreset(v);
    if (k == "savePreset") return savePreset(v);
    if (k == "deletePreset") return deletePreset(v);
    if (k == "amoled") {
        const bool b = toBool(v, &ok); if (!ok) return false;
        if (b) setScheme("amoled"); else if (m_scheme == "amoled") setScheme("dark");
        return true;
    }
    if (k == "accent") {
        const int i = kAccentNames.indexOf(v.trimmed().toLower());
        if (i >= 0) { setAccent(kAccentColours[i]); return true; }
        bool isInt = false; const int n = v.trimmed().toInt(&isInt);
        if (isInt && n >= 0 && n < kAccentColours.size() && !v.startsWith("#")) { setAccent(kAccentColours[n]); return true; }
    }
    if (k == "tileColor") {   // "id=#rrggbb" sets, "id" or "id=" clears
        const int e = v.indexOf('=');
        const QString id = (e < 0 ? v : v.left(e)).trimmed(), c = e < 0 ? QString() : v.mid(e + 1).trimmed();
        if (id.isEmpty() || (!c.isEmpty() && normColour(c).isEmpty())) return false;
        setTileColor(id, c); return true;
    }
    if (k == "clearTileColors") { clearTileColors(); return true; }
    if (k == "toggleGroup") { toggleGroup(v.toInt()); return true; }
    if (k == "addGroup") { addGroup(v); return true; }
    if (k == "removeGroup") { removeGroup(v.toInt()); return true; }
    if (kSchemaKeys.contains(k)) return set(k, v);
    return false;
}

void Personalise::reset() {
    const bool was = m_loading; m_loading = true;
    defaults();
    m_loading = was;
    emit presetChanged(); emit schemeChanged(); emit accentChanged(); emit tileOpacityChanged(); emit tileRadiusChanged();
    emit gapChanged(); emit columnsChanged(); emit tilesOverWallpaperChanged(); emit grainChanged(); emit labelsChanged();
    emit badgesChanged(); emit flipSpeedChanged(); emit fontWeightChanged(); emit titleCaseChanged(); emit motionChanged();
    emit groupsChanged(); emit tileColorsChanged(); emit startPhotoChanged(); emit currentPresetChanged();
    touch("reset");
}

// ---------- file ----------
bool Personalise::applyObject(const QVariantMap &o) {
    const bool was = m_loading; m_loading = true;
    bool any = false;
    if (o.contains("customPresets")) any |= set("customPresets", o["customPresets"]);
    if (o.contains("preset")) {
        const QString p = o["preset"].toString();
        if (!presetData(p).isEmpty() && p != m_preset) { m_preset = p; emit presetChanged(); emit currentPresetChanged(); }
    }
    for (const QString &k : kSchemaKeys)
        if (k != "preset" && k != "customPresets" && o.contains(k)) any |= set(k, o[k]);
    m_loading = was;
    return any;
}

void Personalise::load() {
    QFile f(m_path);
    if (!f.exists()) { setStatus("missing"); return; }
    QJsonParseError err;
    const QByteArray raw = f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
    const auto doc = QJsonDocument::fromJson(raw, &err);
    if (raw.isEmpty() || err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "tilesde theme file corrupt, using defaults:" << m_path << err.errorString();
        QFile::remove(m_path + ".bad");
        QFile::copy(m_path, m_path + ".bad");
        setStatus("corrupt");
        return;
    }
    applyObject(doc.object().toVariantMap());
    setStatus("ok");
}

bool Personalise::reload() {
    const bool was = m_loading; m_loading = true;
    defaults(); m_custom.clear(); m_loading = was;
    load();
    // defaults() rewrote members silently: tell QML everything may have changed
    emit presetChanged(); emit schemeChanged(); emit accentChanged(); emit tileOpacityChanged(); emit tileRadiusChanged();
    emit gapChanged(); emit columnsChanged(); emit tilesOverWallpaperChanged(); emit grainChanged(); emit labelsChanged();
    emit badgesChanged(); emit flipSpeedChanged(); emit fontWeightChanged(); emit titleCaseChanged(); emit motionChanged();
    emit groupsChanged(); emit tileColorsChanged(); emit startPhotoChanged(); emit customPresetsChanged();
    emit presetListChanged(); emit currentPresetChanged();
    return m_status == "ok";
}

bool Personalise::saveNow() {
    const bool wasActive = m_save.isActive();
    m_save.stop();
    QDir().mkpath(QFileInfo(m_path).absolutePath());
    QSaveFile f(m_path);
    if (!f.open(QIODevice::WriteOnly)) { qWarning() << "tilesde theme file not writable:" << m_path; return false; }
    f.write(QJsonDocument(QJsonObject::fromVariantMap(toMap())).toJson(QJsonDocument::Indented));
    if (!f.commit()) { qWarning() << "tilesde theme file commit failed:" << m_path; return false; }
    setStatus("ok");
    if (wasActive) emit dirtyChanged();
    return true;
}
