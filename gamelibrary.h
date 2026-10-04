#pragma once

#include <QAbstractListModel>
#include <QtQml/qqmlregistration.h>

struct Game{
    QString name;
    QString source;
    QString command;
    QString cover;
};

class GameLibrary : public QAbstractListModel{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        SourceRole,
        CommandRole,
        CoverRole
    };

    explicit GameLibrary(QObject *parent = nullptr);

    int count() const {return m_games.size();}

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();

signals:
    void countChanged();

private:
    static QList<Game> scanSteam();

    QList<Game> m_games;
};