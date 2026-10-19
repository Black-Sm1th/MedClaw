// Verify that project collapse state is owned by ProjectSidebar rather than a
// transient Repeater delegate, so project metadata refreshes cannot reset it.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const qml = fs.readFileSync(
  path.resolve(__dirname, '../components/ProjectSidebar.qml'),
  'utf8',
).replace(/\r\n/g, '\n');

function extract(name) {
  const signature = `    function ${name}(`;
  const start = qml.indexOf(signature);
  if (start < 0) throw new Error(`function ${name} not found`);

  const open = qml.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < qml.length; ++i) {
    if (qml[i] === '{') depth += 1;
    if (qml[i] === '}') depth -= 1;
    if (depth === 0) return qml.slice(start, i + 1);
  }
  throw new Error(`end of ${name} not found`);
}

const functions = [
  extract('projectKey'),
  extract('isProjectExpanded'),
  extract('setProjectExpanded'),
  extract('pruneCollapsedProjects'),
].join('\n');

function harness(initialProjects) {
  const factory = new Function('initialProjects', `
    let projects = initialProjects;
    let collapsedProjectIds = {};
    ${functions}
    return {
      isExpanded: isProjectExpanded,
      setExpanded: setProjectExpanded,
      setProjects: (value) => { projects = value; },
      prune: pruneCollapsedProjects,
      states: () => collapsedProjectIds,
    };
  `);
  return factory(initialProjects);
}

const alpha = { project_id: 'alpha', color: '#73000000' };
const beta = { project_id: 'beta', color: '#FF3D40' };
const h = harness([alpha, beta]);

assert.equal(h.isExpanded(alpha), true, 'projects are expanded by default');
h.setExpanded(alpha, false);
assert.equal(h.isExpanded(alpha), false, 'a project can be collapsed');

// Simulate updateProjectColor reloading and reordering the entire model with
// fresh project objects. The stable project id must retain the collapsed state.
const refreshedAlpha = { project_id: 'alpha', color: '#16B1FF' };
h.setProjects([beta, refreshedAlpha]);
h.prune();
assert.equal(
  h.isExpanded(refreshedAlpha),
  false,
  'color refresh and reorder must preserve the collapsed state',
);
assert.deepEqual(h.states(), { alpha: true });

h.setExpanded(refreshedAlpha, true);
assert.equal(h.isExpanded(refreshedAlpha), true, 'a project can be expanded again');

h.setExpanded(beta, false);
h.setProjects([refreshedAlpha]);
h.prune();
assert.deepEqual(h.states(), {}, 'removed projects are pruned from remembered state');

assert.match(
  qml,
  /readonly property bool expanded: root\.isProjectExpanded\(modelData\)/,
  'the delegate must derive expanded state from the sidebar-level store',
);
assert.doesNotMatch(
  qml,
  /property bool expanded: true/,
  'the delegate must not own reset-prone expanded state',
);

console.log('project sidebar collapse checks passed');
