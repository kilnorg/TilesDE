#include "TermSession.h"
#include <QDir>
#include <QProcessEnvironment>
#include <QSocketNotifier>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <pty.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vterm.h>

bool TermSession::s_testDone = false;

namespace {
const char *palDark[16] = {"#4a4a4a", "#e5484d", "#46c05f", "#e0b13a", "#4f8dff", "#c678dd", "#33c1c9", "#d0d0d0",
                           "#7a7a7a", "#ff6b6b", "#6fe58a", "#ffd866", "#7aa7ff", "#e599f7", "#5fe3ea", "#ffffff"};
const char *palLight[16] = {"#000000", "#c4262e", "#2e7d32", "#a06a00", "#1a5fd0", "#8e3bb5", "#00838f", "#595959",
                            "#555555", "#e53935", "#388e3c", "#b8860b", "#2f7bff", "#a64dc9", "#00a0b0", "#2a2a2a"};
}

// libvterm callbacks (user = TermSession*)
struct TermCb {
    static int damage(VTermRect r, void *u) { static_cast<TermSession *>(u)->damage(r.start_row, r.end_row - 1); return 1; }
    static int moveRect(VTermRect d, VTermRect s, void *u) {
        auto *t = static_cast<TermSession *>(u);
        t->damage(qMin(d.start_row, s.start_row), qMax(d.end_row, s.end_row) - 1); return 1;
    }
    static int moveCursor(VTermPos p, VTermPos, int vis, void *u) {
        auto *t = static_cast<TermSession *>(u);
        t->m_curRow = p.row; t->m_curCol = p.col; t->m_curVisible = vis; t->m_curDirty = true; return 1;
    }
    static int setProp(VTermProp prop, VTermValue *v, void *u) {
        auto *t = static_cast<TermSession *>(u);
        switch (prop) {
        case VTERM_PROP_CURSORVISIBLE: t->m_curVisible = v->boolean; t->m_curDirty = true; break;
        case VTERM_PROP_ALTSCREEN:
            if (t->m_alt != bool(v->boolean)) { t->m_alt = v->boolean; emit t->altScreenChanged(); }
            break;
        case VTERM_PROP_TITLE:
            if (v->string.initial) t->m_titleBuf.clear();
            t->m_titleBuf += QString::fromUtf8(v->string.str, int(v->string.len));
            if (v->string.final && t->m_titleBuf != t->m_title) { t->m_title = t->m_titleBuf; emit t->titleChanged(); }
            break;
        default: break;
        }
        return 1;
    }
    static int bell(void *u) { emit static_cast<TermSession *>(u)->bell(); return 1; }
    static int pushLine(int cols, const VTermScreenCell *cells, void *u) {
        auto *t = static_cast<TermSession *>(u);
        t->m_sb.push_back(t->renderCells(cells, cols));
        if (t->m_sb.size() > 5000) t->m_sb.pop_front();
        emit t->scrollbackChanged();
        return 1;
    }
    static int sbClear(void *u) { auto *t = static_cast<TermSession *>(u); t->m_sb.clear(); emit t->scrollbackChanged(); return 1; }
    static void output(const char *s, size_t len, void *u) { static_cast<TermSession *>(u)->rawWrite(s, len); }
};

static const VTermScreenCallbacks kCbs = {TermCb::damage, TermCb::moveRect, TermCb::moveCursor, TermCb::setProp,
                                          TermCb::bell, nullptr, TermCb::pushLine, nullptr, TermCb::sbClear};

TermSession::TermSession(QObject *p) : QObject(p) {
    m_vt = vterm_new(m_rows, m_cols);
    vterm_set_utf8(m_vt, 1);
    vterm_output_set_callback(m_vt, TermCb::output, this);
    m_screen = vterm_obtain_screen(m_vt);
    vterm_screen_enable_altscreen(m_screen, 1);
    vterm_screen_set_callbacks(m_screen, &kCbs, this);
    vterm_screen_set_damage_merge(m_screen, VTERM_DAMAGE_ROW);
    vterm_screen_reset(m_screen, 1);
    m_timer.setSingleShot(true); m_timer.setInterval(16);
    connect(&m_timer, &QTimer::timeout, this, &TermSession::flushDamage);
    m_reapTimer.setInterval(100);
    connect(&m_reapTimer, &QTimer::timeout, this, &TermSession::reap);
}

TermSession::~TermSession() {
    stop();
    vterm_free(m_vt);
}

