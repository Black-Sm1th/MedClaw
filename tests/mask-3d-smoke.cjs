const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const puppeteer = require('../viewer-web/node_modules/puppeteer-core');

const root = path.resolve(__dirname, '../viewer-web/dist/cornerstone3d');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const server = http.createServer((req, res) => {
  if (req.url === '/favicon.ico') { res.writeHead(204); res.end(); return; }
  const file = path.resolve(root, '.' + (req.url === '/' ? '/index.html' : req.url.split('?')[0]));
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  res.setHeader('Content-Type', file.endsWith('.js') ? 'application/javascript' : file.endsWith('.html') ? 'text/html' : 'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
let browser;
let qtProcess;
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const errors = [];
  const gpuWarnings = [];
  const captureGpuWarnings = data => {
    if(process.env.MASK_DEBUG) process.stderr.write(data);
    for (const line of String(data).split('\n')) {
      if (/Attribute 0 is disabled|texture bound .* not renderable/.test(line)) gpuWarnings.push(line);
    }
  };
  if (process.argv.includes('--qt')) {
    const portProbe = http.createServer();
    await new Promise(resolve=>portProbe.listen(0,'127.0.0.1',resolve));
    const debugPort = portProbe.address().port;
    await new Promise(resolve=>portProbe.close(resolve));
    qtProcess = spawn('D:/qt.8.3/6.8.3/msvc2022_64/bin/qml.exe', [path.join(__dirname,'mask-3d-qt.qml')], {
      windowsHide:true,
      env:{...process.env, QT_OPENGL:'desktop', QSG_RHI_BACKEND:'opengl', QTWEBENGINE_REMOTE_DEBUGGING:`127.0.0.1:${debugPort}`, QTWEBENGINE_CHROMIUM_FLAGS:'--remote-allow-origins=* --use-gl=desktop --enable-webgl --disable-features=CalculateNativeWinOcclusion'}
    });
    qtProcess.stderr.on('data', captureGpuWarnings);
    for(let i=0;i<40;i++) {
      try { browser = await puppeteer.connect({browserURL:`http://127.0.0.1:${debugPort}`,defaultViewport:null}); break; }
      catch { await pause(250); }
    }
    assert(browser,'Qt WebEngine remote debugging must start');
  } else {
    browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--enable-unsafe-swiftshader'], dumpio: !!process.env.MASK_DEBUG });
    browser.process().stderr.on('data', captureGpuWarnings);
  }
  const page = qtProcess ? (await browser.pages())[0] : await browser.newPage();
  if (!qtProcess) await page.setViewport({ width: 1400, height: 1000 });
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', msg => { if (['error', 'warn'].includes(msg.type())) console.log(msg.type(), msg.text()); });
  await page.evaluateOnNewDocument(noFloatLinear => {
    window.__glFailures = [];
    for (const proto of [WebGLRenderingContext.prototype, WebGL2RenderingContext.prototype]) {
      const getExtension = proto.getExtension;
      proto.getExtension = function(name) {
        return noFloatLinear && name === 'OES_texture_float_linear' ? null : getExtension.call(this,name);
      };
      for (const name of ['drawArrays','drawElements']) {
        const draw = proto[name];
        proto[name] = function(...args) {
          if (!this.getVertexAttrib(0, this.VERTEX_ATTRIB_ARRAY_ENABLED)) {
            const program = this.getParameter(this.CURRENT_PROGRAM);
            window.__glFailures.push({message:'attribute zero disabled', shaders:this.getAttachedShaders(program).filter(s=>this.getShaderParameter(s,this.SHADER_TYPE)===this.VERTEX_SHADER).map(s=>this.getShaderSource(s))});
          }
          const result = draw.apply(this,args);
          const error = this.getError();
          if (error) window.__glFailures.push('draw error ' + error);
          return result;
        };
      }
    }
  }, process.argv.includes('--no-float-linear'));
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  await page.waitForFunction(() => window.__medclawRenderingDiagnostics);
  await page.evaluate(() => {
    function nifti(mask) {
      const n = 48, b = new ArrayBuffer(352 + n*n*n*2), d = new DataView(b);
      d.setInt32(0,348,true); d.setInt16(40,3,true);
      [n,n,n,1,1,1,1].forEach((v,i)=>d.setInt16(42+2*i,v,true));
      d.setInt16(70,4,true); d.setInt16(72,16,true);
      for (let i=0;i<8;i++) d.setFloat32(76+4*i,1,true);
      d.setFloat32(108,352,true); d.setFloat32(112,1,true);
      d.setInt16(254,1,true); [280,300,320].forEach(o=>d.setFloat32(o,1,true));
      new Uint8Array(b,344,4).set([110,43,49,0]);
      const v = new Int16Array(b,352);
      for(let z=0;z<n;z++) for(let y=0;y<n;y++) for(let x=0;x<n;x++) {
        const r = (x-24)**2+(y-24)**2+(z-24)**2;
        v[x+n*(y+n*z)] = mask ? (r<100 ? 1 : 0) : (r<400 ? 100 : -1000);
      }
      return new File([b], mask ? 'synthetic_mask.nii' : 'synthetic_ct.nii');
    }
    const dt = new DataTransfer(); dt.items.add(nifti(false)); dt.items.add(nifti(true));
    const input = document.querySelector('#fileInput'); input.files=dt.files;
    input.dispatchEvent(new Event('change', {bubbles:true}));
  });
  await page.waitForFunction(() => document.querySelectorAll('.mask-card').length > 0, {timeout:60000});
  await page.evaluate(() => window.__medclawSetLayout('four'));
  await pause(4000);
  const snapshot = () => page.evaluate(() => {
    const c = document.querySelector('#viewport-3d canvas');
    if (!c) return {missing:true};
    const copy = document.createElement('canvas'); copy.width=c.width; copy.height=c.height;
    const ctx = copy.getContext('2d'); ctx.drawImage(c,0,0);
    const data = ctx.getImageData(0,0,c.width,c.height).data;
    let lit=0, colored=0, green=0;
    for(let i=0;i<data.length;i+=4) {
      const [r,g,b]=data.subarray(i,i+3);
      if(r+g+b>30) lit++;
      if(Math.max(r,g,b)-Math.min(r,g,b)>30) colored++;
      if(g>r*1.25 && g>b*1.1 && g>40) green++;
    }
    return {lit,colored,green,actors:window.__medclawRenderingDiagnostics().viewports.find(v=>v.id==='CT_3D')?.actors};
  });
  // Set a distinctive mask color through the same UI controls used by the user.
  await page.click('.mask-card');
  await page.click('.mask-swatch');
  const greenChip = await page.$('.mask-color-chip[data-color="#5c947c"]');
  if(greenChip) await greenChip.click();
  await pause(1500);
  const visible = await snapshot();
  await page.screenshot({path:path.resolve(__dirname, '../build/mask-3d-visible' + (process.argv.includes('--no-float-linear') ? '-no-float' : '') + '.png')});
  await page.click('.mask-vis input'); await pause(1500);
  const hidden = await snapshot();
  await page.click('.mask-vis input');
  await page.$eval('[data-mask-action="opacity"]', input => {
    input.value='0'; input.dispatchEvent(new Event('input',{bubbles:true}));
  });
  await pause(1000);
  const transparent = await snapshot();
  await page.$eval('[data-mask-action="opacity"]', input => {
    input.value='100'; input.dispatchEvent(new Event('input',{bubbles:true}));
  });
  await pause(1000);
  const restored = await snapshot();
  const glFailures = await page.evaluate(()=>window.__glFailures);
  console.log(JSON.stringify({visible,hidden,transparent,restored,errors,gpuWarnings,glFailures},null,2));
  assert.equal(errors.length,0);
  assert(visible.lit>0, '3D must not be blank');
  assert(visible.green>100, 'visible green mask must render');
  assert(hidden.green<visible.green/4, 'hidden mask must disappear');
  assert(hidden.colored>100, 'original CT must remain visible with the mask hidden');
  assert(transparent.green<visible.green/4, 'zero opacity must hide mask');
  assert(restored.green>100, 'mask must return after changing opacity');
  assert.deepEqual(glFailures,[]);
  assert.deepEqual(gpuWarnings,[]);
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(async()=>{
  if(qtProcess) { browser?.disconnect(); qtProcess.kill(); }
  else await browser?.close();
  server.close();
});
