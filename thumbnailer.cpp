#include "thumbnailer.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDir>
#include <QElapsedTimer>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QStandardPaths>
#include <QtConcurrent/QtConcurrent>
#include <QtEndian>
#include <QtZlib/zlib.h>   // Qt 自带 zlib；zconf.h 里的 Z_PREFIX 已把符号映射到 Qt6Core 导出的 z_*

#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace {

constexpr int kMaxEdge = 128;               // 缩略图最长边
constexpr qint64 kMaxInflate = 1024LL * 1024 * 1024;  // 解压上限 1GB，防内存爆炸

// ─────────────────────────────────────────────────────────────
// gzip
// ─────────────────────────────────────────────────────────────
QByteArray inflateRaw(const QByteArray &input, qint64 hintSize, QString *error)
{
    QByteArray output;
    output.resize(int(qBound<qint64>(hintSize, 64 * 1024, kMaxInflate)));

    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) {
        if (error) *error = QStringLiteral("zlib 初始化失败");
        return {};
    }

    stream.next_in = reinterpret_cast<Bytef *>(const_cast<char *>(input.constData()));
    stream.avail_in = uInt(input.size());

    int code = Z_OK;
    qint64 written = 0;
    while (code != Z_STREAM_END) {
        if (written >= kMaxInflate) {
            inflateEnd(&stream);
            if (error) *error = QStringLiteral("解压后超过 1GB，放弃");
            return {};
        }
        if (written == output.size())
            output.resize(output.size() * 2);
        stream.next_out = reinterpret_cast<Bytef *>(output.data() + written);
        stream.avail_out = uInt(output.size() - written);
        code = inflate(&stream, Z_NO_FLUSH);
        written = qint64(stream.total_out);
        if (code != Z_OK && code != Z_STREAM_END && code != Z_BUF_ERROR) {
            inflateEnd(&stream);
            if (error) *error = QStringLiteral("解压失败（数据可能损坏）");
            return {};
        }
        if (code == Z_BUF_ERROR && stream.avail_out != 0)
            break;   // 输入已经取完，没有更多输出
    }
    inflateEnd(&stream);
    output.resize(int(written));
    return output;
}

/** 读取文件；.gz/.mgz/.mgh 会先解压。limitBytes 用于预先分配。 */
QByteArray readVolumeBytes(const QString &path, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = QStringLiteral("无法打开文件");
        return {};
    }
    const QByteArray raw = file.readAll();
    file.close();

    const bool gz = raw.size() > 2
            && quint8(raw.at(0)) == 0x1f && quint8(raw.at(1)) == 0x8b;
    if (!gz)
        return raw;

    // 跳过 gzip 头（含可选的 FEXTRA / FNAME / FCOMMENT / FHCRC）
    int offset = 10;
    const quint8 flags = raw.size() > 3 ? quint8(raw.at(3)) : 0;
    if (flags & 0x04) {
        if (offset + 2 > raw.size()) { if (error) *error = QStringLiteral("gzip 头损坏"); return {}; }
        const int extra = quint8(raw.at(offset)) | (quint8(raw.at(offset + 1)) << 8);
        offset += 2 + extra;
    }
    if (flags & 0x08) { while (offset < raw.size() && raw.at(offset) != '\0') ++offset; ++offset; }
    if (flags & 0x10) { while (offset < raw.size() && raw.at(offset) != '\0') ++offset; ++offset; }
    if (flags & 0x02) offset += 2;
    if (offset <= 0 || offset >= raw.size()) {
        if (error) *error = QStringLiteral("gzip 头损坏");
        return {};
    }

    // gzip 尾部 ISIZE 是解压后大小（低 32 位），用它预分配
    qint64 hint = 64LL * 1024 * 1024;
    if (raw.size() >= 4) {
        const quint32 isize = qFromLittleEndian<quint32>(
            reinterpret_cast<const uchar *>(raw.constData() + raw.size() - 4));
        if (isize > 0)
            hint = qint64(isize);
    }

    return inflateRaw(raw.mid(offset, raw.size() - offset - 8), hint, error);
}

// ─────────────────────────────────────────────────────────────
// 灰度切片 → QImage
// ─────────────────────────────────────────────────────────────
template <typename T>
QImage sliceToImage(const T *data, int width, int height, qint64 strideSamples,
                    double slope, double intercept)
{
    const qint64 count = qint64(width) * height;
    if (count <= 0 || !data)
        return {};

    // 1%–99% 分位做窗宽窗位，比 min/max 稳健（避免个别极值把整体压暗）
    std::vector<double> samples;
    const qint64 step = qMax<qint64>(1, count / 200000);
    samples.reserve(size_t(count / step) + 1);
    for (qint64 i = 0; i < count; i += step) {
        const qint64 index = (i / width) * strideSamples + (i % width);
        samples.push_back(double(data[index]) * slope + intercept);
    }
    if (samples.empty())
        return {};
    std::sort(samples.begin(), samples.end());
    const double low = samples[size_t(samples.size() * 0.01)];
    double high = samples[size_t(samples.size() * 0.99)];
    if (!std::isfinite(low) || !std::isfinite(high) || high - low < 1e-6)
        high = low + 1.0;

    QImage image(width, height, QImage::Format_Grayscale8);
    const double scale = 255.0 / (high - low);
    for (int y = 0; y < height; ++y) {
        uchar *line = image.scanLine(y);
        const qint64 rowBase = qint64(y) * strideSamples;
        for (int x = 0; x < width; ++x) {
            double value = double(data[rowBase + x]) * slope + intercept;
            int level = int((value - low) * scale);
            line[x] = uchar(qBound(0, level, 255));
        }
    }
    return image;
}