bool TermSession::start() {
    if (m_pid > 0) return true;
    QString sh = m_shell;
    bool dflt = sh.isEmpty();
    if (dflt) sh = qEnvironmentVariable("SHELL");
    if (sh.isEmpty()) sh = "/bin/bash";
    auto env = QProcessEnvironment::systemEnvironment();
    env.insert("TERM", "xterm-256color"); env.insert("COLORTERM", "truecolor");
    env.remove("COLUMNS"); env.remove("LINES");
    QList<QByteArray> envs;
    for (const QString &k : env.keys()) envs << (k + "=" + env.value(k)).toLocal8Bit();
    std::vector<char *> envp;
    for (auto &e : envs) envp.push_back(e.data());
    envp.push_back(nullptr);
    QByteArray shB = sh.toLocal8Bit(), home = QDir::homePath().toLocal8Bit();
    QByteArray dashL = "-l";
    char *argv[] = {shB.data(), dashL.data(), nullptr};

    struct winsize ws = {};
    ws.ws_row = m_rows; ws.ws_col = m_cols;
    int fd = -1;
    pid_t pid = forkpty(&fd, nullptr, nullptr, &ws);
    if (pid < 0) return false;
    if (pid == 0) {
        if (chdir(home.constData()) != 0) {}
        execve(shB.constData(), argv, envp.data());
        // not an absolute path: search PATH
        execvp(shB.constData(), argv);
        _exit(127);
    }
    m_fd = fd; m_pid = pid;
    vterm_screen_reset(m_screen, 1);
    vterm_screen_flush_damage(m_screen);
    emit screenReset();
    damage(0, m_rows - 1);
    fcntl(m_fd, F_SETFL, fcntl(m_fd, F_GETFL) | O_NONBLOCK);
    fcntl(m_fd, F_SETFD, FD_CLOEXEC);
    m_notifier = new QSocketNotifier(m_fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &TermSession::onReadable);
    emit runningChanged();
    const QByteArray test = qgetenv("FLOWDE_TERM_TEST");
    if (!test.isEmpty() && !s_testDone) {
        s_testDone = true;
        QTimer::singleShot(1200, this, [this, test] { write(QString::fromLocal8Bit(test) + "\r"); });
    }
    return true;
}

void TermSession::rawWrite(const char *d, size_t n) {
    if (m_fd < 0) return;
    while (n > 0) {
        ssize_t w = ::write(m_fd, d, n);
        if (w < 0) { if (errno == EINTR) continue; if (errno == EAGAIN) { usleep(1000); continue; } return; }
        d += w; n -= size_t(w);
    }
}

void TermSession::onReadable() {
    char buf[65536];
    for (;;) {
        ssize_t n = ::read(m_fd, buf, sizeof buf);
        if (n > 0) { vterm_input_write(m_vt, buf, size_t(n)); continue; }
        if (n < 0 && (errno == EAGAIN || errno == EINTR)) break;
        childGone();
        break;
    }
    vterm_screen_flush_damage(m_screen);
    if (m_curDirty || m_dmgFirst >= 0) { if (!m_timer.isActive()) m_timer.start(); }
}

void TermSession::childGone() {
    if (m_notifier) { m_notifier->setEnabled(false); m_notifier->deleteLater(); m_notifier = nullptr; }
    if (m_fd >= 0) { ::close(m_fd); m_fd = -1; }
    reap();
    if (m_pid > 0) m_reapTimer.start();
}

void TermSession::reap() {
    int st = 0;
    pid_t r = waitpid(m_pid, &st, WNOHANG);
    if (r == 0) return;
    m_reapTimer.stop();
    m_pid = 0;
    int code = (r > 0 && WIFEXITED(st)) ? WEXITSTATUS(st) : (r > 0 && WIFSIGNALED(st) ? 128 + WTERMSIG(st) : 0);
    emit runningChanged();
    emit finished(code);
}

void TermSession::stop() {
    if (m_pid <= 0) return;
    if (m_notifier) { m_notifier->setEnabled(false); delete m_notifier; m_notifier = nullptr; }
    if (m_fd >= 0) { ::close(m_fd); m_fd = -1; }
    ::kill(m_pid, SIGHUP);
    int st; pid_t r = 0;
    for (int i = 0; i < 20 && r == 0; ++i) { r = waitpid(m_pid, &st, WNOHANG); if (r == 0) usleep(10000); }
    if (r == 0) { ::kill(m_pid, SIGKILL); waitpid(m_pid, &st, 0); }
    m_reapTimer.stop();
    m_pid = 0;
    emit runningChanged();
}

