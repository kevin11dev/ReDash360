#include "news.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextDocumentFragment>
#include <QUrlQuery>
#include <QXmlStreamReader>

#include <algorithm>

namespace {

const int MaxGames = 12;            // Steam games asked about each time
const int MaxPerSite = 10;          // stories kept from the news site

QString cacheFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/news.json";
}

// HTML to plain text: no tags, &amp; and friends turned back into characters,
// and no stand-in characters where the pictures were
QString plainText(const QString &html)
{
    return QTextDocumentFragment::fromHtml(html).toPlainText().remove(QChar::ObjectReplacementCharacter).simplified();
}

} // namespace

News::News(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    load();
}

void News::refresh(const QVariantList &games, const QString &feedUrl, const QString &siteName)
{
    const bool wasLoading = loading();
    ++m_round;                      // answers to an earlier look are ignored from now on
    m_pending = 0;
    m_found.clear();
    m_failed.clear();

    // Just the developers' own posts: patch notes, events, announcements
    for (const QVariant &value : games.mid(0, MaxGames)) {
        const QVariantMap game = value.toMap();
        QUrl url("https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/");
        url.setQuery(QUrlQuery({
            { "appid", game.value("appid").toString() },
            { "count", "3" },
            { "maxlength", "300" },
            { "feeds", "steam_community_announcements" },
            }));
        fetch(url, "steam:" + game.value("appid").toString(),
              [game](const QByteArray &data) { return readSteam(data, game); });
    }

    if (!feedUrl.isEmpty()) {
        fetch(QUrl(feedUrl), "site:" + siteName,
              [siteName](const QByteArray &data) { return readFeed(data, siteName); });
    }

    if (m_pending == 0)
        finish();
    else if (!wasLoading)
        emit loadingChanged();
}

void News::fetch(const QUrl &url, const QString &from, std::function<QVariantList(const QByteArray &)> read)
{
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "ReDash360");
    request.setTransferTimeout(20000);
    QNetworkReply *reply = m_network->get(request);
    ++m_pending;

    const int round = m_round;
    connect(reply, &QNetworkReply::finished, this, [this, reply, round, from, read] {
        reply->deleteLater();
        if (round != m_round)
            return;
        const QVariantList found = reply->error() == QNetworkReply::NoError ? read(reply->readAll())
                                                                            : QVariantList();
        // A news site always has stories, so none means it didn't really answer
        if (reply->error() != QNetworkReply::NoError || (found.isEmpty() && from.startsWith("site:")))
            m_failed << from;
        m_found += found;
        if (--m_pending == 0)
            finish();
    });
}

// Everything has answered: the new news, plus the old news from wherever didn't
void News::finish()
{
    QVariantList items = m_found;
    for (const QVariant &old : std::as_const(m_items)) {
        if (m_failed.contains(old.toMap().value("from").toString()))
            items << old;
    }
    std::sort(items.begin(), items.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("time").toLongLong() > b.toMap().value("time").toLongLong();
    });

    m_items = items;
    m_found.clear();
    save();
    emit changed();
    emit loadingChanged();
}

// {"appnews": {"newsitems": [{"gid", "title", "contents", "feedlabel", "date", ...}]}}
QVariantList News::readSteam(const QByteArray &json, const QVariantMap &game)
{
    static const QRegularExpression bbCode("\\[[^\\]]*\\]|\\{STEAM_CLAN_IMAGE\\}\\S*");
    static const QRegularExpression joined("([.!?])(\\p{Lu})");    // "Sinners!Continue"

    const QString appid = game.value("appid").toString();
    QVariantList list;
    const QJsonArray news = QJsonDocument::fromJson(json).object()
                                .value("appnews").toObject().value("newsitems").toArray();
    for (const QJsonValue &value : news) {
        const QJsonObject post = value.toObject();
        QString summary = post.value("contents").toString();
        summary.remove(bbCode);
        summary.replace(joined, "\\1 \\2");
        list << QVariantMap {
            { "kind", "game" },
            { "from", "steam:" + appid },
            { "title", post.value("title").toString() },
            { "source", game.value("name") },
            { "label", post.value("feedlabel").toString() },
            { "time", qint64(post.value("date").toInteger()) * 1000 },
            { "url", "https://store.steampowered.com/news/app/" + appid + "/view/" + post.value("gid").toString() },
            { "image", game.value("image") },
            { "summary", summary.simplified() },
            };
    }
    return list;
}

