/* 阅片台「重定向影像」对话框（类 ITK-SNAP）
 * 实现方式：不改体素数据，只重新指派三个视口的观察平面（setOrientation）与上下翻转（viewUp）。
 * 依赖 bundle 暴露的 window.__medclawRedirect（getState / applyOrientation / resetOrientation）。
 */
(function () {
  'use strict';

  var LETTERS = {
    '1,0,0': 'L', '-1,0,0': 'R',
    '0,1,0': 'P', '0,-1,0': 'A',
    '0,0,1': 'S', '0,0,-1': 'I'
  };
  // 下拉选项：value = "<源轴>:<符号>"，文案按"从 A 到 B"
  var OPTIONS = [
    { axis: 0, sign: 1, text: 'Left to Right' },
    { axis: 0, sign: -1, text: 'Right to Left' },
    { axis: 1, sign: 1, text: 'Posterior to Anterior' },
    { axis: 1, sign: -1, text: 'Anterior to Posterior' },
    { axis: 2, sign: 1, text: 'Inferior to Superior' },
    { axis: 2, sign: -1, text: 'Superior to Inferior' }
  ];

  function bridge() {
    var b = window.__medclawRedirect;
    return b && b.available ? b : null;
  }

  function vecKey(v) {
    return [Math.round(v[0]), Math.round(v[1]), Math.round(v[2])].join(',');
  }

  // 世界向量（LPS）-> 方位字母。斜位时取最大分量。
  function letterOf(v) {
    var idx = 0;
    var best = -1;
    for (var i = 0; i < 3; i += 1) {
      var a = Math.abs(v[i]);
      if (a > best) { best = a; idx = i; }
    }
    var out = [0, 0, 0];
    out[idx] = v[idx] >= 0 ? 1 : -1;
    return LETTERS[vecKey(out)] || '?';
  }

  // 源轴（0/1/2）在 LPS 下的方向向量，来自 volume.direction（列优先，3x3）
  function axisVector(direction, axis) {
    return [direction[axis * 3], direction[axis * 3 + 1], direction[axis * 3 + 2]];
  }

  function raiCode(columns) {
    // columns: [[x axis world dir], [y], [z]] 语义为"每根体素轴指向的方位"
    return columns.map(letterOf).join('');
  }

  function identitySelection() {
    return {
      x: { axis: 0, sign: 1 },
      y: { axis: 1, sign: 1 },
      z: { axis: 2, sign: 1 }
    };
  }

  function selectionToColumns(sel, direction) {
    var order = ['x', 'y', 'z'];
    return order.map(function (k) {
      var s = sel[k];
      var v = axisVector(direction, s.axis).slice();
      return v.map(function (c) { return c * s.sign; });
    });
  }

  function selectionMatrix(sel) {
    // 4x4，行优先：第 r 行第 c 列 = 新轴 c 在源轴 r 上的分量
    var m = [];
    for (var r = 0; r < 4; r += 1) m.push([0, 0, 0, 0]);
    ['x', 'y', 'z'].forEach(function (k, cIdx) {
      var s = sel[k];
      m[s.axis][cIdx] = s.sign;
    });
    m[3][3] = 1;
    return m;
  }

  function directionMatrix(direction, spacing) {
    // 体素到世界的 4x4（列 = 轴向量 * 间距）
    var m = [];
    for (var r = 0; r < 4; r += 1) m.push([0, 0, 0, 0]);
    for (var c = 0; c < 3; c += 1) {
      m[0][c] = direction[c * 3] * spacing[c];
      m[1][c] = direction[c * 3 + 1] * spacing[c];
      m[2][c] = direction[c * 3 + 2] * spacing[c];
    }
    m[3][3] = 1;
    return m;
  }

  function multiply4(a, b) {
    var out = [];
    for (var r = 0; r < 4; r += 1) {
      out.push([0, 0, 0, 0]);
      for (var c = 0; c < 4; c += 1) {
        var s = 0;
        for (var k = 0; k < 4; k += 1) s += a[r][k] * b[k][c];
        out[r][c] = s;
      }
    }
    return out;
  }

  function fmt(n) {
    if (Math.abs(n) < 1e-9) return '0';
    var s = Math.abs(n) >= 100 ? n.toFixed(1) : n.toFixed(3);
    return s.replace(/\.?0+$/, '');
  }

  function matrixHtml(m) {
    var rows = '';
    for (var r = 0; r < 4; r += 1) {
      rows += '<tr>';
      for (var c = 0; c < 4; c += 1) rows += '<td>' + fmt(m[r][c]) + '</td>';
      rows += '</tr>';
    }
    return '<table class="rd-matrix">' + rows + '</table>';
  }

  // 立方体三轴示意图
  function drawCube(canvas, columns, labels) {
    var dpr = window.devicePixelRatio || 1;
    var w = 150;
    var h = 120;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
    var ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    var ox = 62;
    var oy = 74;
    var unit = 34;
    // 等轴测投影：世界 x -> 右下，y -> 左下，z -> 上
    function project(v) {
      return [
        ox + (v[0] * 0.86 - v[1] * 0.86) * unit,
        oy + (v[0] * 0.5 + v[1] * 0.5 - v[2]) * unit
      ];
    }
    var colors = ['#e05252', '#3ecf8e', '#27aae1'];
    var names = ['X', 'Y', 'Z'];

    // 立方体轮廓（用三根轴拼出的平行六面体）
    var axes = [[1, 0, 0], [0, 1, 0], [0, 0, 1]].map(project);
    var o = project([0, 0, 0]);
    function line(a, b, color, width) {
      ctx.beginPath();
      ctx.strokeStyle = color;
      ctx.lineWidth = width || 1;
      ctx.moveTo(a[0], a[1]);
      ctx.lineTo(b[0], b[1]);
      ctx.stroke();
    }
    var pxy = [axes[0][0] + axes[1][0] - o[0], axes[0][1] + axes[1][1] - o[1]];
    var pxz = [axes[0][0] + axes[2][0] - o[0], axes[0][1] + axes[2][1] - o[1]];
    var pyz = [axes[1][0] + axes[2][0] - o[0], axes[1][1] + axes[2][1] - o[1]];
    var pxyz = [pxy[0] + axes[2][0] - o[0], pxy[1] + axes[2][1] - o[1]];
    ctx.strokeStyle = 'rgba(138,147,156,.45)';
    line(axes[0], pxy);
    line(axes[1], pxy);
    line(axes[1], pyz);
    line(axes[2], pyz);
    line(axes[0], pxz);
    line(axes[2], pxz);
    line(pxy, pxyz);
    line(pxz, pxyz);
    line(pyz, pxyz);

    columns.forEach(function (col, i) {
      var tip = project([col[0], col[1], col[2]]);
      line(o, tip, colors[i], 2);
      ctx.fillStyle = colors[i];
      ctx.beginPath();
      ctx.arc(tip[0], tip[1], 3.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.font = '600 11px "Segoe UI", "Microsoft YaHei", sans-serif';
      ctx.fillText(names[i] + (labels && labels[i] ? '·' + labels[i] : ''), tip[0] + 5, tip[1] - 4);
    });
  }

  var dialog = null;
  var state = {
    direction: [1, 0, 0, 0, 1, 0, 0, 0, 1],
    spacing: [1, 1, 1],
    selection: identitySelection()
  };

  function axisText(axis, sign, direction) {
    // 文案是固定的 6 项；value 用源轴+符号
    for (var i = 0; i < OPTIONS.length; i += 1) {
      if (OPTIONS[i].axis === axis && OPTIONS[i].sign === sign) return OPTIONS[i].text;
    }
    return axis + ':' + sign;
  }

  function currentColumns() {
    return selectionToColumns(identitySelection(), state.direction);
  }

  function newColumns() {
    return selectionToColumns(state.selection, state.direction);
  }

  function refresh() {
    if (!dialog) return;
    var cur = currentColumns();
    var nxt = newColumns();
    dialog.querySelector('[data-rd="cur-rai"]').value = raiCode(cur);
    dialog.querySelector('[data-rd="new-rai"]').value = raiCode(nxt);
    dialog.querySelector('[data-rd="cur-matrix"]').innerHTML = matrixHtml(directionMatrix(state.direction, state.spacing));
    dialog.querySelector('[data-rd="new-matrix"]').innerHTML =
      matrixHtml(multiply4(directionMatrix(state.direction, state.spacing), selectionMatrix(state.selection)));
    drawCube(dialog.querySelector('[data-rd="cur-cube"]'), cur, raiCode(cur).split(''));
    drawCube(dialog.querySelector('[data-rd="new-cube"]'), nxt, raiCode(nxt).split(''));
  }

  function selectHtml(role, sel) {
    var opts = OPTIONS.map(function (o) {
      var value = o.axis + ':' + o.sign;
      var chosen = sel.axis === o.axis && sel.sign === o.sign ? ' selected' : '';
      return '<option value="' + value + '"' + chosen + '>' + o.text + '</option>';
    }).join('');
    return '<select data-rd="' + role + '">' + opts + '</select>';
  }

  function buildDialog() {
    var wrap = document.createElement('div');
    wrap.className = 'rd-overlay';
    wrap.innerHTML = [
      '<div class="rd-dialog" role="dialog" aria-label="重定向影像">',
      '  <div class="rd-head"><span>重定向影像</span><button type="button" class="rd-close" title="关闭">✕</button></div>',
      '  <div class="rd-body">',
      '    <div class="rd-col">',
      '      <div class="rd-col-title">当前方向</div>',
      '      <label class="rd-row"><span>RAI 代码</span><input data-rd="cur-rai" readonly /></label>',
      '      <label class="rd-row"><span>体素 X 轴</span><input readonly value="—" data-rd="cur-x" /></label>',
      '      <label class="rd-row"><span>体素 Y 轴</span><input readonly value="—" data-rd="cur-y" /></label>',
      '      <label class="rd-row"><span>体素 Z 轴</span><input readonly value="—" data-rd="cur-z" /></label>',
      '      <div class="rd-row rd-row-top"><span>体素到世界矩阵</span><div data-rd="cur-matrix" class="rd-matrix-wrap"></div></div>',
      '      <canvas data-rd="cur-cube" class="rd-cube"></canvas>',
      '    </div>',
      '    <div class="rd-col">',
      '      <div class="rd-col-title">新方向</div>',
      '      <label class="rd-row"><span>RAI 代码</span><input data-rd="new-rai" readonly /></label>',
      '      <label class="rd-row"><span>体素 X 轴</span>' + selectHtml('sel-x', state.selection.x) + '</label>',
      '      <label class="rd-row"><span>体素 Y 轴</span>' + selectHtml('sel-y', state.selection.y) + '</label>',
      '      <label class="rd-row"><span>体素 Z 轴</span>' + selectHtml('sel-z', state.selection.z) + '</label>',
      '      <div class="rd-row rd-row-top"><span>体素到世界矩阵</span><div data-rd="new-matrix" class="rd-matrix-wrap"></div></div>',
      '      <canvas data-rd="new-cube" class="rd-cube"></canvas>',
      '    </div>',
      '  </div>',
      '  <div class="rd-foot">',
      '    <span class="rd-hint" data-rd="hint"></span>',
      '    <button type="button" class="rd-btn rd-btn-ghost" data-rd="reset">恢复默认</button>',
      '    <button type="button" class="rd-btn" data-rd="cancel">关闭</button>',
      '    <button type="button" class="rd-btn rd-btn-primary" data-rd="apply">应用</button>',
      '  </div>',
      '</div>'
    ].join('');

    document.body.appendChild(wrap);

    wrap.addEventListener('click', function (e) {
      if (e.target === wrap) closeDialog();
    });
    wrap.querySelector('.rd-close').addEventListener('click', closeDialog);
    wrap.querySelector('[data-rd="cancel"]').addEventListener('click', closeDialog);
    wrap.querySelector('[data-rd="reset"]').addEventListener('click', function () {
      state.selection = identitySelection();
      syncSelects();
      refresh();
    });
    wrap.querySelector('[data-rd="apply"]').addEventListener('click', applySelection);

    ['x', 'y', 'z'].forEach(function (k) {
      wrap.querySelector('[data-rd="sel-' + k + '"]').addEventListener('change', function (e) {
        var parts = String(e.target.value).split(':');
        state.selection[k] = { axis: Number(parts[0]), sign: Number(parts[1]) };
        // 三个新轴必须来自三个不同的源轴：刚改的那根优先保留，其余按顺序补齐
        var order = [k].concat(['x', 'y', 'z'].filter(function (o) { return o !== k; }));
        var used = {};
        order.forEach(function (key) {
          var sel = state.selection[key];
          if (!used[sel.axis]) { used[sel.axis] = true; return; }
          for (var a = 0; a < 3; a += 1) {
            if (!used[a]) { sel.axis = a; used[a] = true; return; }
          }
        });
        syncSelects();
        refresh();
      });
    });

    return wrap;
  }

  function syncSelects() {
    if (!dialog) return;
    ['x', 'y', 'z'].forEach(function (k) {
      var sel = state.selection[k];
      var el = dialog.querySelector('[data-rd="sel-' + k + '"]');
      if (el) el.value = sel.axis + ':' + sel.sign;
    });
  }

  function readCurrentAxes() {
    if (!dialog) return;
    var dir = state.direction;
    ['x', 'y', 'z'].forEach(function (k, i) {
      var v = axisVector(dir, i);
      var el = dialog.querySelector('[data-rd="cur-' + k + '"]');
      if (el) el.value = axisText(i, v[0] + v[1] + v[2] >= 0 ? 1 : -1, dir) + ' (' + letterOf(v) + ')';
    });
  }

  function setHint(text, isError) {
    if (!dialog) return;
    var el = dialog.querySelector('[data-rd="hint"]');
    if (!el) return;
    el.textContent = text || '';
    el.classList.toggle('rd-hint-error', !!isError);
  }

  function viewSpec() {
    // 新 Z 决定轴位视口法线，新 X 决定矢状，新 Y 决定冠状
    return {
      views: {
        axial: { axis: state.selection.z.axis, flipUp: state.selection.z.sign < 0 },
        sagittal: { axis: state.selection.x.axis, flipUp: state.selection.x.sign < 0 },
        coronal: { axis: state.selection.y.axis, flipUp: state.selection.y.sign < 0 }
      }
    };
  }

  function applySelection() {
    var b = bridge();
    if (!b) { setHint('阅片台桥接不可用，无法应用', true); return; }
    setHint('正在应用…');
    var spec = viewSpec();
    var res = b.applyOrientation(spec);
    if (!res || !res.ok) {
      setHint('应用失败：' + ((res && res.error) || '未知错误'), true);
      return;
    }
    lastSpec = spec;
    updateHudLabels();
    setHint('已应用（仅影响当前显示，不会写回文件）');
    try {
      window.__medclawFitViewport && window.__medclawFitViewport();
    } catch (e) { /* ignore */ }
  }

  // 视口四边的方位字母：屏幕右 = cross(up, normal)
  function cross(a, b) {
    return [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0]
    ];
  }

  function updateHudLabels() {
    var b = bridge();
    if (!b) return;
    var st = b.getState();
    if (!st || !st.cameras) return;
    var map = { axial: 'container-axial', sagittal: 'container-sagittal', coronal: 'container-coronal' };
    Object.keys(map).forEach(function (name) {
      var cam = st.cameras[name];
      var host = document.getElementById(map[name]);
      if (!cam || !host) return;
      var right = cross(cam.up, cam.normal);
      var labels = [letterOf(right.map(function (v) { return -v; })), letterOf(right), letterOf(cam.up), letterOf(cam.up.map(function (v) { return -v; }))];
      var nodes = host.querySelectorAll('.orient');
      // DOM 顺序：left, right, top, bottom
      for (var i = 0; i < nodes.length && i < 4; i += 1) nodes[i].textContent = labels[i];
    });
  }

  function openDialog() {
    var b = bridge();
    if (!b) {
      window.alert && window.alert('当前环境不支持重定向（阅片台桥接未就绪）');
      return;
    }
    var st = b.getState();
    if (!st) {
      window.alert && window.alert('请先加载影像');
      return;
    }
    state.direction = st.direction || state.direction;
    state.spacing = st.spacing || state.spacing;
    state.selection = inferSelection(st.cameras) || identitySelection();
    if (dialog) {
      dialog.classList.add('rd-open');
    } else {
      dialog = buildDialog();
      dialog.classList.add('rd-open');
    }
    syncSelects();
    readCurrentAxes();
    refresh();
    setHint('只改变当前显示的观察方向，不修改体素数据；切片编号仍按原始网格计数');
  }

  // cornerstone 每个标准平面默认的 up 方向（用来反推是否翻转）
  var DEFAULT_UP = { 0: [0, 0, 1], 1: [0, 0, 1], 2: [0, -1, 0] };

  // 从当前相机反推"新 X/Y/Z 分别来自哪个源轴 + 是否翻转"。
  // 单图布局下只有 axial 视口存在，缺的轴用剩余源轴补齐（切到 MPR 后会重新贴一次）。
  function inferSelection(cameras) {
    if (!cameras) return null;
    var mapping = { x: 'sagittal', y: 'coronal', z: 'axial' };
    var out = {};
    var used = {};
    Object.keys(mapping).forEach(function (key) {
      var cam = cameras[mapping[key]];
      if (!cam || !cam.normal) return;
      var n = cam.normal;
      var idx = 0;
      var best = -1;
      for (var i = 0; i < 3; i += 1) {
        if (Math.abs(n[i]) > best) { best = Math.abs(n[i]); idx = i; }
      }
      if (used[idx]) return;
      var ref = DEFAULT_UP[idx];
      var dot = cam.up ? (cam.up[0] * ref[0] + cam.up[1] * ref[1] + cam.up[2] * ref[2]) : 1;
      used[idx] = true;
      out[key] = { axis: idx, sign: dot < 0 ? -1 : 1 };
    });
    ['x', 'y', 'z'].forEach(function (key) {
      if (out[key]) return;
      for (var a = 0; a < 3; a += 1) {
        if (!used[a]) { used[a] = true; out[key] = { axis: a, sign: 1 }; return; }
      }
    });
    return out.x && out.y && out.z ? out : null;
  }

  // 切换单图/MPR 布局后 bundle 会重置相机，这里把上次的重定向重新贴回去
  var lastSpec = null;

  function rememberLayoutGuard() {
    document.addEventListener('click', function (e) {
      var btn = e.target && e.target.closest ? e.target.closest('[data-medclaw-layout]') : null;
      if (!btn || !lastSpec) return;
      setTimeout(function () {
        var b = bridge();
        if (!b) return;
        b.applyOrientation(lastSpec);
        updateHudLabels();
      }, 3500);
    }, true);
  }

  function closeDialog() {
    if (dialog) dialog.classList.remove('rd-open');
  }

  function injectStyle() {
    var css = [
      '.rd-overlay{position:fixed;inset:0;background:rgba(0,0,0,.55);display:none;align-items:center;justify-content:center;z-index:210;}',
      '.rd-overlay.rd-open{display:flex;}',
      '.rd-dialog{width:640px;max-width:calc(100vw - 48px);background:var(--panel,#14171a);border:1px solid var(--border,#262b30);border-radius:10px;box-shadow:0 16px 40px rgba(0,0,0,.45);color:var(--text,#d7dde3);font-size:13px;overflow:hidden;}',
      '.rd-head{display:flex;align-items:center;justify-content:space-between;height:40px;padding:0 14px;border-bottom:1px solid var(--border,#262b30);font-weight:600;}',
      '.rd-close{background:none;border:0;color:var(--muted,#8a939c);font-size:15px;cursor:pointer;line-height:1;padding:4px 6px;border-radius:6px;}',
      '.rd-close:hover{background:var(--panel2,#191d21);color:var(--text,#d7dde3);}',
      '.rd-body{display:flex;gap:12px;padding:12px 14px 4px;}',
      '.rd-col{flex:1;min-width:0;}',
      '.rd-col-title{font-size:12px;color:var(--muted,#8a939c);margin-bottom:8px;}',
      '.rd-row{display:flex;align-items:center;gap:8px;margin-bottom:8px;}',
      '.rd-row>span{width:70px;flex:none;font-size:12px;color:var(--muted,#8a939c);}',
      '.rd-row-top{align-items:flex-start;}',
      '.rd-row-top>span{margin-top:4px;}',
      '.rd-row input,.rd-row select{flex:1;min-width:0;height:28px;background:var(--panel2,#191d21);border:1px solid var(--border,#262b30);border-radius:6px;color:var(--text,#d7dde3);font-size:12px;padding:0 8px;outline:none;}',
      '.rd-row input[readonly]{color:var(--muted,#8a939c);}',
      '.rd-matrix-wrap{flex:1;min-width:0;}',
      '.rd-matrix{border-collapse:collapse;font-family:Consolas,monospace;font-size:11px;}',
      '.rd-matrix td{border:1px solid var(--border,#262b30);padding:2px 6px;text-align:right;color:var(--text,#d7dde3);}',
      '.rd-cube{display:block;margin:2px 0 0 8px;background:var(--panel2,#191d21);border:1px solid var(--border,#262b30);border-radius:8px;}',
      '.rd-foot{display:flex;align-items:center;gap:8px;padding:10px 14px 12px;border-top:1px solid var(--border,#262b30);}',
      '.rd-hint{flex:1;min-width:0;font-size:11px;color:var(--muted,#8a939c);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
      '.rd-hint-error{color:var(--red,#e05252);}',
      '.rd-btn{height:30px;padding:0 14px;border-radius:6px;border:1px solid var(--border,#262b30);background:var(--panel2,#191d21);color:var(--text,#d7dde3);font-size:12px;cursor:pointer;}',
      '.rd-btn:hover{border-color:var(--accent,#27aae1);}',
      '.rd-btn-ghost{background:none;color:var(--muted,#8a939c);}',
      '.rd-btn-primary{background:var(--accent-dim,#1b7ca8);border-color:var(--accent-dim,#1b7ca8);color:#fff;}',
      '.rd-btn-primary:hover{background:var(--accent,#27aae1);border-color:var(--accent,#27aae1);}',
      '@media (max-width: 720px){.rd-body{flex-direction:column;}.rd-dialog{width:min(92vw,640px);}}'
    ].join('');
    var style = document.createElement('style');
    style.id = 'medclaw-redirect-style';
    style.textContent = css;
    document.head.appendChild(style);
  }

  function injectButton() {
    if (document.getElementById('btnRedirect')) return;
    var anchor = document.getElementById('btnReset');
    var group = anchor && anchor.parentElement;
    if (!group) return;

    var wrap = document.createElement('div');
    wrap.className = 'tgroup';
    wrap.innerHTML = '<button type="button" class="tbtn" id="btnRedirect">'
      + '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
      + '<path d="M12 3.5 20 8v8l-8 4.5L4 16V8z"/>'
      + '<path d="M12 3.5v17M4 8l8 4.5L20 8"/>'
      + '<path d="M17.5 19.5a6.5 6.5 0 0 0 2-4.2"/>'
      + '</svg> <span class="tip">重定向影像</span></button>';

    group.parentNode.insertBefore(wrap, group.nextSibling);
    wrap.querySelector('#btnRedirect').addEventListener('click', openDialog);
  }

  function init() {
    injectStyle();
    injectButton();
    rememberLayoutGuard();
    // 切换影像后方位标签会回到 bundle 的默认值，顺手再校正一次
    document.addEventListener('change', function (e) {
      if (e.target && e.target.id === 'fileInput') {
        lastSpec = null;
        setTimeout(updateHudLabels, 3000);
      }
    });
  }

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    setTimeout(init, 0);
  } else {
    window.addEventListener('load', init);
  }
})();
