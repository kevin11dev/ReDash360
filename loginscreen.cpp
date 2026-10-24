#include "loginscreen.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QUrl>

namespace {

const QFileDevice::Permissions EveryoneReads = QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                               | QFileDevice::ReadGroup | QFileDevice::ReadOther;

// "file:///home/kevin/a.gif" or "/home/kevin/a.gif" -> "/home/kevin/a.gif"
QString localFile(const QString &source)
{
    const QUrl url(source);
    return url.isLocalFile() ? url.toLocalFile() : source;
}

// The copy in ~/.redash360 under this name, or none when there's no picture
void keepCopy(const QString &source, const QString &copy)
{
    QFile::remove(copy);
    const QString file = localFile(source);
    if (!file.isEmpty() && QFile::copy(file, copy))
        QFile::setPermissions(copy, EveryoneReads);
}

} // namespace

void LoginScreen::share(const QString &gamerpic, const QString &avatar)
{
#ifdef Q_OS_LINUX
    const QString home = QDir::homePath();
    const QString folder = home + "/.redash360";
    QDir().mkpath(folder);
    QFile::setPermissions(folder, EveryoneReads | QFileDevice::ExeOwner | QFileDevice::ExeGroup | QFileDevice::ExeOther);

    keepCopy(gamerpic, folder + "/gamerpic");
    keepCopy(avatar, folder + "/avatar");

    // sddm may pass through your home folder to ~/.redash360. It still can't
    // see what else is in there. Already open to everyone: nothing to do.
    if (!QFileInfo(home).permission(QFileDevice::ExeOther))
        QProcess::startDetached("setfacl", { "-m", "u:sddm:x", home });
#else
    Q_UNUSED(gamerpic)
    Q_UNUSED(avatar)
#endif
}