/** 按内容外接框裁剪：体数据四周常有大片背景，不裁的话 28px 缩略图基本是黑的。 */
QImage cropToContent(const QImage &source)
{
    if (source.isNull())
        return source;
    const int width = source.width();
    const int height = source.height();
    int left = width, top = height, right = -1, bottom = -1;
    for (int y = 0; y < height; ++y) {
        const uchar *line = source.constScanLine(y);
        for (int x = 0; x < width; ++x) {
            if (line[x] > 12) {
                left = qMin(left, x);
                right = qMax(right, x);
                top = qMin(top, y);
                bottom = qMax(bottom, y);
            }
        }
    }
    if (right < 0 || bottom < 0)
        return source;
    const int margin = qMax(2, qMin(width, height) / 40);
    left = qMax(0, left - margin);
    top = qMax(0, top - margin);
    right = qMin(width - 1, right + margin);
    bottom = qMin(height - 1, bottom + margin);
    // 内容本来就占满时不必裁
    if (right - left + 1 >= width * 0.98 && bottom - top + 1 >= height * 0.98)
        return source;
    return source.copy(left, top, right - left + 1, bottom - top + 1);
}

struct VolumeSlice
{
    QImage image;
    QString error;
};

/** NIfTI-1：取 z 轴中间层 */
VolumeSlice sliceFromNifti(const QByteArray &bytes)
{
    VolumeSlice out;
    if (bytes.size() < 352) {
        out.error = QStringLiteral("NIfTI 文件过小");
        return out;
    }
    const uchar *base = reinterpret_cast<const uchar *>(bytes.constData());
    const qint16 dimX = qFromLittleEndian<qint16>(base + 42);
    const qint16 dimY = qFromLittleEndian<qint16>(base + 44);
    const qint16 dimZ = qFromLittleEndian<qint16>(base + 46);
    const qint16 datatype = qFromLittleEndian<qint16>(base + 70);
    const float slope = qFromLittleEndian<float>(base + 112);
    const float intercept = qFromLittleEndian<float>(base + 116);
    qint64 voxOffset = qint64(qFromLittleEndian<float>(base + 108));
    if (voxOffset <= 0)
        voxOffset = 352;

    int bytesPerVoxel = 0;
    switch (datatype) {
    case 2: bytesPerVoxel = 1; break;      // uint8
    case 4: bytesPerVoxel = 2; break;      // int16
    case 8: bytesPerVoxel = 4; break;      // int32
    case 16: bytesPerVoxel = 4; break;     // float32
    case 64: bytesPerVoxel = 8; break;     // float64
    case 256: bytesPerVoxel = 1; break;    // int8
    case 512: bytesPerVoxel = 2; break;    // uint16
    default:
        out.error = QStringLiteral("不支持的 NIfTI 数据类型 %1").arg(datatype);
        return out;
    }
    if (dimX <= 0 || dimY <= 0 || dimZ <= 0) {
        out.error = QStringLiteral("NIfTI 维度无效");
        return out;
    }

    const qint64 sliceBytes = qint64(dimX) * dimY * bytesPerVoxel;
    const qint64 z = dimZ / 2;
    const qint64 offset = voxOffset + z * sliceBytes;
    if (offset + sliceBytes > bytes.size()) {
        out.error = QStringLiteral("NIfTI 数据不完整");
        return out;
    }

    const uchar *slice = base + offset;
    const double s = (std::isfinite(slope) && slope != 0) ? slope : 1.0;
    const double b = std::isfinite(intercept) ? intercept : 0.0;
    const qint64 n = qint64(dimX) * dimY;

    switch (datatype) {
    case 2:
        out.image = sliceToImage(reinterpret_cast<const uchar *>(slice), dimX, dimY, dimX, s, b);
        break;
    case 256:
        out.image = sliceToImage(reinterpret_cast<const qint8 *>(slice), dimX, dimY, dimX, s, b);
        break;
    case 4:
        out.image = sliceToImage(reinterpret_cast<const qint16 *>(slice), dimX, dimY, dimX, s, b);
        break;
    case 512:
        out.image = sliceToImage(reinterpret_cast<const quint16 *>(slice), dimX, dimY, dimX, s, b);
        break;
    case 8:
        out.image = sliceToImage(reinterpret_cast<const qint32 *>(slice), dimX, dimY, dimX, s, b);
        break;
    case 16:
        out.image = sliceToImage(reinterpret_cast<const float *>(slice), dimX, dimY, dimX, s, b);
        break;
    case 64:
        out.image = sliceToImage(reinterpret_cast<const double *>(slice), dimX, dimY, dimX, s, b);
        break;
    }
    Q_UNUSED(n)
    return out;
}

