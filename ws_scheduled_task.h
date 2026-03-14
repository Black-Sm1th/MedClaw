/**
 * @file ws_scheduled_task.h
 * @brief WebSocket 定时任务类（定时任务类 / 子类之一）【预留】
 *
 * 预留类结构，用于后续扩展定时 / 周期性任务逻辑。
 *
 * 可能的应用场景：
 *   - 心跳保活机制（定期发送 ping / 响应 tick 事件）
 *   - 断线自动重连策略（指数退避重连、最大重试次数限制）
 *   - 会话列表定期刷新（确保多端同步时列表及时更新）
 *   - 消息队列的定期清理（清除过期的 pending 请求）
 *   - Token 过期检测与自动续期
 *
 * 设计说明：
 *   本类为纯逻辑类，不继承 QObject。
 *   如需定时器功能，可由主类（GatewayClient）创建 QTimer 并调用本类方法。
 *   当前无具体实现，仅保留类结构和注释。
 */
#ifndef WS_SCHEDULED_TASK_H
#define WS_SCHEDULED_TASK_H

#include <QString>

class WsScheduledTask
{
public:
    WsScheduledTask();

    // ═══════════════════════════════════════════════════════════════
    //  心跳保活（预留）
    // ═══════════════════════════════════════════════════════════════

    /// 【预留】处理服务器下发的 tick / heartbeat 事件
    // void handleTick();

    /// 【预留】判断是否需要主动发送心跳
    // bool shouldSendHeartbeat() const;

    // ═══════════════════════════════════════════════════════════════
    //  断线重连策略（预留）
    // ═══════════════════════════════════════════════════════════════

    /// 【预留】记录一次断线事件，更新重连计数器
    // void recordDisconnect();

    /// 【预留】计算下次重连的等待时间（毫秒），基于指数退避策略
    // int nextReconnectDelayMs() const;

    /// 【预留】重置重连计数器（连接成功后调用）
    // void resetReconnectCounter();

    /// 【预留】是否已达到最大重试次数
    // bool maxRetriesExceeded() const;

    // ═══════════════════════════════════════════════════════════════
    //  定期刷新任务（预留）
    // ═══════════════════════════════════════════════════════════════

    /// 【预留】判断会话列表是否需要刷新（基于时间间隔）
    // bool shouldRefreshSessions() const;

    /// 【预留】清理超时的 pending 请求
    // int cleanExpiredRequests();
};

#endif // WS_SCHEDULED_TASK_H
