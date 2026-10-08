#pragma once

#include <QAbstractListModel>
#include <QtQml/qqmlregistration.h>

// One installed game, from any launcher
struct Game
{
    QString name;
    QString source;     // "Steam", "Heroic", "Faugus"
    QString command;    // what Launcher.play() should run
    QString cover;      // image URL (file:// or https://), or empty
    QString banner;
    QString hero;
};

// Every installed game, as a list model QML can show with a ListView/Repeater
class GameLibrary : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        SourceRole,
        CommandRole,
        CoverRole,
        BannerRole
    };

    explicit GameLibrary(QObject *parent = nullptr);

    int count() const { return m_games.size(); }

    // QAbstractListModel: how many rows, what's in each, and the role names QML uses
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Scan the disk again (e.g. after installing a game)
    Q_INVOKABLE void refresh();

    // Every game as {name, source, command, cover, banner}, for filtering and sorting in QML
    Q_INVOKABLE QVariantList all() const;

    // The installed game with this launch command, in the same form; empty if it isn't installed
    Q_INVOKABLE QVariantMap find(const QString &command) const;

signals:
    void countChanged();

private:
    static QList<Game> scanSteam();
    static QList<Game> scanHeroic();
    static QList<Game> scanFaugus();

    QList<Game> m_games;
};