#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

class Autostart : public QObject{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit Autostart(QObject *parent = nullptr);

    bool enabled() const{return m_enabled;}
    void setEnabled(bool enabled);

    Q_INVOKABLE void refresh();

signals:
    void enabledChanged();

private:
    bool m_enabled = false;
};