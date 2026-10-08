// 把 main.qml 里的产物列表条目（artifactSidebarFileDelegate）原样抽出来渲染，
// 核对「查看全部」那一轮的高亮样式。只做渲染，不参与产品逻辑。
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const qml = fs.readFileSync(path.join(root, 'main.qml'), 'utf8').replace(/\r\n/g, '\n');

function extractById(id) {
  const at = qml.indexOf(`id: ${id}`);
  if (at < 0) throw new Error(`${id} not found in main.qml`);
  const open = qml.lastIndexOf('Component {', at);
  if (open < 0) throw new Error('enclosing Component not found');
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

const imagesDir = path.join(root, 'images').replace(/\\/g, '/');
const delegate = extractById('artifactSidebarFileDelegate')
  .replace(/qrc:\/images\//g, `file:///${imagesDir}/`);
// 让列表里的图标走仓库里的真实 svg（列首那行是标题，不在 delegate 里）

const outDir = path.join(root, 'build');
fs.mkdirSync(outDir, { recursive: true });
const shot = path.join(outDir, 'artifact-list-highlight.png').replace(/\\/g, '/');

const harness = `import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: win
    width: 320
    height: 200
    visible: true
    color: "#FFFFFF"

    QtObject {
        id: newTaskRec
        // 只高亮“本次问答”的两个产物（模拟点查看全部后的状态）
        property var artifactHighlights: ({
            "c:/w/2026-10-08/影像分析报告.html": true,
            "c:/w/2026-10-08/ct报告.md": true
        })
        function artifactHighlightKey(file) {
            return String((file && file.path) || "").replace(/\\\\/g, "/").toLowerCase()
        }
        function artifactIcon(file) {
            var ext = String((file && file.extension) || (file && file.path) || "").split(".").pop().toLowerCase()
            var name = (ext === "docx" || ext === "doc") ? "document-word.svg"
                     : (ext === "xlsx" || ext === "csv") ? "document-excel.svg"
                     : (ext === "pptx") ? "document-ppt.svg" : "document-text.svg"
            return "file:///${imagesDir}/doc/" + name
        }
        function hideResourcePopover() {}
        function openOfficeFile(file) { console.log("[harness] open", file && file.path) }
    }

    Item {
        id: content
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: "#FFFFFF" }

${delegate}

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Repeater {
                model: [
                    { name: "影像分析报告.html", path: "C:/w/2026-10-08/影像分析报告.html", extension: "html" },
                    { name: "CT报告.md", path: "C:/w/2026-10-08/CT报告.md", extension: "md" },
                    { name: "CT历史.json", path: "C:/w/2026-09-30/CT历史.json", extension: "json" },
                    { name: "分割标签.nii.gz", path: "C:/w/2026-09-30/分割标签.nii.gz", extension: "gz" }
                ]
                delegate: artifactSidebarFileDelegate
            }
        }

        Timer {
            interval: 800
            running: true
            repeat: false
            onTriggered: content.grabToImage(function(r) { r.saveToFile("${shot}"); Qt.quit() })
        }
    }
}
`;

const harnessPath = path.join(outDir, 'artifact-list-render.qml');
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
console.log(shot, fs.existsSync(shot) ? `ok ${fs.statSync(shot).size}B` : 'MISSING');
