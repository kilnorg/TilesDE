#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
#include <deque>
#include <sys/types.h>
#include <QtQml/qqmlregistration.h>

struct VTerm;
struct VTermScreen;
class QSocketNotifier;

// Real terminal emulation: forkpty() child + libvterm screen model.
// QML: TermSession { id: t }  t.start(); t.resize(cols, rows); t.write("ls\r"); t.sendKey(Qt.Key_Up, 0);
// Render: t.lineHtml(r) for visible rows 0..rows-1 (RichText spans; default fg/bg unstyled), t.scrollbackLineHtml(i)
// with i = 0 oldest .. scrollbackCount-1 newest. rowsDamaged(first,last) is batched at 16 ms.
// Test hook: env FLOWDE_TERM_TEST="cmd; cmd" is typed (plus Enter) into the first session started, after ~1.2 s.
class TermSession : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString shell READ shell WRITE setShell NOTIFY shellChanged)
    Q_PROPERTY(int cols READ cols WRITE setCols NOTIFY sizeChanged)
    Q_PROPERTY(int rows READ rows WRITE setRows NOTIFY sizeChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(int cursorRow READ cursorRow NOTIFY cursorChanged)
    Q_PROPERTY(int cursorCol READ cursorCol NOTIFY cursorChanged)
    Q_PROPERTY(bool cursorVisible READ cursorVisible NOTIFY cursorChanged)
    Q_PROPERTY(bool altScreen READ altScreen NOTIFY altScreenChanged)
    Q_PROPERTY(int scrollbackCount READ scrollbackCount NOTIFY scrollbackChanged)
    Q_PROPERTY(bool appCursorKeys READ appCursorKeys NOTIFY appCursorKeysChanged)
    Q_PROPERTY(bool darkPalette READ darkPalette WRITE setDarkPalette NOTIFY paletteChanged)
    Q_PROPERTY(QString defaultFg READ defaultFg WRITE setDefaultFg NOTIFY paletteChanged)
    Q_PROPERTY(QString defaultBg READ defaultBg WRITE setDefaultBg NOTIFY paletteChanged)
public:
    explicit TermSession(QObject *p = nullptr);
    ~TermSession() override;
    QString shell() const { return m_shell; }
    void setShell(const QString &s) { if (s != m_shell) { m_shell = s; emit shellChanged(); } }
    int cols() const { return m_cols; }
    int rows() const { return m_rows; }
    void setCols(int c) { resize(c, m_rows); }
    void setRows(int r) { resize(m_cols, r); }
    bool running() const { return m_pid > 0; }
    QString title() const { return m_title; }
    int cursorRow() const { return m_curRow; }
    int cursorCol() const { return m_curCol; }
    bool cursorVisible() const { return m_curVisible; }
    bool altScreen() const { return m_alt; }
    int scrollbackCount() const { return int(m_sb.size()); }
    bool appCursorKeys() const { return m_appCursor; }
    bool darkPalette() const { return m_dark; }
    void setDarkPalette(bool d) { if (d != m_dark) { m_dark = d; emit paletteChanged(); } }
    QString defaultFg() const { return m_defFg; }
    void setDefaultFg(const QString &c) { if (c != m_defFg) { m_defFg = c; emit paletteChanged(); } }
    QString defaultBg() const { return m_defBg; }
    void setDefaultBg(const QString &c) { if (c != m_defBg) { m_defBg = c; emit paletteChanged(); } }

    Q_INVOKABLE bool start();
    Q_INVOKABLE void resize(int cols, int rows);
    Q_INVOKABLE void write(const QString &text);
    Q_INVOKABLE void sendKey(int qtKey, int modifiers);
    Q_INVOKABLE void stop();
    Q_INVOKABLE QString lineHtml(int row) const;
    Q_INVOKABLE QString scrollbackLineHtml(int i) const;
    Q_INVOKABLE QString screenText() const;   // visible screen as plain text (for copy)

signals:
    void shellChanged();
    void sizeChanged();
    void runningChanged();
    void titleChanged();
    void cursorChanged();
    void altScreenChanged();
    void scrollbackChanged();
    void appCursorKeysChanged();
    void paletteChanged();
    void rowsDamaged(int first, int last);
    void screenReset();
    void bell();
    void finished(int code);

private:
    friend struct TermCb;
    void onReadable();
    void childGone();
    void reap();
    void flushDamage();
    void damage(int first, int last);
    void rawWrite(const char *d, size_t n);
    QString renderCells(const void *cells, int n) const;

    VTerm *m_vt = nullptr;
    VTermScreen *m_screen = nullptr;
    QSocketNotifier *m_notifier = nullptr;
    int m_fd = -1;
    pid_t m_pid = 0;
    QString m_shell, m_title, m_titleBuf, m_defFg = "#ffffff", m_defBg = "#000000";
    int m_cols = 48, m_rows = 24;
    int m_curRow = 0, m_curCol = 0;
    bool m_curVisible = true, m_alt = false, m_appCursor = false, m_dark = true;
    int m_dmgFirst = -1, m_dmgLast = -1;
    bool m_curDirty = false;
    QTimer m_timer, m_reapTimer;
    std::deque<QString> m_sb;
    static bool s_testDone;
};
