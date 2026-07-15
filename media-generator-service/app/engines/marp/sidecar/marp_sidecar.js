import readline from 'node:readline';
import process from 'node:process';

import { Marp } from '@marp-team/marp-core';
import { chromium } from 'playwright';

const RENDER_TIMEOUT_MS = Number(process.env.MARP_SIDECAR_RENDER_TIMEOUT_MS ?? 30000);
const BROWSER_ARGS = ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'];

let browser = null;

function send(message) {
  process.stdout.write(JSON.stringify(message) + '\n');
}

function log(message) {
  process.stderr.write(`[marp-sidecar] ${message}\n`);
}

async function ensureBrowser() {
  if (browser && browser.isConnected()) {
    return browser;
  }
  if (browser) {
    try {
      await browser.close();
    } catch (err) {
      log(`stale browser close failed: ${err}`);
    }
  }
  browser = await chromium.launch({ args: BROWSER_ARGS });
  return browser;
}

function withMarpDirective(markdown) {
  const fm = /^---\s*\n([\s\S]*?)\n---\s*\n?/.exec(markdown || '');
  if (fm) {
    if (/^\s*marp\s*:/m.test(fm[1])) {
      return markdown;
    }
    const body = markdown.slice(fm[0].length);
    return `---\n${fm[1].replace(/\s+$/, '')}\nmarp: true\n---\n${body}`;
  }
  return `---\nmarp: true\n---\n\n${markdown || ''}`;
}

function buildMarp(themeCss) {
  const marp = new Marp({ inlineSVG: false });
  if (themeCss) {
    const theme = marp.themeSet.add(themeCss);
    if (theme && theme.meta && theme.meta.name) {
      marp.themeSet.default = theme.meta.name;
    }
  }
  return marp;
}

function assembleHtml(html, css) {
  return `<!DOCTYPE html><html lang="id"><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width, initial-scale=1">` +
    `<style>${css}</style></head><body>${html}</body></html>`;
}

async function renderHtml(params) {
  const marp = buildMarp(params.theme_css);
  const { html, css } = marp.render(withMarpDirective(params.markdown));
  return { html: assembleHtml(html, css) };
}

async function renderPdf(params) {
  const b = await ensureBrowser();
  const context = await b.newContext({ viewport: { width: 1280, height: 720 } });
  try {
    const page = await context.newPage();
    await page.setContent(params.html || '', { waitUntil: 'load' });
    const pdf = await page.pdf({ preferCSSPageSize: true, printBackground: true });
    return { pdf: Buffer.from(pdf).toString('base64') };
  } finally {
    await context.close();
  }
}

async function health() {
  return { status: 'ok', browser: Boolean(browser && browser.isConnected()) };
}

const METHODS = {
  render_html: renderHtml,
  render_pdf: renderPdf,
  health,
};

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} exceeded ${ms}ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

async function dispatch(message) {
  const fn = METHODS[message.method];
  if (!fn) {
    send({ id: message.id, error: { code: -32601, message: `method not found: ${message.method}` } });
    return;
  }
  try {
    const result = await withTimeout(fn(message.params ?? {}), RENDER_TIMEOUT_MS, message.method);
    send({ id: message.id, result });
  } catch (err) {
    send({
      id: message.id,
      error: { code: -32000, message: err instanceof Error ? err.message : String(err) },
    });
  }
}

async function main() {
  await ensureBrowser();
  send({ ready: true });
  log('Chromium launched, sidecar ready for requests');

  const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
  rl.on('line', (line) => {
    const trimmed = line.trim();
    if (!trimmed) {
      return;
    }
    let message;
    try {
      message = JSON.parse(trimmed);
    } catch (err) {
      send({ id: null, error: { code: -32700, message: `parse error: ${err.message}` } });
      return;
    }
    dispatch(message);
  });

  let shuttingDown = false;
  const shutdown = async () => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    try {
      if (browser) {
        await browser.close();
      }
    } catch (err) {
      log(`browser close failed: ${err}`);
    }
    process.exit(0);
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
  process.stdin.on('end', shutdown);
}

main().catch((err) => {
  log(`fatal: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
