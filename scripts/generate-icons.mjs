/**
 * Generates PWA icons from the SVG logo.
 * Run from the project root: node scripts/generate-icons.mjs
 */
import sharp from 'sharp'
import { readFileSync, mkdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const root = join(__dirname, '..')

const svgPath = join(root, 'public', 'ijwi-logo.svg')
const svgBuffer = readFileSync(svgPath)

mkdirSync(join(root, 'public', 'icons'), { recursive: true })

const sizes = [
  { size: 192, name: 'icon-192.png' },
  { size: 512, name: 'icon-512.png' },
  { size: 180, name: 'apple-touch-icon.png' },
  { size: 32,  name: 'favicon-32.png' },
]

for (const { size, name } of sizes) {
  const outPath = join(root, 'public', 'icons', name)
  await sharp(svgBuffer)
    .resize(size, size)
    .png()
    .toFile(outPath)
  console.log(`✓ Generated ${name} (${size}×${size})`)
}

// Also write a 32px favicon to public root
await sharp(svgBuffer)
  .resize(32, 32)
  .png()
  .toFile(join(root, 'public', 'favicon.png'))
console.log('✓ Generated favicon.png (32×32)')

console.log('\nAll icons generated. Commit public/icons/ to your repo.')
