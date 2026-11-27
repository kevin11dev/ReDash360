#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class Launcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // The last game started with play(); saved, so it survives a restart
    Q_PROPERTY(QString lastName READ lastName NOTIFY lastPlayedChanged)
    Q_PROPERTY(QString lastCommand READ lastCommand NOTIFY lastPlayedChanged)
    Q_PROPERTY(QString gameTitle READ gameTitle NOTIFY gameChanged)
    // The app in front when the Guide opened over it (not a game), for "Close"
    Q_PROPERTY(QString appTitle READ appTitle NOTIFY gameChanged)
    Q_PROPERTY(QVariant recents READ recents NOTIFY recentsChanged)

public:
    explicit Launcher(QObject *parent = nullptr);
    ~Launcher() override;

    Q_INVOKABLE bool run(const QString &command);

    // Like run(), but for games: also remembers it as the last played game
    Q_INVOKABLE bool play(const QString &name, const QString &command);
    Q_INVOKABLE void eject();

    Q_INVOKABLE bool openApp(const QString &name, const QString &command, const QString &icon);
    Q_INVOKABLE void removeRecent(int index);

    // Sign out of the desktop, back to the login screen
    Q_INVOKABLE bool signOut();

    Q_INVOKABLE void exitToDesktop();

    static bool gameRunning();

    // Does this program (or the one that started it) read a controller
    // itself? Like Steam's Big Picture, an app with a TV mode, Moonlight or
    // an emulator
    static bool readsController(qint64 pid);

    // Is a streaming app (Moonlight...) or an emulator running anywhere? For
    // when which window is in front isn't known
    static bool playerRunning();

    Q_INVOKABLE void rememberGame();
    Q_INVOKABLE void closeGame();
    Q_INVOKABLE void closeApp();
    // The apps that are open (Plasma and Hyprland): [{id, title, names}], for
    // the Guide's Open Apps and the Open marks in My Apps
    Q_INVOKABLE QVariantList openWindows() const;
    // The names an app's windows go by, to find it among those (see AppWindows)
    Q_INVOKABLE QStringList appNames(const QString &command, const QString &icon) const;
    // Bring one of them to the front, or close it the way its X would
    Q_INVOKABLE bool switchTo(const QString &windowId);
    Q_INVOKABLE bool closeWindow(const QString &windowId);
    Q_INVOKABLE void pauseGame();
    Q_INVOKABLE void resumeGame();

    QString lastName() const { return m_lastName; }
    QString lastCommand() const { return m_lastCommand; }
    QString gameTitle() const {return m_gameTitle;}
    QString appTitle() const { return m_appTitle; }
    QVariantList recents() const{return m_recents;}

signals:
    void lastPlayedChanged();
    void gameChanged();
    void recentsChanged();
    void desktopRequested();

private:
    void addRecent(const QString &kind, const QString &name, const QString &command, const QString &icon);
    void saveRecents();

    QString m_lastName;
    QString m_lastCommand;
    qint64 m_gamePid = 0;
    QString m_gameTitle;
    qint64 m_appPid = 0;
    QString m_appTitle;
    bool m_gamePaused = false;
    int m_savedVrr = 0;
    QVariantList m_recents;
};