/** FreeSurfer MGH/MGZ：284 字节大端头，取 z 轴中间层 */
VolumeSlice sliceFromMgh(const QByteArray &bytes)
{
    VolumeSlice out;
    if (bytes.size() < 284) {
        out.error = QStringLiteral("MGH 文件过小");
        return out;
    }
    const uchar *base = reinterpret_cast<const uchar *>(bytes.constData());
    const qint32 dimX = qFromBigEndian<qint32>(base + 4);
    const qint32 dimY = qFromBigEndian<qint32>(base + 8);
    const qint32 dimZ = qFromBigEndian<qint32>(base + 12);
    const qint32 type = qFromBigEndian<qint32>(base + 20);

    int bytesPerVoxel = 0;
    switch (type) {
    case 0: bytesPerVoxel = 1; break;   // MRI_UCHAR
    case 1: bytesPerVoxel = 4; break;   // MRI_INT
    case 3: bytesPerVoxel = 4; break;   // MRI_FLOAT
    case 4: bytesPerVoxel = 2; break;   // MRI_SHORT
    default:
        out.error = QStringLiteral("不支持的 MGH 类型 %1").arg(type);
        return out;
    }
    if (dimX <= 0 || dimY <= 0 || dimZ <= 0) {
        out.error = QStringLiteral("MGH 维度无效");
        return out;
    }

    const qint64 sliceBytes = qint64(dimX) * dimY * bytesPerVoxel;
    const qint64 offset = 284 + (dimZ / 2) * sliceBytes;
    if (offset + sliceBytes > bytes.size()) {
        out.error = QStringLiteral("MGH 数据不完整");
        return out;
    }
    const uchar *slice = base + offset;

    // MGH 是大端
    switch (type) {
    case 0:
        out.image = sliceToImage(reinterpret_cast<const uchar *>(slice), dimX, dimY, dimX, 1, 0);
        break;
    case 4: {
        QByteArray swapped(sliceBytes, Qt::Uninitialized);
        for (qint64 i = 0; i < sliceBytes / 2; ++i) {
            const quint16 v = qFromBigEndian<quint16>(slice + i * 2);
            swapped[i * 2] = char(v & 0xff);
            swapped[i * 2 + 1] = char(v >> 8);
        }
        out.image = sliceToImage(reinterpret_cast<const qint16 *>(swapped.constData()),
                                 dimX, dimY, dimX, 1, 0);
        break;
    }
    case 3: {
        std::vector<float> values(size_t(dimX) * dimY);
        for (qint64 i = 0; i < qint64(dimX) * dimY; ++i) {
            quint32 bits = qFromBigEndian<quint32>(slice + i * 4);
            float f;
            memcpy(&f, &bits, sizeof(f));
            values[size_t(i)] = f;
        }
        out.image = sliceToImage(values.data(), dimX, dimY, dimX, 1, 0);
        break;
    }
    case 1: {
        std::vector<qint32> values(size_t(dimX) * dimY);
        for (qint64 i = 0; i < qint64(dimX) * dimY; ++i)
            values[size_t(i)] = qint32(qFromBigEndian<quint32>(slice + i * 4));
        out.image = sliceToImage(values.data(), dimX, dimY, dimX, 1, 0);
        break;
    }
    }
    return out;
}

// ─────────────────────────────────────────────────────────────
// JPEG Lossless（SOF3 / Process 14 SV1，DICOM 1.2.840.10008.1.2.4.70）
// ------------------------------------------------------------
// 医院的 MRI/CT 常见这种压缩，Qt 的 JPEG 插件只支持 baseline/progressive，
// 解不了 SOF3，所以这里自己实现：Huffman 熵解码 + 预测器（Ss 选 1..7）。
// ─────────────────────────────────────────────────────────────
struct HuffmanTable
{
    int minCode[17] = {0};
    int maxCode[17] = {0};
    int valPtr[17] = {0};
    std::vector<uchar> values;
    bool valid = false;
};

class BitReader
{
public:
    BitReader(const uchar *data, qint64 size) : m_data(data), m_size(size) {}

    int readBit()
    {
        if (m_pos >= m_size)
            return 0;
        const int bit = (m_data[m_pos] >> (7 - m_bit)) & 1;
        if (++m_bit == 8) {
            m_bit = 0;
            // 填充判断要看「刚读完的这个字节」：0xFF 后面跟 0x00 表示转义，
            // 跟 D0-D7 表示重启标记，两者都不是数据。
            const uchar last = m_data[m_pos];
            ++m_pos;
            if (last == 0xff && m_pos < m_size) {
                const uchar next = m_data[m_pos];
                if (next == 0x00 || (next >= 0xd0 && next <= 0xd7))
                    ++m_pos;
            }
        }
        return bit;
    }

