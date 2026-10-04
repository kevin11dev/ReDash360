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

public:
    explicit Launcher(QObject *parent = nullptr);

    Q_INVOKABLE bool run(const QString &command);

    // Like run(), but for games: also remembers it as the last played game
    Q_INVOKABLE bool play(const QString &name, const QString &command);

    QString lastName() const { return m_lastName; }
    QString lastCommand() const { return m_lastCommand; }

signals:
    void lastPlayedChanged();

private:
    QString m_lastName;
    QString m_lastCommand;
};