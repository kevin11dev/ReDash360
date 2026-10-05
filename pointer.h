#pragma once

#include <QObject>
#include <QPoint>
#include <QtQml/qqmlregistration.h>

class Pointer : public QObject{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit Pointer(QObject *parent = nullptr);

    bool active() const {return m_active;}

signals:
    void activeChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void setActive(bool active);

    bool m_active = true;
    QPointF m_lastPos;
};