    int readBits(int count)
    {
        int value = 0;
        for (int i = 0; i < count; ++i)
            value = (value << 1) | readBit();
        return value;
    }

    /** JPEG 的「接收并扩展」：把 s 位无符号数还原成有符号差分 */
    int receiveExtend(int s)
    {
        if (s <= 0)
            return 0;
        const int value = readBits(s);
        if (value < (1 << (s - 1)))
            return value - ((1 << s) - 1);
        return value;
    }

private:
    const uchar *m_data;
    qint64 m_size;
    qint64 m_pos = 0;
    int m_bit = 0;
};

int decodeHuffman(BitReader &reader, const HuffmanTable &table)
{
    int code = 0;
    for (int length = 1; length <= 16; ++length) {
        code = (code << 1) | reader.readBit();
        if (table.maxCode[length] >= 0 && code <= table.maxCode[length]
                && code >= table.minCode[length]) {
            const int index = table.valPtr[length] + (code - table.minCode[length]);
            if (index >= 0 && index < int(table.values.size()))
                return table.values[size_t(index)];
            return 0;
        }
    }
    return 0;
}

void buildHuffman(const uchar *counts, const uchar *symbols, int symbolCount,
                  HuffmanTable *table)
{
    table->values.assign(symbols, symbols + symbolCount);
    int code = 0;
    int index = 0;
    for (int length = 1; length <= 16; ++length) {
        const int count = counts[length - 1];
        table->valPtr[length] = index;
        table->minCode[length] = code;
        code += count;
        index += count;
        table->maxCode[length] = count > 0 ? code - 1 : -1;
        code <<= 1;
    }
    table->valid = true;
}

struct JpegLosslessResult
{
    std::vector<qint16> samples;
    int width = 0;
    int height = 0;
    QString error;
};

JpegLosslessResult decodeJpegLossless(const QByteArray &data)
{
    JpegLosslessResult out;
    const uchar *base = reinterpret_cast<const uchar *>(data.constData());
    const qint64 size = data.size();
    if (size < 4 || base[0] != 0xff || base[1] != 0xd8) {
        out.error = QStringLiteral("不是 JPEG 流");
        return out;
    }

    HuffmanTable dcTables[4];
    int precision = 0;
    int frameWidth = 0;
    int frameHeight = 0;
    int componentCount = 0;
    bool sawSof3 = false;

    qint64 pos = 2;
    while (pos + 3 < size) {
        if (base[pos] != 0xff) {
            ++pos;
            continue;
        }
        const uchar marker = base[pos + 1];
        if (marker == 0xd8 || marker == 0xd9 || (marker >= 0xd0 && marker <= 0xd7)) {
            pos += 2;
            continue;
        }
        if (marker == 0xda) {
            const int length = (base[pos + 2] << 8) | base[pos + 3];
            const qint64 headerEnd = pos + 2 + length;
            if (headerEnd > size) {
                out.error = QStringLiteral("JPEG 头不完整");
                return out;
            }
            const uchar *sos = base + pos + 4;
            const int scanComponents = sos[0];
            const int dcTableId = scanComponents > 0 ? (sos[2] >> 4) : 0;
            const int predictor = sos[1 + scanComponents * 2];
            const int pointTransform = sos[1 + scanComponents * 2 + 2] & 0x0f;

            if (scanComponents < 1 || dcTableId >= 4 || !dcTables[dcTableId].valid) {
                out.error = QStringLiteral("JPEG 缺少 Huffman 表");
                return out;
            }
            const int width = frameWidth;
            const int height = frameHeight;
            const int components = componentCount;
            if (width <= 0 || height <= 0 || components <= 0) {
                out.error = QStringLiteral("JPEG 帧头无效");
                return out;
            }

            out.width = width;
            out.height = height;

            BitReader reader(base + headerEnd, size - headerEnd);
            std::vector<std::vector<int>> lines(size_t(components),
                                                std::vector<int>(size_t(width), 0));
            out.samples.resize(size_t(width) * size_t(height) * size_t(components));

            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width; ++x) {
                    for (int c = 0; c < components; ++c) {
                        const int category = decodeHuffman(reader, dcTables[dcTableId]);
                        const int diff = reader.receiveExtend(category);

                        std::vector<int> &line = lines[size_t(c)];
                        const int ra = x > 0 ? line[size_t(x - 1)] : 0;
                        const int rb = y > 0 ? line[size_t(x)] : 0;
                        const int rc = (x > 0 && y > 0) ? line[size_t(x - 1)] : 0;

                        int pred = 0;
                        if (x == 0 && y == 0)
                            pred = 1 << (precision - pointTransform - 1);
                        else if (y == 0)
                            pred = ra;
                        else if (x == 0)
                            pred = rb;
                        else {
                            switch (predictor) {
                            case 1: pred = ra; break;
                            case 2: pred = rb; break;
                            case 3: pred = rc; break;
                            case 4: pred = ra + rb - rc; break;
                            case 5: pred = ra + ((rb - rc) >> 1); break;
                            case 6: pred = rb + ((ra - rc) >> 1); break;
                            case 7: pred = (ra + rb) >> 1; break;
                            default: pred = ra; break;
                            }
                        }

                        const int mask = (1 << precision) - 1;
                        const int value = (pred + diff) & mask;
                        line[size_t(x)] = value;
                        out.samples[size_t((qint64(y) * width + x) * components + c)] =
                                qint16(value << pointTransform);
                    }
                }
            }

            if (components > 1) {
                std::vector<qint16> gray(size_t(width) * size_t(height));
                for (qint64 i = 0; i < qint64(width) * height; ++i)
                    gray[size_t(i)] = out.samples[size_t(i * components)];
                out.samples.swap(gray);
            }
            return out;
        }

        const int length = (base[pos + 2] << 8) | base[pos + 3];
        if (length < 2 || pos + 2 + length > size) {
            out.error = QStringLiteral("JPEG 段长度异常");
            return out;
        }
        const uchar *segment = base + pos + 4;
        if (marker == 0xc3) {          // SOF3：无损
            sawSof3 = true;
            precision = segment[0];
            frameHeight = (segment[1] << 8) | segment[2];
            frameWidth = (segment[3] << 8) | segment[4];
            componentCount = segment[5];
        } else if (marker == 0xc4) {   // DHT
            qint64 offset = 0;
            const qint64 segmentLength = length - 2;
            while (offset + 17 <= segmentLength) {
                const uchar tableClass = segment[offset] >> 4;
                const uchar tableId = segment[offset] & 0x0f;
                const uchar *counts = segment + offset + 1;
                int symbolCount = 0;
                for (int i = 0; i < 16; ++i)
                    symbolCount += counts[i];
                if (tableClass == 0 && tableId < 4 && symbolCount > 0
                        && offset + 17 + symbolCount <= segmentLength)
                    buildHuffman(counts, segment + offset + 17, symbolCount,
                                 &dcTables[tableId]);
                offset += 17 + symbolCount;
            }
        }
        pos += 2 + length;
    }

    out.error = sawSof3 ? QStringLiteral("JPEG 熵编码段缺失")
                        : QStringLiteral("不是 JPEG Lossless（无 SOF3）");
    return out;
}

