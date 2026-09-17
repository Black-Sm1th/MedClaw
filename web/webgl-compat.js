/**
 * Qt WebEngine WebGL/WebGL2 getContext retries for every page (Mol*, DICOM,
 * HTML popups). Does not fake WebGL2 on top of WebGL1.
 */
(function () {
  if (window.__medclawWebGlPatched) return;
  window.__medclawWebGlPatched = true;

  var original = HTMLCanvasElement.prototype.getContext;
  var attempts = [
    {
      alpha: true,
      depth: true,
      stencil: false,
      antialias: false,
      premultipliedAlpha: true,
      preserveDrawingBuffer: false,
      failIfMajorPerformanceCaveat: false,
      powerPreference: "default",
    },
    {
      alpha: true,
      depth: true,
      antialias: false,
      failIfMajorPerformanceCaveat: false,
      powerPreference: "low-power",
    },
    {
      alpha: true,
      depth: true,
      antialias: false,
      failIfMajorPerformanceCaveat: false,
      powerPreference: "high-performance",
    },
    { failIfMajorPerformanceCaveat: false, antialias: false },
    { failIfMajorPerformanceCaveat: false },
    {},
  ];

  function merge(a, b) {
    var out = {};
    if (a) for (var key in a) out[key] = a[key];
    if (b) for (var key2 in b) out[key2] = b[key2];
    out.failIfMajorPerformanceCaveat = false;
    return out;
  }

  function isWebGlType(kind) {
    return kind === "webgl" || kind === "webgl2" || kind === "experimental-webgl";
  }

  HTMLCanvasElement.prototype.getContext = function (type, attrs) {
    var kind = String(type || "").toLowerCase();
    if (!isWebGlType(kind)) return original.call(this, type, attrs);

    var tries = [merge(attrs || {}, { failIfMajorPerformanceCaveat: false })];
    for (var i = 0; i < attempts.length; i += 1) {
      tries.push(merge(attempts[i], attrs));
      tries.push(attempts[i]);
    }
    for (var j = 0; j < tries.length; j += 1) {
      try {
        var gl = original.call(this, kind, tries[j]);
        if (gl) {
          window.__medclawWebGl = {
            type: kind,
            webgl2: kind === "webgl2",
          };
          return gl;
        }
      } catch (error) {
        /* Qt WebEngine may throw instead of returning null */
      }
    }
    if (kind === "webgl2") {
      try {
        return original.call(this, "webgl2", { failIfMajorPerformanceCaveat: false });
      } catch (error2) {
        return null;
      }
    }
    return original.call(this, type, attrs);
  };
})();
