// 从 main.qml 抽出 finishSidebarSessionLoad 原样运行，验证「后台历史重载不会把正在看的
// 文件预览重置掉」这条修复，同时确认跨会话恢复预览的原有行为还在。
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const qml = fs.readFileSync(path.resolve(__dirname, '../main.qml'), 'utf8').replace(/\r\n/g, '\n');

function extract(name) {
  const start = qml.indexOf(`                function ${name}(`);
  if (start < 0) throw new Error(`function ${name} not found`);
  const rest = qml.slice(start);
  const end = rest.indexOf('\n                }\n');
  if (end < 0) throw new Error(`end of ${name} not found`);
  return rest.slice(0, end + '\n                }'.length);
}

const body = extract('finishSidebarSessionLoad');

function harness(deps) {
  const factory = new Function('deps', `
    let { currentSidebarSessionKey, wsClient, rebuildSessionArtifacts, sidebarVisibilityBySession,
          officeTabs, findOfficeTab, activateOfficeTab, activeOfficeTabIndex,
          artifactSidebarVisible, artifactSidebarMode, officePanelMaximized,
          officePanelSizeManuallySet, sessionHistoryLoading, sessionInputFiles,
          selectedOfficeFile, sidebarStateSessionKey } = deps;
    ${body}
    return {
      call: finishSidebarSessionLoad,
      state: () => ({ activeOfficeTabIndex, artifactSidebarVisible, artifactSidebarMode,
                      officePanelMaximized, officePanelSizeManuallySet, sessionHistoryLoading,
                      sidebarStateSessionKey }),
    };
  `);
  return factory(deps);
}

function makeDeps(overrides = {}) {
  const activated = [];
  const deps = {
    currentSidebarSessionKey: () => 'task:A',
    wsClient: { currentSessionInputFiles: () => [] },
    rebuildSessionArtifacts: () => {},
    sidebarVisibilityBySession: {},
    officeTabs: {
      count: 1,
      get: (i) => ({ path: 'C:/w/a.docx', sessionKey: 'task:A' })[i === undefined ? 0 : 0],
    },
    findOfficeTab: () => -1,
    activateOfficeTab: (i) => activated.push(i),
    activeOfficeTabIndex: -1,
    artifactSidebarVisible: false,
    artifactSidebarMode: 'list',
    officePanelMaximized: false,
    officePanelSizeManuallySet: false,
    sessionHistoryLoading: true,
    sessionInputFiles: [],
    selectedOfficeFile: {},
    sidebarStateSessionKey: 'task:A',
    ...overrides,
  };
  deps.__activated = activated;
  return deps;
}

// 1. 后台历史重载：面板上正开着文件 → 什么都不许动
{
  const deps = makeDeps({
    activeOfficeTabIndex: 0,
    artifactSidebarVisible: true,
    artifactSidebarMode: 'preview',
    officePanelMaximized: true,
    selectedOfficeFile: { path: 'C:/w/a.docx' },
    officeTabs: { count: 1, get: () => ({ path: 'C:/w/a.docx', sessionKey: 'task:A' }) },
  });
  const h = harness(deps);
  h.call();
  assert.deepEqual(h.state(), {
    activeOfficeTabIndex: 0,
    artifactSidebarVisible: true,
    artifactSidebarMode: 'preview',
    officePanelMaximized: true,
    officePanelSizeManuallySet: false,
    sessionHistoryLoading: false,
    sidebarStateSessionKey: 'task:A',
  }, 'a background history reload must not reset the open preview');
  assert.equal(deps.__activated.length, 0, 'must not re-activate a tab while one is showing');
}

// 2. 编辑态同样不能被后台重载打断
{
  const deps = makeDeps({
    activeOfficeTabIndex: 0,
    artifactSidebarVisible: true,
    artifactSidebarMode: 'edit',
    officeTabs: { count: 1, get: () => ({ path: 'C:/w/a.docx', sessionKey: 'task:A' }) },
  });
  const h = harness(deps);
  h.call();
  assert.equal(h.state().artifactSidebarMode, 'edit', 'edit mode must survive a history reload');
  assert.equal(h.state().artifactSidebarVisible, true, 'panel must stay open in edit mode');
}

// 3. 面板上有标签但属于别的会话（切换中）→ 仍走恢复逻辑，不因标签存在就短路
{
  const deps = makeDeps({
    activeOfficeTabIndex: 0,
    artifactSidebarVisible: true,
    artifactSidebarMode: 'preview',
    officeTabs: { count: 1, get: () => ({ path: 'C:/w/old.docx', sessionKey: 'task:B' }) },
  });
  const h = harness(deps);
  h.call();
  assert.equal(h.state().artifactSidebarMode, 'list', 'a tab from another session must not block restore');
}

// 4. 切到某会话：该会话有快照且文件标签还开着 → 恢复预览（原有功能）
{
  const deps = makeDeps({
    sidebarVisibilityBySession: { 'task:A': { visible: true, activePath: 'C:/w/a.docx' } },
    activeOfficeTabIndex: 5, // 上一次会话留下的索引；恢复分支不该把它清成 -1
    officeTabs: { count: 2, get: (i) => [{ path: 'C:/w/b.pdf', sessionKey: 'task:B' },
                                         { path: 'C:/w/a.docx', sessionKey: 'task:A' }][i] },
    findOfficeTab: (p, k) => (String(p).toLowerCase().endsWith('a.docx') && k === 'task:A' ? 1 : -1),
  });
  const h = harness(deps);
  h.call();
  assert.deepEqual(deps.__activated, [1], 'restore must re-activate the remembered file');
  assert.equal(h.state().activeOfficeTabIndex, 5,
    'the restore branch must not reset the active tab index');
  assert.equal(h.state().artifactSidebarVisible, true,
    'restored visibility comes from the snapshot');
}

// 5. 切到某会话但没有快照 → 回到文件列表并收起（保持原有行为）
{
  const deps = makeDeps({ sidebarVisibilityBySession: {} });
  const h = harness(deps);
  h.call();
  assert.equal(h.state().artifactSidebarMode, 'list', 'no snapshot -> file list');
  assert.equal(h.state().artifactSidebarVisible, false, 'no snapshot -> panel hidden');
}

// 6. 快照里的文件标签已经关掉了 → 回列表，可见性沿用快照
{
  const deps = makeDeps({
    sidebarVisibilityBySession: { 'task:A': { visible: true, activePath: 'C:/w/gone.docx' } },
    findOfficeTab: () => -1,
  });
  const h = harness(deps);
  h.call();
  assert.equal(h.state().artifactSidebarMode, 'list', 'closed tab -> file list');
  assert.equal(h.state().artifactSidebarVisible, true, 'visibility falls back to the snapshot');
}

console.log('sidebar restore checks passed');
