#pragma once

#include <QDir>
#include <QFile>
#include <QFileSystemWatcher>
#include <QStringList>
#include <QTimer>

#include <algorithm>
#include <functional>

#define SDL_MAIN_HANDLED
#include <SDL.h>

class ControllerWatch
{
public:
    explicit ControllerWatch(std::function<void()> lookAgain,
                             const QString &devices = "/dev/input",
                             const QString &sysfs = "/sys/class/input")
        : m_lookAgain(std::move(lookAgain))
        , m_sysfs(sysfs)
    {
        m_wait.setSingleShot(true);
        m_wait.setInterval(1500);                   // long enough for Linux to let you use it
        QObject::connect(&m_wait, &QTimer::timeout, &m_wait, [this] {
            if (gamepadsOnSystem(m_sysfs) > SDL_NumJoysticks())
                m_lookAgain();
        });
        // Something came or went in /dev/input: look in a moment
        QObject::connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_wait, [this] { m_wait.start(); });
        m_watcher.addPath(devices);
    }

    static int gamepadsOnSystem(const QString &sysfs = "/sys/class/input")
    {
        constexpr int ButtonSouth = 0x130;
        constexpr int WordBits = QT_POINTER_SIZE * 8;
        int count = 0;
        const QDir folder(sysfs);
        for (const QString &device : folder.entryList({ "event*" }, QDir::AllEntries | QDir::System | QDir::NoDotAndDotDot)) {
            QFile keys(folder.filePath(device + "/device/capabilities/key"));
            if (!keys.open(QIODevice::ReadOnly))
                continue;
            QStringList words = QString::fromLatin1(keys.readAll()).simplified().split(' ', Qt::SkipEmptyParts);
            std::reverse(words.begin(), words.end());     // the lowest first
            const int word = ButtonSouth / WordBits;
            if (word < words.size() && (words.at(word).toULongLong(nullptr, 16) >> (ButtonSouth % WordBits)) & 1)
                ++count;
        }
        return count;
    }

private:
    std::function<void()> m_lookAgain;
    QString m_sysfs;
    QFileSystemWatcher m_watcher;
    QTimer m_wait;
};