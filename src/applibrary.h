#pragma once

#include <QObject>
#include <QQuickImageProvider>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// One installed app, read from its .desktop file
struct App
{
    QString name;
    QString command;    // what Launcher.run() should run
    QString icon;       // icon theme name ("firefox") or a full path to an image
    QStringList categories;
};

// Every installed desktop app (the ones in your app menu), like GameLibrary
// does for games. Linux only: on other systems the list is empty.
class AppLibrary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit AppLibrary(QObject *parent = nullptr);

    int count() const { return m_apps.size(); }

    // Every app as {name, command, icon}, sorted A-Z
    Q_INVOKABLE QVariantList all() const;

    Q_INVOKABLE QVariantList videoApps() const;
    Q_INVOKABLE QVariantList musicApps() const;

    // Scan again (e.g. after installing an app)
    Q_INVOKABLE void refresh();

signals:
    void countChanged();

private:
    QList<App> m_apps;
};

// Lets QML show app icons: Image { source: "image://appicon/" + app.icon }
// works with icon names from the icon theme as well as full paths.
class AppIconProvider : public QQuickImageProvider
{
public:
    AppIconProvider();
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};