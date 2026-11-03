#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QNetworkAccessManager;

// Home's News tile: what's new in your Steam games (their developers' own
// posts, from Steam's news service) and the latest from a gaming news site
// (its RSS feed, chosen in Settings > Preferences). Kept on disk as well, so
// the tile still has something to show when the PC is offline.
class News : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Newest first: [{kind, title, source, label, time, url, image, summary}]
    //   kind: "game" (one of your Steam games) or "site" (the news site)
    //   source: the game or the site; label: which feed ("Community Announcements")
    //   time: when it was posted, in milliseconds (new Date(time) in QML)
    Q_PROPERTY(QVariantList items READ items NOTIFY changed)

    // true while it's looking
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit News(QObject *parent = nullptr);

    QVariantList items() const { return m_items; }
    bool loading() const { return m_pending > 0; }

    // Look again. games: your Steam games, [{appid, name, image}];
    // feedUrl and siteName: the news site's RSS feed ("" for none)
    Q_INVOKABLE void refresh(const QVariantList &games, const QString &feedUrl, const QString &siteName);

    // "3 hours ago", "Yesterday", "12 October"
    Q_INVOKABLE QString ago(qint64 time) const;

    // What Steam's news service and an RSS feed send back, as items
    static QVariantList readSteam(const QByteArray &json, const QVariantMap &game);
    static QVariantList readFeed(const QByteArray &xml, const QString &siteName);

signals:
    void changed();
    void loadingChanged();

private:
    void fetch(const QUrl &url, const QString &from, std::function<QVariantList(const QByteArray &)> read);
    void finish();
    void load();
    void save() const;

    QNetworkAccessManager *m_network;
    QVariantList m_items;
    QVariantList m_found;           // what this look has found so far
    QStringList m_failed;           // where it couldn't look, so the old news from there stays
    int m_pending = 0;
    int m_round = 0;                // which look the answers belong to
};