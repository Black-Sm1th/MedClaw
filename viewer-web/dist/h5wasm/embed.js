(function () {
  var params = new URLSearchParams(location.search);
  var session = params.get("session") || "";
  var statusEl = document.getElementById("status");
  var treeEl = document.getElementById("tree");
  var mainEl = document.getElementById("main");
  var MAX_ROWS = 40;
  var MAX_COLS = 12;
  var MAX_TREE = 4000;
  var fileHandle = null;
  var selectedPath = "";

  function setStatus(text, err) {
    statusEl.textContent = text;
    statusEl.style.color = err ? "#fca5a5" : "#e7ecf1";
  }

  function esc(text) {
    return String(text == null ? "" : text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function formatBytes(n) {
    n = Number(n) || 0;
    if (n < 1024) return n + " B";
    if (n < 1048576) return (n / 1024).toFixed(1) + " KB";
    if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB";
    return (n / 1073741824).toFixed(2) + " GB";
  }

  function formatValue(value) {
    if (value == null) return "";
    if (typeof value === "bigint") return value.toString();
    if (typeof value === "number") {
      if (!isFinite(value)) return String(value);
      if (Math.abs(value) >= 1e6 || (Math.abs(value) > 0 && Math.abs(value) < 1e-4))
        return value.toExponential(4);
      return String(Math.round(value * 1e6) / 1e6);
    }
    if (typeof value === "boolean") return value ? "true" : "false";
    if (typeof value === "string") return value;
    if (Array.isArray(value)) {
      if (value.length > 8) return "[" + value.slice(0, 8).map(formatValue).join(", ") + ", …]";
      return "[" + value.map(formatValue).join(", ") + "]";
    }
    if (ArrayBuffer.isView(value)) {
      var out = [];
      var n = Math.min(value.length, 8);
      for (var i = 0; i < n; i++) out.push(formatValue(value[i]));
      return out.join(", ") + (value.length > n ? ", …" : "");
    }
    try {
      return JSON.stringify(value);
    } catch (err) {
      return String(value);
    }
  }

  function dtypeOf(obj) {
    try {
      var dt = obj.dtype;
      if (dt == null) return "";
      if (typeof dt === "string") return dt;
      return JSON.stringify(dt);
    } catch (err) {
      return "";
    }
  }

  function shapeOf(obj) {
    try {
      var shape = obj.shape;
      return Array.isArray(shape) ? shape : [];
    } catch (err) {
      return [];
    }
  }

  function attrMap(obj) {
    var out = {};
    try {
      var attrs = obj.attrs || {};
      Object.keys(attrs).forEach(function (name) {
        try {
          var attr = attrs[name];
          out[name] = attr && "json_value" in attr ? attr.json_value : attr && attr.value;
        } catch (err) {
          out[name] = "(无法读取)";
        }
      });
    } catch (err) {
    }
    return out;
  }

  function isGroup(obj) {
    return !!(obj && (obj.type === "Group" || (obj.keys && !obj.slice)));
  }

  function isDataset(obj) {
    return !!(obj && (obj.type === "Dataset" || obj.slice));
  }

  function joinPath(parent, name) {
    if (!parent || parent === "/") return "/" + name;
    return parent.replace(/\/+$/, "") + "/" + name;
  }

  function walk(group, path, nodes, depth) {
    if (nodes.length >= MAX_TREE) return;
    var keys = [];
    try {
      keys = group.keys() || [];
    } catch (err) {
      return;
    }
    keys.sort();
    for (var i = 0; i < keys.length; i++) {
      if (nodes.length >= MAX_TREE) return;
      var name = keys[i];
      var childPath = joinPath(path, name);
      var child = null;
      try {
        child = group.get(name);
      } catch (err) {
        nodes.push({ path: childPath, name: name, kind: "error", depth: depth, error: err.message });
        continue;
      }
      if (!child) {
        nodes.push({ path: childPath, name: name, kind: "missing", depth: depth });
        continue;
      }
      var kind = isDataset(child) ? "dataset" : isGroup(child) ? "group" : String(child.type || "object");
      var node = { path: childPath, name: name, kind: kind, depth: depth, obj: child };
      if (kind === "dataset") {
        node.shape = shapeOf(child);
        node.dtype = dtypeOf(child);
      }
      nodes.push(node);
      if (kind === "group") walk(child, childPath, nodes, depth + 1);
    }
  }

  function renderTree(nodes) {
    treeEl._nodes = nodes;
    treeEl.innerHTML = "";
    nodes.forEach(function (node) {
      var row = document.createElement("div");
      row.className = "tree-item" + (node.path === selectedPath ? " active" : "");
      row.style.paddingLeft = (8 + node.depth * 12) + "px";
      var kind = node.kind === "dataset" ? "ds" : node.kind === "group" ? "g" : "";
      var extra = node.kind === "dataset" && node.shape
        ? " <span class='muted'>[" + node.shape.join("×") + "]</span>"
        : "";
      row.innerHTML = "<span class='kind " + kind + "'>" + esc(node.kind === "dataset" ? "D" : node.kind === "group" ? "G" : "?") + "</span>"
        + "<span>" + esc(node.name) + extra + "</span>";
      row.onclick = function () { selectPath(node.path); };
      treeEl.appendChild(row);
    });
  }

  function cardsHtml(items) {
    return "<div class='cards'>" + items.map(function (item) {
      return "<div class='card'><div class='k'>" + esc(item.k) + "</div><div class='v'>" + esc(item.v) + "</div></div>";
    }).join("") + "</div>";
  }

  function attrsHtml(attrs) {
    var names = Object.keys(attrs);
    if (!names.length) return "<p class='muted'>没有属性</p>";
    return "<table><thead><tr><th>属性</th><th>值</th></tr></thead><tbody>"
      + names.map(function (name) {
        return "<tr><td>" + esc(name) + "</td><td>" + esc(formatValue(attrs[name])) + "</td></tr>";
      }).join("")
      + "</tbody></table>";
  }

  function tableFromSlice(data, shape) {
    var rows = [];
    if (data == null) return "<p class='muted'>无法读取该切片</p>";
    if (ArrayBuffer.isView(data) || typeof data === "string" || typeof data === "number" || typeof data === "boolean") {
      if (ArrayBuffer.isView(data) && shape && shape.length >= 2) {
        var cols = Math.min(shape[shape.length - 1], MAX_COLS);
        var rcount = Math.min(Math.floor(data.length / Math.max(1, shape[shape.length - 1])), MAX_ROWS);
        for (var r = 0; r < rcount; r++) {
          var row = [];
          for (var c = 0; c < cols; c++) row.push(data[r * shape[shape.length - 1] + c]);
          if (shape[shape.length - 1] > cols) row.push("…");
          rows.push(row);
        }
      } else if (ArrayBuffer.isView(data)) {
        rows.push(Array.prototype.slice.call(data, 0, MAX_COLS));
        if (data.length > MAX_COLS) rows[0].push("…");
      } else {
        rows.push([data]);
      }
    } else if (Array.isArray(data)) {
      var sample = data.slice(0, MAX_ROWS);
      sample.forEach(function (item) {
        if (Array.isArray(item) || ArrayBuffer.isView(item)) {
          var row = [];
          var n = Math.min(item.length, MAX_COLS);
          for (var i = 0; i < n; i++) row.push(item[i]);
          if (item.length > MAX_COLS) row.push("…");
          rows.push(row);
        } else {
          rows.push([item]);
        }
      });
    } else {
      return "<pre>" + esc(formatValue(data)) + "</pre>";
    }
    if (!rows.length) return "<p class='muted'>空切片</p>";
    var width = rows.reduce(function (m, row) { return Math.max(m, row.length); }, 0);
    var head = "<tr>" + Array.from({ length: width }, function (_, i) {
      return "<th>" + (i + 1) + "</th>";
    }).join("") + "</tr>";
    var body = rows.map(function (row) {
      return "<tr>" + Array.from({ length: width }, function (_, i) {
        return "<td>" + esc(formatValue(row[i])) + "</td>";
      }).join("") + "</tr>";
    }).join("");
    return "<table><thead>" + head + "</thead><tbody>" + body + "</tbody></table>";
  }

  function previewDataset(ds) {
    var shape = shapeOf(ds);
    var ranges = [];
    if (!shape.length) {
      try {
        return tableFromSlice(ds.value, shape);
      } catch (err) {
        return "<p class='error'>" + esc(err.message) + "</p>";
      }
    }
    for (var i = 0; i < shape.length; i++) {
      var dim = Number(shape[i]) || 0;
      var take = i >= shape.length - 2 ? (i === shape.length - 1 ? MAX_COLS : MAX_ROWS) : 1;
      ranges.push([0, Math.min(dim, take)]);
    }
    try {
      return tableFromSlice(ds.slice(ranges), shape);
    } catch (err) {
      try {
        return tableFromSlice(ds.value, shape);
      } catch (err2) {
        return "<p class='error'>读取失败：" + esc(err.message || err2.message) + "</p>";
      }
    }
  }

  function look(path) {
    if (!fileHandle) return null;
    if (!path || path === "/") return fileHandle;
    try {
      return fileHandle.get(path.replace(/^\//, ""));
    } catch (err) {
      return null;
    }
  }

  function anndataSummary() {
    var rootAttrs = attrMap(fileHandle);
    var encoding = String(rootAttrs["encoding-type"] || rootAttrs["encoding_type"] || "");
    var hasX = !!look("X");
    var hasObs = !!look("obs");
    var hasVar = !!look("var");
    if (!(encoding.indexOf("anndata") >= 0 || (hasX && hasObs && hasVar)))
      return "";

    function dimOf(name) {
      var obj = look(name);
      if (!obj) return "—";
      if (isDataset(obj)) {
        var shape = shapeOf(obj);
        return shape.length ? String(shape[0]) : "—";
      }
      if (isGroup(obj)) {
        var attrs = attrMap(obj);
        if (attrs["encoding-type"] === "dataframe") {
          var index = look(name + "/_index") || (obj.get && obj.get("_index"));
          if (index && isDataset(index)) {
            var ishape = shapeOf(index);
            if (ishape.length) return String(ishape[0]);
          }
          var keys = obj.keys ? obj.keys() : [];
          for (var i = 0; i < keys.length; i++) {
            if (keys[i].charAt(0) === "_") continue;
            var col = obj.get(keys[i]);
            if (col && isDataset(col)) {
              var cshape = shapeOf(col);
              if (cshape.length) return String(cshape[0]);
            }
            if (col && isGroup(col)) {
              var codes = col.get && col.get("codes");
              if (codes && isDataset(codes)) {
                var gshape = shapeOf(codes);
                if (gshape.length) return String(gshape[0]);
              }
            }
          }
        }
        if (attrs["encoding-type"] === "csr_matrix" || attrs["encoding-type"] === "csc_matrix") {
          var shapeAttr = attrs.shape;
          if (Array.isArray(shapeAttr)) return shapeAttr.join(" × ");
        }
      }
      return "—";
    }

    var x = look("X");
    var xShape = "—";
    if (x && isDataset(x)) xShape = shapeOf(x).join(" × ") || "—";
    else if (x && isGroup(x)) {
      var xAttrs = attrMap(x);
      if (Array.isArray(xAttrs.shape)) xShape = xAttrs.shape.join(" × ");
      else xShape = (xAttrs["encoding-type"] || "group");
    }

    var extras = [];
    ["obsm", "varm", "layers", "uns", "obsp", "varp", "raw"].forEach(function (key) {
      var obj = look(key);
      if (obj && isGroup(obj)) extras.push(key + "(" + (obj.keys() || []).length + ")");
      else if (obj) extras.push(key);
    });

    return "<h2>AnnData</h2>"
      + cardsHtml([
        { k: "细胞 obs", v: dimOf("obs") },
        { k: "基因 var", v: dimOf("var") },
        { k: "矩阵 X", v: xShape },
        { k: "其它", v: extras.join(" · ") || "—" }
      ])
      + "<p class='muted'>只读预览：左侧浏览 HDF5 结构，点击数据集查看切片，不会改写文件。</p>";
  }

  function selectPath(path) {
    selectedPath = path || "/";
    Array.prototype.forEach.call(treeEl.querySelectorAll(".tree-item"), function (row, index) {
      var nodes = treeEl._nodes || [];
      row.classList.toggle("active", nodes[index] && nodes[index].path === selectedPath);
    });
    var obj = look(selectedPath);
    var html = "";
    if (selectedPath === "/") html += anndataSummary();
    if (!obj) {
      mainEl.innerHTML = html + "<p class='error'>无法打开 " + esc(selectedPath) + "</p>";
      return;
    }
    html += "<h2>" + esc(selectedPath) + "</h2>";
    if (isDataset(obj)) {
      var shape = shapeOf(obj);
      html += cardsHtml([
        { k: "类型", v: "Dataset" },
        { k: "形状", v: shape.length ? shape.join(" × ") : "标量" },
        { k: "dtype", v: dtypeOf(obj) || "—" }
      ]);
      html += "<h3>属性</h3>" + attrsHtml(attrMap(obj));
      html += "<h3>数据切片（最多 " + MAX_ROWS + " × " + MAX_COLS + "）</h3>" + previewDataset(obj);
    } else {
      var keys = [];
      try { keys = obj.keys() || []; } catch (err) {}
      html += cardsHtml([
        { k: "类型", v: obj.type || "Group" },
        { k: "子项", v: String(keys.length) }
      ]);
      html += "<h3>属性</h3>" + attrsHtml(attrMap(obj));
      if (keys.length) {
        html += "<h3>子项</h3><p>" + keys.map(function (key) {
          return "<code>" + esc(key) + "</code>";
        }).join(" · ") + "</p>";
      }
    }
    mainEl.innerHTML = html;
  }

  async function main() {
    var api = (typeof h5wasm !== "undefined" && h5wasm.default) ? h5wasm.default : h5wasm;
    if (!api || !api.ready) throw new Error("未找到 h5wasm 运行时");
    setStatus("正在初始化 HDF5 / WebAssembly…");
    var Module = await api.ready;
    var FS = Module.FS;
    if (!FS || !api.File) throw new Error("h5wasm 初始化失败");
    var response = await fetch("/api/medical/manifest?session=" + encodeURIComponent(session), { cache: "no-store" });
    if (!response.ok) throw new Error("文件清单读取失败 (" + response.status + ")");
    var manifest = await response.json();
    var files = Array.isArray(manifest.files) ? manifest.files : [];
    if (!files.length) throw new Error("没有可预览的 HDF5 文件");
    var file = files[0];
    setStatus("正在载入 " + (file.name || "") + "（" + formatBytes(file.size) + "）…");
    var buf = await fetch(file.url, { cache: "no-store" }).then(function (r) {
      if (!r.ok) throw new Error("下载失败 " + r.status);
      return r.arrayBuffer();
    });
    var virtualName = file.name || "data.h5";
    FS.writeFile(virtualName, new Uint8Array(buf));
    fileHandle = new api.File(virtualName, "r");
    var nodes = [{ path: "/", name: virtualName, kind: "group", depth: 0, obj: fileHandle }];
    walk(fileHandle, "/", nodes, 1);
    treeEl._nodes = nodes;
    renderTree(nodes);
    selectPath("/");
    var note = file.size > 256 * 1024 * 1024
      ? " · 大文件已完整载入内存，仅展示切片"
      : "";
    setStatus("只读预览 · " + virtualName + " · " + formatBytes(file.size) + note);
  }

  main().catch(function (error) {
    var message = error && error.message ? error.message : String(error);
    setStatus(message, true);
    mainEl.innerHTML = "<p class='error'>" + esc(message) + "</p>";
  });
})();