void TermSession::resize(int cols, int rows) {
    cols = qBound(1, cols, 500); rows = qBound(1, rows, 300);
    if (cols == m_cols && rows == m_rows) return;
    m_cols = cols; m_rows = rows;
    vterm_set_size(m_vt, rows, cols);
    if (m_fd >= 0) {
        struct winsize ws = {};
        ws.ws_row = rows; ws.ws_col = cols;
        ioctl(m_fd, TIOCSWINSZ, &ws);
    }
    vterm_screen_flush_damage(m_screen);
    emit sizeChanged();
    emit screenReset();
    damage(0, rows - 1);
    m_curDirty = true;
    if (!m_timer.isActive()) m_timer.start();
}

void TermSession::write(const QString &text) {
    if (m_fd < 0 || text.isEmpty()) return;
    QByteArray b = text.toUtf8();
    b.replace("\r\n", "\r"); b.replace('\n', '\r');
    rawWrite(b.constData(), size_t(b.size()));
}

void TermSession::sendKey(int k, int mods) {
    if (m_fd < 0) return;
    int vm = VTERM_MOD_NONE;
    if (mods & Qt::ShiftModifier) vm |= VTERM_MOD_SHIFT;
    if (mods & Qt::AltModifier) vm |= VTERM_MOD_ALT;
    if (mods & Qt::ControlModifier) vm |= VTERM_MOD_CTRL;
    VTermKey vk = VTERM_KEY_NONE;
    switch (k) {
    case Qt::Key_Up: vk = VTERM_KEY_UP; break;
    case Qt::Key_Down: vk = VTERM_KEY_DOWN; break;
    case Qt::Key_Left: vk = VTERM_KEY_LEFT; break;
    case Qt::Key_Right: vk = VTERM_KEY_RIGHT; break;
    case Qt::Key_Home: vk = VTERM_KEY_HOME; break;
    case Qt::Key_End: vk = VTERM_KEY_END; break;
    case Qt::Key_PageUp: vk = VTERM_KEY_PAGEUP; break;
    case Qt::Key_PageDown: vk = VTERM_KEY_PAGEDOWN; break;
    case Qt::Key_Insert: vk = VTERM_KEY_INS; break;
    case Qt::Key_Delete: vk = VTERM_KEY_DEL; break;
    case Qt::Key_Tab: vk = VTERM_KEY_TAB; break;
    case Qt::Key_Backtab: vk = VTERM_KEY_TAB; vm |= VTERM_MOD_SHIFT; break;
    case Qt::Key_Escape: vk = VTERM_KEY_ESCAPE; break;
    case Qt::Key_Return: case Qt::Key_Enter: vk = VTERM_KEY_ENTER; break;
    case Qt::Key_Backspace: vk = VTERM_KEY_BACKSPACE; break;
    default:
        if (k >= Qt::Key_F1 && k <= Qt::Key_F12) vk = VTermKey(VTERM_KEY_FUNCTION(k - Qt::Key_F1 + 1));
    }
    if (vk != VTERM_KEY_NONE) vterm_keyboard_key(m_vt, vk, VTermModifier(vm));
    else if (k >= 0x20 && k < 0x7f) {
        uint32_t c = uint32_t(k);
        if (c >= 'A' && c <= 'Z' && !(mods & Qt::ShiftModifier)) c += 32;   // Qt letter keys are upper case
        vterm_keyboard_unichar(m_vt, c, VTermModifier(vm));
    } else if (k >= 0x7f) vterm_keyboard_unichar(m_vt, uint32_t(k), VTermModifier(vm));
}

void TermSession::damage(int first, int last) {
    if (m_dmgFirst < 0) { m_dmgFirst = first; m_dmgLast = last; }
    else { m_dmgFirst = qMin(m_dmgFirst, first); m_dmgLast = qMax(m_dmgLast, last); }
    if (!m_timer.isActive()) m_timer.start();
}

void TermSession::flushDamage() {
    if (m_curDirty) { m_curDirty = false; emit cursorChanged(); }
    if (m_dmgFirst >= 0) {
        int a = qBound(0, m_dmgFirst, m_rows - 1), b = qBound(0, m_dmgLast, m_rows - 1);
        m_dmgFirst = m_dmgLast = -1;
        emit rowsDamaged(a, b);
    }
}

