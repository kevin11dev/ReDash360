#include "gamepad.h"

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJSEngine>
#include <QKeyEvent>
#include <QProcess>
#include <QRegularExpression>

#include <algorithm>

namespace {

constexpr int PollIntervalMs = 16;       // check the controllers ~60 times a second
constexpr int RepeatDelayMs = 400;       // hold a direction this long before it repeats
constexpr int RepeatIntervalMs = 120;    // then repeat this often
constexpr int StickDeadzone = 16000;     // ignore small stick movements (range is ±32767)
constexpr int TriggerPressed = 16000;    // a trigger counts as pressed past halfway (range is 0 to 32767)
constexpr int BatteryCheckMs = 15000;    // batteries don't change quickly
constexpr int MaxPlayers = 4;            // the ring of light has four quarters

// Which key each controller button pretends to be
int keyForButton(Uint8 button)
{
    switch (button) {
    case SDL_CONTROLLER_BUTTON_DPAD_UP:       return Qt::Key_Up;
    case SDL_CONTROLLER_BUTTON_DPAD_DOWN:     return Qt::Key_Down;
    case SDL_CONTROLLER_BUTTON_DPAD_LEFT:     return Qt::Key_Left;
    case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:    return Qt::Key_Right;
    case SDL_CONTROLLER_BUTTON_A:             return Qt::Key_Return;
    case SDL_CONTROLLER_BUTTON_B:             return Qt::Key_Escape;
    case SDL_CONTROLLER_BUTTON_X:             return Qt::Key_X;
    case SDL_CONTROLLER_BUTTON_Y:             return Qt::Key_Y;
    case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:  return Qt::Key_Q;
    case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER: return Qt::Key_E;
    case SDL_CONTROLLER_BUTTON_GUIDE:         return Qt::Key_Home;
    case SDL_CONTROLLER_BUTTON_START:         return Qt::Key_Menu;       // keyboard: Done
    case SDL_CONTROLLER_BUTTON_LEFTSTICK:     return Qt::Key_CapsLock;   // keyboard: Caps
    default:                                  return 0;
    }
}

// Send a key press + release to a window, as if typed on a keyboard
void postKey(QWindow *window, int key)
{
    QGuiApplication::postEvent(window, new QKeyEvent(QEvent::KeyPress, key, Qt::NoModifier));
    QGuiApplication::postEvent(window, new QKeyEvent(QEvent::KeyRelease, key, Qt::NoModifier));
}

bool isDirection(int key)
{
    return key == Qt::Key_Up || key == Qt::Key_Down
           || key == Qt::Key_Left || key == Qt::Key_Right;
}

// A Bluetooth controller's serial is its address ("AA:BB:CC:DD:EE:FF");
// anything else means it isn't one (or SDL can't tell)
QString bluetoothAddress(const char *serial)
{
    static const QRegularExpression address("^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$");
    const QString text = QString::fromUtf8(serial ? serial : "").trimmed();
    return address.match(text).hasMatch() ? text.toUpper().replace('-', ':') : QString();
}

// Linux keeps many wireless controllers' batteries in /sys/class/power_supply,
// in a folder named after the controller's Bluetooth address
int batteryPercent(const QString &address)
{
#ifdef Q_OS_LINUX
    if (address.isEmpty())
        return -1;
    const QDir supplies("/sys/class/power_supply");
    const QString lowered = address.toLower();
    for (const QString &name : supplies.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!name.toLower().contains(lowered))
            continue;
        QFile file(supplies.filePath(name + "/capacity"));
        if (file.open(QIODevice::ReadOnly))
            return file.readAll().trimmed().toInt();
    }
#else
    Q_UNUSED(address)
#endif
    return -1;
}

QString batteryLevel(int percent)
{
    return percent >= 70 ? "full" : percent >= 35 ? "medium" : percent >= 10 ? "low" : "empty";
}

// Whose button labels it has: A B X Y, the PlayStation shapes, or Nintendo's
QString controllerType(SDL_GameController *controller)
{
    switch (SDL_GameControllerGetType(controller)) {
    case SDL_CONTROLLER_TYPE_PS3:
    case SDL_CONTROLLER_TYPE_PS4:
    case SDL_CONTROLLER_TYPE_PS5:
        return "playstation";
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_PRO:
#if SDL_VERSION_ATLEAST(2, 24, 0)
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_LEFT:
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT:
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_PAIR:
#endif
        return "nintendo";
    default:
        return "xbox";
    }
}

} // namespace

