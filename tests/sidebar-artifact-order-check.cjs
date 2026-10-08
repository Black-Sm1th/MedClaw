// 从 main.qml 抽出 sortedSidebarFiles 原样运行，验证「查看全部那一轮排最前」在
// 升序/降序两种状态下都成立（降序会 reverse，容易把高亮项甩到末尾）。
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

const body = [extract('artifactHighlightKey'), extract('sortedSidebarFiles')].join('\n');

function harness(deps) {
  const factory = new Function('deps', `
    let { artifactHighlights, sidebarFilesAscending } = deps;
    ${body}
    return { sort: sortedSidebarFiles };
  `);
  return factory(deps);
}

const files = [
  { name: 'z_旧产物.json', path: 'C:/w/old/z.json' },
  { name: 'a_本轮报告.html', path: 'C:/w/new/a.html' },
  { name: 'm_本轮分数.csv', path: 'C:/w/new/m.csv' },
  { name: 'b_旧产物.png', path: 'C:/w/old/b.png' },
];
const highlights = {
  'c:/w/new/a.html': true,
  'c:/w/new/m.csv': true,
};
const names = (list) => list.map((f) => f.name);

// 1) 升序：本轮两个在前（按名字排），其余按名字在后
{
  const h = harness({ artifactHighlights: highlights, sidebarFilesAscending: true });
  assert.deepEqual(names(h.sort(files)), [
    'a_本轮报告.html', 'm_本轮分数.csv',   // 本轮，按名字
    'b_旧产物.png', 'z_旧产物.json',       // 其余，按名字
  ], 'ascending: highlighted first, then the rest by name');
}

// 2) 降序：本轮仍然在最前（不能被 reverse 甩到末尾），其余按名字倒序
{
  const h = harness({ artifactHighlights: highlights, sidebarFilesAscending: false });
  assert.deepEqual(names(h.sort(files)), [
    'm_本轮分数.csv', 'a_本轮报告.html',   // 本轮仍在前
    'z_旧产物.json', 'b_旧产物.png',       // 其余倒序
  ], 'descending: highlighted must stay on top after reverse');
}

// 3) 没有高亮时行为不变（仍与升/降序一致）
{
  const asc = harness({ artifactHighlights: {}, sidebarFilesAscending: true });
  assert.deepEqual(names(asc.sort(files)),
    ['a_本轮报告.html', 'b_旧产物.png', 'm_本轮分数.csv', 'z_旧产物.json'],
    'no highlight -> plain name sort');

  const desc = harness({ artifactHighlights: {}, sidebarFilesAscending: false });
  assert.deepEqual(names(desc.sort(files)),
    ['z_旧产物.json', 'm_本轮分数.csv', 'b_旧产物.png', 'a_本轮报告.html'],
    'no highlight -> reversed name sort');
}

// 4) 路径归一化：反斜杠 / 大小写不同也算同一份产物
{
  const h = harness({
    artifactHighlights: { 'c:/w/new/a.html': true },
    sidebarFilesAscending: true,
  });
  const listed = h.sort([{ name: '报告', path: 'C:\\W\\NEW\\A.HTML' }, files[0]]);
  assert.equal(listed[0].name, '报告', 'path normalization must match backslashes/case');
}

console.log('sidebar artifact ordering checks passed');
