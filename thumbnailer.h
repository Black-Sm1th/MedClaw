#pragma once

#include <QImage>
#include <QObject>
#include <QString>
#include <QThreadPool>

/**
 * 缩略图生成器。
 *
 * - 图片（png/jpg/bmp/webp）：直接按目标尺寸解码；
 * - 体数据（.nii / .nii.gz / .mgz / .mgh）：解压取中间层，做 1%–99% 窗宽映射；
 * - DICOM：单文件解码；目录里是一整个序列时，只取中间那一张。
 *
 * 全部在后台线程完成（QtConcurrent），结果写磁盘缓存，页面按需索取。
 */
class Thumbnailer : public QObject
{
    Q_OBJECT

public:
    explicit Thumbnailer(QObject *parent = nullptr);

    /// 异步生成缩略图。requestId 由调用方生成，用于把结果对回去。
    Q_INVOKABLE void request(const QString &requestId, const QString &path);

    /// 清空磁盘缓存（诊断用）。
    Q_INVOKABLE void clearCache();

signals:
    void ready(const QString &requestId, const QString &path,
               const QString &dataUrl, int width, int height);
    void failed(const QString &requestId, const QString &path, const QString &reason);

private:
    struct Result
    {
        QString dataUrl;
        int width = 0;
        int height = 0;
        QString error;
    };

    static Result build(const QString &path, int maxEdge);
    static QString cacheDir();

    // 体数据解压单次可能占几百 MB，限制并发数
    QThreadPool m_pool;
};