Gamepad *Gamepad::s_instance = nullptr;

Gamepad::Gamepad(QObject *parent)
    : QObject(parent)
{
    s_instance = this;

    // Leave Ctrl+C to Qt instead of SDL, and keep reading the controller
    // without an SDL window (we check our own window's focus in sendKey)
    SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");

    // Name the face buttons by where they are, not what's printed on them:
    // A is always the bottom one (on a Nintendo controller too, where it
    // says B), so it's always Select, and Test Controller lights the right one
    SDL_SetHint(SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS, "0");

    if (SDL_Init(SDL_INIT_GAMECONTROLLER) != 0) {
        qWarning("Gamepad: SDL_Init failed: %s", SDL_GetError());
        return;
    }

    connect(&m_timer, &QTimer::timeout, this, &Gamepad::poll);
    m_timer.start(PollIntervalMs);

    connect(&m_batteryTimer, &QTimer::timeout, this, [this] {
        readBatteries();
        updateList();
    });
    m_batteryTimer.start(BatteryCheckMs);
}

Gamepad::~Gamepad()
{
    for (const Pad &pad : std::as_const(m_pads))
        SDL_GameControllerClose(pad.controller);
    SDL_Quit();
    if (s_instance == this)
        s_instance = nullptr;
}

Gamepad *Gamepad::create(QQmlEngine *, QJSEngine *engine)
{
    engine->setObjectOwnership(s_instance, QJSEngine::CppOwnership);    // main() owns it
    return s_instance;
}

void Gamepad::setCaptured(bool captured)
{
    if (captured == m_captured)
        return;
    m_captured = captured;
    stopHold(m_heldKey);                        // nothing keeps repeating behind the tester
    emit capturedChanged();
}

void Gamepad::poll()
{
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_CONTROLLERDEVICEADDED:
            // Also sent at startup for controllers that are already plugged in
            open(event.cdevice.which);
            break;

        case SDL_CONTROLLERDEVICEREMOVED:
            close(event.cdevice.which);
            break;

        case SDL_CONTROLLERBUTTONDOWN: {
            setLastUsed(event.cbutton.which);
            if (m_captured)
                break;
            const int key = keyForButton(event.cbutton.button);
            if (isDirection(key))
                startHold(key);
            else if (key)
                sendKey(key);
            break;
        }

        case SDL_CONTROLLERBUTTONUP:
            stopHold(keyForButton(event.cbutton.button));
            break;
        }
    }

    if (!m_pads.isEmpty()) {
        handleSticks();
        handleTriggers();
    }

    // Repeat the held direction
    if (m_heldKey && m_heldFor.elapsed() >= m_nextRepeatAt) {
        sendKey(m_heldKey);
        m_nextRepeatAt += RepeatIntervalMs;
    }
}

void Gamepad::open(int deviceIndex)
{
    SDL_GameController *controller = SDL_GameControllerOpen(deviceIndex);
    if (!controller)
        return;
    const SDL_JoystickID id = SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(controller));
    if (m_pads.contains(id)) {                  // already open: SDL counts opens, so even it out
        SDL_GameControllerClose(controller);
        return;
    }

    // The lowest free player number, like a 360 handing out quarters of the ring
    int player = 0;
    for (int number = 1; number <= MaxPlayers && !player; ++number) {
        const bool taken = std::any_of(m_pads.cbegin(), m_pads.cend(),
                                       [number](const Pad &pad) { return pad.player == number; });
        if (!taken)
            player = number;
    }

    Pad pad;
    pad.controller = controller;
    const char *name = SDL_GameControllerName(controller);
    pad.name = name ? QString::fromUtf8(name) : QStringLiteral("Controller");
    pad.type = controllerType(controller);
    pad.player = player;
    pad.address = bluetoothAddress(SDL_GameControllerGetSerial(controller));
    SDL_GameControllerSetPlayerIndex(controller, player - 1);   // lights its LEDs, where it has them
    m_pads.insert(id, pad);
    qInfo("Gamepad: opened %s as player %d", qPrintable(pad.name), player);

    if (m_lastUsed < 0)
        setLastUsed(id);
    readBatteries();
    updateList();
}

