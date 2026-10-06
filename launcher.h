#pragma once

#include <QObject>
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

public:
    explicit Launcher(QObject *parent = nullptr);

    Q_INVOKABLE bool run(const QString &command);

    // Like run(), but for games: also remembers it as the last played game
    Q_INVOKABLE bool play(const QString &name, const QString &command);

    Q_INVOKABLE void rememberGame();
    Q_INVOKABLE void closeGame();

    QString lastName() const { return m_lastName; }
    QString lastCommand() const { return m_lastCommand; }
    QString gameTitle() const {return m_gameTitle;}

signals:
    void lastPlayedChanged();
    void gameChanged();

private:
    QString m_lastName;
    QString m_lastCommand;
    qint64 m_gamePid = 0;
    QString m_gameTitle;
};