/** Preserve WebGL context attributes and bound retries after a creation failure. */
(function () {
  if (window.__medclawWebGlPatched) return;
  window.__medclawWebGlPatched = true;
  var original = HTMLCanvasElement.prototype.getContext;
  var failedUntil = 0;
  HTMLCanvasElement.prototype.getContext = function (type, attrs) {
    var kind = String(type || '').toLowerCase();
    if (kind !== 'webgl' && kind !== 'webgl2' && kind !== 'experimental-webgl')
      return original.apply(this, arguments);
    // All canvases share the same GPU device. Do not hammer a lost device.
    if (Date.now() < failedUntil) return null;
    var options = {};
    if (attrs) for (var key in attrs) options[key] = attrs[key];
    options.failIfMajorPerformanceCaveat = false;
    var gl = null;
    try { gl = original.call(this, type, options); } catch (error) {}
    if (!gl) {
      failedUntil = Date.now() + 1000;
      return null;
    }
    window.__medclawWebGl = { type: kind, webgl2: kind === 'webgl2' };
    return gl;
  };
})();
