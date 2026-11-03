#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

// The login screen (the SDDM theme in sddm/redash360) shows your gamerpic and
// avatar too. It runs as the sddm user, which can't read your home folder, so
// share() keeps copies of them in ~/.redash360 and lets sddm through to them.
// Linux only: elsewhere it does nothing.
class LoginScreen : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit LoginScreen(QObject *parent = nullptr) : QObject(parent) {}

    // Your gamerpic and avatar as UserProfile has them (files or file:// URLs,
    // "" for none)
    Q_INVOKABLE void share(const QString &gamerpic, const QString &avatar);
};