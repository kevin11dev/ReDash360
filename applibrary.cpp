#include "applibrary.h"

#include <QDir>
#include <QFile>
#include <QIcon>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>

namespace {

// Read the [Desktop Entry] part of a .desktop file. Returns false for things
// that shouldn't be listed: hidden entries, links, terminal programs, and
// game shortcuts (those are already in My Games).
bool readDesktopFile(const QString &path, App &app)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;

    QHash<QString, QString> keys;
    bool inEntry = false;
    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line.startsWith('[')) {
            inEntry = (line == "[Desktop Entry]");      // ignore [Desktop Action ...] groups
            continue;
        }
        const int equals = line.indexOf('=');
        if (!inEntry || equals < 1 || line.startsWith('#'))
            continue;
        keys.insert(line.left(equals).trimmed(), line.mid(equals + 1).trimmed());
    }

    if (keys.value("Type") != "Application"
        || keys.value("NoDisplay") == "true"
        || keys.value("Hidden") == "true"
        || keys.value("Terminal") == "true")
        return false;

    // Exec can contain codes like %U or %f for files to open; we open none
    static const QRegularExpression fieldCode("%[fFuUdDnNickvm]");
    QString command = keys.value("Exec");
    command.remove(fieldCode);
    command.replace("%%", "%");
    command = command.simplified();

    if (command.isEmpty())
        return false;

    // Game shortcuts made by Steam, Heroic and Faugus are already in My Games
    static const QStringList gameLinks = { "steam://rungameid", "heroic://launch", "faugus-launcher --game" };
    for (const QString &link : gameLinks) {
        if (command.contains(link))
            return false;
    }

    app.name = keys.value("Name");
    app.command = command;
    app.icon = keys.value("Icon");
    return !app.name.isEmpty();
}

} // namespace

AppLibrary::AppLibrary(QObject *parent)
    : QObject(parent)
{
    refresh();
}

QVariantList AppLibrary::all() const
{
    QVariantList list;
    for (const App &app : m_apps) {
        list << QVariantMap{
            { "name", app.name },
            { "command", app.command },
            { "icon", app.icon },
            };
    }
    return list;
}

void AppLibrary::refresh()
{
    // Your own apps folder first (~/.local/share/applications), then the
    // system ones; Flatpak apps live in their own folders
    QStringList folders = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    folders << QDir::homePath() + "/.local/share/flatpak/exports/share/applications"
            << "/var/lib/flatpak/exports/share/applications";

    QList<App> apps;
    QSet<QString> seen;     // the same file name in a later folder is the same app: skip it
    for (const QString &folder : std::as_const(folders)) {
        const QStringList files = QDir(folder).entryList({ "*.desktop" }, QDir::Files);
        for (const QString &fileName : files) {
            if (seen.contains(fileName))
                continue;
            seen.insert(fileName);

            App app;
            if (readDesktopFile(folder + "/" + fileName, app))
                apps << app;
        }
    }

    std::sort(apps.begin(), apps.end(), [](const App &a, const App &b) {
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    m_apps = apps;
    emit countChanged();
}

AppIconProvider::AppIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap)
{
}

QPixmap AppIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int side = requestedSize.width() > 0 ? requestedSize.width() : 128;

    // "/usr/share/.../app.png" is a file; "firefox" is looked up in the icon theme
    QIcon icon = id.startsWith('/') ? QIcon(id) : QIcon::fromTheme(id);
    if (icon.isNull())
        icon = QIcon::fromTheme("application-x-executable");    // generic "program" icon

    const QPixmap pixmap = icon.pixmap(side, side);
    if (size)
        *size = pixmap.size();
    return pixmap;
}