void Gamepad::close(SDL_JoystickID id)
{
    const auto it = m_pads.find(id);
    if (it == m_pads.end())
        return;
    SDL_GameControllerClose(it->controller);
    m_pads.erase(it);

    if (m_pads.isEmpty()) {
        m_heldKey = 0;
        m_stickKey = 0;
    }
    if (m_lastUsed == id)
        setLastUsed(m_pads.isEmpty() ? -1 : m_pads.cbegin().key());
    updateList();
}

// How full each controller's battery is: SDL knows for many controllers,
// Linux's own battery readings help with the rest
void Gamepad::readBatteries()
{
    for (Pad &pad : m_pads) {
        const SDL_JoystickPowerLevel level = SDL_JoystickCurrentPowerLevel(SDL_GameControllerGetJoystick(pad.controller));
        pad.wired = level == SDL_JOYSTICK_POWER_WIRED;
        pad.percent = pad.wired ? -1 : batteryPercent(pad.address);
        if (pad.percent >= 0)
            pad.battery = batteryLevel(pad.percent);
        else if (level == SDL_JOYSTICK_POWER_FULL || level == SDL_JOYSTICK_POWER_MAX)
            pad.battery = "full";
        else if (level == SDL_JOYSTICK_POWER_MEDIUM)
            pad.battery = "medium";
        else if (level == SDL_JOYSTICK_POWER_LOW)
            pad.battery = "low";
        else if (level == SDL_JOYSTICK_POWER_EMPTY)
            pad.battery = "empty";
        else
            pad.battery.clear();

        // Say so once when it runs low, and again only after it's been charged
        const bool low = pad.battery == "low" || pad.battery == "empty";
        if (low && !pad.warned)
            emit batteryLow(pad.name, pad.player);
        if (pad.battery == "full" || pad.battery == "medium" || pad.wired)
            pad.warned = false;
        else if (low)
            pad.warned = true;
    }
}

void Gamepad::updateList()
{
    QVariantList list;
    for (auto it = m_pads.cbegin(); it != m_pads.cend(); ++it) {
        const Pad &pad = it.value();
        list << QVariantMap {
            { "id", it.key() },
            { "name", pad.name },
            { "type", pad.type },
            { "player", pad.player },
            { "battery", pad.battery },
            { "percent", pad.percent },
            { "wired", pad.wired },
            { "bluetooth", !pad.address.isEmpty() },
            };
    }
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        const int x = a.toMap()["player"].toInt(), y = b.toMap()["player"].toInt();
        return (x ? x : 99) < (y ? y : 99);     // players without a number go last
    });
    if (list != m_list) {
        m_list = list;
        emit controllersChanged();
    }
}

QVariantMap Gamepad::state(int id) const
{
    const auto it = m_pads.constFind(id);
    if (it == m_pads.cend())
        return {};
    SDL_GameController *c = it->controller;
    const auto down = [c](SDL_GameControllerButton button) {
        return SDL_GameControllerGetButton(c, button) == 1;
    };
    const auto axis = [c](SDL_GameControllerAxis which) {
        return std::clamp(SDL_GameControllerGetAxis(c, which) / 32767.0, -1.0, 1.0);
    };
    return {
        { "buttons", QVariantMap {
                        { "a", down(SDL_CONTROLLER_BUTTON_A) },
                        { "b", down(SDL_CONTROLLER_BUTTON_B) },
                        { "x", down(SDL_CONTROLLER_BUTTON_X) },
                        { "y", down(SDL_CONTROLLER_BUTTON_Y) },
                        { "back", down(SDL_CONTROLLER_BUTTON_BACK) },
                        { "guide", down(SDL_CONTROLLER_BUTTON_GUIDE) },
                        { "start", down(SDL_CONTROLLER_BUTTON_START) },
                        { "leftStick", down(SDL_CONTROLLER_BUTTON_LEFTSTICK) },
                        { "rightStick", down(SDL_CONTROLLER_BUTTON_RIGHTSTICK) },
                        { "lb", down(SDL_CONTROLLER_BUTTON_LEFTSHOULDER) },
                        { "rb", down(SDL_CONTROLLER_BUTTON_RIGHTSHOULDER) },
                        { "up", down(SDL_CONTROLLER_BUTTON_DPAD_UP) },
                        { "down", down(SDL_CONTROLLER_BUTTON_DPAD_DOWN) },
                        { "left", down(SDL_CONTROLLER_BUTTON_DPAD_LEFT) },
                        { "right", down(SDL_CONTROLLER_BUTTON_DPAD_RIGHT) },
                        } },
        { "leftX", axis(SDL_CONTROLLER_AXIS_LEFTX) },
        { "leftY", axis(SDL_CONTROLLER_AXIS_LEFTY) },
        { "rightX", axis(SDL_CONTROLLER_AXIS_RIGHTX) },
        { "rightY", axis(SDL_CONTROLLER_AXIS_RIGHTY) },
        { "lt", axis(SDL_CONTROLLER_AXIS_TRIGGERLEFT) },
        { "rt", axis(SDL_CONTROLLER_AXIS_TRIGGERRIGHT) },
        };
}