// RSS (<item>) or Atom (<entry>): the title, link, date and a picture of each story
QVariantList News::readFeed(const QByteArray &xml, const QString &siteName)
{
    static const QRegularExpression firstImage("<img[^>]+src=[\"']([^\"']+)[\"']");
    static const QRegularExpression readMore("\\s*(Read the full article on|The post .* appeared first on)\\b.*$");
    const QString mediaRss = "http://search.yahoo.com/mrss/";

    QVariantList list;
    QXmlStreamReader reader(xml);
    QString title, link, html, image;
    QDateTime when;
    bool inStory = false;

    while (!reader.atEnd() && list.size() < MaxPerSite) {
        reader.readNext();
        const QStringView name = reader.name();
        if (reader.isStartElement()) {
            if (name == u"item" || name == u"entry") {
                inStory = true;
                title.clear(); link.clear(); html.clear(); image.clear();
                when = QDateTime();
            } else if (!inStory) {
                continue;
            } else if (name == u"title") {
                title = plainText(reader.readElementText(QXmlStreamReader::IncludeChildElements));
            } else if (name == u"link") {
                const auto attributes = reader.attributes();
                if (!attributes.hasAttribute("href"))
                    link = reader.readElementText().trimmed();                    // RSS
                else if (attributes.value("rel").isEmpty() || attributes.value("rel") == u"alternate")
                    link = attributes.value("href").toString();                   // Atom
            } else if (name == u"pubDate" || name == u"published" || name == u"updated" || name == u"date") {
                if (!when.isValid()) {
                    QString text = reader.readElementText().trimmed();
                    when = QDateTime::fromString(text, Qt::RFC2822Date);
                    if (!when.isValid())
                        when = QDateTime::fromString(text.replace(" GMT", " +0000"), Qt::RFC2822Date);
                    if (!when.isValid())
                        when = QDateTime::fromString(text, Qt::ISODate);
                }
            } else if (reader.namespaceUri() == mediaRss && (name == u"content" || name == u"thumbnail")) {
                const auto attributes = reader.attributes();
                const QStringView type = attributes.value("type");
                if (image.isEmpty() && (type.isEmpty() || type.startsWith(u"image") || attributes.value("medium") == u"image"))
                    image = attributes.value("url").toString();
            } else if (name == u"enclosure") {
                if (image.isEmpty() && reader.attributes().value("type").startsWith(u"image"))
                    image = reader.attributes().value("url").toString();
            } else if (name == u"description" || name == u"summary" || name == u"encoded" || name == u"content") {
                if (html.isEmpty())
                    html = reader.readElementText(QXmlStreamReader::IncludeChildElements);
            }
        } else if (reader.isEndElement() && inStory && (name == u"item" || name == u"entry")) {
            inStory = false;
            if (title.isEmpty() || link.isEmpty())
                continue;
            if (image.isEmpty())
                image = firstImage.match(html).captured(1).replace("&amp;", "&");
            QString summary = plainText(html);
            summary.remove(readMore);
            list << QVariantMap {
                { "kind", "site" },
                { "from", "site:" + siteName },
                { "title", title },
                { "source", siteName },
                { "label", QString() },
                { "time", when.isValid() ? when.toMSecsSinceEpoch() : QDateTime::currentMSecsSinceEpoch() },
                { "url", link },
                { "image", image },
                { "summary", summary },
                };
        }
    }
    return list;
}

QString News::ago(qint64 time) const
{
    const qint64 minutes = (QDateTime::currentMSecsSinceEpoch() - time) / 60000;
    if (minutes < 2)
        return "Just now";
    if (minutes < 60)
        return QString("%1 minutes ago").arg(minutes);
    const qint64 hours = minutes / 60;
    if (hours < 24)
        return hours == 1 ? QString("An hour ago") : QString("%1 hours ago").arg(hours);
    const qint64 days = hours / 24;
    if (days < 14)
        return days == 1 ? QString("Yesterday") : QString("%1 days ago").arg(days);
    return QLocale().toString(QDateTime::fromMSecsSinceEpoch(time).date(), "d MMMM");
}

// The news from last time, so the tile isn't empty while it looks again
void News::load()
{
    QFile file(cacheFile());
    if (file.open(QIODevice::ReadOnly))
        m_items = QJsonDocument::fromJson(file.readAll()).array().toVariantList();
}

void News::save() const
{
    QDir().mkpath(QFileInfo(cacheFile()).path());
    QFile file(cacheFile());
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(QJsonDocument(QJsonArray::fromVariantList(m_items)).toJson(QJsonDocument::Compact));
}