// ─────────────────────────────────────────────────────────────
// DICOM
// ─────────────────────────────────────────────────────────────
struct DicomMeta
{
    int rows = 0;
    int columns = 0;
    int bitsAllocated = 0;
    int pixelRepresentation = 0;
    double slope = 1.0;
    double intercept = 0.0;
    qint64 pixelOffset = -1;
    qint64 pixelLength = 0;
    bool encapsulated = false;
    QString transferSyntax;
    bool ok = false;
};

quint16 readU16(const uchar *data, bool littleEndian)
{
    return littleEndian ? qFromLittleEndian<quint16>(data) : qFromBigEndian<quint16>(data);
}

quint32 readU32(const uchar *data, bool littleEndian)
{
    return littleEndian ? qFromLittleEndian<quint32>(data) : qFromBigEndian<quint32>(data);
}

QString readAscii(const uchar *data, qint64 length)
{
    return QString::fromLatin1(reinterpret_cast<const char *>(data), int(qMin<qint64>(length, 1024)))
            .remove(QChar('\0')).trimmed();
}


/** 跳过未定长序列：向后找 (FFFE,E0DD) 序列结束标记，返回其后的偏移 */
qint64 findSequenceDelimiter(const QByteArray &bytes, qint64 from, bool littleEndian)
{
    const uchar *base = reinterpret_cast<const uchar *>(bytes.constData());
    const qint64 size = bytes.size();
    for (qint64 i = from; i + 8 <= size; i += 2) {
        const quint16 group = readU16(base + i, littleEndian);
        const quint16 element = readU16(base + i + 2, littleEndian);
        if (group == 0xfffe && element == 0xe0dd)
            return i + 8;
    }
    return -1;
}

