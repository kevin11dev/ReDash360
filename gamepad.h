#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QWindow>

#define SDL_MAIN_HANDLED
#include <SDL.h>

// Reads a game controller with SDL2 and turns it into key presses for the
// window, so the QML side only ever has to handle the keyboard.
class Gamepad : public QObject
{
    Q_OBJECT

public:
    explicit Gamepad(QObject *parent = nullptr);
    ~Gamepad() override;

    void setWindow(QWindow *window) { m_window = window; }

private:
    void poll();
    void handleStick();
    void startHold(int key);
    void stopHold(int key);
    void sendKey(int key);

    QTimer m_timer;
    QPointer<QWindow> m_window;
    SDL_GameController *m_controller = nullptr;

    // Holding a direction repeats it, like the real dashboard
    int m_heldKey = 0;
    QElapsedTimer m_heldFor;
    qint64 m_nextRepeatAt = 0;

    int m_stickKey = 0;     // direction the left stick is pushed, or 0
};