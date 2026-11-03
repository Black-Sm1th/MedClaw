#pragma once

#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

/**
 * 文件树的目录读取服务。
 *
 * 页面（web/file-tree.html）在 QWebEngine 里拿不到"操作系统拖进来的文件夹"的
 * 真实路径与目录结构（webkitGetAsEntry 对 OS 拖拽返回 null，只能退化成
 * dataTransfer.files 一次性枚举整棵树），所以目录枚举改由宿主完成：
 * 页面按需请求某一层的第 N 段，宿主返回这一段的条目，从而实现逐层、分块加载。
 */
class FileTreeProvider : public QObject
{
    Q_OBJECT

public:
    explicit FileTreeProvider(QObject *parent = nullptr);

    /// 列一层目录。offset/limit 用于分块（limit<=0 表示取到底）。
    Q_INVOKABLE QVariantMap list(const QString &dirPath, int offset, int limit);

    /// 只取路径元信息（根节点名称等）。
    Q_INVOKABLE QVariantMap describe(const QString &path);

    /// 批量 describe：拖入多个文件/文件夹时一次问清楚，避免 N 次往返。
    Q_INVOKABLE QVariantList describeAll(const QStringList &paths);

    /// 读一小段文本（预览用）。超过 maxBytes 直接拒绝，避免把大文件塞进 WebEngine。
    Q_INVOKABLE QVariantMap readText(const QString &path, int maxBytes);

    /// 清空已缓存的分层结果。
    Q_INVOKABLE void reset();

private:
    static QString normalize(const QString &path);

    QHash<QString, QVector<QVariantMap>> m_cache;
};
