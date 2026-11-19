#pragma once
#include <QObject>
#include <QString>
#include <QTimer>

// Text-input path for Wayland clients. The compositor's text-input-v3 manager (QtWayland.Compositor TextInputManagerV3)
// turns a client's enable/disable/surrounding-text into Qt input-method state on the focused surface item; this bridge
// reads that state (so the on-screen keyboard knows when to show and what is around the caret) and writes back through
// ordinary QInputMethodEvents (commit / delete surrounding) and key events (Enter, arrows).
// Context property "ImBridge".
class ImBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY changed)           // focused client text field wants an input method
    Q_PROPERTY(QString text READ text NOTIFY changed)            // surrounding text
    Q_PROPERTY(int cursor READ cursor NOTIFY changed)
    Q_PROPERTY(int anchor READ anchor NOTIFY changed)
    Q_PROPERTY(int hints READ hints NOTIFY changed)              // Qt::InputMethodHints
    Q_PROPERTY(bool polling MEMBER m_wanted WRITE setPolling NOTIFY pollingChanged)
public:
    explicit ImBridge(QObject *p = nullptr);
    bool active() const { return m_active; }
    QString text() const { return m_text; }
    int cursor() const { return m_cursor; }
    int anchor() const { return m_anchor; }
    int hints() const { return m_hints; }
    void setPolling(bool on);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void commit(const QString &text, int replaceStart = 0, int replaceLength = 0);   // start is relative to the caret
    Q_INVOKABLE void key(int qtKey, int evdev, const QString &text = QString());
signals:
    void changed();
    void pollingChanged();
private:
    bool m_active = false, m_wanted = false;
    QString m_text; int m_cursor = 0, m_anchor = 0, m_hints = 0;
    QTimer m_timer;
};
