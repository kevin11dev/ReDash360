#include "updater.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>
#include <memory>

// CMake fills these in: the commit this was built from, and where updates come from
#ifndef REDASH360_COMMIT
#define REDASH360_COMMIT ""
#endif
#ifndef REDASH360_REPO
#define REDASH360_REPO "kevin11dev/ReDash360"
#endif

namespace {

constexpr int FirstCheckMs = 20 * 1000;             // a little after the dashboard starts
constexpr int CheckEveryMs = 6 * 60 * 60 * 1000;    // then every six hours
constexpr int MaxChanges = 30;
constexpr char PackageName[] = "redash360-git";
constexpr char PackageFolder[] = "packaging/arch/redash360-git";

// The last thing a program said, for "didn't work: ..."
QString lastLine(const QByteArray &output)
{
    const QStringList lines = QString::fromUtf8(output).split('\n', Qt::SkipEmptyParts);
    for (auto it = lines.crbegin(); it != lines.crend(); ++it) {
        const QString line = it->trimmed();
        if (!line.isEmpty())
            return line.left(160);
    }
    return QString();
}

} // namespace

Updater::Updater(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    m_version = QString::fromLatin1(REDASH360_COMMIT);
    m_repo = QString::fromLatin1(REDASH360_REPO);
    // Other addresses for GitHub's API and raw files, for trying it out
    m_api = qEnvironmentVariable("REDASH360_UPDATE_API", "https://api.github.com");
    m_raw = qEnvironmentVariable("REDASH360_UPDATE_RAW", "https://raw.githubusercontent.com");
    m_folder = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/update";

    // Only an installed dashboard looks. One run from a build folder (Qt
    // Creator) is yours to update. (Also remembers where this one is, for
    // restart(), before an update replaces the file.)
    const bool installed = QCoreApplication::applicationFilePath().startsWith("/usr/")
                           || qEnvironmentVariableIsSet("REDASH360_UPDATE_API");
    m_looks = installed && m_version.size() >= 7;

#ifdef Q_OS_LINUX
    // Installed as the package? Then makepkg can update it
    auto *pacman = new QProcess(this);
    connect(pacman, &QProcess::finished, this, [this, pacman](int code, QProcess::ExitStatus status) {
        m_canInstall = status == QProcess::NormalExit && code == 0;
        pacman->deleteLater();
        emit changed();
    });
    connect(pacman, &QProcess::errorOccurred, pacman, &QObject::deleteLater);     // no pacman here
    pacman->start("pacman", { "-Qq", PackageName });
#endif

    connect(&m_timer, &QTimer::timeout, this, [this] {
        check();
        m_timer.setInterval(CheckEveryMs);
    });
    if (m_looks)
        m_timer.start(FirstCheckMs);
}

Updater::~Updater()
{
    m_password.fill(QChar(0));
    if (m_process)
        m_process->kill();
}

bool Updater::worthTelling() const
{
    return m_state == "available" && m_latest != QSettings().value("update/later").toString();
}

void Updater::setState(const QString &state)
{
    m_state = state;
    emit changed();
}

void Updater::setStep(const QString &step, double progress)
{
    m_step = step;
    m_progress = std::max(m_progress, progress);
    emit changed();
}

// ---- Looking -----------------------------------------------------------------

void Updater::check()
{
    if (!m_looks || m_state == "checking" || m_state == "updating" || m_state == "done")
        return;
    setState("checking");

    // What main has that this version doesn't
    QNetworkRequest request(QUrl(QString("%1/repos/%2/compare/%3...main").arg(m_api, m_repo, m_version)));
    request.setHeader(QNetworkRequest::UserAgentHeader, "ReDash360");
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setTransferTimeout(20000);
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            // 404: GitHub doesn't have this commit (a build with your own changes).
            // Otherwise offline: an update it already knew about is still there.
            setState(status == 404 ? "unknown" : !m_changes.isEmpty() ? "available" : "offline");
            return;
        }
        QString latest;
        QVariantList changes;
        const QString state = readCompare(reply->readAll(), &latest, &changes);
        m_latest = latest.isEmpty() ? m_version : latest;
        m_changes = changes;
        setState(state);
    });
}

