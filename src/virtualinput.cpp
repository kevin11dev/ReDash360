#include "virtualinput.h"

#include <QtGlobal>

#ifdef Q_OS_LINUX
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>
#include <unistd.h>
#endif

namespace {
constexpr char Device[] = "/dev/uinput";
}

VirtualInput::~VirtualInput()
{
#ifdef Q_OS_LINUX
    if (m_fd >= 0) {
        releaseAll();
        ioctl(m_fd, UI_DEV_DESTROY);
        ::close(m_fd);
    }
#endif
}

bool VirtualInput::possible()
{
#ifdef Q_OS_LINUX
    return ::access(Device, W_OK) == 0;
#else
    return false;
#endif
}

bool VirtualInput::open()
{
#ifdef Q_OS_LINUX
    if (m_fd >= 0)
        return true;
    if (m_failed)
        return false;

    const int fd = ::open(Device, O_WRONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) {
        m_failed = true;
        qWarning("Controller as mouse: can't open %s (%s). Restart once after installing "
                 "ReDash360, so its udev rule (60-redash360-uinput.rules) lets you use it.",
                 Device, strerror(errno));
        return false;
    }

    // What it has: every keyboard key (so it can type anything), the three
    // mouse buttons, moving, and both scroll wheels
    bool ok = ioctl(fd, UI_SET_EVBIT, EV_KEY) == 0 && ioctl(fd, UI_SET_EVBIT, EV_REL) == 0;
    for (int key = KEY_ESC; key <= KEY_MICMUTE && ok; ++key)
        ok = ioctl(fd, UI_SET_KEYBIT, key) == 0;
    for (int button : { BTN_LEFT, BTN_RIGHT, BTN_MIDDLE })
        ok = ok && ioctl(fd, UI_SET_KEYBIT, button) == 0;
    for (int axis : { REL_X, REL_Y, REL_WHEEL, REL_HWHEEL })
        ok = ok && ioctl(fd, UI_SET_RELBIT, axis) == 0;
#ifdef REL_WHEEL_HI_RES
    // Smooth scrolling: the wheels in 120ths of a notch (Linux 5.0 and newer)
    ok = ok && ioctl(fd, UI_SET_RELBIT, REL_WHEEL_HI_RES) == 0
         && ioctl(fd, UI_SET_RELBIT, REL_HWHEEL_HI_RES) == 0;
#endif

    uinput_setup setup {};
    setup.id.bustype = BUS_VIRTUAL;
    setup.id.vendor = 0x5244;               // "RD"
    setup.id.product = 0x0360;
    setup.id.version = 1;
    std::strncpy(setup.name, "ReDash360 Controller Mouse", UINPUT_MAX_NAME_SIZE - 1);

    ok = ok && ioctl(fd, UI_DEV_SETUP, &setup) == 0 && ioctl(fd, UI_DEV_CREATE) == 0;
    if (!ok) {
        qWarning("Controller as mouse: can't make the virtual mouse (%s)", strerror(errno));
        ::close(fd);
        m_failed = true;
        return false;
    }
    m_fd = fd;
    qInfo("Controller as mouse: ready");
    return true;
#else
    m_failed = true;
    return false;
#endif
}

void VirtualInput::send(int type, int code, int value)
{
#ifdef Q_OS_LINUX
    input_event event {};
    event.type = type;
    event.code = code;
    event.value = value;
    // If Linux's queue is ever full, this one event is dropped; nothing waits
    if (::write(m_fd, &event, sizeof event) != ssize_t(sizeof event))
        return;
#else
    Q_UNUSED(type) Q_UNUSED(code) Q_UNUSED(value)
#endif
}

// Ends a report: what was sent since the last one happens together
void VirtualInput::sync()
{
#ifdef Q_OS_LINUX
    send(EV_SYN, SYN_REPORT, 0);
#endif
}

void VirtualInput::move(int dx, int dy)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0 || (dx == 0 && dy == 0))
        return;
    if (dx)
        send(EV_REL, REL_X, dx);
    if (dy)
        send(EV_REL, REL_Y, dy);
    sync();
#else
    Q_UNUSED(dx) Q_UNUSED(dy)
#endif
}

void VirtualInput::scroll(int vertical, int horizontal)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0 || (vertical == 0 && horizontal == 0))
        return;
    // Apps that understand smooth scrolling read the 120ths; the others get
    // a whole notch every time those add up to one
    if (vertical) {
#ifdef REL_WHEEL_HI_RES
        send(EV_REL, REL_WHEEL_HI_RES, vertical);
#endif
        m_wheelRest += vertical;
        if (const int notches = m_wheelRest / 120) {
            send(EV_REL, REL_WHEEL, notches);
            m_wheelRest -= notches * 120;
        }
    }
    if (horizontal) {
#ifdef REL_WHEEL_HI_RES
        send(EV_REL, REL_HWHEEL_HI_RES, horizontal);
#endif
        m_hwheelRest += horizontal;
        if (const int notches = m_hwheelRest / 120) {
            send(EV_REL, REL_HWHEEL, notches);
            m_hwheelRest -= notches * 120;
        }
    }
    sync();
#else
    Q_UNUSED(vertical) Q_UNUSED(horizontal)
#endif
}

void VirtualInput::press(int code, bool down)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0 || down == m_held.contains(code))
        return;                             // already down, or already up
    if (down)
        m_held.insert(code);
    else
        m_held.remove(code);
    send(EV_KEY, code, down ? 1 : 0);
    sync();
#else
    Q_UNUSED(code) Q_UNUSED(down)
#endif
}

void VirtualInput::tap(int code)
{
    press(code, true);
    press(code, false);
}

void VirtualInput::releaseAll()
{
    const QSet<int> held = m_held;
    for (int code : held)
        press(code, false);
    m_wheelRest = 0;
    m_hwheelRest = 0;
}