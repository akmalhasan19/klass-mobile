import readline from 'node:readline';
import process from 'node:process';
import { chromium, Browser } from 'playwright';
import { generatePresentation, PresentationInput } from './presentation_generator.js';

const RENDER_TIMEOUT_MS = Number(process.env.MARP_SIDECAR_RENDER_TIMEOUT_MS ?? 30000);
const BROWSER_ARGS = ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'];

let browser: Browser | null = null;

function send(message: any) {
  process.stdout.write(JSON.stringify(message) + '\n');
}

function log(message: string) {
  process.stderr.write(`[chromium-sidecar] ${message}\n`);
}

async function ensureBrowser(): Promise<Browser> {
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

async function htmlToPdf(params: { html?: string }) {
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

async function generatePptx(params: { spec: PresentationInput }) {
  try {
    const buffer = await generatePresentation(params.spec);
    return { pptx: buffer.toString('base64') };
  } catch (err) {
    log(`generate_pptx failed: ${err instanceof Error ? err.message : String(err)}`);
    throw err;
  }
}

async function health() {
  return { status: 'ok', browser: Boolean(browser && browser.isConnected()) };
}

type RPCMethod = (params: any) => Promise<any>;

const METHODS: Record<string, RPCMethod> = {
  html_to_pdf: htmlToPdf,
  generate_pptx: generatePptx,
  health,
};

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  let timer: NodeJS.Timeout;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} exceeded ${ms}ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

async function dispatch(message: { id: any; method: string; params?: any }) {
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
    let message: any;
    try {
      message = JSON.parse(trimmed);
    } catch (err: any) {
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
