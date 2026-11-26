#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

#define SDL_MAIN_HANDLED
#include <SDL.h>

#include "controllercursor.h"
#include "controllerwatch.h"
#include "virtualinput.h"

class QQmlEngine;
class QJSEngine;

class Gamepad : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList controllers READ controllers NOTIFY controllersChanged)

    Q_PROPERTY(int lastUsed READ lastUsed NOTIFY lastUsedChanged)

    Q_PROPERTY(bool captured READ captured WRITE setCaptured NOTIFY capturedChanged)

    Q_PROPERTY(bool mouseEnabled READ mouseEnabled WRITE setMouseEnabled NOTIFY mouseEnabledChanged)

    Q_PROPERTY(bool mousePossible READ mousePossible CONSTANT)

public:
    explicit Gamepad(QObject *parent);
    ~Gamepad() override;

    static Gamepad *create(QQmlEngine *, QJSEngine *engine);

    void setWindow(QWindow *window) { m_window = window; }
    void setOverlay(QWindow *overlay) { m_overlay = overlay; }

    QVariantList controllers() const { return m_list; }
    int lastUsed() const { return m_lastUsed; }
    bool captured() const { return m_captured; }
    void setCaptured(bool captured);

    bool mouseEnabled() const { return m_mouseEnabled; }
    void setMouseEnabled(bool enabled);
    bool mousePossible() const { return m_mousePossible; }

    Q_INVOKABLE QVariantMap state(int id) const;

    Q_INVOKABLE void vibrate(int id);

    Q_INVOKABLE bool turnOff(int id);

signals:
    void controllersChanged();
    void lastUsedChanged();
    void capturedChanged();
    void mouseEnabledChanged();
    void batteryLow(const QString &name, int player);

private:
    struct Pad {
        SDL_GameController *controller = nullptr;
        QString name;
        QString type;
        int player = 0;                 // 1-4, 0 when there are more than four
        QString address;                // Bluetooth address, "" when it isn't Bluetooth
        QString battery;
        int percent = -1;
        bool wired = false;
        bool warned = false;            // told about a low battery already
    };

    void poll();
    void open(int deviceIndex);
    void close(SDL_JoystickID id);
    void readBatteries();
    void updateList();
    void handleSticks();
    void handleTriggers();
    void startHold(int key);
    void stopHold(int key);
    void sendKey(int key);
    void setLastUsed(int id);

    // Start SDL's controllers over, to find one it missed (see controllerwatch.h)
    void lookAgain();

    // Using the controller counts as using the PC, so the screen doesn't dim
    void stillHere();

    // Controller as mouse
    void updateMouseMode();
    void setMouseMode(bool on);
    void mouseButton(Uint8 button, bool down);
    void moveMouse(double seconds);
    void pauseMouse(SDL_JoystickID id);

    static Gamepad *s_instance;

    QTimer m_timer;
    QTimer m_batteryTimer;
    QPointer<QWindow> m_window;
    QPointer<QWindow> m_overlay;
    QHash<SDL_JoystickID, Pad> m_pads;
    QVariantList m_list;
    int m_lastUsed = -1;
    bool m_captured = false;

    int m_heldKey = 0;
    QElapsedTimer m_heldFor;
    qint64 m_nextRepeatAt = 0;

    int m_stickKey = 0;

    bool m_leftTrigger = false;
    bool m_rightTrigger = false;

    // Controller as mouse
    VirtualInput m_mouse;
    ControllerCursor m_cursor;      // the big ring while the controller moves the pointer

    // Controllers that connect later, which SDL can miss
    ControllerWatch m_watch { [this] { lookAgain(); } };
    bool m_mouseEnabled = true;
    bool m_mousePossible = false;
    bool m_mouseMode = false;
    bool m_mousePaused = false;
    bool m_switching = false;
    bool m_gameRunning = false;
    QElapsedTimer m_gameCheck;
    QElapsedTimer m_stillHere;
    QElapsedTimer m_frame;
    double m_moveRestX = 0;
    double m_moveRestY = 0;
    double m_scrollRestV = 0;
    double m_scrollRestH = 0;
};