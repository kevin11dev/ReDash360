#include "storage.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QThread>

#include <algorithm>

namespace {

QString readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(file.readAll());
}

// First match of `"key"   "value"` in a Steam .vdf/.acf file
QString vdfValue(const QString &text, const QString &key)
{
    const QRegularExpression re("\"" + QRegularExpression::escape(key) + "\"\\s+\"([^\"]*)\"",
                                QRegularExpression::CaseInsensitiveOption);
    return re.match(text).captured(1);
}

// How much the files in a folder (and the folders in it) take up
qint64 folderSize(const QString &path)
{
    qint64 total = 0;
    QDirIterator it(path, QDir::Files | QDir::Hidden | QDir::System | QDir::NoSymLinks,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }
    return total;
}

QString deviceOf(const QString &path)
{
    return QString::fromUtf8(QStorageInfo(path).device());
}

// Where Steam is installed: the normal place, the ~/.steam link and the Flatpak
QStringList steamRoots()
{
    const QString home = QDir::homePath();
    QStringList candidates = {
        home + "/.local/share/Steam",
        home + "/.steam/steam",
        home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam",
    };
#ifdef Q_OS_WIN
    candidates << "C:/Program Files (x86)/Steam";
#endif
    QStringList roots;
    for (const QString &candidate : candidates) {
        const QString root = QFileInfo(candidate).canonicalFilePath();     // the same folder through a link counts once
        if (!root.isEmpty() && QDir(root + "/steamapps").exists() && !roots.contains(root))
            roots << root;
    }
    return roots;
}

// Every Steam library folder: Steam's own and the ones you added on other drives
QStringList steamLibraries()
{
    QStringList libraries;
    for (const QString &root : steamRoots()) {
        if (!libraries.contains(root))
            libraries << root;
        static const QRegularExpression pathRe("\"path\"\\s+\"([^\"]+)\"");
        auto matches = pathRe.globalMatch(readFile(root + "/steamapps/libraryfolders.vdf"));
        while (matches.hasNext()) {
            QString path = matches.next().captured(1);
            path.replace("\\\\", "/");          // Windows paths are written with doubled backslashes
            path = QFileInfo(path).canonicalFilePath();
            if (!path.isEmpty() && !libraries.contains(path))
                libraries << path;
        }
    }
    return libraries;
}

// Drives worth showing: real disks, not the system's own bits (/boot, tmpfs, snaps...)
bool worthShowing(const QStorageInfo &volume)
{
    if (!volume.isValid() || !volume.isReady() || volume.bytesTotal() <= 0)
        return false;
#ifdef Q_OS_WIN
    return true;
#else
    const QString device = QString::fromUtf8(volume.device());
    if (!device.startsWith("/dev/") || device.startsWith("/dev/loop"))
        return false;
    const QString root = volume.rootPath();
    for (const QString &system : { "/boot", "/efi", "/var", "/srv", "/opt", "/root", "/usr", "/tmp", "/nix", "/snap" })
        if (root == system || root.startsWith(system + "/"))
            return false;
    return true;
#endif
}

QVariantMap category(const QString &id, const QString &name, qint64 size)
{
    return { { "id", id }, { "name", name }, { "size", size } };
}

} // namespace

Storage::Storage(QObject *parent)
    : QObject(parent)
{
    refresh();
}

void Storage::refresh()
{
    // One entry per disk; a disk mounted in several places (btrfs puts / and
    // /home on the same one) shows up where it's mounted highest
    const QString systemDevice = QString::fromUtf8(QStorageInfo::root().device());
    QHash<QString, QStorageInfo> byDevice;
    for (const QStorageInfo &volume : QStorageInfo::mountedVolumes()) {
        if (!worthShowing(volume))
            continue;
        const QString device = QString::fromUtf8(volume.device());
        if (!byDevice.contains(device) || volume.rootPath().size() < byDevice[device].rootPath().size())
            byDevice[device] = volume;
    }

    QVariantList devices;
    for (auto it = byDevice.cbegin(); it != byDevice.cend(); ++it) {
        const QStorageInfo &volume = it.value();
        const QString root = volume.rootPath();
        const QString kind = it.key() == systemDevice ? "system"
                             : root.startsWith("/run/media/") || root.startsWith("/media/") ? "usb" : "drive";
        QString name = volume.name();
        if (kind == "system")
            name = "Hard Drive";
        else if (name.isEmpty() && kind == "usb")
            name = "USB Storage Device";
        else if (name.isEmpty())
            name = QDir(root).dirName().isEmpty() ? root : QDir(root).dirName();
        devices << QVariantMap {
            { "id", it.key() },
            { "name", name },
            { "kind", kind },
            { "path", root },
            { "total", volume.bytesTotal() },
            { "free", volume.bytesAvailable() },
            { "used", volume.bytesTotal() - volume.bytesFree() },
            };
    }

    // The system drive, then the other drives, then USB sticks, each by name
    std::sort(devices.begin(), devices.end(), [](const QVariant &a, const QVariant &b) {
        static const QStringList order = { "system", "drive", "usb" };
        const QVariantMap x = a.toMap(), y = b.toMap();
        const int kindX = order.indexOf(x["kind"].toString()), kindY = order.indexOf(y["kind"].toString());
        if (kindX != kindY)
            return kindX < kindY;
        return x["name"].toString().compare(y["name"].toString(), Qt::CaseInsensitive) < 0;
    });

    if (devices != m_devices) {
        m_devices = devices;
        emit devicesChanged();
    }
}

