#include "ImBridge.h"
#include <QCoreApplication>
#include <QGuiApplication>
#include <QInputMethodEvent>
#include <QInputMethodQueryEvent>
#include <QKeyEvent>
#include <QQuickItem>

ImBridge::ImBridge(QObject *p) : QObject(p) {
    m_timer.setInterval(120);
    connect(&m_timer, &QTimer::timeout, this, &ImBridge::refresh);
}
void ImBridge::setPolling(bool on) {
    if (on == m_wanted) return;
    m_wanted = on; if (on) m_timer.start(); else { m_timer.stop(); }
    emit pollingChanged();
    if (!on && m_active) { m_active = false; emit changed(); }
}
void ImBridge::refresh() {
    QObject *f = QGuiApplication::focusObject();
    bool act = false; QString t; int c = 0, a = 0, h = 0;
    auto *it = qobject_cast<QQuickItem *>(f);
    if (it && it->metaObject()->className() != QByteArray("QQuickRootItem") && (it->flags() & QQuickItem::ItemAcceptsInputMethod)) {
        QInputMethodQueryEvent q(Qt::ImEnabled | Qt::ImSurroundingText | Qt::ImCursorPosition | Qt::ImAnchorPosition | Qt::ImHints);
        QCoreApplication::sendEvent(f, &q);
        act = q.value(Qt::ImEnabled).toBool();
        if (act) {
            t = q.value(Qt::ImSurroundingText).toString();
            c = q.value(Qt::ImCursorPosition).toInt(); a = q.value(Qt::ImAnchorPosition).toInt();
            h = q.value(Qt::ImHints).toInt();
        }
    }
    if (act != m_active || t != m_text || c != m_cursor || a != m_anchor || h != m_hints) {
        m_active = act; m_text = t; m_cursor = c; m_anchor = a; m_hints = h; emit changed();
    }
}
void ImBridge::commit(const QString &text, int replaceStart, int replaceLength) {
    QObject *f = QGuiApplication::focusObject(); if (!f) return;
    QInputMethodEvent ev; ev.setCommitString(text, replaceStart, replaceLength);
    QCoreApplication::sendEvent(f, &ev);
    QTimer::singleShot(40, this, &ImBridge::refresh);
}
// evdev: Linux input event code; Wayland/xkb keycodes are evdev + 8
void ImBridge::key(int qtKey, int evdev, const QString &text) {
    QObject *f = QGuiApplication::focusObject(); if (!f) return;
    for (QEvent::Type t : {QEvent::KeyPress, QEvent::KeyRelease}) {
        QKeyEvent ev(t, qtKey, Qt::NoModifier, quint32(evdev + 8), 0, 0, text);
        QCoreApplication::sendEvent(f, &ev);
    }
    QTimer::singleShot(40, this, &ImBridge::refresh);
}