QString Updater::readCompare(const QByteArray &json, QString *latest, QVariantList *changes)
{
    // {"status": "ahead", "ahead_by": 3, "commits": [{"sha", "commit": {"message", "committer": {"date"}}}]}
    // "ahead": main has commits this version doesn't (they're listed oldest first)
    const QJsonObject answer = QJsonDocument::fromJson(json).object();
    const QString status = answer.value("status").toString();
    const int newer = answer.value("ahead_by").toInt();
    const QJsonArray commits = answer.value("commits").toArray();

    changes->clear();
    for (qsizetype i = commits.size() - 1; i >= 0 && changes->size() < MaxChanges; --i) {
        const QJsonObject commit = commits.at(i).toObject().value("commit").toObject();
        const QDateTime time = QDateTime::fromString(commit.value("committer").toObject().value("date").toString(),
                                                     Qt::ISODate);
        changes->append(QVariantMap {
            { "title", commit.value("message").toString().section('\n', 0, 0).trimmed() },
            { "time", time.isValid() ? time.toMSecsSinceEpoch() : 0 },
            });
    }
    *latest = commits.isEmpty() ? QString() : commits.last().toObject().value("sha").toString();

    const bool available = newer > 0 && (status == "ahead" || status == "diverged");
    if (!available)
        changes->clear();
    return available ? "available" : "upToDate";
}

void Updater::later()
{
    QSettings().setValue("update/later", m_latest);
    emit changed();
}

// ---- Installing ----------------------------------------------------------------
// The README's steps: the newest PKGBUILD, makepkg to build it (which gets
// the code from GitHub), pacman to install what it builds. Done in
// ~/.cache/ReDash360/ReDash360/update, which it keeps, so the next update
// only downloads and builds what changed. update.log there has everything
// the programs said.

void Updater::install(const QString &password)
{
    if (!m_canInstall || (m_state != "available" && m_state != "failed"))
        return;
    m_password = password;
    m_error.clear();
    m_progress = 0;
    setState("updating");
    checkPassword();
}

void Updater::fail(const QString &why)
{
    m_password.fill(QChar(0));
    m_password.clear();
    m_error = why;
    setState("failed");
}

void Updater::finishInstall()
{
    m_password.fill(QChar(0));
    m_password.clear();
    setStep("Done", 1);
    setState("done");
}

void Updater::run(const QString &program, const QStringList &arguments,
                  std::function<void(int, const QByteArray &)> done, bool withPassword,
                  std::function<void(const QByteArray &)> eachLine)
{
    QDir().mkpath(m_folder);
    auto *process = new QProcess(this);
    m_process = process;
    process->setWorkingDirectory(m_folder);
    process->setProcessChannelMode(QProcess::MergedChannels);

    auto output = std::make_shared<QByteArray>();
    auto log = std::make_shared<QFile>(m_folder + "/update.log");
    log->open(QIODevice::Append);
    log->write("\n$ " + program.toUtf8() + " " + arguments.join(' ').toUtf8() + "\n");

    connect(process, &QProcess::readyRead, this, [process, output, log, eachLine] {
        while (process->canReadLine()) {
            const QByteArray line = process->readLine();
            output->append(line);
            log->write(line);
            if (eachLine)
                eachLine(line);
        }
    });
    auto finished = std::make_shared<bool>(false);
    auto end = [this, process, output, log, done, finished](int code) {
        if (*finished)
            return;
        *finished = true;
        const QByteArray rest = process->readAll();
        output->append(rest);
        log->write(rest);
        log->close();
        if (m_process == process)
            m_process = nullptr;
        process->deleteLater();
        done(code, *output);
    };
    connect(process, &QProcess::finished, this, [end](int code, QProcess::ExitStatus status) {
        end(status == QProcess::NormalExit ? code : -1);
    });
    connect(process, &QProcess::errorOccurred, this, [end, output, program](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            output->append(program.toUtf8() + " isn't installed");
            end(-1);
        }
    });

    process->start(program, arguments);
    if (withPassword) {
        // sudo -S reads it from here: never on the command line, never on
        // disk. -k makes sudo always read it, so none is left over for the
        // program sudo runs
        process->write(m_password.toUtf8() + '\n');
    }
    process->closeWriteChannel();
}

void Updater::checkPassword()
{
    setStep("Checking your password", 0.02);
    run("sudo", { "-S", "-k", "-p", "", "-v" }, [this](int code, const QByteArray &) {
        if (code != 0) {
            m_password.fill(QChar(0));
            m_password.clear();
            m_error = "That password didn't work. Try again.";
            setState("available");              // nothing has changed: try again
            return;
        }
        download();
    }, true);
}

void Updater::download()
{
    setStep("Downloading", 0.05);

    // The newest PKGBUILD and its install script, from main
    auto files = std::make_shared<QStringList>(QStringList { "PKGBUILD", "redash360.install" });
    auto next = std::make_shared<std::function<void()>>();
    *next = [this, files, next] {
        if (files->isEmpty()) {
            getNeeds();
            return;
        }
        const QString name = files->takeFirst();
        QNetworkRequest request(QUrl(QString("%1/%2/main/%3/%4").arg(m_raw, m_repo, PackageFolder, name)));
        request.setHeader(QNetworkRequest::UserAgentHeader, "ReDash360");
        request.setTransferTimeout(30000);
        QNetworkReply *reply = m_network->get(request);
        connect(reply, &QNetworkReply::finished, this, [this, reply, name, next] {
            reply->deleteLater();
            QFile file(m_folder + "/" + name);
            if (reply->error() != QNetworkReply::NoError || !file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                fail("Couldn't download the update. Check the internet connection, then try again.");
                return;
            }
            file.write(reply->readAll());
            file.close();
            (*next)();
        });
    };
    QDir().mkpath(m_folder);
    (*next)();
}

