import { resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { cpSync } from 'node:fs'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const cwd = process.cwd()
const vditorBuildPlugin = {
  name: 'vditor-prod-build',
  apply: 'build' as const,
  closeBundle() {
    const result = spawnSync(
      process.execPath,
      [resolve(cwd, 'node_modules/vite/bin/vite.js'), 'build', '--mode', 'production'],
      { cwd: resolve(cwd, 'vditor'), stdio: 'inherit' },
    )
    if (result.status !== 0) throw new Error('vditor build failed')
    cpSync(
      resolve(cwd, 'vditor/dist'),
      resolve(cwd, 'dist/markdown/dist'),
      { recursive: true },
    )
  },
}
// https://vitejs.dev/config/
export default defineConfig(({ command, mode }) => ({
  plugins: [
    react(),
    vditorBuildPlugin,
  ],
  define: {
    global: 'globalThis',
  },
  resolve: {
    alias: {
      buffer: 'buffer',
      stream: resolve(cwd, 'src/react/shims/nodeStream.ts'),
      util: resolve(cwd, 'src/react/shims/nodeUtil.ts'),
    },
  },
  optimizeDeps: {
    include: ['buffer'],
  },
  server: {
    cors: {
      origin: true,
    },
    host: '127.0.0.1',
    port: 5739,
    fs: {
      allow: ['..'],
    },
  },
  // Static viewers (notably PDF.js) are shared by the VS Code extension and
  // the standalone desktop host.
  publicDir: resolve(cwd, 'resource'),
  base: '/',
  build: {
    outDir: 'dist',
    target: 'chrome83',
    emptyOutDir: true,
    chunkSizeWarningLimit: 2048,
  }
}))
