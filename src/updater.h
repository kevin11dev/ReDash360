#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QNetworkAccessManager;
class QProcess;

// Updates from GitHub. ReDash360 knows which commit it was built from, asks
// GitHub now and then whether main has newer ones, and can install them for
// you: the README's makepkg steps, done in the background with a progress
// bar. The password goes to sudo for this update only and isn't kept.
// Installing works for the redash360-git package (Arch, CachyOS); other
// installs are told about updates and how to get them.
class Updater : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // The commit this dashboard was built from, short ("a63abd5"); "" if it isn't known
    Q_PROPERTY(QString version READ version CONSTANT)

    // "unknown": doesn't look (a build that isn't installed, or one GitHub doesn't have)
    // "checking", "upToDate", "available", "offline" (couldn't reach GitHub),
    // "updating", "done" (installed: restart to use it), "failed"
    Q_PROPERTY(QString state READ state NOTIFY changed)

    // The newest commit on GitHub (short), and what's new since this
    // version, newest first: [{title, time}] (time in milliseconds)
    Q_PROPERTY(QString latest READ latest NOTIFY changed)
    Q_PROPERTY(QVariantList changes READ changes NOTIFY changed)

    // Can the dashboard install it here? (the redash360-git package)
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY changed)

    // An update you haven't said Later to: worth popping up about
    Q_PROPERTY(bool worthTelling READ worthTelling NOTIFY changed)

    // While updating: what it's doing, how far along (0 to 1), and what went wrong
    Q_PROPERTY(QString step READ step NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit Updater(QObject *parent = nullptr);
    ~Updater() override;

    QString version() const { return m_version.left(7); }
    QString state() const { return m_state; }
    QString latest() const { return m_latest.left(7); }
    QVariantList changes() const { return m_changes; }
    bool canInstall() const { return m_canInstall; }
    bool worthTelling() const;
    QString step() const { return m_step; }
    double progress() const { return m_progress; }
    QString error() const { return m_error; }

    // Ask GitHub now
    Q_INVOKABLE void check();

    // Don't pop up about this update again (a newer one will)
    Q_INVOKABLE void later();

    // Download, build and install it, with your password for sudo
    Q_INVOKABLE void install(const QString &password);

    // Start the new version
    Q_INVOKABLE void restart();

    // What GitHub's compare answer says: "available" or "upToDate", the
    // newest commit and what's new (newest first)
    static QString readCompare(const QByteArray &json, QString *latest, QVariantList *changes);

    // The parts a PKGBUILD needs (makepkg --printsrcinfo's depends and makedepends)
    static QStringList readNeeds(const QByteArray &srcinfo);

signals:
    void changed();

private:
    void setState(const QString &state);
    void setStep(const QString &step, double progress);
    void fail(const QString &why);
    void finishInstall();

    // Run a program in the update folder; done(exit code, what it printed).
    // With sudo, the password goes in first. eachLine sees each line as it comes.
    void run(const QString &program, const QStringList &arguments, std::function<void(int, const QByteArray &)> done,
             bool withPassword = false, std::function<void(const QByteArray &)> eachLine = {});

    // The steps, one after another
    void checkPassword();
    void download();
    void getNeeds();
    void build();
    void installPackage();

    QNetworkAccessManager *m_network;
    QTimer m_timer;
    QString m_api;                  // GitHub's API, and where its raw files are
    QString m_raw;
    QString m_repo;                 // "kevin11dev/ReDash360"
    QString m_version;              // full commit
    QString m_latest;
    QString m_state = "unknown";
    QVariantList m_changes;
    bool m_canInstall = false;
    bool m_looks = false;           // installed, with a known version: worth asking GitHub
    QString m_step;
    double m_progress = 0;
    QString m_error;
    QString m_password;             // only while installing
    QString m_folder;               // where it builds: ~/.cache/ReDash360/ReDash360/update
    QProcess *m_process = nullptr;
};