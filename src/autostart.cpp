#include "autostart.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>

namespace {

// What starts the dashboard: its AppImage when it runs from one, otherwise this program
QString program()
{
    const QString appImage = qEnvironmentVariable("APPIMAGE");
    return appImage.isEmpty() ? QCoreApplication::applicationFilePath() : appImage;
}

#ifdef Q_OS_WIN

const QString runKey = "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run";

bool isOn()
{
    return QSettings(runKey, QSettings::NativeFormat).contains("ReDash360");
}

void turn(bool on)
{
    QSettings run(runKey, QSettings::NativeFormat);
    if (on)
        run.setValue("ReDash360", "\"" + QDir::toNativeSeparators(program()) + "\"");
    else
        run.remove("ReDash360");
}

#else

QString desktopFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
    + "/autostart/ReDash360.desktop";
}

bool isOn()
{
    QFile file(desktopFile());
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QByteArray text = file.readAll();
    // Switched off in the desktop's settings, but still there
    return !text.contains("Hidden=true") && !text.contains("X-GNOME-Autostart-enabled=false");
}

void turn(bool on)
{
    if (!on) {
        QFile::remove(desktopFile());
        return;
    }

    // The path in quotes, in case it has spaces. The .desktop rules: \ " ` $
    // get a \ in front, then every \ is doubled, and % is doubled
    QString path = program();
    path.replace('\\', "\\\\").replace('"', "\\\"").replace('`', "\\`").replace('$', "\\$");
    QString exec = "\"" + path + "\"";
    exec.replace('\\', "\\\\").replace('%', "%%");

    QDir().mkpath(QFileInfo(desktopFile()).path());
    QFile file(desktopFile());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    file.write("[Desktop Entry]\n"
               "Type=Application\n"
               "Name=ReDash360\n"
               "Comment=Xbox 360-style dashboard\n"
               "Icon=input-gaming\n"
               "Exec=" + exec.toUtf8() + "\n");
}

#endif

} // namespace

Autostart::Autostart(QObject *parent)
    : QObject(parent)
    , m_enabled(isOn())
{
}

void Autostart::setEnabled(bool enabled)
{
    turn(enabled);
    refresh();
}

void Autostart::refresh()
{
    const bool on = isOn();
    if (on == m_enabled)
        return;
    m_enabled = on;
    emit enabledChanged();
}