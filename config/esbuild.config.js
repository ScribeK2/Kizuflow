import esbuild from 'esbuild'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const config = {
  entryPoints: ['app/javascript/application.js'],
  bundle: true,
  outdir: 'app/assets/builds',
  absWorkingDir: path.join(process.cwd()),
  publicPath: 'assets',
  write: true,
  format: 'esm',
  loader: {
    '.js': 'jsx',
  },
  banner: {
    js: '/* Kizuflow Application Bundle */',
  },
  logLevel: 'info',
  sourcemap: true,
  minify: process.env.RAILS_ENV === 'production',
  target: ['es2020'],
  plugins: [],
}

if (process.argv.includes('--watch')) {
  config.watch = {
    onRebuild(error, result) {
      if (error) console.error('watch build failed:', error)
      else console.log('watch build succeeded')
    },
  }
}

esbuild.build(config).catch(() => process.exit(1))

