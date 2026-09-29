// 把 main.qml 里的 officeActionButton 原样抽出来单独渲染（编辑态 / 视图态各一张），
// 用于跟 Figma 设计稿核对。只做渲染，不参与产品逻辑。
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const qml = fs.readFileSync(path.join(root, 'main.qml'), 'utf8').replace(/\r\n/g, '\n');

function extractById(id) {
  const at = qml.indexOf(`id: ${id}`);
  if (at < 0) throw new Error(`${id} not found`);
  const open = qml.lastIndexOf('Rectangle {', at);
  if (open < 0) throw new Error('enclosing Rectangle not found');
  let depth = 0;
  for (let i = open; i < qml.length; i += 1) {
    if (qml[i] === '{') depth += 1;
    else if (qml[i] === '}') {
      depth -= 1;
      if (depth === 0) return qml.slice(open, i + 1);
    }
  }
  throw new Error('unbalanced braces');
}

// 独立运行时没有 qrc，指到仓库里的真实 svg 文件（字节就是产品用的那份）
const imagesDir = path.join(root, 'images').replace(/\\/g, '/');
const button = extractById('officeActionButton').replace(/qrc:\/images\//g, `file:///${imagesDir}/`);

const outDir = path.join(root, 'build');
fs.mkdirSync(outDir, { recursive: true });
const shot = (name) => path.join(outDir, `edit-save-button-${name}.png`).replace(/\\/g, '/');

const harness = `import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: win
    width: 320
    height: 60
    visible: true
    color: "#FFFFFF"

    QtObject {
        id: newTaskRec
        property string artifactSidebarMode: "edit"
        property var selectedOfficeFile: ({})
        property bool officeEditPending: false
        property bool officePreviewPending: false
        property bool officeSaveRequested: false
        property bool officePanelMaximized: false
        function supportsLocalViewerEdit(file) { return true }
        function refreshOfficeTab(index) { console.log("[harness] refresh", index) }
    }

    QtObject {
        id: fakeView
        property string mode: "edit"
        function switchMode(m) { mode = m; console.log("[harness] switchMode", m) }
        function saveEditor() { console.log("[harness] saveEditor"); return true }
        function refresh() { return true }
    }

    QtObject {
        id: fakeClient
        property bool saving: false
        property string editorUrl: "http://127.0.0.1:1/index.html"
    }

    Item {
        id: fakeHost
        property var officeView: fakeView
        property var officeClient: fakeClient
    }

    QtObject {
        id: officeViewsRepeater
        property int count: 1
        function itemAt(i) { return fakeHost }
    }

    Item {
        id: content
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: "#FFFFFF" }  // 给透明底的按钮一个背景，否则抓图看不出灰字

        Item {
            id: officeMoreButton
            width: 36
            height: 36
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
        }

${button}

        Timer {
            interval: 700
            running: true
            repeat: false
            onTriggered: {
                content.grabToImage(function(r) {
                    r.saveToFile("${shot('edit')}")
                    // 截图回调是异步的，切状态必须等第一张存完
                    newTaskRec.artifactSidebarMode = "preview"
                    fakeView.mode = "view"
                    viewTimer.restart()
                })
            }
        }

        Timer {
            id: viewTimer
            interval: 500
            repeat: false
            onTriggered: content.grabToImage(function(r) {
                r.saveToFile("${shot('view')}")
                Qt.quit()
            })
        }
    }
}
`;

const harnessPath = path.join(outDir, 'edit-save-button-render.qml');
fs.writeFileSync(harnessPath, harness);
const qmlExe = 'D:/qt.8.3/6.8.3/msvc2022_64/bin/qml.exe';
const res = spawnSync(qmlExe, [harnessPath], {
  env: { ...process.env, QT_OPENGL: 'desktop', QSG_RHI_BACKEND: 'opengl' },
  timeout: 60000,
  encoding: 'utf8',
});
if (res.stdout) process.stdout.write(res.stdout);
if (res.stderr) process.stderr.write(res.stderr);
console.log('exit', res.status);
for (const f of [shot('edit'), shot('view')])
  console.log(path.basename(f), fs.existsSync(f) ? `ok ${fs.statSync(f).size}B` : 'MISSING');
