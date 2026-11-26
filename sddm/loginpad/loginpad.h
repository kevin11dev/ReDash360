#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QQuickItem>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

#define SDL_MAIN_HANDLED
#include <SDL.h>

#include "controllerwatch.h"

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

    // Start SDL's controllers over, to find one it missed (see controllerwatch.h)
    void lookAgain();

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

    // Controllers that connect later, which SDL can miss
    ControllerWatch m_watch { [this] { lookAgain(); } };
};