bool parseDicom(const QByteArray &bytes, DicomMeta *meta)
{
    if (bytes.size() < 132)
        return false;
    const uchar *base = reinterpret_cast<const uchar *>(bytes.constData());
    qint64 offset = 0;
    if (memcmp(base + 128, "DICM", 4) == 0)
        offset = 132;

    // 文件元信息组一定用 Explicit VR Little Endian
    bool explicitVr = true;
    bool littleEndian = true;
    qint64 guard = 0;
    while (offset + 8 <= bytes.size() && guard++ < 100000) {
        const quint16 group = readU16(base + offset, littleEndian);
        const quint16 element = readU16(base + offset + 2, littleEndian);
        const uchar *cursor = base + offset + 4;
        qint64 headerSize = 8;
        qint64 length = 0;
        QByteArray vr;

        if (explicitVr) {
            vr = QByteArray(reinterpret_cast<const char *>(cursor), 2);
            if (vr == "OB" || vr == "OW" || vr == "OF" || vr == "SQ" || vr == "UT"
                    || vr == "UN") {
                length = qint64(readU32(cursor + 4, littleEndian));
                headerSize = 12;
            } else {
                length = qint64(readU16(cursor + 2, littleEndian));
            }
        } else {
            length = qint64(readU32(cursor, littleEndian));
        }

        const qint64 valueOffset = offset + headerSize;
        if (length < 0)
            break;

        if (group == 0x0002 && element == 0x0010) {
            meta->transferSyntax = readAscii(base + valueOffset, length);
            // 1.2.840.10008.1.2 = Implicit VR LE；…1.2.1 = Explicit VR LE；
            // .2 = Explicit VR BE；1.2.4.* = 封装（JPEG 等）
            meta->encapsulated = meta->transferSyntax.startsWith(QStringLiteral("1.2.840.10008.1.2.4"));
            if (meta->transferSyntax == QStringLiteral("1.2.840.10008.1.2"))
                explicitVr = false;
            else if (meta->transferSyntax == QStringLiteral("1.2.840.10008.1.2.2")) {
                littleEndian = false;
                explicitVr = true;
            }
        } else if (group == 0x0028 && element == 0x0010) {
            meta->rows = int(readU16(base + valueOffset, littleEndian));
        } else if (group == 0x0028 && element == 0x0011) {
            meta->columns = int(readU16(base + valueOffset, littleEndian));
        } else if (group == 0x0028 && element == 0x0100) {
            meta->bitsAllocated = int(readU16(base + valueOffset, littleEndian));
        } else if (group == 0x0028 && element == 0x0103) {
            meta->pixelRepresentation = int(readU16(base + valueOffset, littleEndian));
        } else if (group == 0x0028 && element == 0x1052) {
            meta->intercept = readAscii(base + valueOffset, length).toDouble();
        } else if (group == 0x0028 && element == 0x1053) {
            meta->slope = readAscii(base + valueOffset, length).toDouble();
            if (qFuzzyIsNull(meta->slope))
                meta->slope = 1.0;
        } else if (group == 0x7fe0 && element == 0x0010) {
            meta->pixelOffset = valueOffset;
            meta->pixelLength = length;
            break;
        }

        if (length == 0xffffffffLL) {
            // 未定长序列（如 Procedure Code Sequence）：必须整体跳过，否则后面的
            // 标签全会被错位解析 —— 真实 MRI 数据里 (0008,1032) 就是这个情况。
            const qint64 delimiter = findSequenceDelimiter(bytes, valueOffset, littleEndian);
            if (delimiter < 0) {
                offset = bytes.size();
                break;
            }
            offset = delimiter;
            continue;
        }
        offset = valueOffset + length;
    }

    meta->ok = meta->rows > 0 && meta->columns > 0 && meta->pixelOffset >= 0;

    // 兜底：序列/私有标签千奇百怪，未必能一路走到 PixelData；
    // 直接按 little-endian 的 (7FE0,0010) 标签字节定位，封装数据一定是这个头。
    if (!meta->ok) {
        const int index = bytes.indexOf(QByteArray::fromHex("e07f1000"));
        if (index > 0 && index + 12 <= bytes.size()) {
            const QByteArray vr = bytes.mid(index + 4, 2);
            if (vr == QByteArrayLiteral("OB") || vr == QByteArrayLiteral("OW")
                    || vr == QByteArrayLiteral("UN")) {
                meta->pixelOffset = index + 12;
                meta->pixelLength = -1;
                meta->encapsulated = true;
                meta->ok = true;
                // 尺寸从 JPEG 的 SOF3 里拿，这里不用 DICOM 的 Rows/Columns
            }
        }
    }
    return meta->ok;
}

