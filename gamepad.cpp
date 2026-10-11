#include "gamepad.h"

#include <QGuiApplication>
#include <QKeyEvent>

namespace {

constexpr int PollIntervalMs = 16;       // check the controller ~60 times a second
constexpr int RepeatDelayMs = 400;       // hold a direction this long before it repeats
constexpr int RepeatIntervalMs = 120;    // then repeat this often
constexpr int StickDeadzone = 16000;     // ignore small stick movements (range is ±32767)
constexpr int TriggerPressed = 16000;    // a trigger counts as pressed past halfway (range is 0 to 32767)

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

} // namespace

Gamepad::Gamepad(QObject *parent)
    : QObject(parent)
{
    // Leave Ctrl+C to Qt instead of SDL, and keep reading the controller
    // without an SDL window (we check our own window's focus in sendKey)
    SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");

    if (SDL_Init(SDL_INIT_GAMECONTROLLER) != 0) {
        qWarning("Gamepad: SDL_Init failed: %s", SDL_GetError());
        return;
    }

    connect(&m_timer, &QTimer::timeout, this, &Gamepad::poll);
    m_timer.start(PollIntervalMs);
}

Gamepad::~Gamepad()
{
    if (m_controller)
        SDL_GameControllerClose(m_controller);
    SDL_Quit();
}

void Gamepad::poll()
{
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_CONTROLLERDEVICEADDED:
            // Also sent at startup for controllers that are already plugged in
            if (!m_controller) {
                m_controller = SDL_GameControllerOpen(event.cdevice.which);
                qInfo("Gamepad: opened %s", SDL_GameControllerName(m_controller));
            }
            break;

        case SDL_CONTROLLERDEVICEREMOVED:
            if (m_controller && event.cdevice.which
                                    == SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(m_controller))) {
                SDL_GameControllerClose(m_controller);
                m_controller = nullptr;
                m_heldKey = 0;
                m_stickKey = 0;
            }
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

    if (m_controller) {
        handleStick();
        handleTriggers();
    }

    // Repeat the held direction
    if (m_heldKey && m_heldFor.elapsed() >= m_nextRepeatAt) {
        sendKey(m_heldKey);
        m_nextRepeatAt += RepeatIntervalMs;
    }
}

// Turn the left stick into the same arrow keys as the d-pad
void Gamepad::handleStick()
{
    const int x = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_LEFTX);
    const int y = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_LEFTY);

    int key = 0;
    if (qAbs(x) > qAbs(y) && qAbs(x) > StickDeadzone)
        key = x < 0 ? Qt::Key_Left : Qt::Key_Right;
    else if (qAbs(y) > StickDeadzone)
        key = y < 0 ? Qt::Key_Up : Qt::Key_Down;

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
    const bool left = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_TRIGGERLEFT) > TriggerPressed;
    const bool right = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_TRIGGERRIGHT) > TriggerPressed;
    if (left && !m_leftTrigger)
        sendKey(Qt::Key_PageUp);
    if (right && !m_rightTrigger)
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