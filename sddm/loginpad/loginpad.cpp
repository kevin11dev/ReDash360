#include "loginpad.h"

#include <QGuiApplication>
#include <QKeyEvent>
#include <QQuickWindow>

namespace {

// The same timings and keys as the dashboard (gamepad.cpp)
constexpr int PollIntervalMs = 16;
constexpr int RepeatDelayMs = 400;
constexpr int RepeatIntervalMs = 120;
constexpr int StickDeadzone = 16000;
constexpr int TriggerPressed = 16000;

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
    case SDL_CONTROLLER_BUTTON_START:         return Qt::Key_Menu;       // keyboard: Done
    case SDL_CONTROLLER_BUTTON_LEFTSTICK:     return Qt::Key_CapsLock;   // keyboard: Caps
    default:                                  return 0;
    }
}

bool isDirection(int key)
{
    return key == Qt::Key_Up || key == Qt::Key_Down
           || key == Qt::Key_Left || key == Qt::Key_Right;
}

} // namespace

LoginPad::LoginPad(QQuickItem *parent)
    : QQuickItem(parent)
{
    // Leave Ctrl+C to Qt, keep reading controllers without an SDL window, and
    // A is always the bottom face button (on a Nintendo controller too)
    SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    SDL_SetHint(SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS, "0");

    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) != 0) {
        qWarning("LoginPad: SDL_InitSubSystem failed: %s", SDL_GetError());
        return;
    }
    m_started = true;
    connect(&m_timer, &QTimer::timeout, this, &LoginPad::poll);
    m_timer.start(PollIntervalMs);
}

LoginPad::~LoginPad()
{
    for (SDL_GameController *controller : std::as_const(m_pads))
        SDL_GameControllerClose(controller);
    if (m_started)
        SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
}

void LoginPad::poll()
{
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_CONTROLLERDEVICEADDED:         // also sent for ones plugged in already
            open(event.cdevice.which);
            break;
        case SDL_CONTROLLERDEVICEREMOVED:
            close(event.cdevice.which);
            break;
        case SDL_CONTROLLERBUTTONDOWN: {
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

    if (m_heldKey && m_heldFor.elapsed() >= m_nextRepeatAt) {
        sendKey(m_heldKey);
        m_nextRepeatAt += RepeatIntervalMs;
    }
}

void LoginPad::open(int deviceIndex)
{
    SDL_GameController *controller = SDL_GameControllerOpen(deviceIndex);
    if (!controller)
        return;
    const SDL_JoystickID id = SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(controller));
    if (m_pads.contains(id)) {                  // already open: SDL counts opens, so even it out
        SDL_GameControllerClose(controller);
        return;
    }
    SDL_GameControllerSetPlayerIndex(controller, int(m_pads.size()));  // player 1, 2... on its lights
    m_pads.insert(id, controller);
    const char *name = SDL_GameControllerName(controller);
    qInfo("LoginPad: opened %s", name ? name : "a controller");
}

void LoginPad::close(SDL_JoystickID id)
{
    const auto it = m_pads.find(id);
    if (it == m_pads.end())
        return;
    SDL_GameControllerClose(it.value());
    m_pads.erase(it);
    if (m_pads.isEmpty()) {
        m_heldKey = 0;
        m_stickKey = 0;
    }
}

// The left sticks are the arrows too: whichever is pushed furthest
void LoginPad::handleSticks()
{
    int key = 0;
    int furthest = StickDeadzone;
    for (SDL_GameController *controller : std::as_const(m_pads)) {
        const int x = SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_LEFTX);
        const int y = SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_LEFTY);
        if (qAbs(x) > qAbs(y) && qAbs(x) > furthest) {
            key = x < 0 ? Qt::Key_Left : Qt::Key_Right;
            furthest = qAbs(x);
        } else if (qAbs(y) >= qAbs(x) && qAbs(y) > furthest) {
            key = y < 0 ? Qt::Key_Up : Qt::Key_Down;
            furthest = qAbs(y);
        }
    }

    if (key == m_stickKey)
        return;
    stopHold(m_stickKey);
    m_stickKey = key;
    if (key)
        startHold(key);
}

// LT and RT, past halfway: Page Up / Page Down (the keyboard's Symbols and Accents)
void LoginPad::handleTriggers()
{
    bool left = false;
    bool right = false;
    for (SDL_GameController *controller : std::as_const(m_pads)) {
        left = left || SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_TRIGGERLEFT) > TriggerPressed;
        right = right || SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_TRIGGERRIGHT) > TriggerPressed;
    }
    if (left && !m_leftTrigger)
        sendKey(Qt::Key_PageUp);
    if (right && !m_rightTrigger)
        sendKey(Qt::Key_PageDown);
    m_leftTrigger = left;
    m_rightTrigger = right;
}

void LoginPad::startHold(int key)
{
    sendKey(key);
    m_heldKey = key;
    m_heldFor.restart();
    m_nextRepeatAt = RepeatDelayMs;
}

void LoginPad::stopHold(int key)
{
    if (key && key == m_heldKey)
        m_heldKey = 0;
}

// A key press and release with no text, so the on-screen keyboard can tell
// it's the controller and not typing
void LoginPad::sendKey(int key)
{
    QQuickWindow *target = window();
    if (!target)
        return;
    QGuiApplication::postEvent(target, new QKeyEvent(QEvent::KeyPress, key, Qt::NoModifier));
    QGuiApplication::postEvent(target, new QKeyEvent(QEvent::KeyRelease, key, Qt::NoModifier));
}
