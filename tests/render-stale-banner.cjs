// 把 main.qml 里的「文件已过期」横幅原样抽出来单独渲染，用于核对视觉。
// 只做渲染与截图，不参与产品逻辑。
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const qml = fs.readFileSync(path.join(root, 'main.qml'), 'utf8').replace(/\r\n/g, '\n');

function extractBlock(marker) {
  const at = qml.indexOf(marker);
  if (at < 0) throw new Error(`${marker} not found in main.qml`);
  const open = qml.lastIndexOf('Rectangle {', at);
  if (open < 0) throw new Error('enclosing Rectangle not found');
  // 从这里做花括号配对，取到横幅的结束处
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

const banner = extractBlock('id: staleFileBanner');
const outDir = path.join(root, 'build');
fs.mkdirSync(outDir, { recursive: true });
const viewShot = path.join(outDir, 'stale-banner-view.png').replace(/\\/g, '/');
const editShot = path.join(outDir, 'stale-banner-edit.png').replace(/\\/g, '/');

const harness = `import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: win
    width: 760
    height: 52
    visible: true
    color: "#FFFFFF"

    QtObject {
        id: newTaskRec
        function refreshOfficeTab(index) { console.log("[banner-render] refresh clicked", index) }
    }

    QtObject {
        id: fakeOfficeView
        property string mode: "view"
    }

    Item {
        id: content
        anchors.fill: parent

    Item {
        id: officeViewHost
        anchors.fill: parent
        property bool fileStale: true
        property int index: 0
        property var officeView: fakeOfficeView

${banner}

    }

        Timer {
            interval: 900
            running: true
            repeat: false
            onTriggered: {
                content.grabToImage(function(result) {
                    result.saveToFile("${viewShot}")
                    // 截图是异步回调，改模式必须等第一张存完，否则会截到编辑态文案
                    fakeOfficeView.mode = "edit"
                    editTimer.restart()
                })
            }
        }

        Timer {
            id: editTimer
            interval: 500
            repeat: false
            onTriggered: {
                content.grabToImage(function(result) { result.saveToFile("${editShot}") })
                quitTimer.restart()
            }
        }

        Timer {
            id: quitTimer
            interval: 400
            repeat: false
            onTriggered: Qt.quit()
        }
    }
}
`;

const harnessPath = path.join(outDir, 'stale-banner-render.qml');
fs.writeFileSync(harnessPath, harness);
console.log('harness written:', harnessPath);

const qmlExe = 'D:/qt.8.3/6.8.3/msvc2022_64/bin/qml.exe';
const result = spawnSync(qmlExe, [harnessPath], {
  env: { ...process.env, QT_OPENGL: 'desktop', QSG_RHI_BACKEND: 'opengl' },
  timeout: 60000,
  encoding: 'utf8',
});
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
console.log('exit', result.status, result.error ? String(result.error) : '');
for (const shot of [viewShot, editShot])
  console.log(shot, fs.existsSync(shot) ? `ok ${fs.statSync(shot).size}B` : 'MISSING');