VolumeSlice sliceFromDicom(const QByteArray &bytes)
{
    VolumeSlice out;
    DicomMeta meta;
    if (!parseDicom(bytes, &meta)) {
        out.error = QStringLiteral("无法解析 DICOM 头");
        return out;
    }

    const uchar *base = reinterpret_cast<const uchar *>(bytes.constData());
    const qint64 pixelStart = meta.pixelOffset;

    if (meta.encapsulated) {
        // 封装格式：跳过 Basic Offset Table（(FFFE,E000) 项），把第一段交给 QImage
        qint64 cursor = pixelStart;
        if (cursor + 8 > bytes.size()) {
            out.error = QStringLiteral("DICOM 像素数据缺失");
            return out;
        }
        const quint32 botLength = readU32(base + cursor + 4, true);
        cursor += 8 + qint64(botLength);
        if (cursor + 8 > bytes.size()) {
            out.error = QStringLiteral("DICOM 像素数据缺失");
            return out;
        }
        const quint32 fragmentLength = readU32(base + cursor + 4, true);
        cursor += 8;
        if (fragmentLength == 0 || cursor + fragmentLength > bytes.size()) {
            out.error = QStringLiteral("DICOM 图像片段为空");
            return out;
        }
        const QByteArray fragment = bytes.mid(int(cursor), int(fragmentLength));
        // JPEG Lossless（Process 14 SV1）Qt 解不了，先自己解
        const JpegLosslessResult lossless = decodeJpegLossless(fragment);
        if (!lossless.samples.empty()) {
            out.image = sliceToImage(lossless.samples.data(), lossless.width,
                                     lossless.height, lossless.width,
                                     meta.slope, meta.intercept);
            return out;
        }

        QImage image;
        if (!image.loadFromData(fragment)) {
            out.error = QStringLiteral("压缩格式暂不支持（%1：%2）")
                    .arg(meta.transferSyntax, lossless.error);
            return out;
        }
        out.image = image;
        return out;
    }

    const qint64 expected = qint64(meta.rows) * meta.columns
            * ((meta.bitsAllocated == 16) ? 2 : 1);
    if (meta.pixelLength > 0 && meta.pixelLength < expected) {
        out.error = QStringLiteral("DICOM 像素数据不足");
        return out;
    }
    if (pixelStart + expected > bytes.size()) {
        out.error = QStringLiteral("DICOM 像素数据不足");
        return out;
    }

    const uchar *pixels = base + pixelStart;
    const bool little = meta.transferSyntax != QStringLiteral("1.2.840.10008.1.2.2");
    if (meta.bitsAllocated == 16) {
        std::vector<qint16> values(size_t(meta.rows) * meta.columns);
        const int stride = (bytes.size() - pixelStart) / (meta.rows * 2);
        Q_UNUSED(stride)
        for (int y = 0; y < meta.rows; ++y) {
            for (int x = 0; x < meta.columns; ++x) {
                const qint64 index = qint64(y) * meta.columns + x;
                const quint16 raw = readU16(pixels + index * 2, little);
                values[size_t(index)] = meta.pixelRepresentation
                        ? qint16(raw) : qint16(qMin<quint16>(raw, 32767));
            }
        }
        out.image = sliceToImage(values.data(), meta.columns, meta.rows, meta.columns,
                                 meta.slope, meta.intercept);
    } else {
        out.image = sliceToImage(pixels, meta.columns, meta.rows, meta.columns,
                                 meta.slope, meta.intercept);
    }
    return out;
}

// ─────────────────────────────────────────────────────────────
// 入口
// ─────────────────────────────────────────────────────────────
QImage loadScaledImage(const QString &path)
{
    QImageReader reader(path);
    reader.setAutoTransform(true);
    const QSize size = reader.size();
    if (size.isValid() && !size.isEmpty())
        reader.setScaledSize(size.scaled(kMaxEdge, kMaxEdge, Qt::KeepAspectRatio));
    return reader.read();
}

bool looksLikeDicom(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return false;
    file.seek(128);
    return file.read(4) == QByteArrayLiteral("DICM");
}

/** 目录里若是 DICOM 序列，取中间一张 */
QImage seriesThumbnail(const QString &dirPath, QString *error)
{
    QDir dir(dirPath);
    QStringList candidates;
    const QFileInfoList entries = dir.entryInfoList(
        QDir::Files | QDir::NoDotAndDotDot, QDir::Name);
    for (const QFileInfo &info : entries) {
        const QString suffix = info.suffix().toLower();
        if (suffix == QStringLiteral("dcm") || suffix == QStringLiteral("ima")
                || suffix == QStringLiteral("dicom")) {
            candidates.append(info.absoluteFilePath());
            if (candidates.size() >= 3000)
                break;
        }
    }
    if (candidates.isEmpty()) {
        if (error) *error = QStringLiteral("目录里没有 DICOM");
        return {};
    }
    candidates.sort(Qt::CaseInsensitive);
    const QString middle = candidates.at(candidates.size() / 2);
    QFile file(middle);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = QStringLiteral("无法打开 %1").arg(middle);
        return {};
    }
    const VolumeSlice slice = sliceFromDicom(file.read(64LL * 1024 * 1024));
    if (slice.image.isNull() && error)
        *error = slice.error;
    return slice.image;
}

}  // namespace

Thumbnailer::Thumbnailer(QObject *parent)
    : QObject(parent)
{
    m_pool.setMaxThreadCount(2);
    m_pool.setExpiryTimeout(30000);
}

QString Thumbnailer::cacheDir()
{
    const QString root = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    const QString dir = QDir(root).absoluteFilePath(QStringLiteral("AetherStudy/thumbs"));
    QDir().mkpath(dir);
    return dir;
}

