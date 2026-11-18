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
    explicit Sys(QObject *p = nullptr) : QObject(p) {}
    Q_INVOKABLE bool launch(const QString &prog, const QStringList &args = {}) const;
    Q_INVOKABLE bool openUrl(const QString &url) const;
    Q_INVOKABLE QString home() const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE QString readText(const QString &path, int maxBytes = 262144) const;
    Q_INVOKABLE QVariantList listDir(const QString &path, const QStringList &exts = {}, bool recursive = false, int limit = 2000) const;
    Q_INVOKABLE QVariantMap run(const QString &prog, const QStringList &args = {}, int timeoutMs = 3000) const;
};

// Interactive shell session on a pty (via util-linux `script`). QML: TermSession { id: t; shell: "/bin/bash" }, t.start(),
// t.write("ls\n"), onOutput(text) (raw bytes as UTF-8 incl. ANSI escapes), onFinished(code). rows/cols exported as LINES/COLUMNS.
class TermSession : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString shell READ shell WRITE setShell NOTIFY shellChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int cols MEMBER m_cols NOTIFY sizeChanged)
    Q_PROPERTY(int rows MEMBER m_rows NOTIFY sizeChanged)
public:
    explicit TermSession(QObject *p = nullptr);
    ~TermSession() override;
    QString shell() const { return m_shell; }
    void setShell(const QString &s) { if (s != m_shell) { m_shell = s; emit shellChanged(); } }
    bool running() const { return m_proc.state() != QProcess::NotRunning; }
    Q_INVOKABLE bool start();
    Q_INVOKABLE void write(const QString &text);
    Q_INVOKABLE void interrupt();
    Q_INVOKABLE void stop();
signals:
    void output(const QString &text);
    void finished(int code);
    void shellChanged();
    void runningChanged();
    void sizeChanged();
private:
    QProcess m_proc;
    QString m_shell = "/bin/bash";
    int m_cols = 48, m_rows = 24;
};
