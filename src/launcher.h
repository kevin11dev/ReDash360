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
    // itself? Like Steam's Big Picture, or an app with a TV mode
    static bool readsController(qint64 pid);

    Q_INVOKABLE void rememberGame();
    Q_INVOKABLE void closeGame();
    Q_INVOKABLE void pauseGame();
    Q_INVOKABLE void resumeGame();

    QString lastName() const { return m_lastName; }
    QString lastCommand() const { return m_lastCommand; }
    QString gameTitle() const {return m_gameTitle;}
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
    bool m_gamePaused = false;
    int m_savedVrr = 0;
    QVariantList m_recents;
};