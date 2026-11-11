#pragma once

#include <QAbstractListModel>
#include <QtQml/qqmlregistration.h>
#include <QSet>

class QNetworkAccessManager;

// One installed game, from any launcher
struct Game
{
    QString name;
    QString source;     // "Steam", "Heroic", "Faugus"
    QString command;    // what Launcher.play() should run
    QString cover;      // image URL (file:// or https://), or empty
    QString banner;
    QString hero;
    QString system;     // a ROM's console folder ("snes"); empty for other games
    QString folder;
    bool direct = false;    // the command runs the game itself (a ROM's emulator, a Game Folders game), not a launcher
};

// Every installed game, as a list model QML can show with a ListView/Repeater
class GameLibrary : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)

    // Settings > Preferences: more places to look, each a folder path. Game
    // Folders: games outside the launchers (Linux games and AppImages). ROM
    // Folders: ROMs, a folder per console inside (or a console's own folder).
    Q_PROPERTY(QStringList gameFolders READ gameFolders NOTIFY foldersChanged)
    Q_PROPERTY(QStringList romFolders READ romFolders NOTIFY foldersChanged)

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

    QStringList gameFolders() const;
    QStringList romFolders() const;

    // The folder a game's command has to be started in, for Launcher.run(); "" = anywhere
    static QString startFolder(const QString &command);

    // Does this command run the game itself, not through Steam, Heroic or Faugus? For Launcher.run()
    static bool isDirect(const QString &command);

    // kind: "games" or "roms". Saved in ReDash360.conf under [library]; the games are looked for again
    Q_INVOKABLE void addFolder(const QString &kind, const QString &path);
    Q_INVOKABLE void removeFolder(const QString &kind, const QString &path);

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
    void foldersChanged();

private:
    static QList<Game> scanSteam();
    static QList<Game> scanHeroic();
    static QList<Game> scanFaugus();
    static QList<Game> scanFolders(const QStringList &folders);

    // ROMs' box art: download libretro's lists of covers (see roms.h)
    void fetchCoverLists();

    QList<Game> m_games;
    QNetworkAccessManager *m_network = nullptr;
    QSet<QString> m_coverListsTried;            // each once while the dashboard runs
    int m_coverListsPending = 0;
    bool m_coverListsSaved = false;
};