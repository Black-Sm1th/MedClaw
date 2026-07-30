import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.3
import QtGraphicalEffects 1.0
import "./components"
ApplicationWindow {
    id: window
    width: 1440
    height: 800
    visible: true
    title: qsTr("Aether study")
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint
    font.family: "Alibaba PuHuiTi 3.0"
    font.pixelSize: 14
    property bool isNewTask: true
    property int leftSelectedIndex: 0
    property bool sidebarCollapsed: false
    /// 非空表示「编辑」已有定时任务；空为新建
    property string editingCronJobId: ""
    property string editingCronPayloadKind: "agentTurn"
    property string editingCronScheduleKind: ""
    property string editingCronScheduleExpr: ""
    property string editingCronScheduleTz: ""
    property string pendingDeleteCronJobId: ""
    property string pendingDeleteCronJobName: ""
    property string pendingDeleteMcpName: ""
    /// 右键删除任务会话流程暂存（上下文菜单 → 确认弹窗）
    property string pendingDeleteTaskSessionId: ""
    property string pendingDeleteTaskSessionName: ""
    property string pendingDeleteAgentId: ""
    property string pendingDeleteAgentName: ""
    property int agentManageTabIndex: 0
    property bool agentEditorIsEdit: false
    property string agentEditorAgentId: ""
    property var kbSources: []
    property string kbSearchText: ""
    property bool kbLoading: false
    property string kbBusyText: ""
    property var kbUploadQueue: []
    property int kbUploadIndex: 0
    property string kbUploadCollection: ""
    property var kbMetadata: ({ "files": {}, "folders": [] })
    property string kbMetadataUser: ""
    property string kbCurrentFolder: ""
    property var kbSelectedKeys: []
    property var kbDeleteQueue: []
    property var kbDeleteKeys: []
    /// 编辑 MCP 弹窗预填（由列表 delegate 写入）
    property var mcpEditEntry: null
    property string pendingExpertPrompt: ""

    /// 若整段里出现第二对「()」，只保留到第一对括号结束（含前面文字与第一对括号）
    function trimToFirstParenPairOnly(s) {
        if (!s || s.length < 2)
            return s || ""
        var first = s.indexOf("(")
        if (first < 0)
            return s
        var depth = 0
        var i
        for (i = first; i < s.length; i++) {
            var c = s.charAt(i)
            if (c === "(")
                depth++
            else if (c === ")") {
                depth--
                if (depth === 0)
                    break
            }
        }
        if (i >= s.length)
            return s
        if (s.indexOf("(", i + 1) < 0)
            return s
        return s.substring(0, i + 1).trim()
    }

    /// 任务记录列表中 agent 的展示标题（与左侧列表 Label 渲染逻辑保持一致）
    function agentDisplayTitle(agent) {
        if (!agent) return ""
        var nm = agent.name || ""
        if (nm.indexOf("定时-") === 0) {
            var body = nm.substring(3)
            var lastDash = body.lastIndexOf("-")
            if (lastDash > 0 && /^\d+$/.test(body.substring(lastDash + 1)))
                return body.substring(0, lastDash)
            return body
        }
        var t = agent.activeSessionTitle || ""
        if (t.length === 0) {
            if (nm.match(/^task-\d+$/))
                return qsTr("新对话")
            return nm || agent.id || ""
        }
        return t
    }

    function agentIdentityName(agent) {
        if (!agent) return ""
        var ident = agent.identity || {}
        return ident.name || agent.name || agent.id || ""
    }

    function agentIdentitySummary(agent) {
        if (!agent)
            return ""
        var description = String(agent.description || "").trim()
        if (description.length > 0)
            return description

        var ident = agent.identity || {}
        var parts = []
        if (ident.name) parts.push("Name: " + ident.name)
        if (ident.emoji) parts.push("Emoji: " + ident.emoji)
        if (ident.creature) parts.push("Creature: " + ident.creature)
        if (ident.theme) parts.push("Theme: " + ident.theme)
        if (ident.vibe) parts.push("Vibe: " + ident.vibe)
        if (parts.length > 0)
            return parts.join(" · ")
        return agent.id || ""
    }

    function isMainAgentId(agentId) {
        return String(agentId || "").trim().toLowerCase() === "main"
    }

    function visibleAgentList() {
        var list = wsClient.agentList || []
        var out = []
        for (var i = 0; i < list.length; i++) {
            var id = list[i].id || ""
            if (!window.isMainAgentId(id))
                out.push(list[i])
        }
        return out
    }

    function findVisibleAgentId(preferredId) {
        var target = String(preferredId || "").trim().toLowerCase()
        if (!target || window.isMainAgentId(target))
            return ""
        var list = window.visibleAgentList()
        for (var i = 0; i < list.length; i++) {
            var id = String(list[i].id || "").trim()
            var name = String(list[i].name || "").trim()
            if (id.toLowerCase() === target || name.toLowerCase() === target)
                return id
        }
        return ""
    }

    function medicalAnalysisTeamAgentIds() {
        var wanted = ["Orchestrator", "writer", "researcher", "analyst"]
        var ids = []
        var missing = []
        for (var i = 0; i < wanted.length; i++) {
            var id = window.findVisibleAgentId(wanted[i])
            if (id.length > 0)
                ids.push(id)
            else
                missing.push(wanted[i])
        }
        if (missing.length > 0) {
            errorToast.text = "医疗分析团队缺少专家：" + missing.join(", ")
            errorToast.visible = true
            errorToastTimer.restart()
            return []
        }
        return ids
    }

    function orderedAgentIds(limit) {
        var list = wsClient.agentList || []
        var ids = []
        var preferred = wsClient.defaultAgentId || "main"
        for (var i = 0; i < list.length; i++) {
            var id0 = list[i].id || ""
            if (id0 === preferred) {
                ids.push(id0)
                break
            }
        }
        for (var j = 0; j < list.length; j++) {
            var id = list[j].id || ""
            if (!id) continue
            var exists = false
            for (var k = 0; k < ids.length; k++) {
                if (ids[k] === id) { exists = true; break }
            }
            if (!exists)
                ids.push(id)
        }
        if (limit > 0 && ids.length > limit)
            ids = ids.slice(0, limit)
        return ids
    }

    function startTaskWithAgents(agentIds) {
        var ids = agentIds || []
        if (ids.length === 0) {
            errorToast.text = "暂无可用专家"
            errorToast.visible = true
            errorToastTimer.restart()
            return
        }
        chatModel.clear()
        leftMidPanel.activeAgentId = ""
        leftMidPanel.activeSessionKey = ""
        wsClient.clearActiveAgentContext()
        newTaskRec.selectedCollaborationAgentIds = ids
        window.leftSelectedIndex = 0
    }

    function summonExpert(agentId, promptText) {
        var id = String(agentId || "").trim()
        if (!id)
            return
        pendingExpertPrompt = String(promptText || "")
        startTaskWithAgents([id])
        if (pendingExpertPrompt.length > 0) {
            textInputArea.text = pendingExpertPrompt
            textInputArea.forceActiveFocus()
        }
        wsClient.summonAgent(id)
    }

    function taskSessionDisplayTitle(task) {
        if (!task) return ""
        var t = task.title || ""
        if (t.length === 0)
            t = qsTr("新对话")
        return t
    }

    function agentIdFromSessionKey(sessionKey) {
        var key = String(sessionKey || "")
        var parts = key.split(":")
        if (parts.length >= 2 && parts[0] === "agent")
            return parts[1] || ""
        return ""
    }

    /// FileDialog.fileUrl → 本地路径（与定时任务工作目录选择逻辑一致）
    function localFilePathFromUrl(fileUrl) {
        var path = decodeURIComponent(fileUrl.toString().replace(/^file:\/{2,3}/, ""))
        if (Qt.platform.os === "windows") {
            if (path.length >= 3 && path.charAt(0) === "/" && path.charAt(2) === ":")
                path = path.substring(1)
            path = path.replace(/\//g, "\\")
        } else if (Qt.platform.os === "linux" || Qt.platform.os === "osx") {
            path = "/" + path
        }
        return path
    }

    function kbShowError(message) {
        kbLoading = false
        kbBusyText = ""
        kbUploadQueue = []
        kbUploadIndex = 0
        kbUploadCollection = ""
        errorToast.text = message || "知识库操作失败"
        errorToast.visible = true
        errorToastTimer.restart()
    }

    function kbUserCollection() {
        if (!authController.loggedIn || !authController.userId)
            return ""
        var raw = String(authController.userId).trim()
        var safe = raw.toLowerCase().replace(/[^a-z0-9_]/g, "_")
        safe = safe.replace(/^_+|_+$/g, "").substring(0, 32)
        if (!safe)
            safe = "account"
        var hash = 0
        for (var i = 0; i < raw.length; i++)
            hash = (hash * 131 + raw.charCodeAt(i)) % 4294967291
        return "user_kb_" + safe + "_" + Math.floor(hash).toString(16)
    }

    function kbToolDetails(result) {
        if (!result) return {}
        if (result.details) return result.details
        if (result.result && result.result.details) return result.result.details
        return {}
    }

    function kbInvoke(tool, args, action, collection, done) {
        var base = wsClient.gatewayHttpBaseUrl
        var token = wsClient.gatewayAuthToken
        if (!base || !token) {
            kbShowError("知识库服务配置不完整")
            return
        }
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            var response = null
            try { response = JSON.parse(xhr.responseText || "{}") } catch (e) {}
            if (xhr.status < 200 || xhr.status >= 300 || !response || response.ok !== true) {
                var message = response && response.error
                        ? (response.error.message || response.error.type) : ""
                kbShowError(message || ("知识库请求失败（HTTP " + xhr.status + "）"))
                return
            }
            if (collection !== kbUserCollection()) {
                kbLoading = false
                kbBusyText = ""
                return
            }
            var result = response.result || {}
            var details = kbToolDetails(result)
            if (details.error) {
                var detailMessage = String(details.error)
                detailMessage = detailMessage.replace(/^Error:\s*/, "")
                kbShowError(detailMessage)
                return
            }
            if (details.errors && details.errors.length > 0
                    && (!details.results || details.results.length === 0)) {
                var firstError = details.errors[0]
                kbShowError(firstError.error || String(firstError))
                return
            }
            done(result)
        }
        xhr.open("POST", base + "/tools/invoke")
        xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.setRequestHeader("Content-Type", "application/json")
        var body = { "tool": tool, "args": args || {} }
        if (action)
            body.action = action
        xhr.send(JSON.stringify(body))
    }

    function kbRefreshFiles() {
        var collection = kbUserCollection()
        if (!collection) {
            kbSources = []
            return
        }
        if (kbMetadataUser !== String(authController.userId || ""))
            kbLoadMetadata()
        kbLoading = true
        kbBusyText = "正在加载文件..."
        kbInvoke("kb_manage", { "collection": collection }, "list_sources", collection,
                 function(result) {
            var details = kbToolDetails(result)
            kbSources = details.sources || []
            kbReconcileMetadata()
            kbLoading = false
            kbBusyText = ""
        })
    }

    function kbDefaultMetadata() {
        return { "files": {}, "folders": [] }
    }

    function kbLoadMetadata() {
        if (!authController.loggedIn || !authController.userId) {
            kbMetadata = kbDefaultMetadata()
            kbMetadataUser = ""
            return
        }
        var loaded = $MainViewController.loadKnowledgeBaseMetadata(String(authController.userId)) || {}
        if (!loaded.files) loaded.files = {}
        if (!loaded.folders) loaded.folders = []
        kbMetadata = loaded
        kbMetadataUser = String(authController.userId)
    }

    function kbSaveMetadata(metadata) {
        var saved = JSON.parse(JSON.stringify(metadata))
        kbMetadata = saved
        if (authController.loggedIn && authController.userId)
            $MainViewController.saveKnowledgeBaseMetadata(String(authController.userId), saved)
    }

    function kbNormalizeFolder(path) {
        var value = String(path || "").replace(/\\/g, "/").replace(/^\/+|\/+$/g, "")
        return value.replace(/\/+/g, "/")
    }

    function kbJoinFolder(parent, child) {
        parent = kbNormalizeFolder(parent)
        child = kbNormalizeFolder(child)
        return parent && child ? parent + "/" + child : (parent || child)
    }

    function kbFolderName(path) {
        var parts = kbNormalizeFolder(path).split("/")
        return parts.length ? parts[parts.length - 1] : ""
    }

    function kbParentFolder(path) {
        path = kbNormalizeFolder(path)
        var slash = path.lastIndexOf("/")
        return slash < 0 ? "" : path.substring(0, slash)
    }

    function kbFolderPath(folderEntry) {
        return kbNormalizeFolder(typeof folderEntry === "string" ? folderEntry : folderEntry.path)
    }

    function kbFolderAddedAt(folderEntry) {
        return typeof folderEntry === "string" ? 0 : Number(folderEntry.addedAt || 0)
    }

    function kbEnsureFolder(metadata, path, addedAt) {
        path = kbNormalizeFolder(path)
        if (!path) return
        var parts = path.split("/")
        var current = ""
        for (var i = 0; i < parts.length; i++) {
            current = kbJoinFolder(current, parts[i])
            var exists = false
            for (var j = 0; j < metadata.folders.length; j++) {
                if (kbFolderPath(metadata.folders[j]) === current) {
                    exists = true
                    break
                }
            }
            if (!exists)
                metadata.folders.push({ "path": current, "addedAt": addedAt || Date.now() })
        }
    }

    function kbReconcileMetadata() {
        var metadata = kbMetadata || kbDefaultMetadata()
        if (!metadata.files) metadata.files = {}
        if (!metadata.folders) metadata.folders = []
        var actual = {}
        for (var i = 0; i < kbSources.length; i++) {
            var source = String(kbSources[i] || "")
            actual[source] = true
            if (!metadata.files[source])
                metadata.files[source] = { "folderPath": "", "addedAt": 0, "sizeBytes": -1, "fileSize": "--" }
        }
        var names = Object.keys(metadata.files)
        for (var j = 0; j < names.length; j++) {
            if (!actual[names[j]])
                delete metadata.files[names[j]]
        }
        kbSaveMetadata(metadata)
        kbSelectedKeys = []
    }

    function kbDeleteSource(source) {
        kbDeleteEntries(["file:" + source])
    }

    function kbDeleteEntries(keys) {
        var collection = kbUserCollection()
        if (!collection) return
        var sources = []
        var seen = {}
        var metadata = kbMetadata
        for (var i = 0; i < keys.length; i++) {
            var key = String(keys[i])
            if (key.indexOf("file:") === 0) {
                var source = key.substring(5)
                if (!seen[source]) { seen[source] = true; sources.push(source) }
            } else if (key.indexOf("folder:") === 0) {
                var folder = key.substring(7)
                var fileNames = Object.keys(metadata.files || {})
                for (var j = 0; j < fileNames.length; j++) {
                    var fileFolder = kbNormalizeFolder(metadata.files[fileNames[j]].folderPath)
                    if (fileFolder === folder || fileFolder.indexOf(folder + "/") === 0) {
                        if (!seen[fileNames[j]]) { seen[fileNames[j]] = true; sources.push(fileNames[j]) }
                    }
                }
            }
        }
        kbDeleteQueue = sources
        kbDeleteKeys = keys.slice(0)
        kbLoading = true
        kbBusyText = "正在删除..."
        kbDeleteNext()
    }

    function kbDeleteNext() {
        if (kbDeleteQueue.length === 0) {
            var metadata = kbMetadata
            for (var i = 0; i < kbDeleteKeys.length; i++) {
                var key = String(kbDeleteKeys[i])
                if (key.indexOf("file:") === 0) {
                    delete metadata.files[key.substring(5)]
                } else if (key.indexOf("folder:") === 0) {
                    var folder = key.substring(7)
                    var kept = []
                    for (var j = 0; j < metadata.folders.length; j++) {
                        var path = kbFolderPath(metadata.folders[j])
                        if (path !== folder && path.indexOf(folder + "/") !== 0)
                            kept.push(metadata.folders[j])
                    }
                    metadata.folders = kept
                }
            }
            kbSaveMetadata(metadata)
            kbDeleteKeys = []
            kbSelectedKeys = []
            kbRefreshFiles()
            return
        }
        var collection = kbUserCollection()
        var source = kbDeleteQueue[0]
        kbInvoke("kb_manage", { "collection": collection, "source": source },
                 "delete_source", collection, function(result) {
            kbDeleteQueue = kbDeleteQueue.slice(1)
            kbDeleteNext()
        })
    }

    function kbStartUpload(urls) {
        var entries = []
        for (var i = 0; urls && i < urls.length; i++) {
            var info = $MainViewController.localFileInfo(urls[i])
            if (info && info.fileName) {
                info.folderPath = kbCurrentFolder
                entries.push(info)
            }
        }
        kbStartUploadEntries(entries)
    }

    function kbStartFolderUpload(folderUrl) {
        var entries = $MainViewController.listKnowledgeBaseFolderFiles(folderUrl) || []
        var rootName = kbFolderName(localFilePathFromUrl(folderUrl))
        var baseFolder = kbJoinFolder(kbCurrentFolder, rootName)
        for (var i = 0; i < entries.length; i++)
            entries[i].folderPath = kbJoinFolder(baseFolder, entries[i].relativeDir)
        kbStartUploadEntries(entries)
    }

    function kbStartUploadEntries(entries) {
        var collection = kbUserCollection()
        if (!collection) {
            kbShowError("请先登录后再上传文件")
            return
        }
        var existing = {}
        for (var i = 0; i < kbSources.length; i++) existing[String(kbSources[i])] = true
        kbUploadQueue = []
        for (var j = 0; entries && j < entries.length; j++) {
            var entry = entries[j]
            var source = String(entry.fileName || "")
            if (source && !existing[source]) {
                existing[source] = true
                kbUploadQueue.push(entry)
            }
        }
        if (kbUploadQueue.length === 0) {
            kbShowError(entries.length ? "文件名与知识库现有文件重复" : "文件夹中没有支持的文件")
            return
        }
        kbUploadIndex = 0
        kbUploadCollection = collection
        kbUploadNext()
    }

    function kbUploadNext() {
        if (kbUploadCollection !== kbUserCollection()) {
            kbShowError("登录用户已切换，上传已停止")
            return
        }
        if (kbUploadIndex >= kbUploadQueue.length) {
            kbUploadQueue = []
            kbRefreshFiles()
            return
        }
        kbLoading = true
        kbBusyText = "正在上传 " + (kbUploadIndex + 1) + "/" + kbUploadQueue.length + "..."
        var entry = kbUploadQueue[kbUploadIndex]
        var path = entry.absolutePath || localFilePathFromUrl(entry.fileUrl)
        kbInvoke("kb_ingest", { "path": path, "collection": kbUploadCollection }, "",
                 kbUploadCollection, function(result) {
            var metadata = kbMetadata
            kbEnsureFolder(metadata, entry.folderPath, Date.now())
            metadata.files[String(entry.fileName)] = {
                "folderPath": kbNormalizeFolder(entry.folderPath),
                "addedAt": Date.now(),
                "sizeBytes": Number(entry.sizeBytes || 0),
                "fileSize": String(entry.fileSize || "--")
            }
            kbSaveMetadata(metadata)
            kbUploadIndex++
            kbUploadNext()
        })
    }

    function kbFileIcon(name) {
        var lower = String(name || "").toLowerCase()
        if (/\.(xlsx|xls)$/.test(lower)) return "qrc:/images/knowledge/excel.png"
        if (/\.pptx$/.test(lower)) return "qrc:/images/knowledge/ppt.png"
        if (/\.(docx|doc)$/.test(lower)) return "qrc:/images/knowledge/word.png"
        return "qrc:/images/knowledge/others.png"
    }

    function kbFormatTime(value) {
        var timestamp = Number(value || 0)
        return timestamp > 0 ? Qt.formatDateTime(new Date(timestamp), "yyyy/M/d HH:mm") : "--"
    }

    function kbFolderSize(path) {
        var total = 0
        var known = false
        var files = kbMetadata.files || {}
        var names = Object.keys(files)
        for (var i = 0; i < names.length; i++) {
            var folder = kbNormalizeFolder(files[names[i]].folderPath)
            if (folder === path || folder.indexOf(path + "/") === 0) {
                var size = Number(files[names[i]].sizeBytes)
                if (size >= 0) { total += size; known = true }
            }
        }
        if (!known) return "--"
        if (total < 1024) return total + " B"
        if (total < 1024 * 1024) return (total / 1024).toFixed(1) + " KB"
        if (total < 1024 * 1024 * 1024) return (total / 1024 / 1024).toFixed(1) + " MB"
        return (total / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }

    function kbVisibleEntries() {
        var query = kbSearchText.trim().toLowerCase()
        var rows = []
        var folders = kbMetadata.folders || []
        for (var i = 0; i < folders.length; i++) {
            var path = kbFolderPath(folders[i])
            if ((!query && kbParentFolder(path) === kbCurrentFolder)
                    || (query && kbFolderName(path).toLowerCase().indexOf(query) >= 0)) {
                rows.push({ "kind": "folder", "key": "folder:" + path, "name": kbFolderName(path),
                              "path": path, "addedAt": kbFolderAddedAt(folders[i]), "size": kbFolderSize(path) })
            }
        }
        var files = kbMetadata.files || {}
        for (var j = 0; j < kbSources.length; j++) {
            var source = String(kbSources[j] || "")
            var info = files[source] || {}
            var folderPath = kbNormalizeFolder(info.folderPath)
            if ((!query && folderPath === kbCurrentFolder)
                    || (query && source.toLowerCase().indexOf(query) >= 0)) {
                rows.push({ "kind": "file", "key": "file:" + source, "name": source,
                              "path": folderPath, "addedAt": Number(info.addedAt || 0),
                              "size": String(info.fileSize || "--") })
            }
        }
        return rows
    }

    function kbIsSelected(key) { return kbSelectedKeys.indexOf(key) >= 0 }

    function kbToggleSelected(key) {
        var selected = kbSelectedKeys.slice(0)
        var index = selected.indexOf(key)
        if (index >= 0) selected.splice(index, 1)
        else selected.push(key)
        kbSelectedKeys = selected
    }

    function kbToggleSelectAll() {
        var rows = kbVisibleEntries()
        if (rows.length > 0 && kbSelectedKeys.length === rows.length) {
            kbSelectedKeys = []
            return
        }
        var selected = []
        for (var i = 0; i < rows.length; i++) selected.push(rows[i].key)
        kbSelectedKeys = selected
    }

    function kbBreadcrumbs() {
        var result = [{ "name": qsTr("全部文件"), "path": "", "current": !kbCurrentFolder }]
        var parts = kbNormalizeFolder(kbCurrentFolder).split("/")
        var path = ""
        for (var i = 0; kbCurrentFolder && i < parts.length; i++) {
            path = kbJoinFolder(path, parts[i])
            result.push({ "name": parts[i], "path": path, "current": path === kbCurrentFolder })
        }
        return result
    }

    function kbCreateFolder(name) {
        name = String(name || "").trim()
        if (!name || name === "." || name === ".." || /[\\/:*?\"<>|]/.test(name)) {
            kbShowError("文件夹名称不能为空，且不能包含 \\ / : * ? \" < > |")
            return false
        }
        var path = kbJoinFolder(kbCurrentFolder, name)
        var folders = kbMetadata.folders || []
        for (var i = 0; i < folders.length; i++) {
            if (kbFolderPath(folders[i]) === path) {
                kbShowError("当前目录已存在同名文件夹")
                return false
            }
        }
        var metadata = kbMetadata
        kbEnsureFolder(metadata, path, Date.now())
        kbSaveMetadata(metadata)
        return true
    }

    /// Markdown / 富文本中的超链接点击（需 Text.textFormat 为 MarkdownText 等）
    function openMarkdownLink(link) {
        var raw = String(link || "")
        if (!raw)
            return

        var ws = ""
        if (typeof dropdownSelectionWorkSpace !== "undefined")
            ws = dropdownSelectionWorkSpace.effectiveWorkspacePath || ""
        if (!ws)
            ws = wsClient.currentTaskWorkspace || ""

        var isLocalLink = raw.indexOf("medclaw-local:") === 0
        if (isLocalLink || raw.indexOf("file://") === 0) {
            var resolved = $MainViewController.resolveLocalFileLink(raw, ws)
            if (resolved) {
                Qt.openUrlExternally(resolved)
                return
            }
            if (isLocalLink) {
                console.warn("local file link not found:", raw)
                return
            }
        }

        Qt.openUrlExternally(raw)
    }

    function modelDisplayLabel(nm, pv) {
        var raw = pv ? (nm + " (" + pv + ")") : nm
        return trimToFirstParenPairOnly(raw)
    }

    // Only connect to the Gateway after the user has an authenticated session.
    Component.onCompleted: {
        if (authController.loggedIn)
            wsClient.connectToServer(wsClient.serverUrl)
    }
    Connections {
        target: authController
        function onLoggedInChanged() {
            if (authController.loggedIn) {
                wsClient.connectToServer(wsClient.serverUrl)
            } else {
                wsClient.disconnectFromServer()
                chatModel.clear()
                textInputArea.text = ""
                newTaskRec.resetShortcutSelection()
                kbSources = []
                kbSearchText = ""
                kbLoading = false
                kbBusyText = ""
                kbUploadQueue = []
                kbMetadata = kbDefaultMetadata()
                kbMetadataUser = ""
                kbCurrentFolder = ""
                kbSelectedKeys = []
            }
        }
    }
    Connections{
        target: wsClient
        function onConnectionStateChanged(){
            if(wsClient.connectionState === 3){
                wsClient.refreshSkills()
                wsClient.refreshCronJobs(true)
                wsClient.refreshCronStatus()
                wsClient.refreshMcpList()
                wsClient.refreshAgents()
                if (window.leftSelectedIndex === 7)
                    window.kbRefreshFiles()
            }
        }
        function onCronJobAdded(jobId){
            wsClient.refreshCronJobs(true)
        }
        function onCronJobRemoved(jobId){
            wsClient.refreshCronJobs(true)
        }
        function onCronJobUpdated(jobId){
            wsClient.refreshCronJobs(true)
        }
        function onCronRunsLoaded(runs){
            cronRunsModel.clear()
            for(var i = 0; i < runs.length; i++){
                cronRunsModel.append(runs[i])
            }
        }
        function onAgentListChanged(){
            // 不在列表刷新时自动选中 main；仅用户点击任务记录后才 switchAgent 并加载历史
        }
        function onAgentCreated(agentId, success, message, forChat){
            if (success && forChat) {
                leftMidPanel.activeAgentId = String(agentId || "")
                window.leftSelectedIndex = 6
            }
        }
        function onAgentDeleted(agentId, success, message){
            if (success && leftMidPanel.activeAgentId === agentId) {
                leftMidPanel.activeAgentId = ""
                leftMidPanel.activeSessionKey = ""
                chatModel.clear()
                wsClient.clearActiveAgentContext()
                /// 被删任务正在选中：跳回「新建任务」首页，与点击侧栏「新建任务」一致
                window.leftSelectedIndex = 0
            }
        }
        function onAgentInstallFinished(agentId, success, message) {
            if (success && String(agentId || "").length > 0) {
                var selected = newTaskRec.selectedCollaborationAgentIds || []
                if (window.leftSelectedIndex !== 0 || selected.length !== 1
                        || String(selected[0] || "") !== String(agentId || ""))
                    window.startTaskWithAgents([agentId])
                if (window.pendingExpertPrompt.length > 0) {
                    textInputArea.text = window.pendingExpertPrompt
                    textInputArea.forceActiveFocus()
                }
            }
            window.pendingExpertPrompt = ""
        }
        function onCurrentSessionChanged() {
            var sk = wsClient.currentSessionKey || ""
            leftMidPanel.activeSessionKey = sk
            leftMidPanel.activeAgentId = String(window.agentIdFromSessionKey(sk) || "")
            if (sk.length > 0)
                window.leftSelectedIndex = 6
        }
        function onErrorOccurred(message){
            console.warn("[Gateway Error]", message)
            errorToast.text = message
            errorToast.visible = true
            errorToastTimer.restart()
        }
    }
    ListModel { id: cronRunsModel }

    // 错误提示 Toast
    Rectangle {
        id: errorToast
        property string text: ""
        visible: false
        z: 9999
        width: Math.min(errorToastLabel.implicitWidth + 40, window.width - 80)
        height: 44
        radius: 8
        color: "#CC000000"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60

        Label {
            id: errorToastLabel
            text: errorToast.text
            color: "#FFFFFF"
            font.pixelSize: 14
            anchors.centerIn: parent
            width: parent.width - 32
            elide: Text.ElideRight
        }

        Timer {
            id: errorToastTimer
            interval: 5000
            onTriggered: errorToast.visible = false
        }

        Behavior on visible {
            NumberAnimation { property: "opacity"; duration: 200 }
        }
    }
    Rectangle{
        id: leftContainer
        enabled: authController.loggedIn
        width: authController.loggedIn ? (window.sidebarCollapsed ? 68 : 280) : 0
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        color: "#F7F9FA"
        clip: true

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Column{
            height: parent.height
            width: parent.width
            leftPadding: 16
            rightPadding: 16
            Rectangle{
                id: leftTopPanel
                width: parent.width - 32
                height: 56
                color: "transparent"
                Image{
                    id: logoImage
                    source: "qrc:/images/logoImage.png"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label{
                    text: "Aether study"
                    font.family: "Alimama ShuHeiTi"
                    font.pixelSize: 18
                    anchors.left: logoImage.right
                    anchors.leftMargin: 8
                    visible: !window.sidebarCollapsed
                    anchors.verticalCenter: parent.verticalCenter
                }
                ImageButton{
                    source: "qrc:/images/sidebarMinimalistic.png"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    visible: !window.sidebarCollapsed
                    onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                }
            }
            Rectangle{
                id: leftMidPanel
                width: parent.width - 32
                height: parent.height - 56 - 72
                color: "transparent"

                // 当前选中的 agent ID（用于高亮）
                property string activeAgentId: ""
                // 当前选中的 session key（用于任务记录高亮）
                property string activeSessionKey: ""

                Column{
                    id: leftMenuColumn
                    spacing: 12
                    width: parent.width
                    ImageButton{
                        source: "qrc:/images/sidebarMinimalistic.png"
                        visible: window.sidebarCollapsed
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                    }
                    Column{
                        spacing: 4
                        width: parent.width
                        visible: !window.sidebarCollapsed
                        Repeater {
                            id: selectionRepeater
                            model: ["新建任务", "定时任务", "专家·技能·工具", "知识库"/*, "MCP"*/]
                            delegate: Rectangle{
                                readonly property int targetIndex: index < 2 ? index : (index === 2 ? 2 : 7)
                                property bool isSelected: index === 2
                                                          ? window.leftSelectedIndex >= 2 && window.leftSelectedIndex <= 4
                                                          : targetIndex === window.leftSelectedIndex
                                width: leftMidPanel.width
                                height: 36
                                radius: 8
                                color: isSelected ? "#E6E7EB"
                                     : selItemMouse.containsMouse ? "#0A000000"
                                     : "transparent"
                                Row {
                                    height: parent.height
                                    width: parent.width
                                    spacing: 8
                                    leftPadding: 8
                                    rightPadding: 8
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        source: {
                                            if(modelData === "新建任务"){
                                                return "qrc:/images/chatNew.png"
                                            }else if(modelData === "定时任务"){
                                                return "qrc:/images/alarm.png"
                                            }else if(modelData === "专家·技能·工具"){
                                                return "qrc:/images/category.png"
                                            }else if(modelData === "知识库"){
                                                return "qrc:/images/knowledge.png"
                                            }else if(modelData === "MCP"){
                                                return "qrc:/images/puzzle.png"
                                            }
                                        }
                                    }
                                    Label{
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        color: "#D9000000"
                                    }
                                }
                                MouseArea {
                                    id: selItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.leftSelectedIndex = targetIndex
                                            leftMidPanel.activeAgentId = ""
                                            leftMidPanel.activeSessionKey = ""
                                            chatModel.clear()
                                            wsClient.clearActiveAgentContext()
                                            if (targetIndex === 7) {
                                                window.kbSearchText = ""
                                                window.kbRefreshFiles()
                                            }
                                    }
                                }
                                ToolTip {
                                    id: scheduledTaskMenuTip
                                    visible: modelData === "定时任务" && selItemMouse.containsMouse
                                    text: qsTr("可设置task开机联网后定时启动")
                                    delay: 400
                                    background: Rectangle { color: "#A6000000"; radius: 4 }
                                    contentItem: Text {
                                        text: scheduledTaskMenuTip.text
                                        font.pixelSize: 14
                                        color: "#FFFFFF"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                    Column{
                        spacing: 4
                        width: parent.width
                        visible: window.sidebarCollapsed
                        Repeater {
                            id: selectionRepeaterCollapsed
                            model: ["新建任务", "定时任务", "专家·技能·工具", "知识库" /*, "MCP"*/ ]
                            delegate: Rectangle{
                                readonly property int targetIndex: index < 2 ? index : (index === 2 ? 2 : 7)
                                property bool isSelected: index === 2
                                                          ? window.leftSelectedIndex >= 2 && window.leftSelectedIndex <= 4
                                                          : targetIndex === window.leftSelectedIndex
                                width: leftMidPanel.width
                                height: 36
                                radius: 8
                                color: isSelected ? "#E6E7EB"
                                     : selItemMouseCollapse.containsMouse ? "#0A000000"
                                     : "transparent"
                                Image{
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: {
                                        if(modelData === "新建任务"){
                                            return "qrc:/images/chatNew.png"
                                        }else if(modelData === "定时任务"){
                                            return "qrc:/images/alarm.png"
                                        }else if(modelData === "专家·技能·工具"){
                                            return "qrc:/images/category.png"
                                        }else if(modelData === "知识库"){
                                            return "qrc:/images/knowledge.png"
                                        }else if(modelData === "MCP"){
                                            return "qrc:/images/puzzle.png"
                                        }
                                    }
                                }
                                MouseArea {
                                    id: selItemMouseCollapse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.leftSelectedIndex = targetIndex
                                        leftMidPanel.activeAgentId = ""
                                        leftMidPanel.activeSessionKey = ""
                                        chatModel.clear()
                                        wsClient.clearActiveAgentContext()
                                        if (targetIndex === 7) {
                                            window.kbSearchText = ""
                                            window.kbRefreshFiles()
                                        }
                                    }
                                }
                                ToolTip {
                                    id: scheduledTaskMenuTipCollapsed
                                    visible: modelData === "定时任务" && selItemMouseCollapse.containsMouse
                                    text: qsTr("可设置task开机联网后定时启动")
                                    delay: 400
                                    background: Rectangle { color: "#A6000000"; radius: 4 }
                                    contentItem: Text {
                                        text: scheduledTaskMenuTipCollapsed.text
                                        font.pixelSize: 14
                                        color: "#FFFFFF"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                        Rectangle {
                            id: collapsedHistoryTrigger
                            width: leftMidPanel.width
                            height: 36
                            radius: 8
                            color: collapsedHistoryPopup.visible ? "#E6E7EB"
                                 : collapsedHistoryTriggerMouse.containsMouse ? "#0A000000"
                                 : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: "qrc:/images/history.png"
                            }
                            MouseArea {
                                id: collapsedHistoryTriggerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (collapsedHistoryPopup.visible) {
                                        collapsedHistoryPopup.close()
                                    } else {
                                        var gap = 6
                                        var pt = collapsedHistoryTrigger.mapToItem(window.contentItem,
                                                                                  collapsedHistoryTrigger.width + gap, 0)
                                        collapsedHistoryPopup.x = pt.x
                                        collapsedHistoryPopup._pendingAnchorY = pt.y
                                        collapsedHistoryPopup.open()
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════════════
                //  任务记录列表（本地 SQLite 会话列表）
                // ═══════════════════════════════════════════════
                Item {
                    visible: !window.sidebarCollapsed
                    anchors.top: leftMenuColumn.bottom
                    anchors.topMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    width: parent.width

                    // 分隔标题
                    Label {
                        id: taskRecordLabel
                        text: "任务记录"
                        font.pixelSize: 12
                        color: "#80000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    // 可滚动的任务会话列表
                    ScrollView {
                        id: agentListScrollView
                        anchors.top: taskRecordLabel.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Column {
                            spacing: 2
                            width: agentListScrollView.width

                            Repeater {
                                model: wsClient.taskSessionList

                                delegate: Rectangle {
                                    id: agentItemRect
                                    width: agentListScrollView.width
                                    height: 55
                                    radius: 8
                                    color: {
                                        var isActive = (modelData.session_id === wsClient.currentTaskSessionKey)
                                        if (isActive) return "#E6E7EB"
                                        if (agentItemMouse.containsMouse) return "#0A000000"
                                        return "transparent"
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Row {
                                            spacing: 4
                                            width: parent.width
                                            Label {
                                                id: agentListCronTag
                                                visible: {
                                                    var sk = modelData.session_id || ""
                                                    return sk.indexOf(":cron:") >= 0
                                                }
                                                text: qsTr("[定时]")
                                                font.pixelSize: 14
                                                color: "#73000000"
                                                height: 21
                                            }
                                            Label {
                                                text: window.taskSessionDisplayTitle(modelData)
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                height: 21
                                                elide: Text.ElideRight
                                                width: agentListCronTag.visible
                                                       ? Math.max(0, parent.width - agentListCronTag.width - parent.spacing)
                                                       : parent.width
                                            }
                                        }

                                        // 最近活跃会话的更新时间（与上行标题为同一条 session）
                                        Label {
                                            text: {
                                                var ms = Number(modelData.updated_at || modelData.created_at || 0)
                                                if (!ms || ms <= 0) return ""
                                                return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd hh:mm")
                                            }
                                            font.pixelSize: 12
                                            color: "#73000000"
                                        }
                                    }

                                    MouseArea {
                                        id: agentItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (mouse.button === Qt.RightButton) {
                                                window.pendingDeleteTaskSessionId = modelData.session_id || ""
                                                window.pendingDeleteTaskSessionName = window.taskSessionDisplayTitle(modelData)
                                                var p = agentItemMouse.mapToItem(window.contentItem, mouse.x, mouse.y)
                                                agentContextMenu.x = Math.min(p.x, window.width - agentContextMenu.width - 4)
                                                agentContextMenu.y = Math.min(p.y, window.height - agentContextMenu.height - 4)
                                                agentContextMenu.open()
                                                return
                                            }
                                            leftMidPanel.activeAgentId = modelData.agentId || ""
                                            window.leftSelectedIndex = 6
                                            wsClient.switchTaskSession(modelData.session_id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: accountEntry
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            height: 48
            radius: 6
            color: accountMouse.containsMouse || accountPopup.visible ? "#E6E7EB" : "transparent"
            Image {
                width: 28
                height: 28
                source: "qrc:/images/logoImage.png"
                anchors.left: parent.left
                anchors.leftMargin: window.sidebarCollapsed ? 4 : 8
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                visible: !window.sidebarCollapsed
                anchors.left: parent.left
                anchors.leftMargin: 46
                anchors.right: accountArrow.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Label { text: "用户管理"; color: "#D9000000"; font.pixelSize: 14 }
                Label { width: parent.width; text: authController.phone; color: "#73000000"; font.pixelSize: 14; elide: Text.ElideMiddle }
            }
            Label {
                id: accountArrow
                visible: !window.sidebarCollapsed
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: "#73000000"
                font.pixelSize: 18
            }
            MouseArea {
                id: accountMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pt = accountEntry.mapToItem(window.contentItem,
                                                    window.sidebarCollapsed ? accountEntry.width + 6 : 0,
                                                    -accountPopup.height - 6)
                    accountPopup.x = pt.x
                    accountPopup.y = Math.max(8, pt.y)
                    accountPopup.open()
                }
            }
        }
    }

    Popup {
        id: accountPopup
        parent: window.contentItem
        width: window.sidebarCollapsed ? 190 : 248
        height: 92
        padding: 8
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#FFFFFF"; radius: 6; border.width: 1; border.color: "#1F000000" }
        contentItem: Column {
            spacing: 2
            Rectangle {
                width: parent.width
                height: 34
                color: "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Label { text: "账号"; color: "#73000000"; font.pixelSize: 14 }
                    Label { text: authController.phone; color: "#D9000000"; font.pixelSize: 14 }
                }
            }
            Rectangle {
                width: parent.width
                height: 40
                radius: 5
                color: logoutMouse.containsMouse ? "#F2F3F5" : "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Label { text: "↪"; color: "#D9000000"; font.pixelSize: 16 }
                    Label { text: authController.busy ? "正在退出..." : "退出登录"; color: "#D9000000"; font.pixelSize: 14 }
                }
                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    enabled: !authController.busy
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { accountPopup.close(); authController.logout() }
                }
            }
        }
    }

    Popup {
        id: collapsedHistoryPopup
        parent: window.contentItem
        modal: false
        focus: true
        padding: 12
        width: 300
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        /// 打开后根据实际高度贴底边校正 y（布局完成后再读 height）
        property real _pendingAnchorY: 0
        onOpened: {
            var ph = height
            var ny = _pendingAnchorY
            if (ny + ph > window.height - 12)
                ny = Math.max(12, window.height - 12 - ph)
            collapsedHistoryPopup.y = ny
        }

        readonly property int _maxPopupH: 440
        readonly property int _listViewportH: Math.min(_maxPopupH - 2 * padding,
                                                         Math.max(histPopListColumn.implicitHeight, 0))
        implicitHeight: 2 * padding + _listViewportH

        Connections {
            target: window
            function onSidebarCollapsedChanged() {
                if (!window.sidebarCollapsed)
                    collapsedHistoryPopup.close()
            }
        }

        background: Rectangle {
            radius: 10
            color: "#FFFFFF"
            border.width: 1
            border.color: "#14000000"
        }

        contentItem: ScrollView {
            id: collapsedHistoryPopupScroll
            width: collapsedHistoryPopup.availableWidth
            height: collapsedHistoryPopup._listViewportH
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                id: histPopListColumn
                spacing: 2
                width: collapsedHistoryPopupScroll.width

                Repeater {
                    model: wsClient.taskSessionList

                    delegate: Rectangle {
                        width: collapsedHistoryPopupScroll.width
                        height: 55
                        radius: 8
                        color: {
                            var isActive = (modelData.session_id === wsClient.currentTaskSessionKey)
                            if (isActive) return "#E6E7EB"
                            if (histPopAgentMouse.containsMouse) return "#0A000000"
                            return "transparent"
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                spacing: 4
                                width: parent.width
                                Label {
                                    id: histPopCronTag
                                    visible: {
                                        var sk = modelData.session_id || ""
                                        return sk.indexOf(":cron:") >= 0
                                    }
                                    text: qsTr("[定时]")
                                    font.pixelSize: 14
                                    color: "#73000000"
                                    height: 21
                                }
                                Label {
                                    text: window.taskSessionDisplayTitle(modelData)
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                    height: 21
                                    elide: Text.ElideRight
                                    width: histPopCronTag.visible
                                           ? Math.max(0, parent.width - histPopCronTag.width - parent.spacing)
                                           : parent.width
                                }
                            }

                            Label {
                                text: {
                                    var ms = Number(modelData.updated_at || modelData.created_at || 0)
                                    if (!ms || ms <= 0) return ""
                                    return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd hh:mm")
                                }
                                font.pixelSize: 12
                                color: "#73000000"
                            }
                        }

                        MouseArea {
                            id: histPopAgentMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (mouse.button === Qt.RightButton) {
                                    window.pendingDeleteTaskSessionId = modelData.session_id || ""
                                    window.pendingDeleteTaskSessionName = window.taskSessionDisplayTitle(modelData)
                                    var p = histPopAgentMouse.mapToItem(window.contentItem, mouse.x, mouse.y)
                                    agentContextMenu.x = Math.min(p.x, window.width - agentContextMenu.width - 4)
                                    agentContextMenu.y = Math.min(p.y, window.height - agentContextMenu.height - 4)
                                    agentContextMenu.open()
                                    return
                                }
                                leftMidPanel.activeAgentId = modelData.agentId || ""
                                window.leftSelectedIndex = 6
                                wsClient.switchTaskSession(modelData.session_id)
                                collapsedHistoryPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle{
        id:rightContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftContainer.right
        anchors.right: parent.right
        color: "#FFFFFF"
        Rectangle{
            id: rightTopPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56
            color: "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#14000000"
            }

            MouseArea {
                anchors.fill: parent
                property point dragPos

                onPressed: {
                    dragPos = Qt.point(mouseX, mouseY)
                }
                onPositionChanged: {
                    if (pressed) {
                        var delta = Qt.point(mouseX - dragPos.x, mouseY - dragPos.y)
                        window.x += delta.x
                        window.y += delta.y
                    }
                }
            }
            Rectangle{
                visible: authController.loggedIn
                color: "#F7F9FA"
                width: statusRow.width
                height: 31
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                radius: 8
                Row{
                    id: statusRow
                    height: parent.height
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 5
                    bottomPadding: 5
                    // 连接状态指示灯 + 文本
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: {
                            switch (wsClient.connectionState) {
                            case 0: return "#D32F2F"  // Disconnected
                            case 1: return "#FF9800"  // Connecting
                            case 2: return "#FF9800"  // Handshaking
                            case 3: return "#006BFF"  // Connected
                            default: return "#9E9E9E"
                            }
                        }
                    }
                    Rectangle{
                        width: 8
                        height: 1
                        color: "transparent"
                    }
                    Label {
                        text: wsClient.statusText
                        font.pixelSize: 14
                        color: "#A6000000"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row{
                rightPadding: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Item {
                    id: workspaceTopBarSlot
                    width: (authController.loggedIn
                            && (window.leftSelectedIndex === 0 || window.leftSelectedIndex === 6)
                            && !newTaskRec.isNewTaskWelcome) ? 137 : 0
                    height: parent.height
                    clip: true
                }
                Rectangle {
                    width: workspaceTopBarSlot.width > 0 ? 8 : 0
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: settingBtn
                    visible: authController.loggedIn
                    source: "qrc:/images/setting.png"
                    onClicked: settingsDialog.open()
                }
                Rectangle{
                    visible: authController.loggedIn
                    width: 20
                    height: 1
                    color: "transparent"
                }
                Rectangle{
                    visible: authController.loggedIn
                    width: 1
                    height: 16
                    color: "#1F000000"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle{
                    visible: authController.loggedIn
                    width: 20
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: minusBtn
                    source: "qrc:/images/minus.png"
                    onClicked: window.showMinimized()
                }
                Rectangle{
                    width: 10
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: maxmizeBtn
                    source: "qrc:/images/add-square.png"
                    onClicked: {
                        if (window.visibility === Window.Maximized) {
                            window.showNormal()
                        } else {
                            window.showMaximized()
                        }
                    }
                }
                Rectangle{
                    width: 10
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: closeBtn
                    source: "qrc:/images/close.png"
                    onClicked: {
                        Qt.quit()
                    }
                }
            }
        }
        Rectangle{
            id: rightMainPanel
            enabled: authController.loggedIn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: rightTopPanel.bottom
            anchors.bottom: parent.bottom
            Rectangle{
                id: newTaskRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 0 || window.leftSelectedIndex === 6
                property bool hasMessages: chatModel.count > 0
                readonly property bool hasActiveTask: String(wsClient.currentTaskSessionKey || "").length > 0
                property bool isNewTaskWelcome: window.leftSelectedIndex === 0
                                                && !hasActiveTask && !hasMessages
                property var selectedCollaborationAgentIds: []
                readonly property bool viewingControllerSession: (wsClient.currentViewSessionKey || "") === ""
                                                             || (wsClient.currentViewSessionKey || "") === (wsClient.currentTaskSessionKey || "")

                property int selectedShortcutGroup: -1
                readonly property var shortcutGroups: [
                    {
                        title: "日常办公",
                        icon: "qrc:/images/shortcut/1.png",
                        color: "#0F006BFF",
                        cards: [
                            {
                                title: "文档处理",
                                detail: "请帮我梳理这份文档的结构，提炼核心观点，并生成一份清晰的摘要。",
                                icon: "qrc:/images/shortcut/1-1.png",
                                image: "qrc:/images/shortcut/1-1-large.png",
                                prompt: "请帮我梳理这份文档的结构，提炼核心观点，并生成一份清晰的摘要。"
                            },
                            {
                                title: "数据分析和可视化",
                                detail: "请分析我上传的数据，识别关键趋势，并选择合适的图表完成可视化。",
                                icon: "qrc:/images/shortcut/1-2.png",
                                image: "qrc:/images/shortcut/1-2-large.png",
                                prompt: "请分析我上传的数据，识别关键趋势，并选择合适的图表完成可视化。"
                            }
                        ]
                    },
                    {
                        title: "医疗科研",
                        icon: "qrc:/images/shortcut/2.png",
                        color: "#0F56CA00",
                        cards: [
                            {
                                title: "文献检索",
                                detail: "围绕我的研究主题检索高质量文献，归纳研究进展、争议与空白。",
                                icon: "qrc:/images/shortcut/2-1.png",
                                image: "qrc:/images/shortcut/2-1-large.png",
                                prompt: "围绕我的研究主题检索高质量文献，归纳研究进展、争议与空白。"
                            },
                            {
                                title: "论文撰写",
                                detail: "根据研究材料协助撰写论文，先生成功符合学术规范的详细提纲。",
                                icon: "qrc:/images/shortcut/2-2.png",
                                image: "qrc:/images/shortcut/2-2-large.png",
                                prompt: "根据研究材料协助撰写论文，先生成功符合学术规范的详细提纲。"
                            },
                            {
                                title: "生信分析",
                                detail: "请根据我的生物信息数据和研究目标，制定完整、可复现的分析方案。",
                                icon: "qrc:/images/shortcut/2-3.png",
                                image: "qrc:/images/shortcut/2-3-large.png",
                                prompt: "请根据我的生物信息数据和研究目标，制定完整、可复现的分析方案。"
                            }
                        ]
                    },
                    {
                        title: "政务助手",
                        icon: "qrc:/images/shortcut/3.png",
                        color: "#0FFF8D2F",
                        cards: [
                            {
                                title: "政策匹配",
                                detail: "请根据个人基本情况，匹配可能享受的相关政策与申报条件（如残疾）。",
                                icon: "qrc:/images/shortcut/3-1.png",
                                image: "qrc:/images/shortcut/3-1-large.png",
                                prompt: "用户信息摘要：\n项目        内容\n家庭类型：非低保收入家庭\n子女情况：有子女\n户籍情况：本镇户籍（松江区）\n年龄：69周岁\n残疾情况：下肢残疾，二级残疾证\n交通工具：有电动残疾车\n疾病情况：患有尿毒症\n\n1、从知识库中检索：残疾人政策（含干扰项）政策\n2、根据用户信息，自动匹配可以享受的政策，并以EXCEL格式直接呈现，不需要EXCEL文件；\n3、用角标的形式标注引用政策来源，点击角标可以自动在右侧查看政策对应原文；\n4、结果输出：根据知识库的：“政策匹配模板”政策匹配模板输出结果"
                            },
                            {
                                title: "12345分析月报",
                                detail: "请根据《12345市民服务热线情况专报》模板，生成专报，输出PDF文件。",
                                icon: "qrc:/images/shortcut/3-2.png",
                                image: "qrc:/images/shortcut/3-2-large.png",
                                prompt: "1、分析原始数据；\n2、根据《12345市民服务热线情况专报》模板，生成专报，输出PDF文件；\n3、检查报告格式：专报要保留模板的格式。包括红头文件格式，字体大小，行间距等全文本格式"
                            }
                        ]
                    },
                    {
                        title: "行业研究",
                        icon: "qrc:/images/shortcut/4.png",
                        color: "#0FFF3D40",
                        cards: [
                            {
                                title: "行业研究报告生成",
                                detail: "深度全景式研究，一次性覆盖行业全貌。生成多维度对比 HTML 行业研究报告。",
                                icon: "qrc:/images/shortcut/4-1.png",
                                image: "qrc:/images/shortcut/4-1-large.png",
                                prompt: "【行业名称】：[如：新能源汽车 / 集成电路 / 生物医药]\n【时间范围】：[近3年 / 2022-2025年 / 最新]\n【地域范围】：[全国 / 某省 / 某市]\n\n1、检索：该行业相关的政策文件、市场数据、企业资料、研报资讯；\n2、按研究重点维度组织分析，生成结构化行业研究报告，报告产能布局、技术路线、销售数据、研发投入、新产品创新等多个维度；\n3、关键结论用角标标注引用来源，点击角标可查看对应原文；\n4、结果输出：输出结果为 html 格式。"
                            },
                            {
                                title: "行业产业链拆解",
                                detail: "拆解某行业的产业链上下游结构，分析各环节价值分布，输出为 HTML 可视化报告。",
                                icon: "qrc:/images/shortcut/4-2.png",
                                image: "qrc:/images/shortcut/4-2-large.png",
                                prompt: "【行业名称】：[如：半导体 / 新能源汽车 / 生物医药]\n【关注重点】：[价值分布 / 利润率 / 关键玩家 / 卡脖子点 / 投资切入环节（可多选）]\n\n1、基于行业认知，拆解产业链上下游结构；\n2、分析各环节价值分布、利润率、关键玩家与卡脖子点；\n3、识别高价值环节与投资切入机会；\n4、结果输出：直接生成产业链拆解报告全文，结果为 html 格式。"
                            }
                        ]
                    }
                ]

                readonly property var selectedShortcut: selectedShortcutGroup >= 0
                                                        && selectedShortcutGroup < shortcutGroups.length
                                                        ? shortcutGroups[selectedShortcutGroup] : null

                function resetShortcutSelection() {
                    selectedShortcutGroup = -1
                }

                function doSendMessage() {
                    var msg = textInputArea.text.trim()
                    if (msg === "") return
                    if (wsClient.connectionState !== 3)
                        return
                    if (!newTaskRec.viewingControllerSession)
                        return
                    var wsPath = ""
                    if (!newTaskRec.hasActiveTask) {
                        wsPath = wsClient.prepareTaskWorkspace(
                            dropdownSelectionWorkSpace.absolutePath)
                        if (!wsPath)
                            return
                    }
                    if (newTaskRec.isNewTaskWelcome)
                        wsClient.clearActiveAgentContext()
                    wsClient.setPendingCollaborationAgents(
                        newTaskRec.isNewTaskWelcome ? selectedCollaborationAgentIds : [])
                    textInputArea.text = ""

                    if (attachmentModel.count > 0) {
                        var files = []
                        for (var i = 0; i < attachmentModel.count; i++) {
                            var item = attachmentModel.get(i)
                            files.push({ fileUrl: item.fileUrl || "", fileName: item.fileName || "" })
                        }
                        attachmentModel.clear()
                        $MainViewController.sendMessageWithFiles(
                            msg, files, wsPath, window.kbUserCollection())
                    } else {
                        $MainViewController.sendMessage(
                            msg, wsPath, window.kbUserCollection())
                    }
                }

                Column{
                    id: titleCol
                    visible: newTaskRec.isNewTaskWelcome
                    width: 840
                    spacing: 11
                    anchors.topMargin: 80
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    Image{
                        source: "qrc:/images/mainTitle.png"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                Connections {
                    target: chatModel
                    function onMessagePayloadChanged() {
                        if (chatModel.count > 0)
                            chatWebView.scrollToBottom()
                    }
                }
                Connections {
                    target: chatModel
                    function onCountChanged() {
                        if (chatModel.count > 0)
                            newTaskRec.resetShortcutSelection()
                    }
                }
                Connections {
                    target: chatModel
                    function onIsStreamingChanged() {
                        if (chatModel.isStreaming && chatModel.count > 0)
                            chatWebView.scrollToBottom()
                    }
                }
                Connections {
                    target: leftMidPanel
                    function onActiveAgentIdChanged() {
                        var aid = leftMidPanel.activeAgentId || ""
                        if (aid.length > 0) {
                            newTaskRec.selectedCollaborationAgentIds = [aid]
                            newTaskRec.resetShortcutSelection()
                            return
                        }
                        newTaskRec.selectedCollaborationAgentIds = []
                    }
                }
                Rectangle {
                    id: collaborationTabBar
                    visible: newTaskRec.hasActiveTask
                             && wsClient.collaborationParticipants
                             && wsClient.collaborationParticipants.length > 0
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    width: 840
                    height: visible ? 40 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "transparent"
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        contentWidth: collaborationTabRow.implicitWidth
                        contentHeight: height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Row {
                            id: collaborationTabRow
                            spacing: 8
                            height: parent.height

                            Repeater {
                                model: wsClient.collaborationParticipants

                                delegate: Rectangle {
                                    height: 32
                                    width: Math.min(220, Math.max(92, participantLabel.implicitWidth + rolePill.width + 34))
                                    radius: 8
                                    readonly property bool activeTab: modelData.isPending
                                                                  ? false
                                                                  : (modelData.sessionKey === wsClient.currentViewSessionKey)
                                    color: activeTab ? "#EAF2FF"
                                         : participantMouse.containsMouse ? "#F7F9FA"
                                         : "#FFFFFF"
                                    border.width: 1
                                    border.color: activeTab ? "#66A3FF" : "#E6E7EB"

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Rectangle {
                                            id: rolePill
                                            width: rolePillText.implicitWidth + 10
                                            height: 20
                                            radius: 6
                                            color: modelData.isController ? "#14006BFF" : "#1400A37A"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                id: rolePillText
                                                anchors.centerIn: parent
                                                text: modelData.roleLabel || ""
                                                font.pixelSize: 11
                                                color: modelData.isController ? "#006BFF" : "#007A5A"
                                            }
                                        }

                                        Label {
                                            id: participantLabel
                                            text: modelData.agentName || modelData.title || modelData.agentId || ""
                                            font.pixelSize: 13
                                            color: "#D9000000"
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(0, parent.width - rolePill.width - parent.spacing)
                                        }
                                    }

                                    MouseArea {
                                        id: participantMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.isPending)
                                                wsClient.switchCollaborationViewSession(wsClient.currentTaskSessionKey)
                                            else
                                                wsClient.switchCollaborationViewSession(modelData.sessionKey || "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                ChatWebView {
                    id: chatWebView
                    visible: newTaskRec.hasMessages
                    anchors.top: collaborationTabBar.visible ? collaborationTabBar.bottom : parent.top
                    anchors.topMargin: collaborationTabBar.visible ? 8 : 16
                    anchors.bottom: generatingRow.top
                    anchors.bottomMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    model: chatModel
                    onLinkActivated: function(link) { window.openMarkdownLink(link) }
                }

                Label {
                    visible: newTaskRec.hasActiveTask && !newTaskRec.hasMessages
                    anchors.top: collaborationTabBar.visible ? collaborationTabBar.bottom : parent.top
                    anchors.topMargin: collaborationTabBar.visible ? 8 : 16
                    anchors.bottom: generatingRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("暂无聊天记录")
                    font.pixelSize: 14
                    color: "#66000000"
                }

                // ListView {
                //     id: chatListView
                //     visible: false
                //     anchors.top: collaborationTabBar.visible ? collaborationTabBar.bottom : parent.top
                //     anchors.topMargin: collaborationTabBar.visible ? 8 : 16
                //     anchors.bottom: generatingRow.top
                //     anchors.bottomMargin: 8
                //     width: 840
                //     anchors.horizontalCenter: parent.horizontalCenter
                //     clip: true
                //     model: null
                //     spacing: 12
                //     ScrollBar.vertical: ScrollBar {
                //         policy: ScrollBar.AsNeeded
                //     }
                //     onCountChanged: {
                //         if (count > 0)
                //             chatListView.scheduleScrollToEnd()
                //     }

                //     /// 「粘底」机制：
                //     /// dataChanged / 新增行触发后，delegate 的最终高度（尤其是
                //     /// toolResult 文本块的 Text.contentHeight）可能要再过一两个
                //     /// polish/render pass 才稳定，此时单次 Qt.callLater 调用的
                //     /// positionViewAtEnd() 会按旧 contentHeight 定位，从而漏掉
                //     /// 刚刚展开的工具结果。
                //     ///
                //     /// 解决：把「需要滚到底」标记成一段时间内的待办，期间任何
                //     /// contentHeight / 几何变化都会再次 positionViewAtEnd()，
                //     /// 直到布局稳定到时间窗口结束。
                //     property bool _pendingScrollToEnd: false
                //     property bool _scrollCallLaterQueued: false
                //     Timer {
                //         id: scrollSettleTimer
                //         interval: 220
                //         repeat: false
                //         onTriggered: chatListView._pendingScrollToEnd = false
                //     }
                //     function scheduleScrollToEnd() {
                //         if (count <= 0) return
                //         _pendingScrollToEnd = true
                //         scrollSettleTimer.restart()
                //         if (_scrollCallLaterQueued) return
                //         _scrollCallLaterQueued = true
                //         Qt.callLater(function () {
                //             chatListView._scrollCallLaterQueued = false
                //             if (chatListView.count > 0)
                //                 chatListView.positionViewAtEnd()
                //         })
                //     }
                //     onContentHeightChanged: {
                //         if (_pendingScrollToEnd && count > 0)
                //             positionViewAtEnd()
                //     }
                //     onHeightChanged: {
                //         if (_pendingScrollToEnd && count > 0)
                //             positionViewAtEnd()
                //     }

                //     /// 工具卡片折叠状态记忆：key 优先用 toolCallId（稳定），
                //     /// 缺失时回退到 "idx:<index>"。值为 true 表示「已折叠」。
                //     /// ListView 滚动时会回收/重建 delegate，局部属性会被重置，
                //     /// 故必须把状态提升到 ListView 这一层持久保存。
                //     property var toolCollapsed: ({})
                //     function isToolCollapsed(callId, idx) {
                //         var k = (callId && String(callId).length > 0)
                //                 ? ("id:" + callId) : ("idx:" + idx)
                //         return toolCollapsed[k] === true
                //     }
                //     function setToolCollapsed(callId, idx, collapsed) {
                //         var k = (callId && String(callId).length > 0)
                //                 ? ("id:" + callId) : ("idx:" + idx)
                //         // QML var 属性按引用比较是否变化，必须替换为新对象才能触发绑定刷新
                //         var m = Object.assign({}, toolCollapsed)
                //         if (collapsed) m[k] = true
                //         else delete m[k]
                //         toolCollapsed = m
                //     }
                //     /// 切换会话 / 删除任务时 chatModel.clear() 会触发 modelReset，
                //     /// 顺便清掉折叠记忆，避免遗留键无限累积。
                //     Connections {
                //         target: chatModel
                //         function onModelReset() { chatListView.toolCollapsed = ({}) }
                //     }

                //     delegate: Item {
                //         width: chatListView.width
                //         readonly property bool isCompactionMarker: {
                //             var c = String(content || "").trim().toLowerCase()
                //             return msgType !== "toolCall"
                //                 && msgType !== "toolResult"
                //                 && msgRole !== "user"
                //                 && c === "compaction"
                //         }
                //         height: {
                //             if (msgType === "toolCall") return toolBlockRoot.height
                //             if (msgType === "toolResult") return orphanToolResultRoot.height
                //             if (isCompactionMarker) return compactionDivider.height
                //             return chatBubble.height
                //         }

                //         Rectangle {
                //             id: chatBubble
                //             visible: msgType !== "toolCall" && msgType !== "toolResult" && !parent.isCompactionMarker
                //             width: parent.width
                //             height: visible ? bubbleInner.height + 4 : 0
                //             color: "transparent"
                //             readonly property bool isUser: msgRole === "user"

                //             Rectangle {
                //                 id: bubbleInner
                //                 anchors.left: chatBubble.isUser ? undefined : parent.left
                //                 anchors.right: chatBubble.isUser ? parent.right : undefined
                //                 anchors.top: parent.top
                //                 readonly property real maxBubbleWidth: chatBubble.isUser ? chatBubble.width * 0.75 : chatBubble.width
                //                 readonly property real minBubbleWidth: chatBubble.isUser ? 48 : 64
                //                 width: chatBubble.isUser
                //                        ? Math.min(maxBubbleWidth,
                //                                   Math.max(minBubbleWidth, userText.implicitWidth + 32))
                //                        : maxBubbleWidth
                //                 height: (chatBubble.isUser
                //                          ? userText.implicitHeight
                //                          : (markdownLoader.item ? markdownLoader.item.implicitHeight : 24)) + 24
                //                 radius: 12
                //                 color: chatBubble.isUser ? "#EBEDF0" : "transparent"

                //                 TextEdit {
                //                     id: userText
                //                     visible: chatBubble.isUser
                //                     width: Math.max(0, parent.width - 32)
                //                     anchors.centerIn: parent
                //                     text: content || ""
                //                     textFormat: Text.PlainText
                //                     wrapMode: Text.Wrap
                //                     font.pixelSize: 16
                //                     font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                     color: "#E5000000"
                //                     readOnly: true
                //                     selectByMouse: true
                //                 }

                //                 Loader {
                //                     id: markdownLoader
                //                     active: !chatBubble.isUser
                //                     width: Math.max(0, parent.width - 32)
                //                     anchors.centerIn: parent

                //                     sourceComponent: MarkdownWebView {
                //                         // 流式时只追加 delta；结束后由 WebEngine 本地 HTML 渲染 Markdown。
                //                         width: markdownLoader.width
                //                         sourceText: content || ""
                //                         streaming: isStreaming === true
                //                         isUser: false
                //                         isIntermediate: isIntermediate || false
                //                         maxMarkdownChars: 500000
                //                         markdownDelayMs: 100
                //                         onLinkActivated: function(link) { window.openMarkdownLink(link) }

                //                         Connections {
                //                             target: chatModel
                //                             function onStreamFlushed(row, delta) {
                //                                 if (row !== index) return
                //                                 if (!delta || delta.length === 0) return
                //                                 if (markdownLoader.item)
                //                                     markdownLoader.item.append(delta)
                //                             }
                //                         }
                //                     }
                //                 }
                //             }
                //         }

                //         Rectangle {
                //             id: compactionDivider
                //             visible: parent.isCompactionMarker
                //             width: parent.width
                //             height: visible ? 20 : 0
                //             color: "transparent"

                //             Rectangle {
                //                 anchors.verticalCenter: parent.verticalCenter
                //                 anchors.left: parent.left
                //                 anchors.right: parent.right
                //                 height: 1
                //                 color: "#14000000"
                //             }
                //         }

                //         // ── 工具调用 + 结果（合并到同一行，可折叠详情）──
                //         Item {
                //             id: toolBlockRoot
                //             visible: msgType === "toolCall"
                //             width: parent.width
                //             height: visible ? toolBlockRow.implicitHeight : 0

                //             readonly property bool toolDone: hasToolResult
                //             readonly property bool toolRunning: !hasToolResult
                //             readonly property bool toolOk: hasToolResult && !isError
                //             readonly property bool toolFail: hasToolResult && isError
                //             /// 折叠态由 chatListView.toolCollapsed 持久化记忆，
                //             /// 即便 delegate 滚出可视区被回收重建，状态也不会丢失。
                //             readonly property bool toolDetailExpanded:
                //                 !chatListView.isToolCollapsed(toolCallId, index)

                //             Column {
                //                 id: toolBlockRow
                //                 width: parent.width
                //                 spacing: 0

                //                 Row {
                //                     id: toolHeaderRow
                //                     width: parent.width
                //                     spacing: 8
                //                     height: 28

                //                     Item {
                //                         width: 20
                //                         height: 20
                //                         anchors.verticalCenter: parent.verticalCenter
                //                         Rectangle {
                //                             id: toolHeaderRunDot
                //                             anchors.centerIn: parent
                //                             visible: toolBlockRoot.toolRunning
                //                             width: 8
                //                             height: 8
                //                             radius: 4
                //                             color: "#006BFF"
                //                         }
                //                         SequentialAnimation {
                //                             running: toolBlockRoot.toolRunning && toolBlockRoot.visible
                //                             loops: Animation.Infinite
                //                             NumberAnimation {
                //                                 target: toolHeaderRunDot
                //                                 property: "opacity"
                //                                 from: 0.35; to: 1; duration: 650
                //                                 easing.type: Easing.InOutQuad
                //                             }
                //                             NumberAnimation {
                //                                 target: toolHeaderRunDot
                //                                 property: "opacity"
                //                                 from: 1; to: 0.35; duration: 650
                //                                 easing.type: Easing.InOutQuad
                //                             }
                //                         }
                //                         Text {
                //                             anchors.centerIn: parent
                //                             visible: toolBlockRoot.toolOk
                //                             text: "\u2713"
                //                             color: "#56CA00"
                //                             font.pixelSize: 16
                //                             font.bold: true
                //                         }
                //                         Rectangle {
                //                             anchors.centerIn: parent
                //                             visible: toolBlockRoot.toolFail
                //                             width: 8
                //                             height: 8
                //                             radius: 4
                //                             color: "#EF4444"
                //                         }
                //                     }

                //                     Row {
                //                         spacing: 4
                //                         anchors.verticalCenter: parent.verticalCenter

                //                         Text {
                //                             text: toolName || qsTr("工具")
                //                             font.pixelSize: 16
                //                             font.family: "Alibaba PuHuiTi 3.0"
                //                             font.bold: true
                //                             color: "#D9000000"
                //                         }

                //                         Text {
                //                             id: toolChevron
                //                             text: toolBlockRoot.toolDetailExpanded ? "\u25BE" : "\u25B8"
                //                             font.pixelSize: 14
                //                             color: "#99000000"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                             MouseArea {
                //                                 anchors.fill: parent
                //                                 anchors.margins: -6
                //                                 cursorShape: Qt.PointingHandCursor
                //                                 onClicked: chatListView.setToolCollapsed(
                //                                                toolCallId, index,
                //                                                toolBlockRoot.toolDetailExpanded)
                //                             }
                //                         }

                //                     }
                //                 }

                //                 Column {
                //                     width: parent.width
                //                     visible: toolBlockRoot.toolDetailExpanded
                //                     spacing: 8

                //                     Row {
                //                         id: toolBlockDetailRow
                //                         width: parent.width
                //                         spacing: 10
                //                         leftPadding: 9
                //                         Rectangle {
                //                             id: toolTimelineBar
                //                             width: 1
                //                             height: toolCallResultStack.height
                //                             radius: 1
                //                             color: "#E6E7EB"
                //                         }

                //                         Column {
                //                             id: toolCallResultStack
                //                             width: toolBlockRoot.width - toolTimelineBar.width - toolBlockDetailRow.spacing - 8
                //                             spacing: 8

                //                             Rectangle {
                //                                 id: toolArgsRect
                //                                 width: parent.width
                //                                 visible: toolArgs && String(toolArgs).length > 0
                //                                 readonly property real _toolArgsPad: 10
                //                                 readonly property real _toolArgsMaxH: 200
                //                                 height: visible ? toolArgsText.contentHeight + 2 * _toolArgsPad + 2 : 0
                //                                 radius: 8
                //                                 color: "#F3F4F6"
                //                                 border.width: 1
                //                                 border.color: "#E5E7EB"
                //                                 clip: true

                //                                 Flickable {
                //                                     id: toolArgsFlick
                //                                     anchors.fill: parent
                //                                     anchors.margins: 1
                //                                     clip: true
                //                                     flickableDirection: Flickable.AutoFlickIfNeeded
                //                                     contentWidth: toolArgsText.contentWidth + 2 * toolArgsRect._toolArgsPad
                //                                     contentHeight: toolArgsText.contentHeight + 2 * toolArgsRect._toolArgsPad
                //                                     boundsBehavior: Flickable.StopAtBounds

                //                                     ScrollBar.horizontal: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }
                //                                     ScrollBar.vertical: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }

                //                                     Text {
                //                                         id: toolArgsText
                //                                         x: toolArgsRect._toolArgsPad
                //                                         y: toolArgsRect._toolArgsPad
                //                                         width: Math.max(
                //                                                    implicitWidth,
                //                                                    toolArgsFlick.width - 2 * toolArgsRect._toolArgsPad)
                //                                         text: toolArgs || ""
                //                                         wrapMode: Text.Wrap
                //                                         font.pixelSize: 14
                //                                         font.family: "Consolas, Courier New, Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                                         color: "#A6000000"
                //                                         // selectByMouse: true
                //                                         // readOnly: true
                //                                         // textFormat: Text.MarkdownText
                //                                         onLinkActivated: function(link) { window.openMarkdownLink(link) }
                //                                     }
                //                                 }
                //                             }

                //                             Rectangle {
                //                                 id: toolResultRect
                //                                 width: parent.width
                //                                 visible: hasToolResult && String(toolResultText).length > 0
                //                                 readonly property real _toolResPad: 10
                //                                 readonly property real _toolResMaxH: 320
                //                                 height: visible ? toolResultBody.contentHeight + 2 * _toolResPad + 2 : 0
                //                                 radius: 8
                //                                 color: "#F3F4F6"
                //                                 border.width: 1
                //                                 border.color: isError ? "#FECACA" : "#E5E7EB"
                //                                 clip: true

                //                                 Flickable {
                //                                     id: toolResultFlick
                //                                     anchors.fill: parent
                //                                     anchors.margins: 1
                //                                     clip: true
                //                                     flickableDirection: Flickable.AutoFlickIfNeeded
                //                                     contentWidth: toolResultBody.contentWidth + 2 * toolResultRect._toolResPad
                //                                     contentHeight: toolResultBody.contentHeight + 2 * toolResultRect._toolResPad
                //                                     boundsBehavior: Flickable.StopAtBounds

                //                                     ScrollBar.horizontal: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }
                //                                     ScrollBar.vertical: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }

                //                                     Text {
                //                                         id: toolResultBody
                //                                         x: toolResultRect._toolResPad
                //                                         y: toolResultRect._toolResPad
                //                                         width: Math.max(
                //                                                    implicitWidth,
                //                                                    toolResultFlick.width - 2 * toolResultRect._toolResPad)
                //                                         text: toolResultText || ""
                //                                         wrapMode: Text.Wrap
                //                                         font.pixelSize: 14
                //                                         font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                                         color: isError ? "#FF3D40" : "#A6000000"
                //                                         // textFormat: Text.MarkdownText
                //                                         // readOnly: true
                //                                         // selectByMouse: true
                //                                         onLinkActivated: function(link) { window.openMarkdownLink(link) }
                //                                     }
                //                                 }
                //                             }
                //                         }
                //                     }

                //                     Row {
                //                         width: parent.width
                //                         visible: toolBlockRoot.toolRunning
                //                         spacing: 8
                //                         height: 24
                //                         Item {
                //                             width: 20
                //                             height: 20
                //                             anchors.verticalCenter: parent.verticalCenter
                //                             Rectangle {
                //                                 id: toolFooterRunDot
                //                                 anchors.centerIn: parent
                //                                 width: 8
                //                                 height: 8
                //                                 radius: 4
                //                                 color: "#006BFF"
                //                             }
                //                             SequentialAnimation {
                //                                 running: toolBlockRoot.toolRunning && toolBlockRoot.visible
                //                                 loops: Animation.Infinite
                //                                 NumberAnimation {
                //                                     target: toolFooterRunDot
                //                                     property: "opacity"
                //                                     from: 0.35; to: 1; duration: 650
                //                                     easing.type: Easing.InOutQuad
                //                                 }
                //                                 NumberAnimation {
                //                                     target: toolFooterRunDot
                //                                     property: "opacity"
                //                                     from: 1; to: 0.35; duration: 650
                //                                     easing.type: Easing.InOutQuad
                //                                 }
                //                             }
                //                         }
                //                         Text {
                //                             text: qsTr("执行中…")
                //                             font.pixelSize: 16
                //                             font.family: "Alibaba PuHuiTi 3.0"
                //                             color: "#006BFF"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                         }
                //                     }
                //                     Row {
                //                         width: parent.width
                //                         visible: hasToolResult
                //                         spacing: 8
                //                         height: 24

                //                         Item {
                //                             width: 20
                //                             height: 20
                //                             anchors.verticalCenter: parent.verticalCenter
                //                             Text {
                //                                 anchors.centerIn: parent
                //                                 visible: toolBlockRoot.toolOk
                //                                 text: "\u2713"
                //                                 color: "#56CA00"
                //                                 font.pixelSize: 16
                //                                 font.bold: true
                //                             }
                //                             Rectangle {
                //                                 anchors.centerIn: parent
                //                                 visible: toolBlockRoot.toolFail
                //                                 width: 8
                //                                 height: 8
                //                                 radius: 4
                //                                 color: "#EF4444"
                //                             }
                //                         }

                //                         Text {
                //                             text: isError ? qsTr("任务失败") : qsTr("任务完成")
                //                             font.pixelSize: 16
                //                             font.family: "Alibaba PuHuiTi 3.0"
                //                             color: isError ? "#FF3D40" : "#16A34A"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                         }
                //                     }
                //                 }
                //             }
                //         }

                //         // 未匹配到 toolCall 的孤立 toolResult（兼容）
                //         Item {
                //             id: orphanToolResultRoot
                //             visible: msgType === "toolResult"
                //             width: parent.width
                //             height: visible ? orphanToolCol.implicitHeight + 24 : 0

                //             Rectangle {
                //                 anchors.fill: parent
                //                 radius: 8
                //                 color: "#F3F4F6"
                //                 border.width: 1
                //                 border.color: isError ? "#FECACA" : "#E5E7EB"

                //                 Column {
                //                     id: orphanToolCol
                //                     width: parent.width - 24
                //                     x: 12
                //                     y: 12
                //                     spacing: 6

                //                     Row {
                //                         spacing: 8
                //                         Text {
                //                             visible: !isError
                //                             text: "\u2713"
                //                             color: "#56CA00"
                //                             font.pixelSize: 14
                //                             font.bold: true
                //                         }
                //                         Rectangle {
                //                             visible: isError
                //                             width: 8
                //                             height: 8
                //                             radius: 4
                //                             color: "#EF4444"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                         }
                //                         Text {
                //                             text: toolName
                //                             font.pixelSize: 13
                //                             font.bold: true
                //                             color: "#D9000000"
                //                         }
                //                     }
                //                     Text {
                //                         width: parent.width
                //                         text: content || ""
                //                         wrapMode: Text.Wrap
                //                         font.pixelSize: 12
                //                         font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                         color: isError ? "#FF3D40" : "#A6000000"
                //                         textFormat: Text.MarkdownText
                //                         // readOnly: true
                //                         // selectByMouse: true
                //                         onLinkActivated: function(link) { window.openMarkdownLink(link) }
                //                     }
                //                 }
                //             }
                //         }
                //     }
                // }

                /// 固定在输入框上方、列表可视区域下方（不参与 ListView 滚动）
                Item {
                    id: generatingRow
                    width: 840
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: chatInputContainer.top
                    height: (newTaskRec.hasMessages && chatModel.isStreaming)
                            ? (generatingStatusLabel.implicitHeight + 12)
                            : 0
                    visible: height > 0

                    Connections {
                        target: chatModel
                        function onIsStreamingChanged() {
                            if (!chatModel.isStreaming)
                                generatingStatusLabel.opacity = 1
                        }
                    }

                    Label {
                        id: generatingStatusLabel
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("生成中...")
                        font.pixelSize: 14
                        font.family: window.font.family
                        color: "#8A8F98"
                        opacity: 1

                        SequentialAnimation on opacity {
                            running: chatModel.isStreaming && generatingRow.visible
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 1.0
                                to: 0.3
                                duration: 700
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                from: 0.3
                                to: 1.0
                                duration: 700
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                ListModel {
                    id: attachmentModel
                }

                Rectangle{
                    id: chatInputContainer
                    border.color: "#40000000"
                    border.width: 1
                    radius: 20
                    height: attachmentModel.count > 0 ? 142 + 72 : 142
                    width: 840
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: newTaskRec.isNewTaskWelcome
                       ? titleCol.y + titleCol.height + 40
                       : newTaskRec.height - height - 24
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    clip: true
                    Column{
                        anchors.fill: parent
                        padding: 12
                        spacing: 8

                        Row {
                            id: attachmentRow
                            visible: attachmentModel.count > 0
                            width: parent.width - 24
                            height: visible ? 60 : 0
                            spacing: 8

                            Repeater {
                                model: attachmentModel

                                delegate: Rectangle {
                                    id: attachCard
                                    width: 168
                                    height: 56
                                    radius: 12
                                    color: "#F7F9FA"

                                    MouseArea {
                                        id: attachCardHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Image {
                                            width: 32; height: 32
                                            source: (model.isFolder || false)
                                                    ? "qrc:/images/folder.png"
                                                    : (model.isImage && model.filePath)
                                                      ? model.filePath
                                                      : "qrc:/images/filePicture.png"
                                            fillMode: (model.isImage && model.filePath && !(model.isFolder || false))
                                                      ? Image.PreserveAspectCrop : Image.Pad
                                            anchors.verticalCenter: parent.verticalCenter
                                            sourceSize.width: 32
                                            sourceSize.height: 32
                                        Rectangle {
                                                anchors.fill: parent
                                            radius: 6
                                            color: "transparent"
                                                border.color: (model.isImage && model.filePath)
                                                              ? "#0A000000" : "transparent"
                                                border.width: 1
                                                z: -1
                                            }
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: attachCard.width - 10 - 32 - 8 - 10
                                            spacing: 4

                                            Text {
                                                id: attachNameText
                                                width: parent.width
                                                text: model.fileName || ""
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                elide: Text.ElideRight
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                ToolTip {
                                                    visible: attachNameHover.containsMouse && attachNameText.truncated
                                                    text: attachNameText.text
                                                    delay: 500
                                                    x: 0; y: attachNameText.height + 4
                                                    background: Rectangle { color: "#A6000000"; radius: 4 }
                                                    contentItem: Text {
                                                        text: attachNameText.text
                                                        font.pixelSize: 14; color: "#FFFFFF"
                                                        wrapMode: Text.Wrap
                                                        font.family: "Alibaba PuHuiTi 3.0"
                                                    }
                                                }
                                                MouseArea {
                                                    id: attachNameHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.NoButton
                                                }
                                            }
                                            Text {
                                                text: model.fileSize || ""
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                font.pixelSize: 12
                                                color: "#40000000"
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: attachDelBtn
                                        width: 20; height: 20; radius: 10
                                        color: attachDelMouse.containsMouse ? "#B0000000" : "#80000000"
                                        visible: attachCardHover.containsMouse || attachDelMouse.containsMouse || attachNameHover.containsMouse
                                        anchors.right: parent.right
                                        anchors.rightMargin: -4
                                        anchors.top: parent.top
                                        anchors.topMargin: -4
                                        z: 9999

                                        Text {
                                            text: "\u2715"
                                            font.pixelSize: 10
                                            color: "#FFFFFF"
                                            anchors.centerIn: parent
                                        }
                                            MouseArea {
                                            id: attachDelMouse
                                                anchors.fill: parent
                                                anchors.margins: -4
                                            hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: attachmentModel.remove(index)
                                        }
                                    }
                                }
                            }
                        }

                        MultiLineTextInput{
                            id: textInputArea
                            focusedBorderColor: "transparent"
                            backgroundColor: "transparent"
                            borderWidth: 0
                            placeholderText: wsClient.connectionState === 3
                                             ? (newTaskRec.viewingControllerSession
                                                ? "分配一个任务或提问任何问题"
                                                : "当前为子 Agent 记录，仅支持查看")
                                             : "正在连接服务器，请稍候..."
                            width: parent.width - 24
                            height: 66
                            readOnly: wsClient.connectionState !== 3 || !newTaskRec.viewingControllerSession
                            onEnterPressed: newTaskRec.doSendMessage()
                        }
                        Rectangle{
                            height: 40
                            width: parent.width - 24
                            Row {
                                anchors.fill: parent
                                spacing: 4
                                Item {
                                    id: workspaceDialogSlot
                                    width: newTaskRec.isNewTaskWelcome ? 137 : 0
                                    height: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    id: modelPickerWrap
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 220
                                    height: 36
                                    property var modelIds: []

                                    function qualifyModelRef(mid, pv) {
                                        if (!mid)
                                            return ""
                                        if (!pv)
                                            return mid
                                        if (mid.indexOf(pv + "/") === 0)
                                            return mid
                                        return pv + "/" + mid
                                    }

                                    function rebuildFromGateway() {
                                        var list = wsClient.modelList || []
                                        var labels = []
                                        var ids = []
                                        for (var i = 0; i < list.length; i++) {
                                            var m = list[i]
                                            var mid = m.id || ""
                                            if (!mid)
                                                continue
                                            var nm = m.name || mid
                                            var pv = m.provider || ""
                                            labels.push(window.modelDisplayLabel(nm, pv))
                                            ids.push(qualifyModelRef(mid, pv))
                                        }
                                        modelIds = ids
                                        if (labels.length === 0) {
                                            dropdownSelectionModel.model = [qsTr("无可用模型")]
                                            dropdownSelectionModel.currentIndex = 0
                                            return
                                        }
                                        dropdownSelectionModel.model = labels
                                        if (dropdownSelectionModel.currentIndex >= labels.length)
                                            dropdownSelectionModel.currentIndex = 0
                                        syncIndexFromGateway()
                                    }

                                    function syncIndexFromGateway() {
                                        // 优先级：pending（用户最近一次点选的模型，sessions.patch 响应到达前的"意图"）
                                        //     →  currentModel（服务端已确认的运行时模型）
                                        // 否则保留 DropdownSelect 当前 currentIndex，避免下拉框被中间状态拉回旧选项。
                                        var cur = wsClient.pendingSessionModelId || ""
                                        if (!cur && wsClient.currentSessionKey && wsClient.currentSessionKey.length > 0) {
                                            var cm = wsClient.currentModel || {}
                                            cur = qualifyModelRef(cm.model || "",
                                                                  cm.modelProvider || "")
                                        }
                                        var ids = modelIds
                                        if (!cur || ids.length === 0)
                                            return
                                        for (var j = 0; j < ids.length; j++) {
                                            if (ids[j] === cur) {
                                                dropdownSelectionModel.currentIndex = j
                                                return
                                            }
                                        }
                                    }

                                    readonly property bool modelPickerEnabled: wsClient.connectionState === 3

                                    Connections {
                                        target: wsClient
                                        function onModelListChanged() { modelPickerWrap.rebuildFromGateway() }
                                        function onCurrentModelChanged() { modelPickerWrap.syncIndexFromGateway() }
                                        function onCurrentSessionChanged() { modelPickerWrap.syncIndexFromGateway() }
                                        function onPendingSessionModelIdChanged() { modelPickerWrap.syncIndexFromGateway() }
                                    }

                                    DropdownSelect {
                                        id: dropdownSelectionModel
                                        anchors.fill: parent
                                        model: [qsTr("加载中…")]
                                        icon: "qrc:/images/ai.png"
                                        iconSize: 16
                                        currentIndex: 0
                                        alignment: Qt.AlignLeft
                                        popupMaxWidth: 320
                                        popupMaxHeight: 280
                                        onSelected: function(index, text) {
                                            if (modelPickerWrap.modelIds.length === 0)
                                                return
                                            if (index < 0 || index >= modelPickerWrap.modelIds.length)
                                                return
                                            wsClient.patchSessionModel(modelPickerWrap.modelIds[index])
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        visible: !modelPickerWrap.modelPickerEnabled
                                        hoverEnabled: false
                                        onClicked: {}
                                    }
                                }
                                Item {
                                    id: expertSelectionTag
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property string expertId: {
                                        var ids = newTaskRec.selectedCollaborationAgentIds || []
                                        return ids.length > 0 ? String(ids[0] || "") : ""
                                    }
                                    readonly property string expertName: {
                                        var list = wsClient.agentList || []
                                        for (var i = 0; i < list.length; i++) {
                                            if (String(list[i].id || "") === expertId)
                                                return list[i].name || list[i].id || ""
                                        }
                                        return expertId
                                    }
                                    visible: newTaskRec.isNewTaskWelcome && expertId.length > 0
                                    width: visible ? Math.min(240, expertTagRow.implicitWidth + 24) : 0
                                    height: 36

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: "#F7F9FA"

                                        Row {
                                            id: expertTagRow
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Image {
                                                width: 16
                                                height: 16
                                                source: "qrc:/images/expert.png"
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Label {
                                                width: Math.min(170, implicitWidth)
                                                text: expertSelectionTag.expertName
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Image {
                                                id: expertTagCloseIcon
                                                width: 14
                                                height: 14
                                                source: "qrc:/images/close.png"
                                                fillMode: Image.PreserveAspectFit
                                                opacity: expertTagCloseMouse.containsMouse ? 1 : 0.65
                                                anchors.verticalCenter: parent.verticalCenter

                                                MouseArea {
                                                    id: expertTagCloseMouse
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: newTaskRec.selectedCollaborationAgentIds = []
                                                }
                                            }
                                        }
                                    }
                                }
                                Item {
                                    id: dropdownSelectionSkill
                                    visible: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 0
                                    height: 36

                                    property var selectedSkills: []
                                    property string searchText: ""

                                    function syncFromWsClient() {
                                        // 与工具开关一致：未在侧栏选中 agent 时默认全选；有暂存则显示暂存（待 agents.create 后写入）
                                        var aid = leftMidPanel.activeAgentId || ""
                                        if (aid === "") {
                                            if (wsClient.pendingNewAgentSkillPolicySet) {
                                                selectedSkills = wsClient.pendingNewAgentSkillNames()
                                                return
                                            }
                                            var arr = []
                                            var list = wsClient.skillList || []
                                            for (var i = 0; i < list.length; i++) {
                                                if (list[i].enabled === false)
                                                    continue
                                                var n = list[i].name || list[i].skillKey || ""
                                                if (n) arr.push(n)
                                            }
                                            selectedSkills = arr
                                            return
                                        }
                                        selectedSkills = wsClient.selectedSkillNamesForAgent(aid)
                                    }

                                    Connections {
                                        target: wsClient
                                        function onSkillListChanged() {
                                            dropdownSelectionSkill.syncFromWsClient()
                                        }
                                    }
                                    Connections {
                                        target: wsClient
                                        function onAgentIdentityChanged() {
                                            dropdownSelectionSkill.syncFromWsClient()
                                        }
                                    }
                                    Connections {
                                        target: leftMidPanel
                                        function onActiveAgentIdChanged() {
                                            dropdownSelectionSkill.syncFromWsClient()
                                        }
                                    }
                                    Connections {
                                        target: wsClient
                                        function onPendingNewAgentSkillPolicyChanged() {
                                            dropdownSelectionSkill.syncFromWsClient()
                                        }
                                    }

                                    function isSelected(name) {
                                        for (var i = 0; i < selectedSkills.length; i++) {
                                            if (selectedSkills[i] === name) return true
                                        }
                                        return false
                                    }

                                    function toggleSkill(name) {
                                        var arr = selectedSkills.slice()
                                        var idx = -1
                                        for (var i = 0; i < arr.length; i++) {
                                            if (arr[i] === name) { idx = i; break }
                                        }
                                        if (idx >= 0) arr.splice(idx, 1)
                                        else arr.push(name)
                                        selectedSkills = arr

                                        if ((leftMidPanel.activeAgentId || "") === "") {
                                            wsClient.setPendingNewAgentSkillSelection(arr)
                                            return
                                        }
                                        var aid = leftMidPanel.activeAgentId
                                        wsClient.setAgentSkillEnabled(aid, name, idx < 0)
                                    }

                                    function filteredSkills() {
                                        var list = wsClient.skillList || []
                                        var enabledOnly = []
                                        for (var j = 0; j < list.length; j++) {
                                            if (list[j].enabled === false)
                                                continue
                                            enabledOnly.push(list[j])
                                        }
                                        list = enabledOnly
                                        if (!searchText) return list
                                        var result = []
                                        for (var i = 0; i < list.length; i++) {
                                            var n = (list[i].name || list[i].skillKey || "").toLowerCase()
                                            if (n.indexOf(searchText.toLowerCase()) >= 0)
                                                result.push(list[i])
                                        }
                                        return result
                                    }

                                    Rectangle {
                                        id: skillButton
                                        anchors.fill: parent
                                        radius: 8
                                        color: skillMouseArea.pressed ? "#14000000"
                                             : skillMouseArea.containsMouse ? "#0A000000"
                                             : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Row {
                                            id: skillBtnRow
                                            spacing: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12

                                            Image {
                                                source: "qrc:/images/category.png"
                                                width: 16; height: 16
                                                anchors.verticalCenter: parent.verticalCenter
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize: Qt.size(16, 16)
                                            }
                                            // Text {
                                            //     text: "技能"
                                            //     font.pixelSize: 14
                                            //     font.family: "Alibaba PuHuiTi 3.0"
                                            //     color: "#D9000000"
                                            //     anchors.verticalCenter: parent.verticalCenter
                                            // }

                                            Text {
                                                id: skillsText
                                                text: "技能"
                                                font.pixelSize: 14
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: skillPopup.visible
                                            }
                                            Rectangle {
                                                visible: dropdownSelectionSkill.selectedSkills.length > 0
                                                width: badgeText.width + 8
                                                height: 20
                                                radius: 10
                                                color: "#14000000"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    id: badgeText
                                                    text: dropdownSelectionSkill.selectedSkills.length
                                                    font.pixelSize: 12
                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                    color: "#73000000"
                                                    anchors.centerIn: parent
                                                }
                                            }
                                        }

                                        // Canvas {
                                        //     id: skillChevron
                                        //     width: 16; height: 16
                                        //     anchors.right: parent.right
                                        //     anchors.rightMargin: 12
                                        //     anchors.verticalCenter: parent.verticalCenter
                                        //     rotation: skillPopup.visible ? 180 : 0
                                        //     Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        //     onPaint: {
                                        //         var ctx = getContext("2d")
                                        //         ctx.reset()
                                        //         ctx.strokeStyle = "#80000000"
                                        //         ctx.lineWidth = 1.5
                                        //         ctx.lineCap = "round"
                                        //         ctx.lineJoin = "round"
                                        //         ctx.beginPath()
                                        //         ctx.moveTo(4, 6)
                                        //         ctx.lineTo(8, 10)
                                        //         ctx.lineTo(12, 6)
                                        //         ctx.stroke()
                                        //     }
                                        // }

                                        MouseArea {
                                            id: skillMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: skillPopup.visible ? skillPopup.close() : skillPopup.open()
                                        }
                                    }

                                    Popup {
                                        id: skillPopup
                                        x: 0
                                        width: 220
                                        padding: 8
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                        function calcY() {
                                            var globalPos = dropdownSelectionSkill.mapToItem(null, 0, 0)
                                            var windowH = window.height
                                            var popupH = Math.min(contentItem.implicitHeight, 300 + 50) + padding * 2
                                            if (popupH < 60)
                                                popupH = 360
                                            if (globalPos.y + dropdownSelectionSkill.height + 4 + popupH > windowH)
                                                return -popupH - 4
                                            return dropdownSelectionSkill.height + 4
                                        }

                                        y: calcY()

                                        onAboutToShow: {
                                            skillSearchInput.text = ""
                                            y = calcY()
                                        }
                                        onOpened: Qt.callLater(function() { y = calcY() })

                                        background: Rectangle {
                                            radius: 8
                                            color: "#FFFFFF"
                                            border.color: "#14000000"
                                            border.width: 1
                                            layer.enabled: true
                                            layer.effect: DropShadow {
                                                transparentBorder: true
                                                radius: 12
                                                samples: 25
                                                color: "#1A000000"
                                            }
                                        }

                                        contentItem: Column {
                                            spacing: 6

                                            Row {
                                                width: parent.width
                                                spacing: 6

                                                SingleLineTextInput {
                                                    id: skillSearchInput
                                                    inputWidth: parent.width - skillSettingPopBtn.width - 6
                                                    inputHeight: 32
                                                    inputRadius: 6
                                                    icon: "qrc:/images/search.png"
                                                    iconSize: 14
                                                    fontSize: 13
                                                    placeholderText: qsTr("搜索技能")
                                                    onTextChanged: dropdownSelectionSkill.searchText = text
                                                }

                                                ImageButton {
                                                    id: skillSettingPopBtn
                                                    source: "qrc:/images/setting.png"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: {
                                                        skillPopup.close()
                                                        window.leftSelectedIndex = 3
                                                    }
                                                }
                                            }

                                            Flickable {
                                                id: skillListFlick
                                                width: parent.width
                                                height: Math.min(skillListCol.height, 300)
                                                contentHeight: skillListCol.height
                                                clip: true
                                                boundsBehavior: Flickable.StopAtBounds

                                                Column {
                                                    id: skillListCol
                                                    width: parent.width
                                                    spacing: 2

                                                    Repeater {
                                                        model: dropdownSelectionSkill.filteredSkills()

                                                        delegate: Rectangle {
                                                            width: skillPopup.width - 16
                                                            height: 36
                                                            radius: 6
                                                            color: skillItemMouse.pressed ? "#14000000"
                                                                 : skillItemMouse.containsMouse ? "#0A000000"
                                                                 : "transparent"
                                                            Behavior on color { ColorAnimation { duration: 100 } }

                                                            Row {
                                                                spacing: 8
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                anchors.left: parent.left
                                                                anchors.leftMargin: 8

                                                                Image {
                                                                    width: 20; height: 20
                                                                    visible: !modelData.emoji
                                                                    source: "qrc:/images/skillIcon.png"

                                                                    fillMode: Image.PreserveAspectFit
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }
                                                                Label {
                                                                    width: 20
                                                                    height: 20
                                                                    visible: modelData.emoji
                                                                    font.pixelSize: 14
                                                                    text: modelData.emoji
                                                                    horizontalAlignment: Text.AlignHCenter
                                                                    verticalAlignment: Text.AlignVCenter
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                                                                }
                                                                Text {
                                                                    id: skilPopNameLabel
                                                                    width: skillPopup.width - 16 - 16 - 20 - 16 - 16
                                                                    text: modelData.name || modelData.skillKey || ""
                                                                    font.pixelSize: 14
                                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                                    color: "#D9000000"
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    elide: Text.ElideRight
                                                                    ToolTip {
                                                                        visible: skillItemMouse.containsMouse && skilPopNameLabel.truncated
                                                                        text: skilPopNameLabel.text
                                                                        delay: 500
                                                                        x: 0
                                                                        y: skilPopNameLabel.height + 4
                                                                        width: Math.min(implicitContentWidth + 20, skillGrid.cellWidth - 40)
                                                                        background: Rectangle {
                                                                            color: "#A6000000"
                                                                            radius: 4
                                                                        }
                                                                        contentItem: Text {
                                                                            text: skilPopNameLabel.text
                                                                            font.pixelSize: 14
                                                                            color: "#FFFFFF"
                                                                            font.family: "Alibaba PuHuiTi 3.0"
                                                                            wrapMode: Text.Wrap
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            Canvas {
                                                                visible: dropdownSelectionSkill.isSelected(modelData.name || modelData.skillKey)
                                                                width: 16; height: 16
                                                                anchors.right: parent.right
                                                                anchors.rightMargin: 8
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                onVisibleChanged: requestPaint()
                                                                onPaint: {
                                                                    var ctx = getContext("2d")
                                                                    ctx.reset()
                                                                    ctx.strokeStyle = "#006BFF"
                                                                    ctx.lineWidth = 2
                                                                    ctx.lineCap = "round"
                                                                    ctx.lineJoin = "round"
                                                                    ctx.beginPath()
                                                                    ctx.moveTo(3, 8)
                                                                    ctx.lineTo(6.5, 11.5)
                                                                    ctx.lineTo(13, 4.5)
                                                                    ctx.stroke()
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: skillItemMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: dropdownSelectionSkill.toggleSkill(modelData.name || modelData.skillKey)
                                                            }
                                                        }
                                                    }
                                                }

                                                ScrollBar.vertical: ScrollBar {
                                                    policy: skillListFlick.contentHeight > skillListFlick.height
                                                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                                    width: 4
                                                    contentItem: Rectangle {
                                                        implicitWidth: 4
                                                        radius: 2
                                                        color: "#40000000"
                                                    }
                                                }
                                            }
                                        }

                                        enter: Transition {
                                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                            NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                        }
                                        exit: Transition {
                                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                                        }
                                    }
                                }
                                Item {
                                    id: dropdownSelectionTool
                                    visible: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 0
                                    height: 36

                                    property var selectedToolIds: []
                                    property string toolSearchText: ""

                                    function syncToolsFromWsClient() {
                                        var arr = []
                                        var list = wsClient.toolList
                                        var isExisting = leftMidPanel.activeAgentId !== ""
                                        if (isExisting) {
                                            for (var i = 0; i < list.length; i++) {
                                                if (list[i].enabled)
                                                    arr.push(list[i].toolId)
                                            }
                                        } else {
                                            for (var i = 0; i < list.length; i++)
                                                arr.push(list[i].toolId)
                                        }
                                        selectedToolIds = arr
                                    }

                                    Connections {
                                        target: wsClient
                                        function onToolListChanged() {
                                            dropdownSelectionTool.syncToolsFromWsClient()
                                        }
                                    }

                                    function isToolSelected(toolId) {
                                        for (var i = 0; i < selectedToolIds.length; i++) {
                                            if (selectedToolIds[i] === toolId) return true
                                        }
                                        return false
                                    }

                                    function toggleToolLocal(toolId) {
                                        var arr = selectedToolIds.slice()
                                        var idx = -1
                                        for (var i = 0; i < arr.length; i++) {
                                            if (arr[i] === toolId) { idx = i; break }
                                        }
                                        if (idx >= 0) arr.splice(idx, 1)
                                        else arr.push(toolId)
                                        selectedToolIds = arr
                                        applyToolSelectionImmediately()
                                    }

                                    /// 勾选/取消后立即同步到网关（或暂存到首个 agent 创建时写入）
                                    function applyToolSelectionImmediately() {
                                        var aid = leftMidPanel.activeAgentId
                                        if (aid === "") {
                                            wsClient.setPendingNewAgentToolSelection(selectedToolIds)
                                            return
                                        }
                                        wsClient.batchSetAgentToolsEnabled(aid, selectedToolIds)
                                    }

                                    function filteredTools() {
                                        var list = wsClient.toolList
                                        if (!toolSearchText) return list
                                        var result = []
                                        var q = toolSearchText.toLowerCase()
                                        for (var i = 0; i < list.length; i++) {
                                            var label = (list[i].label || list[i].toolId || "").toLowerCase()
                                            if (label.indexOf(q) >= 0)
                                                result.push(list[i])
                                        }
                                        return result
                                    }

                                    Rectangle {
                                        id: toolButton2
                                        anchors.fill: parent
                                        radius: 8
                                        readonly property bool toolStripHover: toolIconMouse.containsMouse
                                        color: toolIconMouse.pressed ? "#14000000"
                                             : toolStripHover ? "#0A000000"
                                             : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        MouseArea {
                                            id: toolIconMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: toolPopup2.visible ? toolPopup2.close() : toolPopup2.open()
                                        }
                                        Row {
                                            id: toolBtnRow2
                                            spacing: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12

                                            Item {
                                                id: toolOpenZone
                                                height: 36
                                                width: toolOpenInnerRow.width

                                                Row {
                                                    id: toolOpenInnerRow
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 6

                                                    Image {
                                                        id: toolMainIcon
                                                        source: "qrc:/images/tools.png"
                                                        width: 16
                                                        height: 16
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        fillMode: Image.PreserveAspectFit
                                                        sourceSize: Qt.size(16, 16)
                                                    }

                                                    Text {
                                                        id: toolText
                                                        text: "tools"
                                                        font.pixelSize: 14
                                                        font.family: "Alibaba PuHuiTi 3.0"
                                                        color: "#D9000000"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: toolPopup2.visible
                                                    }

                                                    Rectangle {
                                                        id: toolCountBadge
                                                        visible: dropdownSelectionTool.selectedToolIds.length > 0
                                                        width: toolBadgeText.width + 8
                                                        height: 20
                                                        radius: 10
                                                        color: "#14000000"
                                                        anchors.verticalCenter: parent.verticalCenter

                                                        Text {
                                                            id: toolBadgeText
                                                            text: dropdownSelectionTool.selectedToolIds.length
                                                            font.pixelSize: 12
                                                            font.family: "Alibaba PuHuiTi 3.0"
                                                            color: "#73000000"
                                                            anchors.centerIn: parent
                                                        }
                                                    }
                                                }
                                            }

                                        }
                                    }

                                    Popup {
                                        id: toolPopup2
                                        x: 0
                                        width: 260
                                        padding: 8
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                        function calcY() {
                                            var globalPos = dropdownSelectionTool.mapToItem(null, 0, 0)
                                            var windowH = window.height
                                            var popupH = Math.min(contentItem.implicitHeight, 300 + 80) + padding * 2
                                            if (popupH < 60)
                                                popupH = 400
                                            if (globalPos.y + dropdownSelectionTool.height + 4 + popupH > windowH)
                                                return -popupH - 4
                                            return dropdownSelectionTool.height + 4
                                        }

                                        y: calcY()

                                        onAboutToShow: {
                                            dropdownSelectionTool.syncToolsFromWsClient()
                                            toolSearchInput2.text = ""
                                            y = calcY()
                                        }
                                        onOpened: Qt.callLater(function() { y = calcY() })

                                        background: Rectangle {
                                            color: "#FFFFFF"
                                            radius: 12
                                            border.color: "#14000000"
                                            border.width: 1
                                            layer.enabled: true
                                            layer.effect: DropShadow {
                                                transparentBorder: true
                                                radius: 12
                                                samples: 25
                                                color: "#1A000000"
                                            }
                                        }

                                        contentItem: Column {
                                            spacing: 6
                                            width: toolPopup2.width - 16
                                            Row {
                                                width: parent.width
                                                spacing: 6

                                                SingleLineTextInput {
                                                    id: toolSearchInput2
                                                    inputWidth: parent.width - toolSettingBtn2.width - 6
                                                    inputHeight: 32
                                                    inputRadius: 6
                                                    icon: "qrc:/images/search.png"
                                                    iconSize: 14
                                                    fontSize: 13
                                                    placeholderText: qsTr("搜索工具")
                                                    onTextChanged: dropdownSelectionTool.toolSearchText = text
                                                }

                                                ImageButton {
                                                    id: toolSettingBtn2
                                                    source: "qrc:/images/setting.png"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: {
                                                        toolPopup2.close()
                                                        window.leftSelectedIndex = 4
                                                    }
                                                }
                                            }
                                            Flickable {
                                                id: toolListFlick2
                                                width: parent.width
                                                height: Math.min(toolListCol2.height, 300)
                                                contentHeight: toolListCol2.height
                                                clip: true
                                                boundsBehavior: Flickable.StopAtBounds

                                                Column {
                                                    id: toolListCol2
                                                    width: parent.width
                                                    spacing: 2

                                                    Repeater {
                                                        model: dropdownSelectionTool.filteredTools()

                                                        delegate: Rectangle {
                                                            width: toolPopup2.width - 16
                                                            height: 36
                                                            radius: 6
                                                            color: toolItemMouse2.pressed ? "#14000000"
                                                                 : toolItemMouse2.containsMouse ? "#0A000000"
                                                                 : "transparent"
                                                            Behavior on color { ColorAnimation { duration: 100 } }

                                                            Row {
                                                                spacing: 8
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                anchors.left: parent.left
                                                                anchors.leftMargin: 8

                                                                Text {
                                                                    id: toolPopNameLabel
                                                                    width: toolPopup2.width - 16 - 16 - 16 - 16
                                                                    text: modelData.label || modelData.toolId || ""
                                                                    font.pixelSize: 14
                                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                                    color: "#D9000000"
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    elide: Text.ElideRight
                                                                    ToolTip {
                                                                        visible: toolItemMouse2.containsMouse && toolPopNameLabel.truncated
                                                                        text: toolPopNameLabel.text
                                                                        delay: 500
                                                                        x: 0
                                                                        y: toolPopNameLabel.height + 4
                                                                        background: Rectangle {
                                                                            color: "#A6000000"
                                                                            radius: 4
                                                                        }
                                                                        contentItem: Text {
                                                                            text: toolPopNameLabel.text
                                                                            font.pixelSize: 14
                                                                            color: "#FFFFFF"
                                                                            font.family: "Alibaba PuHuiTi 3.0"
                                                                            wrapMode: Text.Wrap
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            Canvas {
                                                                visible: dropdownSelectionTool.isToolSelected(modelData.toolId)
                                                                width: 16; height: 16
                                                                anchors.right: parent.right
                                                                anchors.rightMargin: 8
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                onVisibleChanged: requestPaint()
                                                                onPaint: {
                                                                    var ctx = getContext("2d")
                                                                    ctx.reset()
                                                                    ctx.strokeStyle = "#006BFF"
                                                                    ctx.lineWidth = 2
                                                                    ctx.lineCap = "round"
                                                                    ctx.lineJoin = "round"
                                                                    ctx.beginPath()
                                                                    ctx.moveTo(3, 8)
                                                                    ctx.lineTo(6.5, 11.5)
                                                                    ctx.lineTo(13, 4.5)
                                                                    ctx.stroke()
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: toolItemMouse2
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: dropdownSelectionTool.toggleToolLocal(modelData.toolId)
                                                            }
                                                        }
                                                    }
                                                }

                                                ScrollBar.vertical: ScrollBar {
                                                    policy: toolListFlick2.contentHeight > toolListFlick2.height
                                                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                                    width: 4
                                                    contentItem: Rectangle {
                                                        implicitWidth: 4
                                                        radius: 2
                                                        color: "#40000000"
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: dropdownSelectionTool.filteredTools().length === 0
                                                text: dropdownSelectionTool.toolSearchText
                                                      ? qsTr("未找到匹配的工具")
                                                      : qsTr("暂无可用工具")
                                                font.pixelSize: 13
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#80000000"
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                topPadding: 16
                                                bottomPadding: 16
                                            }
                                        }

                                        enter: Transition {
                                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                            NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                        }
                                        exit: Transition {
                                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                                        }
                                    }
                                }
                                Rectangle{
                                    width: Math.max(0, parent.width - workspaceDialogSlot.width
                                                    - dropdownSelectionModel.width
                                                    - expertSelectionTag.width
                                                    - inputLeftRow.width - 4 * 4)
                                    height: 1
                                }
                                Row{
                                    id: inputLeftRow
                                    height: parent.height
                                    spacing: 24
                                    ImageButton{
                                        id: uploadBtn
                                        source: "qrc:/images/paperclip.png"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: uploadMenu.open()

                                        Popup {
                                            id: uploadMenu
                                            y: -uploadMenu.height - 8
                                            x: -20
                                            width: 130
                                            padding: 4
                                            background: Rectangle {
                                                radius: 8
                                                color: "#FFFFFF"
                                                border.color: "#14000000"
                                                border.width: 1
                                                layer.enabled: true
                                                layer.effect: DropShadow {
                                                    radius: 12; samples: 25
                                                    color: "#26000000"
                                                    verticalOffset: 4
                                                }
                                            }
                                            Column {
                                                width: parent.width
                                                Rectangle {
                                                    width: parent.width; height: 34; radius: 6
                                                    color: umFile.containsMouse ? "#F0F2F5" : "transparent"
                                                    Label {
                                                        text: qsTr("上传文件")
                                                        font.pixelSize: 14; color: "#D9000000"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.left: parent.left; anchors.leftMargin: 10
                                                    }
                                                    MouseArea {
                                                        id: umFile; anchors.fill: parent
                                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: { uploadMenu.close(); attachFileDialog.open() }
                                                    }
                                                }
                                                Rectangle {
                                                    width: parent.width; height: 34; radius: 6
                                                    color: umFolder.containsMouse ? "#F0F2F5" : "transparent"
                                                    Label {
                                                        text: qsTr("上传文件夹")
                                                        font.pixelSize: 14; color: "#D9000000"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.left: parent.left; anchors.leftMargin: 10
                                                    }
                                                    MouseArea {
                                                        id: umFolder; anchors.fill: parent
                                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: { uploadMenu.close(); attachFolderDialog.open() }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    FileDialog {
                                        id: attachFileDialog
                                        title: qsTr("选择文件")
                                        selectMultiple: true
                                        onAccepted: {
                                            for (var i = 0; i < fileUrls.length; i++) {
                                                var url = fileUrls[i].toString()
                                                var path = url.replace(/^file:\/\/\//, "")
                                                var parts = path.split("/")
                                                var name = decodeURIComponent(parts[parts.length - 1] || "")
                                                var dotIdx = name.lastIndexOf(".")
                                                var ext = dotIdx >= 0 ? name.substring(dotIdx + 1).toUpperCase() : ""
                                                var imgExts = ["JPG", "JPEG", "PNG", "GIF", "BMP", "WEBP"]
                                                var isImg = imgExts.indexOf(ext) >= 0
                                                var size = $MainViewController.fileSizeHuman(url)
                                                attachmentModel.append({
                                                    fileName: name,
                                                    filePath: isImg ? url : "",
                                                    fileUrl: url,
                                                    fileSize: size,
                                                    ext: ext,
                                                    isImage: isImg
                                                })
                                            }
                                        }
                                    }
                                    FileDialog {
                                        id: attachFolderDialog
                                        title: qsTr("选择文件夹")
                                        selectFolder: true
                                        onAccepted: {
                                            var url = fileUrl.toString()
                                            var path = url.replace(/^file:\/\/\//, "")
                                            var parts = path.split("/")
                                            var name = decodeURIComponent(parts[parts.length - 1] || "folder")
                                            var size = $MainViewController.fileSizeHuman(url)
                                            attachmentModel.append({
                                                fileName: name,
                                                filePath: "",
                                                fileUrl: url,
                                                fileSize: size,
                                                ext: "",
                                                isImage: false,
                                                isFolder: true
                                            })
                                        }
                                    }
                                    Rectangle{
                                        width: 1
                                        height: 16
                                        color: "#1F000000"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    CustomButton{
                                        id: sendBtnRec
                                        buttonWidth: 40
                                        buttonHeight: 40
                                        buttonRadius: 12
                                        text: ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        enabled: textInputArea.text !== "" && newTaskRec.viewingControllerSession
                                        backgroundColor: "#006BFF"
                                        iconSource: "qrc:/images/send.png"
                                        onClicked: newTaskRec.doSendMessage()
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: welcomeShortcutStrip
                    visible: newTaskRec.isNewTaskWelcome
                    width: 960
                    height: visible ? shortcutTopRow.height
                                      + (newTaskRec.selectedShortcut
                                         ? 52 + shortcutCardRow.implicitHeight : 0) : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: chatInputContainer.y + chatInputContainer.height + 18

                    Row {
                        id: shortcutTopRow
                        height: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Repeater {
                            model: newTaskRec.shortcutGroups

                            delegate: Rectangle {
                                id: shortcutTab
                                readonly property var group: modelData
                                readonly property bool selected: index === newTaskRec.selectedShortcutGroup
                                width: tabContent.implicitWidth + 32
                                height: 40
                                radius: 20
                                color: selected ? group.color
                                      : tabMouse.containsMouse ? "#F7F9FA" : "#FFFFFF"
                                border.width: 1
                                border.color: selected ? group.color : "#E6E7EB"

                                Row {
                                    id: tabContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Image {
                                        width: 20
                                        height: 20
                                        source: group.icon
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize: Qt.size(20, 20)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Label {
                                        text: group.title
                                        font.pixelSize: 16
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        color: "#D9000000"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: tabMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: newTaskRec.selectedShortcutGroup = index
                                }
                            }
                        }
                    }

                    Row {
                        id: shortcutCardRow
                        anchors.top: shortcutTopRow.bottom
                        anchors.topMargin: 52
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18

                        Repeater {
                            model: newTaskRec.selectedShortcut ? newTaskRec.selectedShortcut.cards : []

                            delegate: Rectangle {
                                id: shortcutLargeCard
                                readonly property var card: modelData
                                width: 300
                                height: cardContent.implicitHeight + 32
                                radius: 8
                                color: largeCardMouse.containsMouse ? "#FAFBFC" : "#FFFFFF"
                                border.width: 1
                                border.color: largeCardMouse.containsMouse ? "#B8CFFF" : "#E1E4E8"
                                clip: true

                                Column {
                                    id: cardContent
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 16
                                    width: 268
                                    spacing: 8

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Row {
                                            width: parent.width
                                            spacing: 5

                                            Image {
                                                width: 20
                                                height: 20
                                                source: card.icon
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize: Qt.size(20, 20)
                                            }

                                            Label {
                                                width: parent.width - 25
                                                text: card.title
                                                font.pixelSize: 16
                                                font.bold: true
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#D9000000"
                                                maximumLineCount: 1
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Label {
                                            width: parent.width
                                            text: card.detail
                                            font.pixelSize: 14
                                            font.family: "Alibaba PuHuiTi 3.0"
                                            color: "#73000000"
                                            wrapMode: Text.Wrap
                                            lineHeight: 1.35
                                        }
                                    }

                                    Image {
                                        width: 268
                                        height: 90
                                        source: card.image
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize: Qt.size(268, 90)
                                    }
                                }

                                MouseArea {
                                    id: largeCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        textInputArea.text = card.prompt
                                        textInputArea.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: workspaceHiddenSlot
                width: 1
                height: 1
                visible: false
                anchors.top: parent.top
                anchors.left: parent.left
            }

            Item {
                id: dropdownSelectionWorkSpace
                width: 137
                height: 36
                z: 10

                readonly property string wsPlaceState: newTaskRec.isNewTaskWelcome ? "dialog"
                    : ((window.leftSelectedIndex === 0 || window.leftSelectedIndex === 6) ? "topbar" : "hidden")

                state: wsPlaceState

                states: [
                    State {
                        name: "dialog"
                        PropertyChanges { target: dropdownSelectionWorkSpace; visible: true }
                        ParentChange {
                            target: dropdownSelectionWorkSpace
                            parent: workspaceDialogSlot
                        }
                        AnchorChanges {
                            target: dropdownSelectionWorkSpace
                            anchors.left: workspaceDialogSlot.left
                            anchors.right: workspaceDialogSlot.right
                            anchors.top: workspaceDialogSlot.top
                            anchors.bottom: workspaceDialogSlot.bottom
                        }
                    },
                    State {
                        name: "topbar"
                        PropertyChanges { target: dropdownSelectionWorkSpace; visible: true }
                        ParentChange {
                            target: dropdownSelectionWorkSpace
                            parent: workspaceTopBarSlot
                        }
                        AnchorChanges {
                            target: dropdownSelectionWorkSpace
                            anchors.verticalCenter: workspaceTopBarSlot.verticalCenter
                            anchors.horizontalCenter: workspaceTopBarSlot.horizontalCenter
                        }
                    },
                    State {
                        name: "hidden"
                        PropertyChanges { target: dropdownSelectionWorkSpace; visible: false }
                        ParentChange {
                            target: dropdownSelectionWorkSpace
                            parent: workspaceHiddenSlot
                        }
                    }
                ]

                property string currentText: qsTr("workspace")
                property string absolutePath: ""
                property var recentFolders: []

                readonly property bool pickerLocked: newTaskRec.hasMessages || window.leftSelectedIndex === 6
                readonly property string effectiveWorkspacePath: {
                    if (pickerLocked) {
                        var taskWs = wsClient.currentTaskWorkspace || ""
                        if (taskWs)
                            return String(taskWs)
                        return ""
                    }
                    return absolutePath || ""
                }

                readonly property string displayText: {
                    if (pickerLocked) {
                        var w = dropdownSelectionWorkSpace.effectiveWorkspacePath
                        w = String(w).replace(/\\/g, "/")
                        if (!w)
                            return qsTr("workspace")
                        var segs = w.split("/")
                        return segs[segs.length - 1] || w
                    }
                    return currentText
                }

                readonly property bool hasWorkspaceSelected: effectiveWorkspacePath.length > 0

                function resetPicker() {
                    absolutePath = ""
                    currentText = qsTr("workspace")
                }

                Connections {
                    target: chatModel
                    function onCountChanged() {
                        if (chatModel.count === 0)
                            dropdownSelectionWorkSpace.resetPicker()
                    }
                }

                Rectangle {
                    id: wsButton
                    anchors.fill: parent
                    radius: 8
                    opacity: dropdownSelectionWorkSpace.pickerLocked ? 0.85 : 1
                    color: wsMouseArea.pressed ? "#14000000"
                         : wsMouseArea.containsMouse ? "#0A000000"
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    ToolTip {
                        id: wsToolTip
                        visible: wsMouseArea.containsMouse
                                 && (dropdownSelectionWorkSpace.hasWorkspaceSelected
                                     ? dropdownSelectionWorkSpace.pickerLocked
                                     : true)
                        text: dropdownSelectionWorkSpace.hasWorkspaceSelected
                            ? dropdownSelectionWorkSpace.effectiveWorkspacePath
                            : qsTr("input+output储存空间")
                        delay: 400
                        background: Rectangle { color: "#A6000000"; radius: 4 }
                        contentItem: Text {
                            text: wsToolTip.text
                            font.pixelSize: 14
                            color: "#FFFFFF"
                            font.family: "Alibaba PuHuiTi 3.0"
                            wrapMode: Text.Wrap
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: dropdownSelectionWorkSpace.pickerLocked ? 0 : (-wsChevron.width / 2 - 2)

                        Image {
                            source: "qrc:/images/folder.png"
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(16, 16)
                        }
                        Text {
                            text: dropdownSelectionWorkSpace.displayText
                            width: Math.min(implicitWidth, 90)
                            elide: Text.ElideMiddle
                            font.pixelSize: 14
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: "#D9000000"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Canvas {
                        id: wsChevron
                        visible: !dropdownSelectionWorkSpace.pickerLocked
                        width: 16; height: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        rotation: wsPopup.visible ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#80000000"
                            ctx.lineWidth = 1.5
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(4, 6)
                            ctx.lineTo(8, 10)
                            ctx.lineTo(12, 6)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        id: wsMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: dropdownSelectionWorkSpace.pickerLocked ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (dropdownSelectionWorkSpace.pickerLocked)
                                return
                            wsPopup.visible ? wsPopup.close() : wsPopup.open()
                        }
                    }
                }

                Popup {
                    id: wsPopup
                    x: 0
                    width: 200
                    padding: 8

                    function calcY() {
                        var globalPos = dropdownSelectionWorkSpace.mapToItem(null, 0, 0)
                        var windowH = window.height
                        var popupH = contentItem.implicitHeight + padding * 2
                        if (globalPos.y + dropdownSelectionWorkSpace.height + 4 + popupH > windowH)
                            return -popupH - 4
                        return dropdownSelectionWorkSpace.height + 4
                    }

                    y: calcY()
                    onAboutToShow: y = calcY()

                    background: Rectangle {
                        radius: 8
                        color: "#FFFFFF"
                        border.color: "#14000000"
                        border.width: 1
                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            radius: 12
                            samples: 25
                            color: "#1A000000"
                        }
                    }

                    contentItem: Column {
                        spacing: 0

                        Rectangle {
                            width: wsPopup.width - 16
                            height: 36
                            radius: 6
                            color: wsOpenMouse.pressed ? "#14000000"
                                 : wsOpenMouse.containsMouse ? "#0A000000"
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                spacing: 8
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12

                                Image {
                                    source: "qrc:/images/folder.png"
                                    width: 18; height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(18, 18)
                                }
                                Text {
                                    text: qsTr("打开文件夹")
                                    font.pixelSize: 14
                                    font.family: "Alibaba PuHuiTi 3.0"
                                    color: "#D9000000"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: wsOpenMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wsPopup.close()
                                    folderDialogWorkSpace.open()
                                }
                            }
                        }
                        Item { width: 1; height: 8; visible: dropdownSelectionWorkSpace.recentFolders.length > 0}
                        Rectangle {
                            width: wsPopup.width - 16
                            height: 1
                            color: "#EBEDF0"
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: dropdownSelectionWorkSpace.recentFolders.length > 0
                        }

                        Item { width: 1; height: 8; visible: dropdownSelectionWorkSpace.recentFolders.length > 0 }

                        Text {
                            text: qsTr("最近")
                            font.pixelSize: 12
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: "#73000000"
                            leftPadding: 12
                            visible: dropdownSelectionWorkSpace.recentFolders.length > 0
                        }

                        Item { width: 1; height: 8; visible: dropdownSelectionWorkSpace.recentFolders.length > 0}

                        Repeater {
                            visible: dropdownSelectionWorkSpace.recentFolders.length > 0
                            model: dropdownSelectionWorkSpace.recentFolders
                            delegate: Rectangle {
                                width: wsPopup.width - 8
                                height: 36
                                radius: 6
                                color: recentMouse.pressed ? "#14000000"
                                     : recentMouse.containsMouse ? "#0A000000"
                                     : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12

                                    Image {
                                        source: "qrc:/images/folder.png"
                                        width: 18; height: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize: Qt.size(18, 18)
                                    }
                                    Text {
                                        text: modelData
                                        font.pixelSize: 14
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        color: "#D9000000"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: recentMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dropdownSelectionWorkSpace.currentText = modelData
                                        wsPopup.close()
                                    }
                                }
                            }
                        }
                    }

                    enter: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                    }
                    exit: Transition {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                    }
                }

                FileDialog {
                    id: folderDialogWorkSpace
                    title: qsTr("选择文件夹")
                    selectFolder: true
                    onAccepted: {
                        var url = folderDialogWorkSpace.fileUrl.toString()
                        var path = decodeURIComponent(url.replace(/^file:\/{2,3}/, ""))
                        if (Qt.platform.os === "windows") {
                        if (path.length >= 3 && path.charAt(0) === "/" && path.charAt(2) === ":")
                            path = path.substring(1)
                        path = path.replace(/\//g, "\\")
                        }else if(Qt.platform.os === "linux"){
                            path = "/" + path
                        }
                        dropdownSelectionWorkSpace.absolutePath = path
                        var parts = path.replace(/\\/g, "/").split("/")
                        dropdownSelectionWorkSpace.currentText = parts[parts.length - 1] || path
                    }
                }
            }

            Rectangle{
                id: scheduledTaskRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 1

                // 调度类型显示名映射
                function scheduleDisplay(kind, expr) {
                    if (kind === "cron") {
                        if (expr === "0 * * * *") return "每小时"
                        if (/^[\d]+ [\d]+ \* \* \*$/.test(expr)) return "每天"
                        if (/^[\d]+ [\d]+ \* \* [0-6,-]+$/.test(expr)) return "每周"
                        return "cron: " + expr
                    }
                    if (kind === "every") {
                        var ms = parseInt(expr)
                        if (ms >= 86400000) return "每 " + Math.round(ms/86400000) + " 天"
                        if (ms >= 3600000) return "每 " + Math.round(ms/3600000) + " 小时"
                        if (ms >= 60000) return "每 " + Math.round(ms/60000) + " 分钟"
                        return "每 " + Math.round(ms/1000) + " 秒"
                    }
                    if (kind === "at") return "不重复"
                    return kind || "未知"
                }

                Column{
                    anchors.fill: parent
                    leftPadding: 60
                    topPadding: 24
                    rightPadding: 60
                    spacing: 16
                    Rectangle{
                        id: scheduledTaskTitleRec
                        height: scheduledTaskTitle.height
                        width: parent.width - 120
                        Column{
                            id: scheduledTaskTitle
                            spacing: 8
                            anchors.left: parent.left
                            Label{
                                text: qsTr("定时任务")
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }
                            Label{
                                text: qsTr("可设置task开机联网后定时启动")
                                font.pixelSize: 12
                                color: "#A6000000"
                            }
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            CustomButton{
                                width: 80
                                height: 36
                                backgroundColor: "#0F006BFF"
                                textColor: "#006BFF"
                                borderWidth: 0
                                text: "+ 新建"
                                fontSize: 14
                                onClicked: {
                                    window.editingCronJobId = ""
                                    window.editingCronPayloadKind = "agentTurn"
                                    window.editingCronScheduleKind = ""
                                    window.editingCronScheduleExpr = ""
                                    window.editingCronScheduleTz   = ""
                                    newTaskTitleInput.text = ""
                                    newTaskPromptInput.text = ""
                                    newTaskRepeatSelect.currentIndex = 0
                                    newTaskIntervalInput.text = ""
                                    newTaskDialog.open()
                                }
                            }
                        }
                    }
                    TabBarView{
                        id: scheduledTaskTab
                        lineWidth: parent.width - 120
                        tabs: [ { text: "任务", badge: wsClient.cronJobs.length }, { text: "历史" }]
                        onTabClicked: {
                            if (index === 1) wsClient.loadCronRuns()
                        }
                    }

                    // ═══════════ 任务 Tab ═══════════
                    ScrollView {
                        id: scheduledTaskScrollView
                        width: parent.width
                        height: parent.height - 32 - scheduledTaskTitleRec.height - scheduledTaskTab.height - 24
                        clip: true
                        visible: scheduledTaskTab.currentIndex === 0
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        Column{
                            spacing: 12
                            width: parent.width

                            // 空状态
                            Rectangle {
                                width: scheduledTaskScrollView.width - 120
                                height: 120
                                visible: wsClient.cronJobs.length === 0
                                color: "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: qsTr("暂无定时任务，点击「+ 新建」创建第一个任务")
                                    font.pixelSize: 14
                                    color: "#A6000000"
                                }
                            }

                            Repeater{
                                model: wsClient.cronJobs
                                delegate: Rectangle {
                                    id: cronJobRow
                                    property var job: modelData
                                    width: scheduledTaskScrollView.width - 120
                                    height: 76
                                    radius: 8
                                    color: taskItemMouse.containsMouse ? "#F0F2F5" : "#F7F9FA"

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MouseArea {
                                        id: taskItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.right: taskRightRow.left
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Label {
                                            text: cronJobRow.job.name || ""
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            color: cronJobRow.job.enabled ? "#D9000000" : "#80000000"
                                            width: parent.width
                                            elide: Text.ElideRight
                                        }
                                        Row {
                                            spacing: 8
                                            Label {
                                                text: scheduledTaskRec.scheduleDisplay(
                                                          cronJobRow.job.scheduleKind || "",
                                                          cronJobRow.job.scheduleExpr || "")
                                                font.pixelSize: 14
                                                color: "#73000000"
                                            }
                                            Label {
                                                text: {
                                                    var next = cronJobRow.job.nextRunAt || ""
                                                    if (next) return "下次: " + next.replace("T", " ").substring(0, 16)
                                                    var last = cronJobRow.job.lastRunAt || ""
                                                    if (last) return "上次: " + last.replace("T", " ").substring(0, 16)
                                                    return ""
                                                }
                                                font.pixelSize: 14
                                                color: "#73000000"
                                                visible: text !== ""
                                            }
                                            // 载荷类型标签
                                            Rectangle {
                                                visible: (cronJobRow.job.payloadKind || "") === "systemEvent"
                                                width: sysLabel.implicitWidth + 12
                                                height: 20
                                                radius: 4
                                                color: "#0FFF8800"
                                                anchors.verticalCenter: parent.verticalCenter
                                                Label {
                                                    id: sysLabel
                                                    text: "系统事件"
                                                    font.pixelSize: 11
                                                    color: "#FF8800"
                                                    anchors.centerIn: parent
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        id: taskRightRow
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 40
                                        height: 22

                                        ImageButton {
                                            id: cronMoreBtn
                                            source: "qrc:/images/more.png"
                                            width: 20; height: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: cronRowMoreMenu.open()
                                        }

                                        Popup {
                                            id: cronRowMoreMenu
                                            parent: cronMoreBtn
                                            x: parent.width - width
                                            y: parent.height + 4
                                            width: 156
                                            padding: 8
                                            modal: false
                                            closePolicy: Popup.CloseOnPressOutside
                                            background: Rectangle {
                                                radius: 8
                                                color: "#FFFFFF"
                                                border.color: "#14000000"
                                                border.width: 1
                                            }
                                            contentItem: Column {
                                                spacing: 2
                                                // 立即运行
                                                Rectangle {
                                                    width: 140
                                                    height: 36
                                                    radius: 6
                                                    color: miRun.pressed ? "#14000000"
                                                         : miRun.containsMouse ? "#EBEDF0" : "transparent"
                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        Image{
                                                            width: 16
                                                            height: 16
                                                            source: "qrc:/images/play.png"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        Label {
                                                            text: qsTr("立即运行")
                                                            font.pixelSize: 14
                                                            color: "#D9000000"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: miRun
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            cronRowMoreMenu.close()
                                                            wsClient.runCronJobNow(cronJobRow.job.id)
                                                        }
                                                    }
                                                }
                                                // 编辑
                                                Rectangle {
                                                    width: 140
                                                    height: 36
                                                    radius: 6
                                                    color: miEdit.pressed ? "#14000000"
                                                         : miEdit.containsMouse ? "#EBEDF0" : "transparent"
                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        Image{
                                                            width: 16
                                                            height: 16
                                                            source: "qrc:/images/edit.png"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        Label {
                                                            text: qsTr("编辑")
                                                            font.pixelSize: 14
                                                            color: "#D9000000"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: miEdit
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            cronRowMoreMenu.close()
                                                            window.editingCronJobId = cronJobRow.job.id
                                                            window.editingCronPayloadKind = cronJobRow.job.payloadKind || "agentTurn"
                                                            window.editingCronScheduleKind = cronJobRow.job.scheduleKind || ""
                                                            window.editingCronScheduleExpr = cronJobRow.job.scheduleExpr || ""
                                                            window.editingCronScheduleTz   = cronJobRow.job.scheduleTz || ""
                                                            newTaskTitleInput.text = cronJobRow.job.name || ""
                                                            newTaskPromptInput.text = cronJobRow.job.payloadMessage || ""

                                                            var sk = window.editingCronScheduleKind
                                                            var expr = window.editingCronScheduleExpr
                                                            if (sk === "at") {
                                                                newTaskRepeatSelect.currentIndex = 0
                                                                if (expr) {
                                                                    var dt = new Date(expr)
                                                                    if (!isNaN(dt.getTime())) {
                                                                        newTaskDatePicker.selectedYear = dt.getFullYear()
                                                                        newTaskDatePicker.selectedMonth = dt.getMonth() + 1
                                                                        newTaskDatePicker.selectedDay = dt.getDate()
                                                                        newTaskTimePicker.selectedHour = dt.getHours()
                                                                        newTaskTimePicker.selectedMinute = dt.getMinutes()
                                                                    }
                                                                }
                                                            } else if (sk === "every") {
                                                                newTaskRepeatSelect.currentIndex = 4
                                                                var sec = Math.round(parseInt(expr) / 1000)
                                                                newTaskIntervalInput.text = sec > 0 ? String(sec) : ""
                                                            } else if (sk === "cron" && expr) {
                                                                var parts = expr.split(" ")
                                                                var mm = parseInt(parts[0]) || 0
                                                                var hh = parseInt(parts[1]) || 0
                                                                if (parts.length >= 5 && parts[4] !== "*") {
                                                                    newTaskRepeatSelect.currentIndex = 2
                                                                } else if (parts[1] === "*") {
                                                                    newTaskRepeatSelect.currentIndex = 3
                                                                } else {
                                                                    newTaskRepeatSelect.currentIndex = 1
                                                                }
                                                                newTaskTimePicker.selectedHour = hh
                                                                newTaskTimePicker.selectedMinute = mm
                                                            }
                                                            newTaskDialog.open()
                                                        }
                                                    }
                                                }
                                                // 删除
                                                Rectangle {
                                                    width: 140
                                                    height: 36
                                                    radius: 6
                                                    color: miDel.pressed ? "#14000000"
                                                         : miDel.containsMouse ? "#EBEDF0" : "transparent"
                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        Image{
                                                            width: 16
                                                            height: 16
                                                            source: "qrc:/images/delete.png"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        Label {
                                                            text: qsTr("删除")
                                                            font.pixelSize: 14
                                                            color: "#FF3D40"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: miDel
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            cronRowMoreMenu.close()
                                                            window.pendingDeleteCronJobId = cronJobRow.job.id
                                                            window.pendingDeleteCronJobName = cronJobRow.job.name || ""
                                                            deleteCronJobPopup.open()
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 开关（checked 不能绑定 model，否则与点击互斥；用 guard 与列表刷新同步）
                                        Switch {
                                            id: taskSwitch
                                            property bool _syncGuard: false
                                            function syncFromModel() {
                                                _syncGuard = true
                                                checked = (cronJobRow.job.enabled === true)
                                                _syncGuard = false
                                            }
                                            Component.onCompleted: syncFromModel()
                                            Connections {
                                                target: wsClient
                                                function onCronJobsChanged() {
                                                    taskSwitch.syncFromModel()
                                                }
                                            }
                                            onCheckedChanged: {
                                                if (_syncGuard)
                                                    return
                                                wsClient.setCronJobEnabled(cronJobRow.job.id, checked)
                                            }
                                            anchors.verticalCenter: parent.verticalCenter
                                            indicator: Rectangle {
                                                implicitWidth: 44
                                                implicitHeight: 22
                                                x: taskSwitch.leftPadding
                                                y: parent.height / 2 - height / 2
                                                radius: 12
                                                color: taskSwitch.checked ? "#006BFF" : "#D9D9D9"

                                                Behavior on color {
                                                    ColorAnimation { duration: 150 }
                                                }

                                                Rectangle {
                                                    x: taskSwitch.checked ? parent.width - width - 3 : 3
                                                    y: parent.height / 2 - height / 2
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: "#FFFFFF"

                                                    Behavior on x {
                                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ 历史 Tab ═══════════
                    ScrollView {
                        id: cronHistoryScrollView
                        width: parent.width
                        height: parent.height - 32 - scheduledTaskTitleRec.height - scheduledTaskTab.height - 24
                        clip: true
                        visible: scheduledTaskTab.currentIndex === 1
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        Column {
                            spacing: 8
                            width: parent.width

                            Rectangle {
                                width: cronHistoryScrollView.width - 120
                                height: 120
                                visible: cronRunsModel.count === 0
                                color: "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: qsTr("暂无执行记录")
                                    font.pixelSize: 14
                                    color: "#A6000000"
                                }
                            }

                            Repeater {
                                model: cronRunsModel

                                delegate: Rectangle {
                                    id: historyRow
                                    property var run: model
                                    width: cronHistoryScrollView.width - 120
                                    height: 76
                                    radius: 8
                                    color: historyHover.containsMouse ? "#F0F2F5" : "#F7F9FA"

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MouseArea {
                                        id: historyHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.right: historyRightCol.left
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12

                                        Rectangle {
                                            width: 10; height: 10; radius: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: {
                                                var s = historyRow.run.status || ""
                                                if (s === "ok") return "#22C55E"
                                                if (s === "error") return "#EF4444"
                                                if (s === "skipped") return "#F59E0B"
                                                return "#D9D9D9"
                                            }
                                        }

                                        Column {
                                            spacing: 4
                                            width: parent.width - 22

                                            Label {
                                                text: historyRow.run.jobName || historyRow.run.jobId || ""
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                color: "#D9000000"
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                spacing: 8

                                                Rectangle {
                                                    width: historyStatusText.implicitWidth + 12
                                                    height: 20
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: {
                                                        var s = historyRow.run.status || ""
                                                        if (s === "ok") return "#0F22C55E"
                                                        if (s === "error") return "#0FEF4444"
                                                        if (s === "skipped") return "#0FF59E0B"
                                                        return "#0A000000"
                                                    }
                                                Label {
                                                        id: historyStatusText
                                                        anchors.centerIn: parent
                                                    text: {
                                                            var s = historyRow.run.status || ""
                                                        if (s === "ok") return "成功"
                                                        if (s === "error") return "失败"
                                                        if (s === "skipped") return "跳过"
                                                        return s
                                                    }
                                                        font.pixelSize: 11
                                                    color: {
                                                            var s = historyRow.run.status || ""
                                                        if (s === "ok") return "#22C55E"
                                                        if (s === "error") return "#EF4444"
                                                            if (s === "skipped") return "#F59E0B"
                                                        return "#73000000"
                                                    }
                                                }
                                                }

                                                Rectangle {
                                                    visible: {
                                                        var d = historyRow.run.deliveryStatus || ""
                                                        return d !== "" && d !== "not-requested"
                                                    }
                                                    width: deliveryLabel.implicitWidth + 12
                                                    height: 20
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: {
                                                        var d = historyRow.run.deliveryStatus || ""
                                                        if (d === "delivered") return "#0F006BFF"
                                                        return "#0A000000"
                                                }
                                                Label {
                                                        id: deliveryLabel
                                                        anchors.centerIn: parent
                                                        text: {
                                                            var d = historyRow.run.deliveryStatus || ""
                                                            if (d === "delivered") return "已投递"
                                                            if (d === "not-delivered") return "未投递"
                                                            if (d === "unknown") return "投递未知"
                                                            return d
                                                        }
                                                        font.pixelSize: 11
                                                        color: {
                                                            var d = historyRow.run.deliveryStatus || ""
                                                            if (d === "delivered") return "#006BFF"
                                                            return "#73000000"
                                                        }
                                                    }
                                                }

                                                Label {
                                                    text: (historyRow.run.startedAt || "").replace("T", " ").substring(0, 19)
                                                    font.pixelSize: 14
                                                    color: "#73000000"
                                                    visible: (historyRow.run.startedAt || "") !== ""
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Label {
                                                    text: {
                                                        var ms = historyRow.run.durationMs || 0
                                                        if (ms <= 0) return ""
                                                        if (ms < 1000) return ms + " ms"
                                                        var sec = (ms / 1000).toFixed(1)
                                                        return sec + " s"
                                                    }
                                                    font.pixelSize: 14
                                                    color: "#A6000000"
                                                    visible: text !== ""
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        id: historyRightCol
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: historyErrorLabel.visible ? Math.min(historyErrorLabel.implicitWidth, 240) : 0
                                        spacing: 0

                                        Label {
                                            id: historyErrorLabel
                                            text: historyRow.run.error || ""
                                        font.pixelSize: 12
                                        color: "#EF4444"
                                            visible: (historyRow.run.error || "") !== ""
                                            width: parent.width
                                        elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignRight

                                            ToolTip {
                                                visible: historyErrorHover.containsMouse && historyErrorLabel.truncated
                                                text: historyErrorLabel.text
                                                delay: 500
                                                x: -width + historyErrorLabel.width
                                                y: -height - 4
                                                width: Math.min(implicitContentWidth + 20, 360)
                                                background: Rectangle {
                                                    color: "#A6000000"
                                                    radius: 4
                                                }
                                                contentItem: Text {
                                                    text: historyErrorLabel.text
                                                    font.pixelSize: 14
                                                    color: "#FFFFFF"
                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                            MouseArea {
                                                id: historyErrorHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: capabilityHubHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 64
                visible: window.leftSelectedIndex >= 2 && window.leftSelectedIndex <= 4
                z: 2

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: [qsTr("专家"), qsTr("技能"), qsTr("工具")]
                        delegate: Rectangle {
                            readonly property int pageIndex: index + 2
                            width: 76
                            height: 36
                            radius: 6
                            color: window.leftSelectedIndex === pageIndex ? "#F0F1F4"
                                 : hubTabMouse.containsMouse ? "#F7F8FA" : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 16
                                font.weight: window.leftSelectedIndex === parent.pageIndex
                                             ? Font.Bold : Font.Medium
                                color: window.leftSelectedIndex === parent.pageIndex
                                     ? "#D9000000" : "#99000000"
                            }

                            MouseArea {
                                id: hubTabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.leftSelectedIndex = parent.pageIndex
                            }
                        }
                    }
                }

                SingleLineTextInput {
                    visible: window.leftSelectedIndex === 2
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    inputWidth: Math.min(220, capabilityHubHeader.width * 0.24)
                    inputHeight: 36
                    icon: "qrc:/images/search.png"
                    iconSize: 16
                    placeholderText: qsTr("搜索专家...")
                    onTextChanged: agentManageRec.searchText = text
                }

                SingleLineTextInput {
                    visible: window.leftSelectedIndex === 4
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    inputWidth: Math.min(220, capabilityHubHeader.width * 0.24)
                    inputHeight: 36
                    icon: "qrc:/images/search.png"
                    iconSize: 16
                    placeholderText: qsTr("搜索工具...")
                    onTextChanged: toolsSettingRec.toolSearchText = text
                }

                Row {
                    visible: window.leftSelectedIndex === 3
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    SingleLineTextInput {
                        inputWidth: Math.min(220, capabilityHubHeader.width * 0.24)
                        inputHeight: 36
                        icon: "qrc:/images/search.png"
                        iconSize: 16
                        placeholderText: qsTr("搜索技能...")
                        onTextChanged: skillSettingRec.skillSearchText = text
                    }

                    Item {
                        width: 80
                        height: 36

                        CustomButton {
                            id: addSkillBtn
                            anchors.fill: parent
                            backgroundColor: "#0F006BFF"
                            textColor: "#006BFF"
                            borderWidth: 0
                            text: "+ 添加"
                            fontSize: 14
                            onClicked: addSkillMenu.visible ? addSkillMenu.close() : addSkillMenu.open()
                        }

                        Popup {
                            id: addSkillMenu
                            y: addSkillBtn.height + 4
                            x: parent.width - width
                            width: 180
                            padding: 4

                            background: Rectangle {
                                radius: 8
                                color: "#FFFFFF"
                                border.color: "#14000000"
                                border.width: 1
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    transparentBorder: true
                                    radius: 12
                                    samples: 25
                                    color: "#1A000000"
                                }
                            }

                            contentItem: Column {
                                spacing: 2

                                Repeater {
                                    model: [
                                        { text: "上传 .ZIP", icon: "qrc:/images/upload.png" },
                                        { text: "上传文件夹", icon: "qrc:/images/folder.png" },
                                        { text: "从 GitHub 导入", icon: "qrc:/images/link.png" }
                                    ]

                                    delegate: Rectangle {
                                        width: 172
                                        height: 36
                                        radius: 6
                                        color: menuItemMouse.pressed ? "#14000000"
                                             : menuItemMouse.containsMouse ? "#0A000000"
                                             : "transparent"

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Image {
                                                width: 16
                                                height: 16
                                                source: modelData.icon
                                                sourceSize: Qt.size(16, 16)
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Label {
                                                text: modelData.text
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: menuItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                addSkillMenu.close()
                                                if (index === 0) {
                                                    zipFileDialog.open()
                                                } else if (index === 1) {
                                                    folderDialog.open()
                                                } else if (index === 2) {
                                                    githubImportDialog.open()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            enter: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                            }
                            exit: Transition {
                                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: agentManageRec
                anchors.top: capabilityHubHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: window.leftSelectedIndex === 2
                property string searchText: ""

                onVisibleChanged: {
                    if (visible && wsClient.connectionState === 3)
                        wsClient.refreshAgents()
                }

                function filteredAgents() {
                    var list = wsClient.agentList || []
                    var kw = searchText.toLowerCase()
                    var out = []
                    for (var i = 0; i < list.length; i++) {
                        var a = list[i]
                        var name = String(a.name || "").trim().toLowerCase()
                        var id = String(a.id || "").trim().toLowerCase()
                        if (id === "main" || name === "默认")
                            continue
                        var detail = String(a.description || "").toLowerCase()
                        if (!kw || name.indexOf(kw) >= 0 || id.indexOf(kw) >= 0
                                || detail.indexOf(kw) >= 0)
                            out.push(a)
                    }
                    return out
                }

                ScrollView {
                    id: expertCardScroll
                    visible: false
                    anchors.fill: parent
                    anchors.leftMargin: 60
                    anchors.rightMargin: 60
                    anchors.bottomMargin: 24
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    Grid {
                        id: expertCardGrid
                        width: expertCardScroll.availableWidth
                        columns: width >= 760 ? 2 : 1
                        spacing: 12
                        property real cardWidth: columns === 2 ? (width - spacing) / 2 : width

                        Repeater {
                            model: agentManageRec.filteredAgents()
                            delegate: Rectangle {
                                id: expertCard
                                property var cardData: modelData
                                readonly property bool installing: wsClient.agentInstallBusy
                                                                    && wsClient.agentInstallingId
                                                                       === (cardData.id || "")
                                readonly property bool hovered: expertCardMouse.containsMouse
                                                                || expertDetailHover.hovered
                                width: expertCardGrid.cardWidth
                                height: 222
                                radius: 8
                                clip: true
                                color: "#F7F8FC"
                                border.width: 0

                                Image {
                                    id: expertCardBackground
                                    anchors.fill: parent
                                    source: "qrc:/images/expertBackground.png"
                                    sourceClipRect: Qt.rect(1, 1, 898, 415)
                                    fillMode: Image.PreserveAspectCrop
                                    cache: true
                                    visible: false
                                }

                                Rectangle {
                                    id: expertCardBackgroundMask
                                    anchors.fill: expertCardBackground
                                    radius: Math.max(0, expertCard.radius - 1)
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: expertCardBackground
                                    source: expertCardBackground
                                    maskSource: expertCardBackgroundMask
                                    cached: true
                                }

                                Rectangle {
                                    z: 1
                                    anchors.fill: parent
                                    radius: expertCard.radius
                                    color: expertCard.hovered ? "#0A006BFF" : "transparent"
                                    border.width: expertCard.hovered ? 1 : 0
                                    border.color: "#66006BFF"

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.width { NumberAnimation { duration: 120 } }
                                }

                                Column {
                                    z: 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 26
                                    anchors.top: parent.top
                                    anchors.topMargin: 26
                                    width: parent.width - 52
                                    spacing: 12

                                    Label {
                                        width: parent.width
                                        text: expertCard.cardData.name || expertCard.cardData.id || ""
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        color: "#D9000000"
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        id: expertDetailLabel
                                        width: parent.width
                                        height: expertCard.installing ? 92 : 136
                                        text: String(expertCard.cardData.description || "").trim()
                                              || qsTr("暂无专家介绍")
                                        font.pixelSize: 13
                                        lineHeight: 1.35
                                        color: "#99000000"
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 7
                                        elide: Text.ElideRight

                                        HoverHandler {
                                            id: expertDetailHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        // ToolTip {
                                        //     id: expertDetailTooltip
                                        //     visible: expertDetailHover.hovered
                                        //              && expertDetailTooltipText.text.length > 0
                                        //     delay: 1000
                                        //     timeout: -1
                                        //     width: Math.min(540, window.width - 48)
                                        //     x: Math.min(0, expertDetailLabel.width - width)
                                        //     y: expertDetailLabel.height + 4
                                        //     padding: 10

                                        //     background: Rectangle {
                                        //         color: "#A6000000"
                                        //         radius: 4
                                        //     }

                                        //     contentItem: Text {
                                        //         id: expertDetailTooltipText
                                        //         width: expertDetailTooltip.availableWidth
                                        //         text: String(expertCard.cardData.description || "").trim()
                                        //         textFormat: Text.PlainText
                                        //         wrapMode: Text.Wrap
                                        //         maximumLineCount: 20
                                        //         elide: Text.ElideRight
                                        //         font.pixelSize: 14
                                        //         font.family: "Alibaba PuHuiTi 3.0"
                                        //         color: "#FFFFFF"
                                        //     }

                                        //     HoverHandler {
                                        //         cursorShape: Qt.PointingHandCursor
                                        //     }
                                        // }
                                    }
                                }

                                Column {
                                    z: 3
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 26
                                    anchors.rightMargin: 26
                                    anchors.bottomMargin: 20
                                    spacing: 6
                                    visible: expertCard.installing

                                    Rectangle {
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: "#E6E7EB"

                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(100,
                                                wsClient.agentInstallProgress)) / 100
                                            height: parent.height
                                            radius: 3
                                            color: "#006BFF"
                                            Behavior on width {
                                                NumberAnimation { duration: 180 }
                                            }
                                        }
                                    }

                                    Label {
                                        width: parent.width
                                        text: qsTr("专家召唤中...") + "  "
                                              + wsClient.agentInstallProgress + "%"
                                        font.pixelSize: 12
                                        color: "#73000000"
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: expertCardMouse
                                    z: 1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !wsClient.agentInstallBusy
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        var id = expertCard.cardData.id || ""
                                        if (id.length > 0)
                                            wsClient.summonAgent(id)
                                    }
                                }
                            }
                        }

                        Label {
                            visible: agentManageRec.filteredAgents().length === 0
                            width: expertCardGrid.width
                            height: 120
                            text: qsTr("未找到匹配的专家")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                            color: "#73000000"
                        }
                    }
                }
                ExpertPage {
                    anchors.fill: parent
                    agentList: wsClient.agentList || []
                    searchText: agentManageRec.searchText
                    installBusy: wsClient.agentInstallBusy
                    hostWidth: window.width
                    hostHeight: window.height
                    onSummonRequested: function(agentId, promptText) {
                        window.summonExpert(agentId, promptText)
                    }
                }
            }

            Rectangle{
                id: skillSettingRec
                anchors.top: capabilityHubHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: window.leftSelectedIndex === 3
                property string skillSearchText: ""
                property string selectedSkillCategory: "全部"
                property var skillCategories: [
                    "全部", "政务技能", "平台基础", "临床科研", "科学计算",
                    "开发者工具", "第三方服务集成", "场景调度"
                ]
                property var skillCategoryById: ({
                    "gov-assessment": "政务技能",
                    "gov-briefing": "政务技能",
                    "gov-data-analysis": "政务技能",
                    "gov-doc-drafting": "政务技能",
                    "gov-doc-summary": "政务技能",
                    "gov-enterprise-report": "政务技能",
                    "gov-hotline-report": "政务技能",
                    "gov-kb-qa": "政务技能",
                    "gov-meeting-minutes": "政务技能",
                    "gov-policy-drafting": "政务技能",
                    "gov-policy-interpret": "政务技能",
                    "gov-policy-lookup": "政务技能",
                    "gov-policy-match": "政务技能",
                    "gov-work-summary": "政务技能",
                    "_shared": "平台基础",
                    "node-connect": "平台基础",
                    "model-usage": "平台基础",
                    "skill-creator": "平台基础",
                    "session-logs": "平台基础",
                    "healthcheck": "平台基础",
                    "coding-agent": "平台基础",
                    "summarize": "平台基础",
                    "apple-notes": "平台基础",
                    "apple-reminders": "平台基础",
                    "bear-notes": "平台基础",
                    "notion": "平台基础",
                    "obsidian": "平台基础",
                    "things-mac": "平台基础",
                    "trello": "平台基础",
                    "biomcp-server": "临床科研",
                    "scma-analyzer": "临床科研",
                    "medical-intelligence": "临床科研",
                    "medical-research-toolkit": "临床科研",
                    "mlp-intelligence": "临床科研",
                    "radiology-skills": "临床科研",
                    "spatial-transcriptomics-agent": "临床科研",
                    "spatial-transcriptomics-analysis": "临床科研",
                    "precision-medicine": "临床科研",
                    "data-analysis": "科学计算",
                    "github": "开发者工具",
                    "gh-issues": "开发者工具",
                    "gitgrep": "开发者工具",
                    "blucl": "开发者工具",
                    "tmux": "开发者工具",
                    "wacli": "开发者工具",
                    "1password": "第三方服务集成",
                    "canva": "第三方服务集成",
                    "discord": "第三方服务集成",
                    "gemini": "第三方服务集成",
                    "gog": "第三方服务集成",
                    "goplaces": "第三方服务集成",
                    "himalaya": "第三方服务集成",
                    "imsg": "第三方服务集成",
                    "mcporter": "第三方服务集成",
                    "openai-whisper": "第三方服务集成",
                    "openai-whisper-api": "第三方服务集成",
                    "opennlue": "第三方服务集成",
                    "oracle": "第三方服务集成",
                    "ordercli": "第三方服务集成",
                    "peekaboo": "第三方服务集成",
                    "sag": "第三方服务集成",
                    "sherpa-onnx-tts": "第三方服务集成",
                    "slack": "第三方服务集成",
                    "songsee": "第三方服务集成",
                    "sonoscli": "第三方服务集成",
                    "spotify-player": "第三方服务集成",
                    "video-frames": "第三方服务集成",
                    "video-call": "第三方服务集成",
                    "weather": "第三方服务集成",
                    "xurl": "第三方服务集成",
                    "camsnap": "第三方服务集成",
                    "bluebubbles": "第三方服务集成",
                    "blogwatcher": "第三方服务集成",
                    "eighthtctl": "第三方服务集成",
                    "paper-writing": "场景调度",
                    "deep-research": "场景调度",
                    "fact-forensics": "场景调度",
                    "clawhub": "场景调度"
                })

                function visibleSkillCategories() {
                    var present = {}
                    var list = wsClient.skillList || []
                    for (var i = 0; i < list.length; i++) {
                        var id = String(list[i].skillKey || list[i].name || "").toLowerCase()
                        var category = skillCategoryById[id] || ""
                        if (category)
                            present[category] = true
                    }
                    var result = ["全部"]
                    for (var j = 1; j < skillCategories.length; j++) {
                        if (present[skillCategories[j]])
                            result.push(skillCategories[j])
                    }
                    return result
                }

                function ensureSelectedSkillCategory() {
                    var categories = visibleSkillCategories()
                    if (categories.indexOf(selectedSkillCategory) < 0)
                        selectedSkillCategory = "全部"
                }

                onVisibleChanged: {
                    if (visible)
                        ensureSelectedSkillCategory()
                }

                Connections {
                    target: wsClient
                    function onSkillListChanged() {
                        skillSettingRec.ensureSelectedSkillCategory()
                    }
                }

                function filteredSkillList() {
                    var list = wsClient.skillList || []
                    var kw = skillSearchText.toLowerCase()
                    var result = []
                    for (var i = 0; i < list.length; i++) {
                        var name = (list[i].name || list[i].skillKey || "").toLowerCase()
                        var desc = (list[i].description || "").toLowerCase()
                        var id = String(list[i].skillKey || list[i].name || "").toLowerCase()
                        var category = skillCategoryById[id] || ""
                        if (selectedSkillCategory !== "全部" && category !== selectedSkillCategory)
                            continue
                        if (kw && name.indexOf(kw) < 0 && desc.indexOf(kw) < 0)
                            continue
                        result.push(list[i])
                    }
                    return result
                }
                Column{
                    anchors.fill: parent
                    leftPadding: 60
                    rightPadding: 60
                    spacing: 16

                    Flickable {
                        id: skillCategoryBar
                        width: parent.width - 120
                        height: 36
                        contentWidth: skillCategoryRow.width
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick

                        Row {
                            id: skillCategoryRow
                            spacing: 8

                            Repeater {
                                model: skillSettingRec.visibleSkillCategories()

                                delegate: Rectangle {
                                    readonly property bool selected: skillSettingRec.selectedSkillCategory === modelData
                                    width: categoryLabel.implicitWidth + 24
                                    height: 32
                                    radius: 6
                                    color: selected ? "#0F006BFF"
                                         : categoryMouse.containsMouse ? "#F7F8FA" : "#F7F9FA"

                                    Label {
                                        id: categoryLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 14
                                        font.weight: parent.selected ? Font.Medium : Font.Normal
                                        color: parent.selected ? "#006BFF" : "#A6000000"
                                    }

                                    MouseArea {
                                        id: categoryMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: skillSettingRec.selectedSkillCategory = modelData
                                    }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: skillScrollView
                        width: parent.width - 120
                        height: skillSettingRec.height - skillCategoryBar.height - 16 - 16
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        Grid {
                            id: skillGrid
                            columns: 2
                            spacing: 12
                            width: skillScrollView.width

                            property real cellWidth: (width - spacing) / 2

                            Repeater {
                                model: skillSettingRec.filteredSkillList()

                                delegate: Rectangle {
                                    width: skillGrid.cellWidth
                                    height: 68
                                    radius: 8
                                    border.color: "#E6E7EB"
                                    border.width: 1
                                    color: "#FFFFFF"

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.right: installedSkillButton.left
                                        anchors.rightMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        height: 28

                                        Image {
                                            width: 28
                                            height: 28
                                            visible: !modelData.emoji
                                            source: "qrc:/images/skillIcon.png"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Label {
                                            width: 28
                                            height: 28
                                            visible: modelData.emoji
                                            font.pixelSize: 20
                                            text: modelData.emoji
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                                        }

                                        Label {
                                            id: skillNameLabel
                                            width: parent.width - 36
                                            text: modelData.name || modelData.skillKey || ""
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                        }
                                    }

                                    CustomButton {
                                        id: installedSkillButton
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 72
                                        height: 32
                                        buttonRadius: 8
                                        fontSize: 13
                                        text: qsTr("已安装")
                                        enabled: false
                                        disabledBackgroundColor: "#F7F9FA"
                                        disabledTextColor: "#73000000"
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle{
                id: toolsSettingRec
                anchors.top: capabilityHubHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: window.leftSelectedIndex === 4
                property string toolSearchText: ""
                property string selectedToolCategory: "深度问数"
                property var toolCategories: ["深度问数", "生信分析", "政务助手", "系统自带"]
                property var deepDataToolIds: ({
                    "data_execute_code": true,
                    "data_explore": true,
                    "data_clean": true,
                    "echarts_transform": true,
                    "file_extract": true,
                    "file_list_archive": true,
                    "ml_export_model": true,
                    "ml_recommend_models": true,
                    "ml_run_pipeline": true,
                    "read_file_content": true,
                    "stats_association": true,
                    "stats_comparative": true,
                    "stats_correlation": true,
                    "stats_crosstab": true,
                    "stats_linear_regression": true,
                    "stats_logistic_regression": true,
                    "stats_tableone": true
                })
                property var bioinformaticsToolIds: ({
                    "scrna_annotate": true,
                    "scrna_cluster": true,
                    "scrna_preprocess": true,
                    "scrna_validate": true,
                    "spatial_cluster": true,
                    "spatial_deg": true,
                    "spatial_enrichment": true,
                    "spatial_load": true,
                    "spatial_qc": true
                })
                property var governmentToolIds: ({
                    "policy_eligibility_match": true,
                    "enterprise_profile_query": true,
                    "policy_document_drafting": true,
                    "12345_monthly_analysis_report": true,
                    "knowledge_base_qa": true,
                    "document_summary": true,
                    "policy_law_fast_search": true,
                    "comprehensive_judgment_analysis": true,
                    "data_analysis": true,
                    "policy_interpretation": true,
                    "official_document_draft": true,
                    "report_material": true,
                    "work_summary": true,
                    "meeting_minutes": true
                })
                onVisibleChanged: {
                    if (visible && wsClient.connectionState === 3)
                        wsClient.refreshToolsCatalog("main")
                }

                function toolIdMatches(id, idMap) {
                    if (idMap[id])
                        return true
                    for (var knownId in idMap) {
                        if (id.length > knownId.length
                                && id.lastIndexOf(knownId) === id.length - knownId.length)
                            return true
                    }
                    return false
                }

                function categoryForTool(tool) {
                    var id = String(tool.toolId || "").trim().toLowerCase()
                    if (toolIdMatches(id, deepDataToolIds))
                        return "深度问数"
                    if (toolIdMatches(id, bioinformaticsToolIds))
                        return "生信分析"
                    if (toolIdMatches(id, governmentToolIds))
                        return "政务助手"
                    return "系统自带"
                }

                function filteredTools(category) {
                    var result = []
                    var list = wsClient.toolList || []
                    var search = toolSearchText.toLowerCase()
                    for (var i = 0; i < list.length; i++) {
                        var t = list[i]
                        if (categoryForTool(t) !== category)
                            continue
                        if (search && (t.label || "").toLowerCase().indexOf(search) < 0)
                            continue
                        result.push(t)
                    }
                    return result
                }

                Column{
                    anchors.fill: parent
                    leftPadding: 60
                    rightPadding: 60
                    spacing: 16

                    Row {
                        id: toolsTab
                        spacing: 8

                        Repeater {
                            model: toolsSettingRec.toolCategories

                            delegate: Rectangle {
                                readonly property bool selected:
                                    toolsSettingRec.selectedToolCategory === modelData
                                width: toolCategoryLabel.implicitWidth + 24
                                height: 32
                                radius: 6
                                color: selected ? "#0F006BFF"
                                     : toolCategoryMouse.containsMouse ? "#F7F8FA" : "#F7F9FA"

                                Label {
                                    id: toolCategoryLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 14
                                    font.weight: parent.selected ? Font.Medium : Font.Normal
                                    color: parent.selected ? "#006BFF" : "#A6000000"
                                }

                                MouseArea {
                                    id: toolCategoryMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toolsSettingRec.selectedToolCategory = modelData
                                }
                            }
                        }
                    }

                    ScrollView {
                        id: toolsScrollView
                        width: parent.width - 120
                        height: toolsSettingRec.height - 16 - toolsTab.height - 16
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        Column {
                            id: toolsScrollContent
                            width: toolsScrollView.width
                            spacing: 12

                            Label {
                                visible: toolsSettingRec.filteredTools(
                                    toolsSettingRec.selectedToolCategory).length === 0
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 40
                                text: qsTr("暂无%1工具").arg(toolsSettingRec.selectedToolCategory)
                                font.pixelSize: 14
                                color: "#73000000"
                                wrapMode: Text.WordWrap
                            }

                            Grid {
                                id: toolCardGrid
                                columns: 2
                                spacing: 12
                                width: parent.width
                                property real cellWidth: (width - spacing) / 2

                                Repeater {
                                    model: toolsSettingRec.filteredTools(
                                        toolsSettingRec.selectedToolCategory)

                                    delegate: Rectangle {
                                        width: toolCardGrid.cellWidth
                                        height: toolsLabelColumn.height
                                        radius: 8
                                        border.color: "#E1E4EA"
                                        border.width: 1
                                        color: "#FFFFFF"

                                        Column {
                                            id: toolsLabelColumn
                                            width: parent.width
                                            padding: 20
                                            spacing: 10

                                            Item {
                                                width: parent.width - 40
                                                height: 44

                                                Image {
                                                    id: toolIcon
                                                    anchors.left: parent.left
                                                    width: 28
                                                    height: 28
                                                    source: "qrc:/images/skillIcon.png"
                                                    fillMode: Image.PreserveAspectFit
                                                }

                                                Column {
                                                    anchors.left: toolIcon.right
                                                    anchors.leftMargin: 12
                                                    anchors.right: toolEnabledSwitch.left
                                                    anchors.rightMargin: 16
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 2

                                                    Label {
                                                        width: parent.width
                                                        text: modelData.label || modelData.toolId || ""
                                                        font.pixelSize: 14
                                                        font.weight: Font.DemiBold
                                                        color: "#D9000000"
                                                        elide: Text.ElideRight
                                                    }

                                                    Label {
                                                        width: parent.width
                                                        text: modelData.pluginId || modelData.toolId || ""
                                                        font.pixelSize: 14
                                                        color: "#40000000"
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Switch {
                                                    id: toolEnabledSwitch
                                                    property bool syncGuard: false
                                                    function syncFromModel() {
                                                        syncGuard = true
                                                        checked = modelData.enabled === true
                                                        syncGuard = false
                                                    }
                                                    Component.onCompleted: syncFromModel()
                                                    Connections {
                                                        target: wsClient
                                                        function onToolListChanged() {
                                                            toolEnabledSwitch.syncFromModel()
                                                        }
                                                    }
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    enabled: wsClient.connectionState === 3
                                                             && !wsClient.toolInstallBusy
                                                             && !wsClient.agentInstallBusy
                                                    onCheckedChanged: {
                                                        if (syncGuard)
                                                            return
                                                        wsClient.setAgentToolEnabled(
                                                            "main",
                                                            modelData.toolId || "",
                                                            checked,
                                                            modelData.pluginId || "")
                                                    }
                                                    indicator: Rectangle {
                                                        implicitWidth: 44
                                                        implicitHeight: 22
                                                        x: toolEnabledSwitch.leftPadding
                                                        radius: 11
                                                        color: toolEnabledSwitch.checked ? "#006BFF" : "#D9D9D9"
                                                        opacity: toolEnabledSwitch.enabled ? 1 : 0.55
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        Rectangle {
                                                            x: toolEnabledSwitch.checked ? parent.width - width - 3 : 3
                                                            y: parent.height / 2 - height / 2
                                                            width: 18
                                                            height: 18
                                                            radius: 9
                                                            color: "#FFFFFF"
                                                            Behavior on x {
                                                                NumberAnimation {
                                                                    duration: 150
                                                                    easing.type: Easing.OutCubic
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Label {
                                                id: toolDescLabel
                                                width: parent.width - 40
                                                text: modelData.description || ""
                                                font.pixelSize: 14
                                                lineHeight: 1.35
                                                color: "#73000000"
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight

                                                ToolTip {
                                                    visible: toolDescHover.containsMouse && toolDescLabel.truncated
                                                    text: toolDescLabel.text
                                                    delay: 500
                                                    x: 0
                                                    y: -height - 4
                                                    width: Math.min(implicitContentWidth + 20,
                                                                    toolsScrollView.width / 2 - 40)
                                                    background: Rectangle {
                                                        color: "#A6000000"
                                                        radius: 4
                                                    }
                                                    contentItem: Text {
                                                        text: toolDescLabel.text
                                                        font.pixelSize: 14
                                                        color: "#FFFFFF"
                                                        font.family: "Alibaba PuHuiTi 3.0"
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                                MouseArea {
                                                    id: toolDescHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.NoButton
                                                }
                                            }

                                            Column {
                                                width: parent.width - 40
                                                spacing: 5
                                                visible: wsClient.toolInstallBusy
                                                         && wsClient.toolInstallingId === (modelData.toolId || "")
                                                height: visible ? implicitHeight : 0

                                                Rectangle {
                                                    width: parent.width
                                                    height: 6
                                                    radius: 3
                                                    color: "#E6E7EB"
                                                    Rectangle {
                                                        width: parent.width * Math.max(0, Math.min(100,
                                                            wsClient.toolInstallProgress)) / 100
                                                        height: parent.height
                                                        radius: 3
                                                        color: "#006BFF"
                                                        Behavior on width {
                                                            NumberAnimation { duration: 180 }
                                                        }
                                                    }
                                                }
                                                Label {
                                                    width: parent.width
                                                    text: (wsClient.toolInstallMessage || "")
                                                          + "  " + wsClient.toolInstallProgress + "%"
                                                    font.pixelSize: 12
                                                    color: "#73000000"
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: knowledgeBaseRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 7
                color: "#FFFFFF"
                property string pendingDeleteName: ""
                property string pendingDeleteKey: ""
                property bool busy: window.kbLoading

                function navigateToFolder(path) {
                    window.kbCurrentFolder = String(path || "")
                    window.kbSearchText = ""
                    window.kbSelectedKeys = []
                }

                function toggleEntrySelection(key) {
                    window.kbToggleSelected(String(key || ""))
                }

                function isEntrySelected(key) {
                    return window.kbIsSelected(String(key || ""))
                }

                function fileIconFor(name) {
                    return window.kbFileIcon(String(name || ""))
                }

                function formatAddedAt(value) {
                    return window.kbFormatTime(value)
                }

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 60
                    anchors.rightMargin: 60
                    anchors.topMargin: 24
                    anchors.bottomMargin: 28
                    spacing: 16

                    Item {
                        width: parent.width
                        height: 40

                        Label {
                            id: kbPathLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("知识库")
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: "#D9000000"
                        }

                        SingleLineTextInput {
                            id: kbSearchInput
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            inputWidth: Math.min(240, knowledgeBaseRec.width * 0.28)
                            inputHeight: 36
                            icon: "qrc:/images/search.png"
                            iconSize: 16
                            placeholderText: qsTr("搜索知识库文件...")
                            text: window.kbSearchText
                            onTextChanged: {
                                window.kbSearchText = text
                                window.kbSelectedKeys = []
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40

                        Flickable {
                            id: kbBreadcrumbView
                            anchors.left: parent.left; anchors.leftMargin: 52
                            anchors.right: kbActionsRow.left; anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            height: 32
                            contentWidth: kbBreadcrumbRow.width
                            contentHeight: height
                            contentX: Math.max(0, contentWidth - width)
                            interactive: contentWidth > width
                            clip: true

                            Row {
                                id: kbBreadcrumbRow
                                height: parent.height
                                spacing: 0

                                Repeater {
                                    model: window.kbBreadcrumbs()
                                    delegate: Item {
                                        readonly property var pageController: knowledgeBaseRec
                                        height: kbBreadcrumbRow.height
                                        width: kbBreadcrumbSeparator.width + kbBreadcrumbName.implicitWidth
                                        Label {
                                            id: kbBreadcrumbSeparator
                                            height: parent.height
                                            visible: index > 0
                                            width: visible ? implicitWidth : 0
                                            verticalAlignment: Text.AlignVCenter
                                            text: "  /  "
                                            font.pixelSize: 14
                                            color: "#73000000"
                                        }
                                        Label {
                                            id: kbBreadcrumbName
                                            anchors.left: kbBreadcrumbSeparator.right
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            text: String(modelData.name || "")
                                            font.pixelSize: 14
                                            color: modelData.current ? "#D9000000" : "#73000000"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !modelData.current
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: pageController.navigateToFolder(modelData.path)
                                        }
                                    }
                                }

                                Label {
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: "  " + window.kbVisibleEntries().length + qsTr(" 个")
                                    font.pixelSize: 14
                                    color: "#73000000"
                                }
                            }
                        }

                        CheckBox {
                            id: kbSelectAll
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24
                            checked: window.kbVisibleEntries().length > 0
                                     && window.kbSelectedKeys.length === window.kbVisibleEntries().length
                            onClicked: window.kbToggleSelectAll()
                            indicator: Rectangle {
                                width: 22; height: 22; radius: 5
                                anchors.centerIn: parent
                                color: kbSelectAll.checked ? "#006BFF" : "#FFFFFF"
                                border.width: 1
                                border.color: kbSelectAll.checked ? "#006BFF" : "#D7D9DE"
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: kbSelectAll.checked
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                }
                            }
                        }

                        Row {
                            id: kbActionsRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                visible: window.kbSelectedKeys.length > 0
                                width: visible ? 125 : 0
                                height: 36
                                radius: 6
                                color: kbBatchDeleteMouse.pressed ? "#E72F33" : "#FF3D40"
                                Row {
                                    height: parent.height
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 6
                                    Image { source: "qrc:/images/delete-white.png";anchors.verticalCenter: parent.verticalCenter}
                                    Label {
                                        text: qsTr("批量删除") + "(" + window.kbSelectedKeys.length + ")"
                                        color: "#FFFFFF"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: kbBatchDeleteMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !window.kbLoading
                                    onClicked: {
                                        knowledgeBaseRec.pendingDeleteName = window.kbSelectedKeys.length + qsTr(" 个项目")
                                        knowledgeBaseRec.pendingDeleteKey = "batch"
                                        kbDeleteConfirm.open()
                                    }
                                }
                            }

                            Rectangle {
                                width: 108; height: 36; radius: 6
                                color: kbNewFolderMouse.containsMouse ? "#F7F8FA" : "#FFFFFF"
                                border.width: 1; border.color: "#E1E3E8"
                                Row {
                                    height: parent.height; spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                    Label { text: "+"; font.pixelSize: 14; color: "#D9000000"; anchors.verticalCenter: parent.verticalCenter }
                                    Label { text: qsTr("新建文件夹"); font.pixelSize: 14; color: "#D9000000"; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea {
                                    id: kbNewFolderMouse
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !window.kbLoading
                                    onClicked: { kbNewFolderInput.text = ""; kbNewFolderPopup.open(); kbNewFolderInput.forceActiveFocus() }
                                }
                            }

                            Rectangle {
                                id: kbUploadButton
                                width: 124
                                height: 36
                                radius: 6
                                color: kbUploadMouse.pressed ? "#075BCC" : "#006BFF"
                                opacity: kbUploadMouse.enabled ? 1 : 0.5
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    height: parent.height
                                    spacing: 7
                                    Image {
                                        width: 16; height: 16
                                        source: "qrc:/images/upload-white.png"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("上传文件")
                                        font.pixelSize: 14
                                        color: "#FFFFFF"
                                    }
                                }
                                MouseArea {
                                    id: kbUploadMouse
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 96
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !window.kbLoading
                                    onClicked: kbFileDialog.open()
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 1; height: 20; color: "#66FFFFFF"
                                }
                                Image {
                                    anchors.right: parent.right; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "qrc:/images/Vector.png"
                                }
                                MouseArea {
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: 28; cursorShape: Qt.PointingHandCursor
                                    enabled: !window.kbLoading
                                    onClicked: kbUploadPopup.open()
                                }
                                Popup {
                                    id: kbUploadPopup
                                    readonly property point popupPosition: kbUploadButton.mapToItem(
                                        Overlay.overlay, kbUploadButton.width - width, kbUploadButton.height + 6)
                                    x: popupPosition.x
                                    y: popupPosition.y
                                    width: 150; height: 52; padding: 0
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                    background: Rectangle {
                                        color: "#FFFFFF"; radius: 6
                                        border.width: 1; border.color: "#E1E3E8"
                                    }
                                    contentItem: Rectangle {
                                        color: kbUploadFolderMouse.containsMouse ? "#F5F7FA" : "transparent"
                                        Row {
                                            height:parent.height; spacing: 8; anchors.left: parent.left; anchors.leftMargin: 20
                                            Image { width: 16; height: 16; source: "qrc:/images/folder.png"; anchors.verticalCenter: parent.verticalCenter}
                                            Label { text: qsTr("上传文件夹"); font.pixelSize: 14; color: "#D9000000"; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                        MouseArea {
                                            id: kbUploadFolderMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { kbUploadPopup.close(); kbFolderDialog.open() }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - 40 - 40 - 32

                        Column {
                            anchors.fill: parent

                            ScrollView {
                                id: kbFileScroll
                                width: parent.width
                                height: parent.height
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                Column {
                                    width: kbFileScroll.width

                                    Repeater {
                                        model: window.kbVisibleEntries()
                                        delegate: Rectangle {
                                            id: kbFileRow
                                            readonly property var pageController: knowledgeBaseRec
                                            readonly property string sourceName: String(modelData.name || "")
                                            readonly property string entryKey: String(modelData.key || "")
                                            readonly property bool isFolder: modelData.kind === "folder"
                                            width: kbFileScroll.width
                                            height: 56
                                            color: kbRowMouse.containsMouse ? "#F7F9FA" : "#FFFFFF"

                                            MouseArea {
                                                id: kbRowMouse
                                                anchors.fill: parent
                                                acceptedButtons: Qt.NoButton
                                                hoverEnabled: true
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                height: 1
                                                color: "#ECEEF2"
                                            }
                                            CheckBox {
                                                id: kbRowCheck
                                                x: 16; anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 24
                                                checked: kbFileRow.pageController.isEntrySelected(kbFileRow.entryKey)
                                                onClicked: kbFileRow.pageController.toggleEntrySelection(kbFileRow.entryKey)
                                                indicator: Rectangle {
                                                    width: 22; height: 22; radius: 5
                                                    anchors.centerIn: parent
                                                    color: kbRowCheck.checked ? "#006BFF" : "#FFFFFF"
                                                    border.width: 1
                                                    border.color: kbRowCheck.checked ? "#006BFF" : "#D7D9DE"
                                                    Label {
                                                        anchors.centerIn: parent; text: "✓"
                                                        visible: kbRowCheck.checked; color: "#FFFFFF"; font.pixelSize: 14
                                                    }
                                                }
                                            }
                                            Image {
                                                x: 52; width: 24; height: 24
                                                anchors.verticalCenter: parent.verticalCenter
                                                source: kbFileRow.isFolder ? "qrc:/images/knowledge/folder.png"
                                                                           : kbFileRow.pageController.fileIconFor(kbFileRow.sourceName)
                                            }
                                            Label {
                                                x: 88
                                                width: parent.width * 0.64 - x - 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: kbFileRow.sourceName
                                                elide: Text.ElideMiddle
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: kbFileRow.isFolder
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: kbFileRow.pageController.navigateToFolder(modelData.path)
                                                }
                                            }
                                            Label {
                                                x: parent.width * 0.64; width: 170
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: kbFileRow.pageController.formatAddedAt(modelData.addedAt)
                                                font.pixelSize: 13; color: "#73000000"
                                            }
                                            Label {
                                                x: parent.width * 0.83; width: 100
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: String(modelData.size || "--")
                                                font.pixelSize: 13; color: "#73000000"
                                            }
                                            Rectangle {
                                                id: kbDeleteButton
                                                width: 36; height: 36; radius: 6
                                                anchors.right: parent.right
                                                anchors.rightMargin: 16
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: kbRowMouse.containsMouse || kbDeleteMouse.containsMouse
                                                color: kbDeleteMouse.containsMouse ? "#0FFF3D40" : "transparent"
                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 17; height: 17
                                                    source: "qrc:/images/delete.png"
                                                }
                                                MouseArea {
                                                    id: kbDeleteMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: !kbFileRow.pageController.busy
                                                    onClicked: {
                                                        knowledgeBaseRec.pendingDeleteName = kbFileRow.sourceName
                                                        knowledgeBaseRec.pendingDeleteKey = kbFileRow.entryKey
                                                        kbDeleteConfirm.open()
                                                    }
                                                }
                                                ToolTip.visible: kbDeleteMouse.containsMouse
                                                ToolTip.text: qsTr("删除")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: !window.kbLoading && window.kbVisibleEntries().length === 0
                            text: window.kbSearchText ? qsTr("未找到匹配文件") : qsTr("暂无知识库文件")
                            font.pixelSize: 14
                            color: "#73000000"
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: window.kbLoading
                            color: "#CCFFFFFF"
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                BusyIndicator {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    running: window.kbLoading
                                    width: 32; height: 32
                                }
                                Label {
                                    text: window.kbBusyText
                                    color: "#73000000"
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                Popup {
                    id: kbNewFolderPopup
                    anchors.centerIn: parent
                    width: 380; height: 190
                    modal: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: Rectangle {
                        color: "#FFFFFF"; radius: 8
                        border.width: 1; border.color: "#E1E3E8"
                    }
                    contentItem: Column {
                        anchors.fill: parent; anchors.margins: 24; spacing: 16
                        Label {
                            text: qsTr("新建文件夹"); font.pixelSize: 17
                            font.weight: Font.Bold; color: "#D9000000"
                        }
                        TextField {
                            id: kbNewFolderInput
                            width: parent.width; height: 38
                            placeholderText: qsTr("请输入文件夹名称")
                            selectByMouse: true
                            onAccepted: {
                                if (window.kbCreateFolder(text)) kbNewFolderPopup.close()
                            }
                        }
                        Row {
                            anchors.right: parent.right; spacing: 8
                            CustomButton {
                                width: 72; height: 34; text: qsTr("取消"); fontSize: 13
                                backgroundColor: "#F0F1F4"; textColor: "#D9000000"; borderWidth: 0
                                onClicked: kbNewFolderPopup.close()
                            }
                            CustomButton {
                                width: 72; height: 34; text: qsTr("创建"); fontSize: 13
                                backgroundColor: "#006BFF"; textColor: "#FFFFFF"; borderWidth: 0
                                onClicked: {
                                    if (window.kbCreateFolder(kbNewFolderInput.text)) kbNewFolderPopup.close()
                                }
                            }
                        }
                    }
                }

                Popup {
                    id: kbDeleteConfirm
                    anchors.centerIn: parent
                    width: 380
                    height: 180
                    modal: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: Rectangle {
                        color: "#FFFFFF"
                        radius: 8
                        border.width: 1
                        border.color: "#E1E3E8"
                    }
                    contentItem: Column {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 20
                        Label {
                            width: parent.width
                            text: knowledgeBaseRec.pendingDeleteKey === "batch"
                                  ? qsTr("批量删除") : qsTr("删除知识库项目")
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: "#D9000000"
                        }
                        Label {
                            width: parent.width
                            text: qsTr("确定删除“") + knowledgeBaseRec.pendingDeleteName + qsTr("”？")
                            elide: Text.ElideMiddle
                            font.pixelSize: 14
                            color: "#A6000000"
                        }
                        Row {
                            anchors.right: parent.right
                            spacing: 8
                            CustomButton {
                                width: 72; height: 34
                                text: qsTr("取消")
                                fontSize: 13
                                backgroundColor: "#F0F1F4"
                                textColor: "#D9000000"
                                borderWidth: 0
                                onClicked: kbDeleteConfirm.close()
                            }
                            CustomButton {
                                width: 72; height: 34
                                text: qsTr("删除")
                                fontSize: 13
                                backgroundColor: "#FF3D40"
                                textColor: "#FFFFFF"
                                borderWidth: 0
                                onClicked: {
                                    kbDeleteConfirm.close()
                                    if (knowledgeBaseRec.pendingDeleteKey === "batch")
                                        window.kbDeleteEntries(window.kbSelectedKeys)
                                    else
                                        window.kbDeleteEntries([knowledgeBaseRec.pendingDeleteKey])
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: mcpSettingRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 5
                property string mcpSearchText: ""

                function filteredMcpList() {
                    var list = wsClient.mcpList
                    var q = (mcpSearchText || "").trim().toLowerCase()
                    if (!q)
                        return list
                    var result = []
                    for (var i = 0; i < list.length; i++) {
                        var e = list[i]
                        var name = String(e.name || e.title || "").toLowerCase()
                        var desc = String(e.description || e.desc || "").toLowerCase()
                        var url = String(e.url || "").toLowerCase()
                        var cmd = String(e.command || "").toLowerCase()
                        var args = String(e.argsText || "").toLowerCase()
                        if (name.indexOf(q) >= 0 || desc.indexOf(q) >= 0
                                || url.indexOf(q) >= 0 || cmd.indexOf(q) >= 0
                                || args.indexOf(q) >= 0)
                            result.push(e)
                    }
                    return result
                }

                onVisibleChanged: {
                    if (visible && wsClient.connectionState === 3)
                        wsClient.refreshMcpList()
                }
                Column {
                    anchors.fill: parent
                    leftPadding: 60
                    topPadding: 24
                    rightPadding: 60
                    spacing: 16
                    Rectangle {
                        id: mcpTitleRec
                        height: mcpTitle.height
                        width: parent.width - 120
                        Column {
                            id: mcpTitle
                            spacing: 8
                            anchors.left: parent.left
                            Label {
                                text: qsTr("MCP")
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }
                            Label {
                                text: qsTr("配置和管理 MCP（Model Context Protocol）服务器，为您的智能体扩展工具能力")
                                font.pixelSize: 14
                                color: "#A6000000"
                            }
                            SingleLineTextInput {
                                id: mcpSearchInput
                                inputHeight: 36
                                inputWidth: mcpTitleRec.width
                                icon: "qrc:/images/search.png"
                                iconSize: 16
                                placeholderText: qsTr("搜索 MCP")
                                onTextChanged: mcpSettingRec.mcpSearchText = text
                            }
                        }
                        CustomButton {
                            width: 80
                            height: 36
                            backgroundColor: "#0F006BFF"
                            textColor: "#006BFF"
                            borderWidth: 0
                            text: "+ 添加"
                            fontSize: 14
                            anchors.right: parent.right
                            onClicked: {
                                window.mcpEditEntry = null
                                mcpServiceDialog.isEdit = false
                                mcpServiceDialog.open()
                            }
                        }
                    }
                    TabBarView {
                        id: mcpTab
                        lineWidth: parent.width - 120
                        tabs: [{ text: "已安装", badge: wsClient.mcpList.length }]
                    }

                    ScrollView {
                        id: mcpInstalledScrollView
                        width: parent.width - 120
                        height: mcpSettingRec.height - 24 - mcpTitleRec.height - mcpTab.height - 32
                        clip: true
                        visible: mcpTab.currentIndex === 0
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        Grid {
                            id: mcpInstalledGrid
                            columns: 2
                            spacing: 12
                            width: mcpInstalledScrollView.width
                            property real cellWidth: (width - spacing) / 2

                            Label {
                                visible: wsClient.mcpList.length === 0
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 40
                                text: qsTr("暂无 MCP 服务，请点击「+ 添加」从网关配置写入 mcp.servers")
                                font.pixelSize: 14
                                color: "#73000000"
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                visible: wsClient.mcpList.length > 0 && mcpSettingRec.filteredMcpList().length === 0
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 40
                                text: qsTr("未找到匹配的 MCP 服务，请尝试其他关键词")
                                font.pixelSize: 14
                                color: "#73000000"
                                wrapMode: Text.WordWrap
                            }

                            Repeater {
                                model: mcpSettingRec.filteredMcpList()

                                delegate: Rectangle {
                                    width: mcpInstalledGrid.cellWidth
                                    height: 100
                                    radius: 8
                                    border.color: "#E6E7EB"
                                    border.width: 1
                                    color: "#FFFFFF"

                                    HoverHandler {
                                        id: mcpCardHover
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        width: parent.width - 40
                                        spacing: 12
                                        Row {
                                            spacing: 12
                                            height: 28
                                            Image {
                                                width: 28; height: 28
                                                source: modelData.icon || "qrc:/images/skillIcon.png"
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            Label {
                                                text: modelData.title || modelData.name || ""
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        Label {
                                            text: modelData.desc || ""
                                            font.pixelSize: 14
                                            color: "#73000000"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        spacing: 8
                                        height: 28

                                        ImageButton {
                                            source: "qrc:/images/edit.png"
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: mcpCardHover.hovered
                                            onClicked: {
                                                window.mcpEditEntry = modelData
                                                mcpServiceDialog.isEdit = true
                                                mcpServiceDialog.open()
                                            }
                                        }
                                        ImageButton {
                                            source: "qrc:/images/delete.png"
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: mcpCardHover.hovered
                                            onClicked: {
                                                window.pendingDeleteMcpName = modelData.name || ""
                                                deleteMcpPopup.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: newTaskDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        onVisibleChanged: {
            if (!visible) {
                window.editingCronJobId = ""
                window.editingCronPayloadKind = "agentTurn"
                window.editingCronScheduleKind = ""
                window.editingCronScheduleExpr = ""
                window.editingCronScheduleTz   = ""
                newTaskWorkDirInput.text = ""
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
            }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: newTaskDialog.close()
            }

            Rectangle {
                id: dialogCard
                width: 600
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: dialogTitleBar.height + dialogContent.implicitHeight + 24 + 16
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // 阻止点击穿透关闭
                }

                Item {
                    id: dialogTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        id: newTaskDialogTitleLabel
                        text: window.editingCronJobId ? qsTr("编辑定时任务") : qsTr("新建任务")
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: newTaskDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Column {
                    id: dialogContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: dialogTitleBar.bottom
                    anchors.margins: 24
                    anchors.topMargin: 16
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: qsTr("标题")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        SingleLineTextInput {
                            id: newTaskTitleInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            placeholderText: qsTr("请输入任务标题")
                            fontSize: 14
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: qsTr("提示词")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        MultiLineTextInput {
                            id: newTaskPromptInput
                            width: parent.width
                            inputHeight: 120
                            placeholderText: qsTr("请输入要执行的提示词")
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: qsTr("计划")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        Row {
                            width: parent.width
                            spacing: 12
                            DropdownSelect {
                                id: newTaskRepeatSelect
                                width: (parent.width - 24) / 3
                                height: 40
                                model: ["不重复", "每天", "每周", "每小时", "自定义间隔"]
                                currentIndex: 0
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                alignment: Qt.AlignLeft
                            }
                            DatePicker {
                                id: newTaskDatePicker
                                width: (parent.width - 24) / 3
                                height: 40
                            }
                            TimePicker {
                                id: newTaskTimePicker
                                width: (parent.width - 24) / 3
                                height: 40
                            }
                        }
                    }

                    // 自定义间隔输入（仅当选择"自定义间隔"时显示）
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: newTaskRepeatSelect.currentIndex === 4
                        Label {
                            text: qsTr("执行间隔（秒）")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        SingleLineTextInput {
                            id: newTaskIntervalInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            placeholderText: qsTr("例如: 3600 = 每小时")
                            fontSize: 14
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: window.editingCronJobId === ""
                        Label {
                            text: qsTr("工作目录")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        Row {
                            width: parent.width
                            spacing: 8
                            SingleLineTextInput {
                                id: newTaskWorkDirInput
                                width: parent.width - 88
                                inputHeight: 40
                                inputRadius: 8
                                placeholderText: ""
                                readOnly: true
                                fontSize: 14
                            }
                            CustomButton {
                                width: 80
                                height: 40
                                backgroundColor: "#F7F9FA"
                                textColor: "#A6000000"
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                text: qsTr("浏览")
                                fontSize: 14
                                onClicked: workDirDialog.open()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: window.editingCronJobId ? qsTr("保存") : qsTr("创建")
                            fontSize: 14
                            onClicked: {
                                var title = newTaskTitleInput.text.trim()
                                var prompt = newTaskPromptInput.text.trim()
                                if (window.editingCronJobId) {
                                    if (!title) {
                                        errorToast.text = "请输入任务标题"
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                        return
                                    }
                                    if (!prompt) {
                                        errorToast.text = "请输入要执行的提示词"
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                        return
                                    }

                                    var repeatIdx = newTaskRepeatSelect.currentIndex
                                    var schedKind = 0
                                    var schedExpr = ""
                                    var schedTz   = "Asia/Shanghai"
                                    function pad2(n) { return n < 10 ? "0" + n : "" + n }

                                    var ehh = newTaskTimePicker.selectedHour
                                    var emm = newTaskTimePicker.selectedMinute

                                    if (repeatIdx === 0) {
                                        schedKind = 3
                                        var ey = newTaskDatePicker.selectedYear
                                        var emo = newTaskDatePicker.selectedMonth
                                        var ed = newTaskDatePicker.selectedDay
                                        schedExpr = ey + "-" + pad2(emo) + "-" + pad2(ed)
                                                  + "T" + pad2(ehh) + ":" + pad2(emm) + ":00"
                                    } else if (repeatIdx === 1) {
                                        schedKind = 1
                                        schedExpr = emm + " " + ehh + " * * *"
                                    } else if (repeatIdx === 2) {
                                        schedKind = 1
                                        var eDate = new Date(newTaskDatePicker.selectedYear,
                                                             newTaskDatePicker.selectedMonth - 1,
                                                             newTaskDatePicker.selectedDay)
                                        var eDow = eDate.getDay()
                                        schedExpr = emm + " " + ehh + " * * " + eDow
                                    } else if (repeatIdx === 3) {
                                        schedKind = 1
                                        schedExpr = emm + " * * * *"
                                    } else if (repeatIdx === 4) {
                                        schedKind = 2
                                        var eSec = parseInt(newTaskIntervalInput.text) || 0
                                        if (eSec <= 0) {
                                            errorToast.text = "间隔须大于 0 秒"
                                            errorToast.visible = true
                                            errorToastTimer.restart()
                                            return
                                        }
                                        schedExpr = String(eSec * 1000)
                                    }

                                    wsClient.updateCronJobContent(
                                        window.editingCronJobId, title, prompt,
                                        window.editingCronPayloadKind,
                                        schedKind, schedExpr, schedTz)
                                    newTaskDialog.close()
                                    return
                                }
                                console.log("[CronAdd] title='" + title + "' prompt='" + prompt.substring(0,50) + "' repeat=" + newTaskRepeatSelect.currentIndex)
                                if (!title) {
                                    errorToast.text = "请输入任务标题"
                                    errorToast.visible = true
                                    errorToastTimer.restart()
                                    return
                                }
                                if (!prompt) {
                                    errorToast.text = "请输入要执行的提示词"
                                    errorToast.visible = true
                                    errorToastTimer.restart()
                                    return
                                }

                                var repeatIdx = newTaskRepeatSelect.currentIndex
                                var y = newTaskDatePicker.selectedYear
                                var m = newTaskDatePicker.selectedMonth
                                var d = newTaskDatePicker.selectedDay
                                var hh = newTaskTimePicker.selectedHour
                                var mm = newTaskTimePicker.selectedMinute
                                var cronWorkspace = newTaskWorkDirInput.text.trim()

                                function pad(n) { return n < 10 ? "0" + n : "" + n }

                                if (repeatIdx === 0) {
                                    var dt = y + "-" + pad(m) + "-" + pad(d) + "T" + pad(hh) + ":" + pad(mm) + ":00"
                                    console.log("[CronAdd] oneTime dateTime=" + dt)
                                    wsClient.prepareCronJobWithDedicatedAgent(3, title, prompt, "", "", 0, dt, cronWorkspace)
                                } else if (repeatIdx === 1) {
                                    var cronExpr = mm + " " + hh + " * * *"
                                    console.log("[CronAdd] daily cron=" + cronExpr)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr, "Asia/Shanghai", 0, "", cronWorkspace)
                                } else if (repeatIdx === 2) {
                                    var dateObj = new Date(y, m - 1, d)
                                    var dow = dateObj.getDay()
                                    var cronExpr2 = mm + " " + hh + " * * " + dow
                                    console.log("[CronAdd] weekly cron=" + cronExpr2)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr2, "Asia/Shanghai", 0, "", cronWorkspace)
                                } else if (repeatIdx === 3) {
                                    var cronExpr3 = mm + " * * * *"
                                    console.log("[CronAdd] hourly cron=" + cronExpr3)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr3, "Asia/Shanghai", 0, "", cronWorkspace)
                                } else if (repeatIdx === 4) {
                                    var sec = parseInt(newTaskIntervalInput.text) || 3600
                                    if (sec <= 0) {
                                        errorToast.text = "间隔须大于 0 秒"
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                        return
                                    }
                                    console.log("[CronAdd] interval sec=" + sec)
                                    wsClient.prepareCronJobWithDedicatedAgent(2, title, prompt, "", "", sec, "", cronWorkspace)
                                }
                                newTaskDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: {
                                window.editingCronJobId = ""
                                newTaskDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }

    /// 任务记录右键菜单：当前仅一项「删除」
    Popup {
        id: agentContextMenu
        parent: window.contentItem
        padding: 4
        width: 132
        height: agentContextMenuCol.implicitHeight + 8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnReleaseOutside
        background: Rectangle {
            radius: 8
            color: "#FFFFFF"
            border.color: "#E6E7EB"
            border.width: 1
        }
        contentItem: Column {
            id: agentContextMenuCol
            spacing: 0
            width: parent.width

            Rectangle {
                id: agentContextDeleteItem
                width: parent.width
                height: 32
                radius: 6
                color: agentContextDeleteMouse.containsMouse ? "#0A000000" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Label {
                        text: qsTr("删除")
                        font.pixelSize: 14
                        color: "#E54545"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: agentContextDeleteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        agentContextMenu.close()
                        if (window.pendingDeleteTaskSessionId.length > 0)
                            deleteSessionPopup.open()
                    }
                }
            }
        }
    }

    /// 删除任务会话确认弹窗（参考 deleteCronJobPopup 的视觉风格）
    Popup {
        id: deleteSessionPopup
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: 360
        padding: 20
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            window.pendingDeleteTaskSessionId = ""
            window.pendingDeleteTaskSessionName = ""
        }
        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.color: "#14000000"
            border.width: 1
        }
        contentItem: Column {
            spacing: 16
            width: parent.width
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("确定删除此任务？\n此操作会从任务列表移除该会话，不会删除 Agent。")
                font.pixelSize: 15
                color: "#D9000000"
            }
            Row {
                spacing: 12
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#E54545"
                    textColor: "#FFFFFF"
                    borderWidth: 0
                    text: qsTr("删除")
                    fontSize: 14
                    onClicked: {
                        var sid = window.pendingDeleteTaskSessionId
                        if (sid.length > 0)
                            wsClient.deleteTaskSession(sid)
                        deleteSessionPopup.close()
                    }
                }
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#F7F9FA"
                    textColor: "#A6000000"
                    borderColor: "#E6E7EB"
                    borderWidth: 1
                    text: qsTr("取消")
                    fontSize: 14
                    onClicked: deleteSessionPopup.close()
                }
            }
        }
    }

    Popup {
        id: deleteCronJobPopup
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: 360
        padding: 20
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.color: "#14000000"
            border.width: 1
        }
        contentItem: Column {
            spacing: 16
            width: parent.width
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("确定删除定时任务「") + window.pendingDeleteCronJobName + qsTr("」？")
                font.pixelSize: 15
                color: "#D9000000"
            }
            Row {
                spacing: 12
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#E54545"
                    textColor: "#FFFFFF"
                    borderWidth: 0
                    text: qsTr("删除")
                    fontSize: 14
                    onClicked: {
                        if (window.pendingDeleteCronJobId)
                            wsClient.removeCronJob(window.pendingDeleteCronJobId)
                        window.pendingDeleteCronJobId = ""
                        window.pendingDeleteCronJobName = ""
                        deleteCronJobPopup.close()
                    }
                }
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#F7F9FA"
                    textColor: "#A6000000"
                    borderColor: "#E6E7EB"
                    borderWidth: 1
                    text: qsTr("取消")
                    fontSize: 14
                    onClicked: deleteCronJobPopup.close()
                }
            }
        }
    }

    Popup {
        id: agentEditorPopup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        Overlay.modal: Rectangle { color: "#40000000" }
        background: Rectangle { color: "transparent" }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: agentEditorPopup.close()
            }

            Rectangle {
                width: 560
                anchors.centerIn: parent
                height: agentEditorTitleBar.height + agentEditorContent.implicitHeight + 24 + 16
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: agentEditorTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: window.agentEditorIsEdit ? qsTr("编辑专家") : qsTr("新增专家")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: agentEditorPopup.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Column {
                    id: agentEditorContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: agentEditorTitleBar.bottom
                    anchors.margins: 24
                    anchors.topMargin: 16
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 8
                        Row {
                            spacing: 2
                            Label {
                                text: qsTr("专家名称")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            Label {
                                text: "*"
                                font.pixelSize: 14
                                color: "#FF4D4F"
                            }
                        }
                        SingleLineTextInput {
                            id: agentEditorNameInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: qsTr("例如：researcher")
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: window.agentEditorIsEdit
                                  ? qsTr("IDENTITY.md（留空不修改）")
                                  : qsTr("IDENTITY.md（可选）")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        MultiLineTextInput {
                            id: agentEditorIdentityInput
                            inputWidth: parent.width
                            inputHeight: 160
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: qsTr("描述该专家的角色、能力边界和协作方式")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                var name = agentEditorNameInput.text.trim()
                                var identity = agentEditorIdentityInput.text
                                if (name.length === 0) {
                                    errorToast.text = "请输入专家名称"
                                    errorToast.visible = true
                                    errorToastTimer.restart()
                                    return
                                }
                                if (window.agentEditorIsEdit) {
                                    wsClient.updateAgent(window.agentEditorAgentId, name, "", "")
                                    if (identity.trim().length > 0)
                                        wsClient.updateAgentIdentity(window.agentEditorAgentId, identity)
                                } else {
                                    wsClient.createAgent(name, "", false, identity)
                                }
                                agentEditorPopup.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: agentEditorPopup.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: deleteAgentPopup
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: 360
        padding: 20
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            window.pendingDeleteAgentId = ""
            window.pendingDeleteAgentName = ""
        }
        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.color: "#14000000"
            border.width: 1
        }
        contentItem: Column {
            spacing: 16
            width: parent.width
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("确定删除专家「") + window.pendingDeleteAgentName + qsTr("」？")
                font.pixelSize: 15
                color: "#D9000000"
            }
            Row {
                spacing: 12
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#E54545"
                    textColor: "#FFFFFF"
                    borderWidth: 0
                    text: qsTr("删除")
                    fontSize: 14
                    onClicked: {
                        if (window.pendingDeleteAgentId.length > 0)
                            wsClient.deleteAgent(window.pendingDeleteAgentId, true)
                        deleteAgentPopup.close()
                    }
                }
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#F7F9FA"
                    textColor: "#A6000000"
                    borderColor: "#E6E7EB"
                    borderWidth: 1
                    text: qsTr("取消")
                    fontSize: 14
                    onClicked: deleteAgentPopup.close()
                }
            }
        }
    }

    FileDialog {
        id: kbFileDialog
        title: qsTr("选择知识库文件")
        nameFilters: ["Documents (*.pdf *.docx *.xlsx *.xls *.pptx *.md *.txt *.text)", "All files (*)"]
        selectMultiple: true
        onAccepted: window.kbStartUpload(kbFileDialog.fileUrls)
    }

    FileDialog {
        id: kbFolderDialog
        title: qsTr("选择知识库文件夹")
        selectFolder: true
        onAccepted: window.kbStartFolderUpload(kbFolderDialog.fileUrl)
    }

    FileDialog {
        id: zipFileDialog
        title: qsTr("选择 ZIP 文件")
        nameFilters: ["ZIP files (*.zip)"]
        selectMultiple: false
        onAccepted: {
            wsClient.addSkillFromZip(window.localFilePathFromUrl(zipFileDialog.fileUrl))
        }
    }

    FileDialog {
        id: folderDialog
        title: qsTr("选择文件夹")
        selectFolder: true
        onAccepted: {
            wsClient.addSkillFromFolder(window.localFilePathFromUrl(folderDialog.fileUrl))
        }
    }

    FileDialog {
        id: workDirDialog
        title: qsTr("选择工作目录")
        selectFolder: true
        onAccepted: {
            var path = decodeURIComponent(workDirDialog.fileUrl.toString().replace(/^file:\/{2,3}/, ""))
            if (Qt.platform.os === "windows") {
                if (path.length >= 3 && path.charAt(0) === "/" && path.charAt(2) === ":")
                    path = path.substring(1)
                path = path.replace(/\//g, "\\")
            }else if(Qt.platform.os === "linux"){
                path = "/" + path
            }
            newTaskWorkDirInput.text = path
        }
    }

    Popup {
        id: githubImportDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: githubImportDialog.close()
            }

            Rectangle {
                width: 600
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: githubTitleBar.height + githubDialogContent.implicitHeight + 24 + 16
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: githubTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: qsTr("从 GitHub 导入")
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: githubImportDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Column {
                    id: githubDialogContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: githubTitleBar.bottom
                    anchors.margins: 24
                    anchors.topMargin: 16
                    spacing: 20

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: "URL"
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        SingleLineTextInput {
                            id: githubUrlInput
                            width: parent.width
                            inputHeight: 36
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: "https://github.com/owner/repo/tree/main/SKILLs/my-skil"
                        }
                    }
                    Label {
                        text: qsTr("支持仓库链接与子目录链接，owner/repo 或 GitHub tree/blob 链接；\n若仓库内有多个技能，将自动全部导入。")
                        font.pixelSize: 14
                        color: "#73000000"
                        lineHeight: 1.5
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("导入")
                            fontSize: 14
                            onClicked: {
                                wsClient.addSkillFromGit(githubUrlInput.text)
                                githubImportDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: githubImportDialog.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: mcpServiceDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        property bool isEdit: false

        onOpened: {
            if (isEdit && window.mcpEditEntry) {
                var e = window.mcpEditEntry
                mcpNameInput.text = e.name || ""
                mcpDescInput.text = e.description || ""
                mcpTransportSelect.currentIndex = e.transportHttp ? 1 : 0
                // 匹配命令下拉
                var cmdList = ["node", "npx", "uvx", "python"]
                var ci = cmdList.indexOf(e.command || "")
                mcpCommandSelect.currentIndex = ci >= 0 ? ci : 0
                mcpArgsInput.text = e.argsText || ""
                mcpHttpUrlInput.text = e.url || ""
                // 恢复环境变量
                envVarModel.clear()
                var envMap = e.env || {}
                var keys = Object.keys(envMap)
                if (keys.length > 0) {
                    for (var i = 0; i < keys.length; i++)
                        envVarModel.append({ key: keys[i], value: String(envMap[keys[i]]) })
                } else {
                    envVarModel.append({ key: "", value: "" })
                }
            } else {
                mcpNameInput.text = ""
                mcpDescInput.text = ""
                mcpTransportSelect.currentIndex = 0
                mcpCommandSelect.currentIndex = 0
                mcpArgsInput.text = ""
                mcpHttpUrlInput.text = ""
                envVarModel.clear()
                envVarModel.append({ key: "", value: "" })
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: mcpServiceDialog.close()
            }

            Rectangle {
                width: 560
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: mcpDialogTitleBar.height + mcpDialogScrollView.height + mcpDialogFooter.height
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: mcpDialogTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: mcpServiceDialog.isEdit ? qsTr("编辑 MCP 服务") : qsTr("添加 MCP 服务")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: mcpServiceDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                ScrollView {
                    id: mcpDialogScrollView
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: mcpDialogTitleBar.bottom
                    height: Math.min(mcpDialogContentCol.implicitHeight, window.height - 280)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        id: mcpDialogContentCol
                        width: mcpDialogScrollView.width
                        leftPadding: 24
                        rightPadding: 24
                        topPadding: 16
                        bottomPadding: 16
                        spacing: 16

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("服务名称")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            SingleLineTextInput {
                                id: mcpNameInput
                                width: parent.width
                                inputHeight: 40
                                inputRadius: 8
                                fontSize: 14
                                placeholderText: qsTr("请输入")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            Label {
                                text: qsTr("描述")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            SingleLineTextInput {
                                id: mcpDescInput
                                width: parent.width
                                inputHeight: 40
                                inputRadius: 8
                                fontSize: 14
                                placeholderText: qsTr("描述此 MCP 服务的用途")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("传输类型")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            DropdownSelect {
                                id: mcpTransportSelect
                                width: parent.width
                                height: 40
                                model: ["标准输入输出（stdio）", "HTTP (SSE)"]
                                currentIndex: 0
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                alignment: Qt.AlignLeft
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 1
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("服务地址")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            SingleLineTextInput {
                                id: mcpHttpUrlInput
                                width: parent.width
                                inputHeight: 40
                                inputRadius: 8
                                fontSize: 14
                                placeholderText: qsTr("https://example.com/mcp")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 0
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("命令")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            DropdownSelect {
                                id: mcpCommandSelect
                                width: parent.width
                                height: 40
                                model: ["node", "npx", "uvx", "python"]
                                currentIndex: 0
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                alignment: Qt.AlignLeft
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 0
                            Label {
                                text: qsTr("参数")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            MultiLineTextInput {
                                id: mcpArgsInput
                                width: parent.width
                                inputHeight: 80
                                placeholderText: qsTr("每行一个参数")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 0
                            Label {
                                text: qsTr("环境变量")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }

                            Column {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    id: envVarRepeater
                                    model: ListModel {
                                        id: envVarModel
                                        ListElement { key: ""; value: "" }
                                    }

                                    delegate: Row {
                                        width: parent.width
                                        spacing: 8

                                        property bool isLast: index === envVarModel.count - 1

                                        SingleLineTextInput {
                                            width: (parent.width - 96) / 2
                                            inputHeight: 40
                                            inputRadius: 8
                                            fontSize: 14
                                            placeholderText: qsTr("键")
                                            text: model.key
                                            onTextChanged: {
                                                if (index >= 0 && index < envVarModel.count)
                                                    envVarModel.setProperty(index, "key", text)
                                            }
                                        }
                                        SingleLineTextInput {
                                            width: (parent.width - 96) / 2
                                            inputHeight: 40
                                            inputRadius: 8
                                            fontSize: 14
                                            placeholderText: qsTr("值")
                                            text: model.value
                                            onTextChanged: {
                                                if (index >= 0 && index < envVarModel.count)
                                                    envVarModel.setProperty(index, "value", text)
                                            }
                                        }
                                        CustomButton{
                                            width: 36
                                            height: 36
                                            borderColor: "#E6E7EB"
                                            borderWidth: 1
                                            buttonRadius: 8
                                            backgroundColor: "#FFFFFF"
                                            textColor: "#73000000"
                                            text: "-"
                                            visible: envVarModel.count !== 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: {
                                                envVarModel.remove(index)
                                            }
                                        }
                                        CustomButton{
                                            width: 36
                                            height: 36
                                            borderColor: "#E6E7EB"
                                            borderWidth: 1
                                            buttonRadius: 8
                                            backgroundColor: "#FFFFFF"
                                            text: "+"
                                            textColor: "#73000000"
                                            visible: isLast
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: {
                                                envVarModel.append({ key: "", value: "" })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: mcpDialogFooter
                    width: parent.width
                    height: 64
                    anchors.top: mcpDialogScrollView.bottom

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.top: parent.top
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                var envObj = {}
                                for (var i = 0; i < envVarModel.count; i++) {
                                    var k = envVarModel.get(i).key.trim()
                                    var v = envVarModel.get(i).value
                                    if (k.length > 0)
                                        envObj[k] = v
                                }
                                var envStr = Object.keys(envObj).length > 0
                                    ? JSON.stringify(envObj) : ""

                                wsClient.applyMcpServer(
                                    mcpServiceDialog.isEdit,
                                    mcpServiceDialog.isEdit ? (window.mcpEditEntry ? (window.mcpEditEntry.name || "") : "") : "",
                                    mcpNameInput.text,
                                    mcpTransportSelect.currentIndex === 1,
                                    mcpCommandSelect.currentText,
                                    mcpArgsInput.text,
                                    mcpHttpUrlInput.text,
                                    mcpDescInput.text,
                                    envStr
                                )
                                mcpServiceDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: mcpServiceDialog.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: deleteMcpPopup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }
        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                onClicked: deleteMcpPopup.close()
            }
            Rectangle {
                width: 400
                height: deleteMcpCol.implicitHeight
                anchors.centerIn: parent
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    id: deleteMcpCol
                    width: parent.width
                    padding: 24
                    spacing: 20

                    Label {
                        text: qsTr("确认删除")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                    }

                    Label {
                        text: qsTr("确定要删除此 MCP 服务吗？此操作不可撤销。")
                        font.pixelSize: 14
                        color: "#A6000000"
                        wrapMode: Text.Wrap
                        width: parent.width - 48
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        spacing: 12
                        layoutDirection: Qt.RightToLeft

                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#FF4D4F"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("删除")
                            fontSize: 14
                            onClicked: {
                                wsClient.removeMcpServer(window.pendingDeleteMcpName)
                                deleteMcpPopup.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: deleteMcpPopup.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: settingsDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        property int settingsTabIndex: 0

        onOpened: {
            if (wsClient.connectionState === 3)
                wsClient.refreshModels()
            memorySwitch.checked = wsClient.memoryEnabled
            llmSwitch.checked = wsClient.llmJudgmentEnabled
            sandboxPage.sandboxMode = wsClient.sandboxMode
            wsClient.loadMemoryEntries()
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: settingsDialog.close()
            }

            Rectangle {
                width: 720
                height: Math.min(600, window.height - 100)
                anchors.centerIn: parent
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: settingsTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: qsTr("设置")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: settingsDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Row {
                    anchors.top: settingsTitleBar.bottom
                    anchors.bottom: settingsFooter.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Rectangle {
                        id: settingsLeftNav
                        width: 180
                        height: parent.height
                        color: "#FFFFFF"

                        Column {
                            anchors.fill: parent
                            padding: 16
                            spacing: 8

                            Repeater {
                                model: [
                                    { text: "模型", icon: "qrc:/images/category.png" },
                                    { text: "记忆", icon: "qrc:/images/category.png" },
                                    { text: "沙箱", icon: "qrc:/images/category.png" }
                                ]

                                delegate: Rectangle {
                                    width: settingsLeftNav.width - 32
                                    height: 36
                                    radius: 8
                                    color: index === settingsDialog.settingsTabIndex ? "#E6E7EB"
                                         : settingsNavMouse.containsMouse ? "#E6E7EB"
                                         : "transparent"

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8

                                        Image {
                                            width: 16; height: 16
                                            source: modelData.icon
                                            sourceSize: Qt.size(16, 16)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Label {
                                            text: modelData.text
                                            font.pixelSize: 14
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: settingsNavMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsDialog.settingsTabIndex = index
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: "#14000000"
                    }

                    ScrollView {
                        id: settingsContentScroll1
                        width: parent.width - settingsLeftNav.width - 1
                        height: parent.height
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        visible: settingsDialog.settingsTabIndex === 0
                        Column {
                            width: settingsContentScroll1.width
                            padding: 16
                            spacing: 12
                            Label {
                                text: qsTr("模型")
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }

                            Label {
                                visible: wsClient.modelList.length === 0
                                width: parent.width - 32
                                wrapMode: Text.WordWrap
                                text: wsClient.connectionState === 3
                                      ? qsTr("暂无可用模型，请稍后重试或检查网关配置。")
                                      : qsTr("未连接服务器，连接成功后将自动加载模型列表。")
                                font.pixelSize: 14
                                color: "#73000000"
                            }

                            Column {
                                width: parent.width - 32
                                spacing: 4

                                Repeater {
                                    model: wsClient.modelList

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: modelRow.implicitHeight + 20
                                        radius: 8
                                        color: "transparent"

                                        Row {
                                            id: modelRow
                                            anchors.left: parent.left
                                            anchors.leftMargin: 16
                                            anchors.right: parent.right
                                            anchors.rightMargin: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Image {
                                                width: 28; height: 28
                                                source: "qrc:/images/ai.png"
                                                sourceSize: Qt.size(28, 28)
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Column {
                                                spacing: 2
                                                width: parent.width - 28 - 8 - 60
                                                anchors.verticalCenter: parent.verticalCenter

                                            Label {
                                                    width: parent.width
                                                    wrapMode: Text.WordWrap
                                                    text: {
                                                        var nm = modelData.name || modelData.id || ""
                                                        var pv = modelData.provider || ""
                                                        return window.modelDisplayLabel(nm, pv)
                                                    }
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                }
                                                Label {
                                                    visible: (modelData.id || "") !== ""
                                                    width: parent.width
                                                    elide: Text.ElideMiddle
                                                    text: modelData.id || ""
                                                    font.pixelSize: 12
                                                    color: "#73000000"
                                            }
                                        }

                                        Switch {
                                                id: settingsModelSwitch
                                                enabled: false
                                                checked: true
                                            anchors.verticalCenter: parent.verticalCenter
                                            indicator: Rectangle {
                                                implicitWidth: 44
                                                implicitHeight: 22
                                                    x: settingsModelSwitch.leftPadding
                                                y: parent.height / 2 - height / 2
                                                radius: 12
                                                    color: settingsModelSwitch.checked ? "#006BFF" : "#D9D9D9"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Rectangle {
                                                        x: settingsModelSwitch.checked ? parent.width - width - 3 : 3
                                                    y: parent.height / 2 - height / 2
                                                    width: 18; height: 18; radius: 9
                                                    color: "#FFFFFF"
                                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: settingsContentScroll2
                        width: parent.width - settingsLeftNav.width - 1
                        height: parent.height
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        visible: settingsDialog.settingsTabIndex === 1
                        Column {
                            width: settingsContentScroll2.width
                            padding: 16
                            spacing: 20
                            Label {
                                text: qsTr("记忆")
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }
                            Row {
                                width: parent.width - 32
                                Item {
                                    width: parent.width - 60
                                    height: memoryToggleCol1.height
                                    Column {
                                        id: memoryToggleCol1
                                        spacing: 4
                                        Label {
                                            text: qsTr("启用用户记忆")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                        }
                                        Label {
                                            text: qsTr("将稳定事实注入到系统提示词中的 <userMemories> 区块。\n建议开启后直接使用下方“记忆条目管理”，无需额外配置。")
                                            font.pixelSize: 14
                                            color: "#73000000"
                                            lineHeight: 1.4
                                        }
                                    }
                                }
                                Switch {
                                    id: memorySwitch
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: memorySwitch.toggle()
                                    }
                                    indicator: Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 22
                                        x: memorySwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: 12
                                        color: memorySwitch.checked ? "#006BFF" : "#D9D9D9"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Rectangle {
                                            x: memorySwitch.checked ? parent.width - width - 3 : 3
                                            y: parent.height / 2 - height / 2
                                            width: 18; height: 18; radius: 9
                                            color: "#FFFFFF"
                                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }
                            Row {
                                width: parent.width - 32
                                Item {
                                    width: parent.width - 60
                                    height: memoryToggleCol2.height
                                    Column {
                                        id: memoryToggleCol2
                                        spacing: 4
                                        Label {
                                            text: qsTr("启用 LLM 二级判定")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                        }
                                        Label {
                                            text: qsTr("仅对规则边界样本调用模型复核，提升准确率（会增加少量 API 调用）")
                                            font.pixelSize: 14
                                            color: "#73000000"
                                            lineHeight: 1.4
                                        }
                                    }
                                }
                                Switch {
                                    id: llmSwitch
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: llmSwitch.toggle()
                                    }
                                    indicator: Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 22
                                        x: llmSwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: 12
                                        color: llmSwitch.checked ? "#006BFF" : "#D9D9D9"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Rectangle {
                                            x: llmSwitch.checked ? parent.width - width - 3 : 3
                                            y: parent.height / 2 - height / 2
                                            width: 18; height: 18; radius: 9
                                            color: "#FFFFFF"
                                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width - 32
                                height: 1
                                color: "#14000000"
                            }

                            Item {
                                width: parent.width - 32
                                height: memoryMgmtTitle.height

                                Column {
                                    id: memoryMgmtTitle
                                    spacing: 4
                                    Label {
                                        text: qsTr("记忆条目管理")
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        color: "#D9000000"
                                    }
                                    Label {
                                        text: qsTr("你可以在这里查看、搜索、新增、编辑或删除记忆内容。")
                                        font.pixelSize: 14
                                        color: "#73000000"
                                    }
                                }

                                CustomButton {
                                    width: 80
                                    height: 32
                                    backgroundColor: "#0F006BFF"
                                    textColor: "#006BFF"
                                    borderWidth: 0
                                    text: "+ 新增"
                                    fontSize: 14
                                    anchors.right: parent.right
                                    onClicked: {
                                        memoryEditPopup.editId = ""
                                        memoryEditPopup.open()
                                    }
                                }
                            }

                            Column {
                                width: parent.width - 32
                                spacing: 4

                                property string memorySearchText: ""

                                function filteredMemoryEntries() {
                                    var list = wsClient.memoryEntries
                                    var q = (memorySearchText || "").trim().toLowerCase()
                                    if (!q) return list
                                    var result = []
                                    for (var i = 0; i < list.length; i++) {
                                        var e = list[i]
                                        var t = String(e.title || "").toLowerCase()
                                        var c = String(e.content || "").toLowerCase()
                                        if (t.indexOf(q) >= 0 || c.indexOf(q) >= 0)
                                            result.push(e)
                                    }
                                    return result
                                }

                                SingleLineTextInput {
                                    width: parent.width
                                    inputHeight: 36
                                    inputRadius: 8
                                    icon: "qrc:/images/search.png"
                                    iconSize: 16
                                    fontSize: 14
                                    placeholderText: qsTr("搜索记忆内容/来源")
                                    onTextChanged: parent.memorySearchText = text
                                }

                                Label {
                                    visible: wsClient.memoryEntries.length === 0
                                    width: parent.width
                                    topPadding: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: qsTr("暂无记忆条目，点击「+ 新增」添加")
                                    font.pixelSize: 14
                                    color: "#73000000"
                                }

                                Repeater {
                                    model: parent.filteredMemoryEntries()

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 48
                                        color: memoryItemHover.hovered ? "#F7F9FA" : "transparent"
                                        radius: 8
                                        HoverHandler {
                                            id: memoryItemHover
                                        }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 16
                                            anchors.right: memoryItemActions.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 12
                                            clip: true
                                            Label {
                                                text: modelData.title || ""
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                color: "#D9000000"
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 200)
                                            }
                                            Label {
                                                text: modelData.content || ""
                                                font.pixelSize: 13
                                                color: "#73000000"
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 180)
                                            }
                                            Label {
                                                text: modelData.date || ""
                                                font.pixelSize: 12
                                                color: "#40000000"
                                            }
                                        }

                                        Row {
                                            id: memoryItemActions
                                            anchors.right: parent.right
                                            anchors.rightMargin: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            visible: memoryItemHover.hovered

                                            ImageButton {
                                                source: "qrc:/images/edit.png"
                                                onClicked: {
                                                    memoryEditPopup.editId = modelData.id || ""
                                                    memoryEditPopup.editTitle = modelData.title || ""
                                                    memoryEditPopup.editContent = modelData.content || ""
                                                    memoryEditPopup.open()
                                                }
                                            }
                                            ImageButton {
                                                source: "qrc:/images/delete.png"
                                                onClicked: {
                                                    wsClient.deleteMemoryEntry(modelData.id || "")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: settingsContentScroll3
                        width: parent.width - settingsLeftNav.width - 1
                        height: parent.height
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        visible: settingsDialog.settingsTabIndex === 2
                        Column {
                            id: sandboxPage
                            width: settingsContentScroll3.width
                            padding: 16
                            spacing: 12

                            property int sandboxMode: 0

                            Label {
                                text: qsTr("沙箱")
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }

                            Label {
                                text: qsTr("执行模式")
                                font.pixelSize: 14
                                color: "#73000000"
                            }

                            Column {
                                width: parent.width - 32
                                spacing: 16

                                Column {
                                    width: parent.width
                                    spacing: 2
                                    Row {
                                        spacing: 4
                                        Rectangle {
                                            width: 20; height: 20
                                            radius: 10
                                            border.color: sandboxPage.sandboxMode === 0 ? "#006BFF" : "#D9D9D9"
                                            border.width: 2
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                color: "#006BFF"
                                                anchors.centerIn: parent
                                                visible: sandboxPage.sandboxMode === 0
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sandboxPage.sandboxMode = 0
                                            }
                                        }
                                        Label {
                                            text: qsTr("自动（优先沙箱）")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }
                                    Label {
                                        text: qsTr("优先使用内置 VM 沙箱，不可用时回退本地")
                                        font.pixelSize: 16
                                        color: "#73000000"
                                        leftPadding: 24
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 2
                                    Row {
                                        spacing: 4
                                        Rectangle {
                                            width: 20; height: 20
                                            radius: 10
                                            border.color: sandboxPage.sandboxMode === 1 ? "#006BFF" : "#D9D9D9"
                                            border.width: 2
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                color: "#006BFF"
                                                anchors.centerIn: parent
                                                visible: sandboxPage.sandboxMode === 1
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sandboxPage.sandboxMode = 1
                                            }
                                        }
                                        Label {
                                            text: qsTr("本地运行")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }
                                    Label {
                                        text: qsTr("始终在本机运行")
                                        font.pixelSize: 16
                                        color: "#73000000"
                                        leftPadding: 24
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 2
                                    Row {
                                        spacing: 4
                                        Rectangle {
                                            width: 20; height: 20
                                            radius: 10
                                            border.color: sandboxPage.sandboxMode === 2 ? "#006BFF" : "#D9D9D9"
                                            border.width: 2
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                color: "#006BFF"
                                                anchors.centerIn: parent
                                                visible: sandboxPage.sandboxMode === 2
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sandboxPage.sandboxMode = 2
                                            }
                                        }
                                        Label {
                                            text: qsTr("仅沙箱（内置VM）")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }
                                    Label {
                                        text: qsTr("要求内置 VM 沙箱可用，否则报错")
                                        font.pixelSize: 16
                                        color: "#73000000"
                                        leftPadding: 24
                                    }
                                    Rectangle{
                                        width: parent.width
                                        height: 2
                                    }
                                    Row {
                                        leftPadding: 24
                                        spacing: 4
                                        Label {
                                            text: qsTr("未检测到沙箱VM，")
                                            font.pixelSize: 14
                                            color: "#73000000"
                                        }
                                        Label {
                                            text: qsTr("立即安装")
                                            font.pixelSize: 14
                                            font.underline: true
                                            color: "#006BFF"
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: settingsFooter
                    width: parent.width
                    height: 64
                    anchors.bottom: parent.bottom

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.top: parent.top
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                wsClient.saveGeneralSettings(
                                    memorySwitch.checked,
                                    llmSwitch.checked,
                                    sandboxPage.sandboxMode
                                )
                                settingsDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: settingsDialog.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: memoryEditPopup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        z: 200

        property string editId: ""
        property string editTitle: ""
        property string editContent: ""
        property bool isEdit: editId.length > 0

        onOpened: {
            memEditTitleInput.text = isEdit ? editTitle : ""
            memEditContentInput.text = isEdit ? editContent : ""
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }
        Overlay.modal: Rectangle {
            color: "#40000000"
        }
        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                onClicked: memoryEditPopup.close()
            }
            Rectangle {
                width: 480
                height: memEditCol.implicitHeight
                anchors.centerIn: parent
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    id: memEditCol
                    width: parent.width
                    padding: 24
                    spacing: 16

                    Label {
                        text: memoryEditPopup.isEdit ? qsTr("编辑记忆") : qsTr("新增记忆")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                    }

                    Column {
                        width: parent.width - 48
                        spacing: 8
                        Row {
                            spacing: 2
                            Label {
                                text: qsTr("标题")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            Label {
                                text: "*"
                                font.pixelSize: 14
                                color: "#FF4D4F"
                            }
                        }
                        SingleLineTextInput {
                            id: memEditTitleInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: qsTr("如：我的名字、偏好语言")
                        }
                    }

                    Column {
                        width: parent.width - 48
                        spacing: 8
                        Row {
                            spacing: 2
                            Label {
                                text: qsTr("内容")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            Label {
                                text: "*"
                                font.pixelSize: 14
                                color: "#FF4D4F"
                            }
                        }
                        MultiLineTextInput {
                            id: memEditContentInput
                            width: parent.width
                            inputHeight: 100
                            placeholderText: qsTr("记忆的具体内容")
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        spacing: 12
                        layoutDirection: Qt.RightToLeft

                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                var t = memEditTitleInput.text.trim()
                                var c = memEditContentInput.text.trim()
                                if (t.length === 0) return
                                if (memoryEditPopup.isEdit)
                                    wsClient.updateMemoryEntry(memoryEditPopup.editId, t, c)
                                else
                                    wsClient.addMemoryEntry(t, c)
                                memoryEditPopup.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: memoryEditPopup.close()
                        }
                    }
                }
            }
        }
    }

    LoginPage {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: rightTopPanel.height
        anchors.bottom: parent.bottom
        visible: !authController.loggedIn
        enabled: visible
        z: 20000
    }
}
