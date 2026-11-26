#pragma once

#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
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
        , m_devices(devices)
        , m_sysfs(sysfs)
    {
        // Something came or went in /dev/input: look every 100 ms for the next
        // 3 seconds. Once Linux lets you use a new controller and SDL still
        // hasn't got it two looks running (it finds most itself, straight
        // away), SDL starts over to find it.
        m_wait.setInterval(100);
        QObject::connect(&m_wait, &QTimer::timeout, &m_wait, [this] {
            if (gamepadsOnSystem(m_sysfs, m_devices) <= SDL_NumJoysticks()) {
                m_missing = 0;
                if (m_since.elapsed() > 3000)
                    m_wait.stop();
            } else if (++m_missing >= 2) {
                m_wait.stop();
                m_lookAgain();
            }
        });
        QObject::connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_wait, [this] {
            m_since.start();
            m_missing = 0;
            m_wait.start();
        });
        m_watcher.addPath(devices);
    }

    // The controllers Linux has. With devices ("/dev/input"), only the ones
    // you can use already (Linux gives you a new one a moment after it appears)
    static int gamepadsOnSystem(const QString &sysfs = "/sys/class/input", const QString &devices = {})
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
            if (word < words.size() && (words.at(word).toULongLong(nullptr, 16) >> (ButtonSouth % WordBits)) & 1
                && (devices.isEmpty() || QFileInfo(devices + "/" + device).isReadable()))
                ++count;
        }
        return count;
    }

private:
    std::function<void()> m_lookAgain;
    QString m_devices;
    QString m_sysfs;
    QFileSystemWatcher m_watcher;
    QTimer m_wait;
    QElapsedTimer m_since;
    int m_missing = 0;
};