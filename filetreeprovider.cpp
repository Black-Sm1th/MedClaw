#include "filetreeprovider.h"

#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QUrl>
#include <QFileInfo>
#include <QVector>

FileTreeProvider::FileTreeProvider(QObject *parent)
    : QObject(parent)
{
}

/// 清空缓存：换根目录或需要刷新时调用。
void FileTreeProvider::reset()
{
    m_cache.clear();
}

QString FileTreeProvider::normalize(const QString &path)
{
    if (path.isEmpty())
        return {};
    // 拖拽/目录选择器（以及 QML 的 url 属性）给过来的可能是 file:///C:/dir
    // 这种 URL，这里统一还原成本地路径，否则 QFileInfo 一律判成不存在。
    QString source = path;
    if (source.startsWith(QStringLiteral("file:"), Qt::CaseInsensitive)) {
        const QString local = QUrl(source).toLocalFile();
        if (!local.isEmpty())
            source = local;
    }
    QString cleaned = QDir::cleanPath(source);
    // QDir::cleanPath("C:/") 会得到 "C:"，那是"该驱动器当前目录"的语义，
    // QFileInfo 常常判成不存在；盘符根要补回分隔符。
    static const QRegularExpression driveRoot(QStringLiteral("^[A-Za-z]:$"));
    if (driveRoot.match(cleaned).hasMatch())
        cleaned += QLatin1Char('/');
    // Windows 路径大小写不敏感，缓存键统一小写，避免同一目录列两次
    return cleaned;
}

QVariantMap FileTreeProvider::list(const QString &dirPath, int offset, int limit)
{
    QVariantMap result;
    const QString key = normalize(dirPath);
    if (key.isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("空路径"));
        return result;
    }

    auto it = m_cache.find(key);
    if (it == m_cache.end()) {
        const QFileInfo info(key);
        if (!info.exists() || !info.isDir()) {
            result.insert(QStringLiteral("error"),
                          QStringLiteral("目录不存在：%1").arg(key));
            return result;
        }
        // DirsFirst 让目录排在前面；IgnoreCase 贴近资源管理器的直观顺序
        const QFileInfoList files = QDir(key).entryInfoList(
            QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden,
            QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);

        QVector<QVariantMap> listing;
        listing.reserve(files.size());
        for (const QFileInfo &file : files) {
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), file.fileName());
            entry.insert(QStringLiteral("path"), file.absoluteFilePath());
            entry.insert(QStringLiteral("isDir"), file.isDir());
            entry.insert(QStringLiteral("size"),
                         file.isDir() ? qint64(0) : file.size());
            listing.append(entry);
        }
        it = m_cache.insert(key, listing);
    }

    const QVector<QVariantMap> &listing = it.value();
    const int total = listing.size();
    const int start = qBound(0, offset, total);
    const int count = limit <= 0 ? total - start : qBound(0, limit, total - start);

    QVariantList slice;
    slice.reserve(count);
    for (int i = start; i < start + count; ++i)
        slice.append(listing.at(i));

    result.insert(QStringLiteral("total"), total);
    result.insert(QStringLiteral("offset"), start);
    result.insert(QStringLiteral("entries"), slice);
    return result;
}

QVariantMap FileTreeProvider::readText(const QString &path, int maxBytes)
{
    QVariantMap result;
    const QFileInfo info(normalize(path));
    if (!info.exists() || !info.isFile()) {
        result.insert(QStringLiteral("error"), QStringLiteral("文件不存在"));
        return result;
    }
    if (maxBytes > 0 && info.size() > maxBytes) {
        result.insert(QStringLiteral("error"), QStringLiteral("文件过大"));
        result.insert(QStringLiteral("size"), info.size());
        return result;
    }
    QFile file(info.absoluteFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        result.insert(QStringLiteral("error"), QStringLiteral("无法打开文件"));
        return result;
    }
    const QByteArray data = file.readAll();
    // 二进制文件（体数据、压缩包等）直接拒掉，否则会在预览区显示一堆乱码
    const QByteArray head = data.left(4096);
    const QByteArray nul(1, char(0));   // gzip 头：1F 8B
    if (head.contains(nul) || head.startsWith(QByteArrayLiteral("\x1f\x8b"))) {
        result.insert(QStringLiteral("error"), QStringLiteral("二进制文件，不支持文本预览"));
        result.insert(QStringLiteral("size"), info.size());
        return result;
    }
    result.insert(QStringLiteral("text"), QString::fromUtf8(data));
    result.insert(QStringLiteral("size"), info.size());
    return result;
}

QVariantList FileTreeProvider::describeAll(const QStringList &paths)
{
    QVariantList list;
    list.reserve(paths.size());
    for (const QString &path : paths) {
        const QFileInfo info(normalize(path));
        if (!info.exists())
            continue;
        QVariantMap item;
        item.insert(QStringLiteral("name"),
                    info.fileName().isEmpty() ? info.absoluteFilePath() : info.fileName());
        item.insert(QStringLiteral("path"), info.absoluteFilePath());
        item.insert(QStringLiteral("isDir"), info.isDir());
        item.insert(QStringLiteral("size"), info.isDir() ? qint64(0) : info.size());
        list.append(item);
    }
    return list;
}

/// 只返回元信息，不列目录：给页面显示根节点名称用。
QVariantMap FileTreeProvider::describe(const QString &path)
{
    QVariantMap result;
    const QFileInfo info(normalize(path));
    if (!info.exists()) {
        result.insert(QStringLiteral("error"), QStringLiteral("路径不存在"));
        return result;
    }
    result.insert(QStringLiteral("name"), info.fileName().isEmpty()
                      ? info.absoluteFilePath() : info.fileName());
    result.insert(QStringLiteral("path"), info.absoluteFilePath());
    result.insert(QStringLiteral("isDir"), info.isDir());
    return result;
}