void Gamepad::vibrate(int id)
{
    const auto it = m_pads.constFind(id);
    if (it != m_pads.cend())
        SDL_GameControllerRumble(it->controller, 0xC000, 0xFFFF, 700);
}

bool Gamepad::turnOff(int id)
{
    const auto it = m_pads.constFind(id);
    if (it == m_pads.cend() || it->address.isEmpty())
        return false;
    return QProcess::startDetached("bluetoothctl", { "disconnect", it->address });
}

// Turn the left sticks into the same arrow keys as the d-pad: whichever
// controller's stick is pushed furthest
void Gamepad::handleSticks()
{
    int key = 0;
    int furthest = StickDeadzone;
    if (!m_captured) {
        for (const Pad &pad : std::as_const(m_pads)) {
            const int x = SDL_GameControllerGetAxis(pad.controller, SDL_CONTROLLER_AXIS_LEFTX);
            const int y = SDL_GameControllerGetAxis(pad.controller, SDL_CONTROLLER_AXIS_LEFTY);
            if (qAbs(x) > qAbs(y) && qAbs(x) > furthest) {
                key = x < 0 ? Qt::Key_Left : Qt::Key_Right;
                furthest = qAbs(x);
            } else if (qAbs(y) >= qAbs(x) && qAbs(y) > furthest) {
                key = y < 0 ? Qt::Key_Up : Qt::Key_Down;
                furthest = qAbs(y);
            }
        }
    }

    if (key == m_stickKey)
        return;
    stopHold(m_stickKey);
    m_stickKey = key;
    if (key)
        startHold(key);
}

// The triggers aren't buttons but how far they're pressed, so they count as
// pressed once they're past halfway: LT is Page Up, RT is Page Down (the
// on-screen keyboard's Symbols and Accents)
void Gamepad::handleTriggers()
{
    bool left = false;
    bool right = false;
    for (const Pad &pad : std::as_const(m_pads)) {
        left = left || SDL_GameControllerGetAxis(pad.controller, SDL_CONTROLLER_AXIS_TRIGGERLEFT) > TriggerPressed;
        right = right || SDL_GameControllerGetAxis(pad.controller, SDL_CONTROLLER_AXIS_TRIGGERRIGHT) > TriggerPressed;
    }
    if (left && !m_leftTrigger && !m_captured)
        sendKey(Qt::Key_PageUp);
    if (right && !m_rightTrigger && !m_captured)
        sendKey(Qt::Key_PageDown);
    m_leftTrigger = left;
    m_rightTrigger = right;
}

void Gamepad::startHold(int key)
{
    sendKey(key);
    m_heldKey = key;
    m_heldFor.restart();
    m_nextRepeatAt = RepeatDelayMs;
}

void Gamepad::stopHold(int key)
{
    if (key && key == m_heldKey)
        m_heldKey = 0;
}

void Gamepad::setLastUsed(int id)
{
    if (id == m_lastUsed)
        return;
    m_lastUsed = id;
    emit lastUsedChanged();
}

void Gamepad::sendKey(int key)
{
    // While the Guide is open over a game, the controller drives the Guide
    if (m_overlay && m_overlay->isVisible()) {
        postKey(m_overlay, key);
        return;
    }

    // The dashboard, while it's the window in front
    if (m_window && m_window->isActive()) {
        postKey(m_window, key);
        return;
    }

    // Something else is in front (a game): only the Xbox button does
    // anything, and it opens the Guide over it
    if (key == Qt::Key_Home && m_overlay)
        QMetaObject::invokeMethod(m_overlay, "openGuide");
}