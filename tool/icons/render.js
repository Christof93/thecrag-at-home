// Renders the web icons from the SVG sources in this folder:
//
//   NODE_PATH=$(npm root -g) node tool/icons/render.js
//
// Needs Playwright (any Chromium works). Writes web/favicon.svg,
// web/favicon.png and web/icons/Icon-*.png.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const here = __dirname;
const web = path.join(here, '..', '..', 'web');
const icon = fs.readFileSync(path.join(here, 'icon.svg'), 'utf8');
const maskable = fs.readFileSync(path.join(here, 'maskable.svg'), 'utf8');

const targets = [
  [icon, 64, path.join(web, 'favicon.png')],
  [icon, 192, path.join(web, 'icons', 'Icon-192.png')],
  [icon, 512, path.join(web, 'icons', 'Icon-512.png')],
  [maskable, 192, path.join(web, 'icons', 'Icon-maskable-192.png')],
  [maskable, 512, path.join(web, 'icons', 'Icon-maskable-512.png')],
];

(async () => {
  fs.copyFileSync(path.join(here, 'icon.svg'), path.join(web, 'favicon.svg'));
  const browser = await chromium.launch();
  for (const [svg, size, out] of targets) {
    const page = await browser.newPage({ viewport: { width: size, height: size } });
    await page.setContent(
      `<body style="margin:0;background:transparent">${svg.replace(
        '<svg ',
        `<svg width="${size}" height="${size}" style="display:block" `,
      )}</body>`,
    );
    await page.screenshot({ path: out, omitBackground: true });
    await page.close();
    console.log('wrote', path.relative(process.cwd(), out));
  }
  await browser.close();
})();