void Storage::measure(const QString &id)
{
    qint64 used = -1;
    for (const QVariant &device : std::as_const(m_devices))
        if (device.toMap().value("id").toString() == id)
            used = device.toMap().value("used").toLongLong();
    if (used < 0 || m_measuring.contains(id))
        return;
    m_measuring.insert(id);

    QThread *worker = QThread::create([this, id, used] {
        QVariantList categories;
        QVariantList games;
        qint64 counted = 0;
        const auto add = [&](const QString &key, const QString &name, qint64 size) {
            categories << category(key, name, size);
            counted += size;
        };

        // Steam: its games (each one's size is in its manifest), the shaders
        // it saved for them and the Proton files (Windows games' saves and settings)
        qint64 gamesSize = 0, shaders = 0, proton = 0;
        bool hasSteam = false;
        for (const QString &library : steamLibraries()) {
            if (deviceOf(library) != id)
                continue;
            hasSteam = true;
            QDir steamapps(library + "/steamapps");
            for (const QString &manifest : steamapps.entryList({ "appmanifest_*.acf" }, QDir::Files)) {
                const QString text = readFile(steamapps.filePath(manifest));
                const qint64 size = vdfValue(text, "SizeOnDisk").toLongLong();
                gamesSize += size;
                games << QVariantMap { { "appId", vdfValue(text, "appid") }, { "name", vdfValue(text, "name") },
                                     { "size", size } };
            }
            shaders += folderSize(steamapps.filePath("shadercache"));
            proton += folderSize(steamapps.filePath("compatdata"));
        }
        if (hasSteam) {
            add("games", "Games and Apps", gamesSize);
            add("shadercache", "Shader Cache", shaders);
            add("proton", "Proton Files", proton);
        }

        // Your screenshots (Steam keeps them per account) and your own folders
        qint64 screenshots = 0;
        for (const QString &root : steamRoots()) {
            if (deviceOf(root) != id)
                continue;
            for (const QFileInfo &account : QDir(root + "/userdata").entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot))
                screenshots += folderSize(account.filePath() + "/760");
        }
        if (screenshots > 0)
            add("screenshots", "Screenshots", screenshots);

        const QList<QPair<QStandardPaths::StandardLocation, QString>> folders = {
                                                                                  { QStandardPaths::DownloadLocation, "Downloads" },
                                                                                  { QStandardPaths::MoviesLocation, "Videos" },
                                                                                  { QStandardPaths::MusicLocation, "Music" },
                                                                                  { QStandardPaths::PicturesLocation, "Pictures" },
                                                                                  };
        for (const auto &[location, name] : folders) {
            const QString path = QStandardPaths::writableLocation(location);
            if (path.isEmpty() || path == QDir::homePath() || !QDir(path).exists() || deviceOf(path) != id)
                continue;
            add(name.toLower(), name, folderSize(path));
        }

        // Everything else: the system, apps, other files
        categories << category("other", "Other Files", std::max<qint64>(0, used - counted));

        std::sort(games.begin(), games.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap()["size"].toLongLong() > b.toMap()["size"].toLongLong();
        });

        QMetaObject::invokeMethod(this, [this, id, categories, games] {
            m_categories[id] = categories;
            m_games[id] = games;
            m_measuring.remove(id);
            emit measured(id);
        }, Qt::QueuedConnection);
    });
    connect(worker, &QThread::finished, worker, &QObject::deleteLater);
    worker->start(QThread::LowPriority);
}

void Storage::clearShaderCache(const QString &id)
{
    if (m_measuring.contains(id))
        return;
    m_measuring.insert(id);

    QThread *worker = QThread::create([this, id] {
        // Only the per-game folders inside Steam's own shadercache folders
        for (const QString &library : steamLibraries()) {
            if (deviceOf(library) != id)
                continue;
            const QDir cache(library + "/steamapps/shadercache");
            for (const QFileInfo &game : cache.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks))
                QDir(game.filePath()).removeRecursively();
        }
        QMetaObject::invokeMethod(this, [this, id] {
            m_measuring.remove(id);
            refresh();                          // more free space now
            measure(id);
        }, Qt::QueuedConnection);
    });
    connect(worker, &QThread::finished, worker, &QObject::deleteLater);
    worker->start(QThread::LowPriority);
}

void Storage::eject(const QString &id)
{
#ifdef Q_OS_WIN
    emit ejected(id, "Use Windows' \"Safely Remove Hardware\" to remove this drive.");
#else
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process, id](int exitCode, QProcess::ExitStatus status) {
        const QString error = QString::fromUtf8(process->readAllStandardError()).trimmed();
        process->deleteLater();
        refresh();
        if (status == QProcess::NormalExit && exitCode == 0)
            emit ejected(id, QString());
        else
            emit ejected(id, error.isEmpty() ? "The drive couldn't be removed. Close anything using it and try again."
                                             : error);
    });
    connect(process, &QProcess::errorOccurred, this, [this, process, id](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            process->deleteLater();
            emit ejected(id, "Removing drives needs udisks (udisksctl).");
        }
    });
    process->start("udisksctl", { "unmount", "--block-device", id });
#endif
}