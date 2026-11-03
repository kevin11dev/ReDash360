#pragma once

#include <QHash>
#include <QObject>
#include <QSet>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Your drives and what's on them, for the Storage screen: every drive with
// how much space is free, then, for one drive, how much its games, shader
// caches, Proton files, screenshots and your own folders take up. Adding up
// a drive means walking through its folders, so that happens on a
// background thread and ends with measured().
class Storage : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Every drive, the one the system is on first:
    // [{id, name, kind ("system", "drive" or "usb"), total, free, used}] (sizes in bytes)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)

public:
    explicit Storage(QObject *parent = nullptr);

    QVariantList devices() const { return m_devices; }

    // Look at the drives again (quick; e.g. after plugging in a USB stick)
    Q_INVOKABLE void refresh();

    // Add up what's on one drive (an id from devices). Ends with measured(id)
    Q_INVOKABLE void measure(const QString &id);
    Q_INVOKABLE bool isMeasuring(const QString &id) const { return m_measuring.contains(id); }

    // What takes up the space on a measured drive: [{id, name, size}]
    Q_INVOKABLE QVariantList categories(const QString &id) const { return m_categories.value(id); }

    // The Steam games and apps on a measured drive, biggest first: [{appId, name, size}]
    Q_INVOKABLE QVariantList games(const QString &id) const { return m_games.value(id); }

    // Delete the shaders Steam has saved on one drive (it makes them again
    // when a game needs them). Ends with measured(id)
    Q_INVOKABLE void clearShaderCache(const QString &id);

    // Safely remove a USB drive. Ends with ejected(id, error), error "" when it worked
    Q_INVOKABLE void eject(const QString &id);

signals:
    void devicesChanged();
    void measured(const QString &id);
    void ejected(const QString &id, const QString &error);

private:
    QVariantList m_devices;
    QHash<QString, QVariantList> m_categories;
    QHash<QString, QVariantList> m_games;
    QSet<QString> m_measuring;
};