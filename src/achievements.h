#pragma once

#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Your Steam achievements, read straight from Steam's own files
// (~/.local/share/Steam/appcache/stats): no API key, works offline and with a
// private profile. Only games you have installed count. Linux only; elsewhere
// everything is empty.
class Achievements : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // The newest 9, newest first: [{name, description, icon, appId, time}]
    Q_PROPERTY(QVariantList recent READ recent NOTIFY changed)

    // How many achievements you've unlocked
    Q_PROPERTY(int total READ total NOTIFY changed)

    // Every installed game with achievements, the one you unlocked something
    // in most recently first: [{appId, name, unlocked, total, last}]
    Q_PROPERTY(QVariantList games READ games NOTIFY changed)

public:
    explicit Achievements(QObject *parent = nullptr);

    QVariantList recent() const { return m_recent; }
    int total() const { return m_total; }
    QVariantList games() const { return m_games; }

    // Every achievement in one game, unlocked ones first (newest first), then
    // the locked ones: [{name, description, icon, unlocked, time, hidden}]
    Q_INVOKABLE QVariantList forGame(const QString &appId) const;

    // Read Steam's files again (e.g. after playing)
    Q_INVOKABLE void refresh();

signals:
    void changed();

private:
    QVariantList m_recent;
    int m_total = 0;
    QVariantList m_games;
    QHash<QString, QString> m_statsFiles;       // game -> its UserGameStats file
};