QStringList Updater::readNeeds(const QByteArray &srcinfo)
{
    // pkgbase = redash360-git
    //     depends = qt6-base
    //     makedepends = cmake
    QStringList needs;
    for (const QString &line : QString::fromUtf8(srcinfo).split('\n')) {
        const QString trimmed = line.trimmed();
        for (const QString key : { QStringLiteral("depends = "), QStringLiteral("makedepends = ") }) {
            if (trimmed.startsWith(key)) {
                const QString need = trimmed.mid(key.size()).trimmed();
                if (!need.isEmpty() && !needs.contains(need))
                    needs << need;
            }
        }
    }
    return needs;
}

void Updater::getNeeds()
{
    // A newer ReDash360 can need something more: install what's missing first
    setStep("Getting ready", 0.08);
    run("makepkg", { "--printsrcinfo" }, [this](int code, const QByteArray &srcinfo) {
        if (code != 0) {
            fail("makepkg couldn't read the update: " + lastLine(srcinfo));
            return;
        }
        // pacman -T lists the ones that aren't installed
        run("pacman", QStringList { "-T" } + readNeeds(srcinfo), [this](int code, const QByteArray &listed) {
            QStringList missing;
            static const QRegularExpression version("[<>=].*$");
            for (const QString &line : QString::fromUtf8(listed).split('\n', Qt::SkipEmptyParts))
                missing << line.trimmed().remove(version);
            missing.removeAll(QString());
            if (code == 0 || missing.isEmpty()) {
                build();
                return;
            }
            setStep("Getting what it needs", 0.1);
            run("sudo", QStringList { "-S", "-k", "-p", "", "pacman", "-S", "--needed", "--noconfirm", "--asdeps" } + missing,
                [this](int code, const QByteArray &output) {
                    if (code != 0) {
                        fail("Couldn't install what the update needs: " + lastLine(output));
                        return;
                    }
                    build();
                }, true);
        });
    });
}

void Updater::build()
{
    setStep("Downloading", 0.12);
    // makepkg gets the code from GitHub, then builds it; ninja counts the
    // steps as it goes ("[57/143] Building ..."), which is the progress bar
    run("makepkg", { "-f", "--noconfirm", "--nocheck" }, [this](int code, const QByteArray &output) {
        if (code != 0) {
            fail("Building the update didn't work: " + lastLine(output));
            return;
        }
        installPackage();
    }, false, [this](const QByteArray &line) {
            static const QRegularExpression ninja("^\\[(\\d+)/(\\d+)\\]");
            const QRegularExpressionMatch step = ninja.match(QString::fromUtf8(line));
            if (step.hasMatch() && step.captured(2).toDouble() > 0)
                setStep("Building", 0.15 + 0.75 * step.captured(1).toDouble() / step.captured(2).toDouble());
            else if (line.contains("Starting build()"))
                setStep("Building", 0.15);
        });
}

void Updater::installPackage()
{
    setStep("Installing", 0.92);
    run("makepkg", { "--packagelist" }, [this](int, const QByteArray &list) {
        // The package it built (not its -debug package)
        QString package;
        for (const QString &line : QString::fromUtf8(list).split('\n', Qt::SkipEmptyParts)) {
            const QString path = line.trimmed();
            if (!path.contains("-debug-") && QFile::exists(path)) {
                package = path;
                break;
            }
        }
        if (package.isEmpty()) {
            fail("The update was built, but its package wasn't there to install.");
            return;
        }
        run("sudo", { "-S", "-k", "-p", "", "pacman", "-U", "--noconfirm", package }, [this](int code, const QByteArray &output) {
            if (code != 0) {
                fail("Installing the update didn't work: " + lastLine(output));
                return;
            }
            finishInstall();
        }, true);
    });
}

void Updater::restart()
{
    // In the ReDash360 sessions systemd runs the dashboard: it starts the new
    // one. Otherwise the new one replaces this one (--replace).
    if (qEnvironmentVariableIsSet("INVOCATION_ID"))
        QProcess::startDetached("systemctl", { "--user", "restart", "redash360.service" });
    else
        QProcess::startDetached(QCoreApplication::applicationFilePath(), { "--replace" });
}