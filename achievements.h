#pragma

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class Achievements : public QObject{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariant recent READ recent NOTIFY changed)

    Q_PROPERTY(int total READ total NOTIFY changed)

public:
    explicit Achievements(QObject *parent = nullptr);

    QVariantList recent() const {return m_recent;}
    int total() const {return m_total;}

    Q_INVOKABLE void refresh();

signals:
    void changed();

private:
    QVariantList m_recent;
    int m_total = 0;
};