static QString hex(const VTermColor &c) {
    return QString("#%1%2%3").arg(c.rgb.red, 2, 16, QChar('0')).arg(c.rgb.green, 2, 16, QChar('0')).arg(c.rgb.blue, 2, 16, QChar('0'));
}

QString TermSession::renderCells(const void *cellsV, int n) const {
    const auto *cells = static_cast<const VTermScreenCell *>(cellsV);
    const char **pal = m_dark ? palDark : palLight;
    // trim trailing default blanks
    int end = n;
    while (end > 0) {
        const VTermScreenCell &c = cells[end - 1];
        bool blank = (c.chars[0] == 0 || c.chars[0] == ' ') && VTERM_COLOR_IS_DEFAULT_BG(&c.bg) && !c.attrs.reverse && !c.attrs.underline;
        if (!blank) break;
        --end;
    }
    auto colorOf = [&](VTermColor c) -> QString {
        if (VTERM_COLOR_IS_INDEXED(&c) && c.indexed.idx < 16) return pal[c.indexed.idx];
        if (VTERM_COLOR_IS_INDEXED(&c)) vterm_screen_convert_color_to_rgb(m_screen, &c);
        return hex(c);
    };
    QString out, run, curStyle;
    auto flush = [&] {
        if (run.isEmpty()) return;
        if (curStyle.isEmpty()) out += run; else out += "<span style=\"" + curStyle + "\">" + run + "</span>";
        run.clear();
    };
    for (int i = 0; i < end; ++i) {
        const VTermScreenCell &c = cells[i];
        if (c.chars[0] == uint32_t(-1)) continue;   // continuation of a wide char
        bool defFg = VTERM_COLOR_IS_DEFAULT_FG(&c.fg), defBg = VTERM_COLOR_IS_DEFAULT_BG(&c.bg);
        QString fg = defFg ? QString() : colorOf(c.fg), bg = defBg ? QString() : colorOf(c.bg);
        if (c.attrs.reverse) {
            QString f = defFg ? m_defFg : fg, b = defBg ? m_defBg : bg;
            fg = b; bg = f;
        }
        QString st;
        if (!fg.isEmpty()) st += "color:" + fg + ";";
        if (!bg.isEmpty()) st += "background-color:" + bg + ";";
        if (c.attrs.bold) st += "font-weight:bold;";
        if (c.attrs.italic) st += "font-style:italic;";
        if (c.attrs.underline || c.attrs.strike)
            st += QString("text-decoration:%1%2;").arg(c.attrs.underline ? "underline" : "", c.attrs.strike ? " line-through" : "");
        if (st != curStyle) { flush(); curStyle = st; }
        if (c.chars[0] == 0 || c.chars[0] == ' ') { run += "&nbsp;"; continue; }
        for (int k = 0; k < VTERM_MAX_CHARS_PER_CELL && c.chars[k]; ++k) {
            uint32_t u = c.chars[k];
            if (u == '&') run += "&amp;"; else if (u == '<') run += "&lt;"; else if (u == '>') run += "&gt;";
            else if (u < 0x20) run += QChar(0xfffd);
            else run += QString::fromUcs4(reinterpret_cast<const char32_t *>(&u), 1);
        }
    }
    flush();
    return out;
}

QString TermSession::lineHtml(int row) const {
    if (row < 0 || row >= m_rows) return {};
    std::vector<VTermScreenCell> cells(m_cols);
    for (int c = 0; c < m_cols; ++c) vterm_screen_get_cell(m_screen, VTermPos{row, c}, &cells[c]);
    return renderCells(cells.data(), m_cols);
}

QString TermSession::scrollbackLineHtml(int i) const {
    return (i >= 0 && i < int(m_sb.size())) ? m_sb[size_t(i)] : QString();
}

QString TermSession::screenText() const {
    QString out;
    for (int r = 0; r < m_rows; ++r) {
        QString line;
        for (int c = 0; c < m_cols; ++c) {
            VTermScreenCell cell; vterm_screen_get_cell(m_screen, VTermPos{r, c}, &cell);
            if (cell.chars[0] == uint32_t(-1)) continue;
            if (cell.chars[0] == 0) line += ' ';
            else for (int k = 0; k < VTERM_MAX_CHARS_PER_CELL && cell.chars[k]; ++k) { uint32_t u = cell.chars[k]; line += QString::fromUcs4(reinterpret_cast<const char32_t *>(&u), 1); }
        }
        while (line.endsWith(' ')) line.chop(1);
        out += line + "\n";
    }
    while (out.endsWith("\n\n")) out.chop(1);
    return out;
}
