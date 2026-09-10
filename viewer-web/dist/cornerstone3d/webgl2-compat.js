/**
 * Qt 5.15.2 WebEngine (Chromium 83) WebGL2 getContext retry.
 * Does not fake WebGL2 on top of WebGL1: VTK.js 36 volume shaders need a real
 * ES 3.0 context (sampler3D / texImage3D). The Qt process flags must enable it.
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
      powerPreference: 'default',
    },
    {
      alpha: true,
      depth: true,
      antialias: false,
      failIfMajorPerformanceCaveat: false,
      powerPreference: 'low-power',
    },
    {
      alpha: true,
      depth: true,
      antialias: false,
      failIfMajorPerformanceCaveat: false,
      powerPreference: 'high-performance',
    },
    { failIfMajorPerformanceCaveat: false, antialias: false },
    {},
  ];

  function merge(a, b) {
    var out = {};
    if (a) for (var key in a) out[key] = a[key];
    if (b) for (var key2 in b) out[key2] = b[key2];
    return out;
  }

  HTMLCanvasElement.prototype.getContext = function (type, attrs) {
    var kind = String(type || '').toLowerCase();
    if (kind !== 'webgl2') return original.call(this, type, attrs);

    var tries = [attrs || {}];
    for (var i = 0; i < attempts.length; i += 1) {
      tries.push(merge(attempts[i], attrs));
      tries.push(attempts[i]);
    }
    for (var j = 0; j < tries.length; j += 1) {
      try {
        var gl = original.call(this, 'webgl2', tries[j]);
        if (gl) {
          window.__medclawWebGl = { webgl2: true };
          return gl;
        }
      } catch (error) {
        /* Qt WebEngine may throw instead of returning null */
      }
    }
    return original.call(this, type, attrs);
  };
})();
