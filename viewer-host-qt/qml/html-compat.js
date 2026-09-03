(function () {
  if (window.__medclawHtmlCompat) return;
  window.__medclawHtmlCompat = true;

  function injectCss() {
    if (document.querySelector("style[data-medclaw-html-compat]")) return;
    var style = document.createElement("style");
    style.setAttribute("data-medclaw-html-compat", "1");
    style.textContent =
      ".focus-overlay.show,.modal-mask.show,[class*=\"overlay\"].show{" +
      "position:fixed!important;top:0!important;right:0!important;bottom:0!important;left:0!important;" +
      "width:auto!important;height:auto!important;max-width:none!important;max-height:none!important;" +
      "z-index:2147483000!important;display:flex!important;flex-direction:column!important;" +
      "box-sizing:border-box!important;}" +
      ".flip-face{top:0!important;right:0!important;bottom:0!important;left:0!important;}";
    var parent = document.head || document.documentElement;
    if (parent) parent.appendChild(style);
  }

  function expandInsetInStyles() {
    var nodes = document.querySelectorAll("style");
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (!el || el.getAttribute("data-medclaw-html-compat") === "1") continue;
      var src = el.textContent || "";
      var next = src.replace(/(^|[{;\s])inset\s*:\s*([^;}{]+)/gi, function (m, pre, val) {
        var imp = /!important/i.test(val) ? " !important" : "";
        var raw = String(val).replace(/!important/ig, "").trim();
        var p = raw.split(/\s+/).filter(Boolean);
        if (!p.length) return m;
        var t = p[0], r = t, b = t, l = t;
        if (p.length === 2) { r = l = p[1]; }
        else if (p.length === 3) { r = l = p[1]; b = p[2]; }
        else if (p.length >= 4) { r = p[1]; b = p[2]; l = p[3]; }
        return pre + "top:" + t + imp + ";right:" + r + imp + ";bottom:" + b + imp + ";left:" + l + imp;
      });
      if (next !== src) el.textContent = next;
    }
  }

  var filledProps = [
    "position", "top", "right", "bottom", "left", "width", "height",
    "z-index", "display", "flex-direction", "box-sizing"
  ];

  function fill(el) {
    if (!el || !el.style) return;
    el.style.setProperty("position", "fixed", "important");
    el.style.setProperty("top", "0px", "important");
    el.style.setProperty("right", "0px", "important");
    el.style.setProperty("bottom", "0px", "important");
    el.style.setProperty("left", "0px", "important");
    el.style.setProperty("width", "auto", "important");
    el.style.setProperty("height", "auto", "important");
    el.style.setProperty("z-index", "2147483000", "important");
    el.style.setProperty("display", "flex", "important");
    el.style.setProperty("flex-direction", "column", "important");
    el.style.setProperty("box-sizing", "border-box", "important");
    el.__medclawFilled = true;
  }

  function clearFill(el) {
    if (!el || !el.style || !el.__medclawFilled) return;
    for (var i = 0; i < filledProps.length; i++)
      el.style.removeProperty(filledProps[i]);
    el.__medclawFilled = false;
  }

  function showFocusOverlay() {
    var overlay = document.getElementById("focusOverlay");
    if (!overlay) return null;
    overlay.classList.add("show");
    return overlay;
  }

  function hideFocusOverlay() {
    var overlay = document.getElementById("focusOverlay");
    if (!overlay) return;
    overlay.classList.remove("show");
    clearFill(overlay);
  }

  function scanOffscreenFixed() {
    var vh = window.innerHeight || (document.documentElement && document.documentElement.clientHeight) || 0;
    var vw = window.innerWidth || (document.documentElement && document.documentElement.clientWidth) || 0;
    var els = document.querySelectorAll("*");
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      var style = window.getComputedStyle(el);
      if (style.position !== "fixed" || style.display === "none") continue;
      var rect = el.getBoundingClientRect();
      if (rect.bottom <= 1 || rect.top >= vh - 1 || rect.right <= 1 || rect.left >= vw - 1
          || rect.width < 4 || rect.height < 4) {
        fill(el);
      }
    }
  }

  function wrapPageFunction(name, before) {
    var fn = window[name];
    if (typeof fn !== "function" || fn.__medclawWrapped) return;
    var wrapped = function () {
      if (before) before();
      try {
        return fn.apply(this, arguments);
      } catch (err) {
        if (before) before();
      } finally {
        scanOffscreenFixed();
      }
    };
    wrapped.__medclawWrapped = true;
    window[name] = wrapped;
  }

  function wrapRenderCard() {
    var fn = window.renderCard;
    if (typeof fn !== "function" || fn.__medclawWrapped) return;
    var wrapped = function () {
      try {
        return fn.apply(this, arguments);
      } catch (err) {
        var coloc = document.getElementById("fColoc");
        if (coloc && !coloc.innerHTML) coloc.innerHTML = "";
      }
    };
    wrapped.__medclawWrapped = true;
    window.renderCard = wrapped;
  }

  function boot() {
    injectCss();
    expandInsetInStyles();
    wrapRenderCard();
    wrapPageFunction("openFocus", showFocusOverlay);
    wrapPageFunction("closeFocus", hideFocusOverlay);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
  document.addEventListener("click", function (ev) {
    boot();
    var node = ev.target;
    while (node && node.nodeType === 1) {
      var handler = node.getAttribute && node.getAttribute("onclick");
      if (handler && handler.indexOf("openFocus") >= 0) {
        showFocusOverlay();
        break;
      }
      node = node.parentNode;
    }
    setTimeout(scanOffscreenFixed, 0);
  }, true);
})();
