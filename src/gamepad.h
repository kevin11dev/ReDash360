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

class QQmlEngine;
class QJSEngine;

// Reads game controllers with SDL2 and turns them into key presses for the
// window, so the QML side only ever has to handle the keyboard. Every
// connected controller works, and each one gets a player number (1-4) like
// the 360's ring of light. QML also sees it as the Gamepad singleton, for the
// Controllers screen: battery levels, vibration, turning a Bluetooth
// controller off and every button's live state for Test Controller.
class Gamepad : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Every connected controller, player 1 first:
    // [{id, name, type, player, battery, percent, wired, bluetooth}]
    //   type: "xbox", "playstation" or "nintendo", for its button labels
    //   battery: "full", "medium", "low", "empty", or "" when it can't tell
    //   percent: 0-100, or -1 when only the rough level is known
    Q_PROPERTY(QVariantList controllers READ controllers NOTIFY controllersChanged)

    // The controller that pressed something last (its id), e.g. for the Guide
    Q_PROPERTY(int lastUsed READ lastUsed NOTIFY lastUsedChanged)

    // While true the buttons don't move around the dashboard (Test Controller)
    Q_PROPERTY(bool captured READ captured WRITE setCaptured NOTIFY capturedChanged)

public:
    // No "= nullptr" on purpose: then QML can't make a second Gamepad of
    // its own and uses the one main() made, through create()
    explicit Gamepad(QObject *parent);
    ~Gamepad() override;

    static Gamepad *create(QQmlEngine *, QJSEngine *engine);

    void setWindow(QWindow *window) { m_window = window; }
    void setOverlay(QWindow *overlay) { m_overlay = overlay; }

    QVariantList controllers() const { return m_list; }
    int lastUsed() const { return m_lastUsed; }
    bool captured() const { return m_captured; }
    void setCaptured(bool captured);

    // What one controller is doing right now, for Test Controller:
    // {buttons: {a, b, x, y, back, guide, start, leftStick, rightStick, lb, rb, up, down, left, right},
    //  leftX, leftY, rightX, rightY (-1 to 1, down and right are positive), lt, rt (0 to 1)}
    Q_INVOKABLE QVariantMap state(int id) const;

    // Rumble both motors for a moment
    Q_INVOKABLE void vibrate(int id);

    // Disconnect a Bluetooth controller, which turns it off. false when it isn't one
    Q_INVOKABLE bool turnOff(int id);

signals:
    void controllersChanged();
    void lastUsedChanged();
    void capturedChanged();
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

    static Gamepad *s_instance;

    QTimer m_timer;
    QTimer m_batteryTimer;
    QPointer<QWindow> m_window;
    QPointer<QWindow> m_overlay;
    QHash<SDL_JoystickID, Pad> m_pads;
    QVariantList m_list;
    int m_lastUsed = -1;
    bool m_captured = false;

    // Holding a direction repeats it, like the real dashboard
    int m_heldKey = 0;
    QElapsedTimer m_heldFor;
    qint64 m_nextRepeatAt = 0;

    int m_stickKey = 0;     // direction a left stick is pushed, or 0

    bool m_leftTrigger = false;     // LT / RT held down past halfway (on any controller)
    bool m_rightTrigger = false;
};