import { Marp } from '@marp-team/marp-core';
import { chromium } from 'playwright';
import fs from 'fs';

const css = fs.readFileSync('../themes/klass-default.css', 'utf8');
const marp = new Marp({ inlineSVG: false });
const theme = marp.themeSet.add(css);
marp.themeSet.default = theme;

const md = '---\nmarp: true\ntheme: klass-educational-v1\npaginate: true\nsize: 16:9\n---\n\n# Hi\n\n- a\n- b\n';
const { html } = marp.render(md);
const full = `<!DOCTYPE html><html lang="id"><head><meta charset="utf-8"><style>${css}</style></head><body>${html}</body></html>`;

const browser = await chromium.launch({ args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'] });
try {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await page.setContent(full, { waitUntil: 'load' });
  const pdf = await page.pdf({ preferCSSPageSize: true, printBackground: true });
  console.log('PDF OK bytes', pdf.length);
} catch (e) {
  console.log('PDF ERR:', e.message);
} finally {
  await browser.close();
}
