/**
 * @file ws_config.h
 * @brief WebSocket 连接配置类（配置类 / 子类之一）
 *
 * 本类负责管理与 OpenClaw Gateway 建立 WebSocket 连接所需的全部配置信息：
 *   - 服务器连接地址（URL）
 *   - 身份认证信息（Token）
 *   - 客户端身份标识（Client ID、版本、平台、模式）
 *   - 协议版本协商参数（minProtocol / maxProtocol）
 *   - Ed25519 设备密钥的生成与签名（用于设备认证握手）
 *
 * 设计说明：
 *   本类为纯数据 + 逻辑类，不继承 QObject，无信号/槽。
 *   由 WebSocket 主类（GatewayClient）持有，在连接握手阶段调用。
 */
#ifndef WS_CONFIG_H
#define WS_CONFIG_H

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>
#include <cstdint>

class WsConfig
{
public:
    /**
     * @brief 构造函数 —— 从「用户主目录/AppData/config.json」加载或创建默认配置，并生成 Ed25519 设备密钥对
     *
     * 自动调用 initDeviceKeys() 完成以下工作：
     *   1. 使用内嵌 TweetNaCl 实现生成 Ed25519 公私钥对
     *   2. 对公钥做 SHA-256 哈希得到 deviceId（十六进制字符串）
     */
    WsConfig();

    // ═══════════════════════════════════════════════════════════════
    //  服务器 & 认证配置（getter / setter）
    // ═══════════════════════════════════════════════════════════════

    /// 获取服务器 WebSocket 地址（如 ws://127.0.0.1:18789）
    QString serverUrl() const;
    /// 设置服务器 WebSocket 地址
    void setServerUrl(const QString &url);

    /// 获取身份认证 Token
    QString token() const;
    /// 设置身份认证 Token
    void setToken(const QString &token);

    /// 存放技能路径（JSON：skillsStoragePath，默认 ~/medclaw/MedClaw/skills）
    QString skillsStoragePath() const;
    void setSkillsStoragePath(const QString &path);

    /**
     * 技能市场分类（JSON：skillMarketCategories，数组项 { "name", "path" }）
     * path 为该分类下技能目录的绝对路径，可使用 ~/ 表示用户主目录。
     */
    QVariantList skillMarketCategories() const;

    /**
     * 主界面快捷方式（JSON：shortcut，数组项含 name、icon、tools、cards）
     * cards 项含 name、description、icon、prompt、files。
     */
    QVariantList shortcuts() const;

    /// LLM 二级判定开关（本地持久化，OpenClaw 无原生支持）
    bool llmJudgmentEnabled() const;
    void setLlmJudgmentEnabled(bool enabled);

    // ═══════════════════════════════════════════════════════════════
    //  设备密钥信息
    // ═══════════════════════════════════════════════════════════════

    /// 获取设备 ID（公钥 SHA-256 哈希的十六进制表示）
    QString deviceId() const;
    /// Ed25519 密钥对是否已成功生成
    bool hasDeviceKeys() const;

    // ═══════════════════════════════════════════════════════════════
    //  构建握手请求参数
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 构建 connect 请求的完整 params 对象
     * @param challengeNonce  服务器在 connect.challenge 事件中下发的随机 nonce
     * @return QJsonObject    包含 auth、client、device、scopes 等全部握手字段
     *
     * 组装 OpenClaw 握手协议所需的全部参数：
     *   - minProtocol / maxProtocol：协议版本（固定 3）
     *   - client：客户端身份 {id, version, platform, mode}
     *   - role / scopes：操作员角色及权限范围
     *   - auth：{token} 认证信息
     *   - device：带 Ed25519 签名的设备认证对象
     *   - locale / userAgent：附加元信息
     */
    QJsonObject buildConnectParams(const QString &challengeNonce) const;

private:
    /**
     * @brief 从 AppData/config/config.json 读取 serverUrl、token、clientId、skillsStoragePath、skillMarketCategories；
     *        若文件不存在则创建并写入默认值；缺省键会补全并写回。
     */
    void loadOrCreatePersistentConfig();

    /**
     * @brief 初始化 Ed25519 设备密钥对
     *
     * 使用内嵌纯 C++ 实现（基于 TweetNaCl，SHA-512 由 Qt 提供）。
     * 生成流程：
     *   1. QRandomGenerator 生成 32 字节随机种子
     *   2. SHA-512 扩展种子 → 得到密钥标量 a
     *   3. 计算 A = a·B（基点乘法）→ 公钥（32 字节）
     *   4. SHA-256(公钥) → deviceId（64 字符十六进制）
     */
    void initDeviceKeys();

    /**
     * @brief 构建带 Ed25519 签名的 device JSON 对象
     * @param challengeNonce  服务器下发的 challenge nonce
     * @return QJsonObject    {id, nonce, publicKey, signature, signedAt}
     *
     * v2 签名 payload 格式：
     *   v2|{deviceId}|{clientId}|{clientMode}|{role}|{scopes}|{signedAtMs}|{token}|{nonce}
     *
     * 签名后各字段编码为 Base64Url（无填充）。
     */
    QJsonObject buildSignedDevice(const QString &challengeNonce) const;

    // ── 服务器与认证 ──
    QString m_serverUrl;        ///< WebSocket 服务器地址
    QString m_token;            ///< 身份认证 Token

    QString m_skillsStoragePath; ///< 存放技能路径
    QVariantList m_skillMarketCategories; ///< 技能市场分类（name + path）
    QVariantList m_shortcuts;             ///< 主界面快捷方式
    bool    m_llmJudgmentEnabled = false;

    // ── 客户端身份标识（需与 Gateway 白名单匹配） ──
    QString m_clientId;         ///< 客户端标识符（如 clawdbot-control-ui）
    QString m_clientVersion;    ///< 客户端版本号（如 dev）
    QString m_clientPlatform;   ///< 运行平台标识（如 Win32）
    QString m_clientMode;       ///< 客户端模式（如 webchat）

    // ── 协议参数 ──
    int     m_minProtocol;      ///< 最低支持协议版本
    int     m_maxProtocol;      ///< 最高支持协议版本
    QString m_role;             ///< 连接角色（如 operator）
    QJsonArray m_scopes;        ///< 权限范围列表

    // ── Ed25519 设备密钥 ──
    uint8_t m_ed25519Pk[32];    ///< Ed25519 公钥（32 字节原始数据）
    uint8_t m_ed25519Sk[64];    ///< Ed25519 私钥（64 字节 = 种子 + 公钥）
    bool    m_hasKeys;          ///< 密钥对是否生成成功
    QString m_deviceId;         ///< 设备 ID（公钥 SHA-256 哈希）
};

#endif // WS_CONFIG_H
