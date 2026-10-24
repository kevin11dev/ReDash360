#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QQuickItem>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

#define SDL_MAIN_HANDLED
#include <SDL.h>

// The controller on ReDash360's login screen. SDDM only knows the keyboard
// and mouse, so this reads controllers with SDL2 and turns their buttons into
// the keys the dashboard uses (A is Enter, B is Escape, the d-pad and left
// stick are the arrows...), sent to the login screen's window. The theme
// loads it as LoginPad {} when it's installed.
class LoginPad : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit LoginPad(QQuickItem *parent = nullptr);
    ~LoginPad() override;

private:
    void poll();
    void open(int deviceIndex);
    void close(SDL_JoystickID id);
    void handleSticks();
    void handleTriggers();
    void startHold(int key);
    void stopHold(int key);
    void sendKey(int key);

    QTimer m_timer;
    QHash<SDL_JoystickID, SDL_GameController *> m_pads;

    // Holding a direction repeats it, like on the dashboard
    int m_heldKey = 0;
    QElapsedTimer m_heldFor;
    qint64 m_nextRepeatAt = 0;
    int m_stickKey = 0;                 // direction a left stick is pushed, or 0

    bool m_leftTrigger = false;         // LT / RT held past halfway
    bool m_rightTrigger = false;
    bool m_started = false;             // SDL is running
};