void Thumbnailer::clearCache()
{
    QDir dir(cacheDir());
    for (const QString &name : dir.entryList({QStringLiteral("*.png")}, QDir::Files))
        dir.remove(name);
}

void Thumbnailer::request(const QString &requestId, const QString &path)
{
    auto *watcher = new QFutureWatcher<Result>(this);
    connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher, requestId, path]() {
        const Result result = watcher->result();
        watcher->deleteLater();
        if (!result.error.isEmpty())
            qWarning().noquote() << "[Thumb] 失败：" << result.error << path;
        if (result.error.isEmpty())
            emit ready(requestId, path, result.dataUrl, result.width, result.height);
        else
            emit failed(requestId, path, result.error);
    });
    watcher->setFuture(QtConcurrent::run(&m_pool, [path]() { return Thumbnailer::build(path, kMaxEdge); }));
}

Thumbnailer::Result Thumbnailer::build(const QString &path, int maxEdge)
{
    QElapsedTimer timer;
    timer.start();
    Result result;
    const QFileInfo info(path);
    if (!info.exists()) {
        result.error = QStringLiteral("路径不存在");
        return result;
    }

    // 缓存：路径 + 修改时间 + 大小（目录用条目数）决定文件名
    QString stamp = info.absoluteFilePath();
    if (info.isDir()) {
        stamp += QStringLiteral("|dir|%1|%2")
                .arg(info.lastModified().toMSecsSinceEpoch())
                .arg(QDir(info.absoluteFilePath()).entryList(QDir::Files).size());
    } else {
        stamp += QStringLiteral("|%1|%2")
                .arg(info.size())
                .arg(info.lastModified().toMSecsSinceEpoch());
    }
    stamp += QStringLiteral("|%1").arg(maxEdge);
    const QString key = QString::fromLatin1(
        QCryptographicHash::hash(stamp.toUtf8(), QCryptographicHash::Sha1).toHex());
    const QString cachePath = QDir(cacheDir()).absoluteFilePath(key + QStringLiteral(".png"));

    QImage image;
    if (QFileInfo::exists(cachePath)) {
        image = QImage(cachePath);
    }

    if (image.isNull()) {
        const QString suffix = info.isDir() ? QString() : info.suffix().toLower();
        if (info.isDir()) {
            image = seriesThumbnail(info.absoluteFilePath(), &result.error);
        } else if (suffix == QStringLiteral("dcm") || suffix == QStringLiteral("ima")) {
            QFile file(info.absoluteFilePath());
            if (!file.open(QIODevice::ReadOnly)) {
                result.error = QStringLiteral("无法打开文件");
                return result;
            }
            const VolumeSlice slice = sliceFromDicom(file.read(64LL * 1024 * 1024));
            image = slice.image;
            if (image.isNull())
                result.error = slice.error;
        } else if (suffix == QStringLiteral("nii") || suffix == QStringLiteral("gz")
                   || suffix == QStringLiteral("mgz") || suffix == QStringLiteral("mgh")) {
            const QByteArray bytes = readVolumeBytes(info.absoluteFilePath(), &result.error);
            if (bytes.isEmpty()) {
                if (result.error.isEmpty())
                    result.error = QStringLiteral("读取失败");
                return result;
            }
            VolumeSlice slice;
            if (suffix == QStringLiteral("mgz") || suffix == QStringLiteral("mgh"))
                slice = sliceFromMgh(bytes);
            else
                slice = sliceFromNifti(bytes);
            image = slice.image;
            if (image.isNull())
                result.error = slice.error.isEmpty()
                        ? QStringLiteral("无法识别为 NIfTI/MGH") : slice.error;
        } else {
            image = loadScaledImage(info.absoluteFilePath());
            if (image.isNull())
                result.error = QStringLiteral("不支持的格式");
        }

        if (image.isNull()) {
            if (result.error.isEmpty())
                result.error = QStringLiteral("无法生成缩略图");
            return result;
        }

        if (info.isDir() || suffix == QStringLiteral("dcm") || suffix == QStringLiteral("ima")
                || suffix == QStringLiteral("nii") || suffix == QStringLiteral("gz")
                || suffix == QStringLiteral("mgz") || suffix == QStringLiteral("mgh"))
            image = cropToContent(image);

        if (image.width() > maxEdge || image.height() > maxEdge)
            image = image.scaled(maxEdge, maxEdge, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        image.save(cachePath, "PNG");
    }

    if (image.isNull()) {
        result.error = QStringLiteral("无法生成缩略图");
        return result;
    }

    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    image.save(&buffer, "PNG");
    result.dataUrl = QStringLiteral("data:image/png;base64,")
            + QString::fromLatin1(png.toBase64());
    result.width = image.width();
    result.height = image.height();
    qInfo().noquote() << QStringLiteral("[Thumb] %1 ms  %2x%3  %4")
                             .arg(timer.elapsed(), 5)
                             .arg(image.width())
                             .arg(image.height())
                             .arg(QFileInfo(path).fileName());
    return result;
}
