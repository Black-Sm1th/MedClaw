// 直接抽取 main.qml 里的过期判定函数运行，验证逻辑（不改动代码文本，只补上外部全局）。
const fs = require('node:fs');
const path = require('node:path');

const qml = fs.readFileSync(path.resolve(__dirname, '../main.qml'), 'utf8').replace(/\r\n/g, '\n');

function extract(name) {
  const start = qml.indexOf(`                function ${name}(`);
  if (start < 0) throw new Error(`function ${name} not found in main.qml`);
  // 函数体按缩进 16 空格结束（下一个同级声明）
  const rest = qml.slice(start);
  const end = rest.indexOf('\n                }\n');
  if (end < 0) throw new Error(`end of ${name} not found`);
  return rest.slice(0, end + '\n                }'.length);
}

const source = [extract('officeTabKey'), extract('setOfficeFileBaseline'), extract('checkOfficeFileChanges')].join('\n');

// ---- stubs -----------------------------------------------------------------
let files = {}; // path -> { modifiedAt, sizeBytes }
let tabs = [];
const officeTabs = { get count() { return tabs.length; }, get: (i) => tabs[i] };
const $MainViewController = {
  localFileInfo: (p) => {
    const f = files[String(p).replace(/\\/g, '/').toLowerCase()];
    return f ? { absolutePath: p, modifiedAt: f.modifiedAt, sizeBytes: f.sizeBytes } : {};
  },
};
let officeTabFileStates = {};
const officeTabKey = null; // provided by the extracted source

// eslint-disable-next-line no-eval
const run = new Function('officeTabs', '$MainViewController', 'officeTabFileStatesRef', `
  let officeTabFileStates = officeTabFileStatesRef;
  ${source}
  return { check: checkOfficeFileChanges, setBaseline: setOfficeFileBaseline,
           getStates: () => officeTabFileStates };
`);
const ctx = run(officeTabs, $MainViewController, officeTabFileStates);
const states = () => ctx.getStates();

// ---- assertions ------------------------------------------------------------
const assert = require('node:assert/strict');
const staleOf = (p) => (states()[p] && states()[p].stale) === true;

// 1. 首次登记基线，不报过期
files['/w/a.docx'] = { modifiedAt: 1000, sizeBytes: 10 };
tabs = [{ path: '/w/a.docx' }];
ctx.check();
assert.equal(staleOf('/w/a.docx'), false, 'first sight should just register a baseline');

// 2. 磁盘未变：连续轮询不报
ctx.check();
ctx.check();
assert.equal(staleOf('/w/a.docx'), false, 'unchanged file must stay clean');

// 3. 内容被外部改写（mtime + size 变化）→ 报过期
files['/w/a.docx'] = { modifiedAt: 2000, sizeBytes: 12 };
ctx.check();
assert.equal(staleOf('/w/a.docx'), true, 'external rewrite must be flagged');

// 4. 之后再改，仍然只报过期，且基线保持打开时的值（不漂移）
files['/w/a.docx'] = { modifiedAt: 3000, sizeBytes: 20 };
ctx.check();
assert.equal(staleOf('/w/a.docx'), true, 'still stale after another rewrite');
assert.equal(states()['/w/a.docx'].modifiedAt, 1000, 'baseline must stay at the opened revision');

// 5. 刷新后重新取基线 → 恢复正常
ctx.setBaseline('/w/a.docx');
assert.equal(staleOf('/w/a.docx'), false, 'baseline reset must clear the flag');

// 6. 只改 mtime、大小不变的原地改写也要报（同尺寸覆盖）
files['/w/a.docx'] = { modifiedAt: 4000, sizeBytes: 20 };
ctx.check();
assert.equal(staleOf('/w/a.docx'), true, 'same-size in-place edit must be flagged');

// 7. 文件暂时读不到（被删除 / 正在被原子替换）时不误报：保留上一次的干净状态
files['/w/a.docx'] = { modifiedAt: 4000, sizeBytes: 20 };
ctx.check();
ctx.setBaseline('/w/a.docx');
delete files['/w/a.docx'];
ctx.check();
assert.equal(staleOf('/w/a.docx'), false,
  'unreadable file must not be reported stale (atomic replace window)');
assert.ok(states()['/w/a.docx'], 'state must be kept while unreadable');

// 8. 两个标签互不干扰；关闭的标签状态会被清掉
files['/w/a.docx'] = { modifiedAt: 5000, sizeBytes: 20 };
files['/w/b.pdf'] = { modifiedAt: 100, sizeBytes: 1 };
tabs = [{ path: '/w/a.docx' }, { path: '/w/b.pdf' }];
ctx.check();
ctx.setBaseline('/w/a.docx');
ctx.setBaseline('/w/b.pdf');
files['/w/b.pdf'] = { modifiedAt: 200, sizeBytes: 2 };
ctx.check();
assert.equal(staleOf('/w/a.docx'), false, 'untouched tab must stay clean');
assert.equal(staleOf('/w/b.pdf'), true, 'changed tab must be flagged');
tabs = [{ path: '/w/a.docx' }];
ctx.check();
assert.equal(Object.keys(states()).length, 1, 'closed tab state must be dropped');

// 9. 标签路径大小写 / 反斜杠归一化：同一个文件只对应一个状态项
//    （stub 的 localFileInfo 按归一化后的路径查表，模拟 QFileInfo 解析真实路径）
files['c:/work/c.txt'] = { modifiedAt: 7, sizeBytes: 3 };
tabs = [{ path: 'C:\\Work\\C.TXT' }];
ctx.check();
assert.ok(states()['c:/work/c.txt'], 'state key must be normalized (lowercase + forward slashes)');
assert.equal(states()['c:/work/c.txt'].stale, false, 'normalized key starts clean');
files['c:/work/c.txt'] = { modifiedAt: 8, sizeBytes: 4 };
ctx.check();
assert.equal(states()['c:/work/c.txt'].stale, true, 'normalized key still detects changes');

console.log('preview staleness checks passed');
