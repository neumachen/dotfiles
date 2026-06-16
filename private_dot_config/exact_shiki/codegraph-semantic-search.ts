/**
 * CodeGraph Semantic Search Override
 *
 * Transparently routes the built-in `power---semantic_search` tool call to the
 * locally-installed CodeGraph engine, so semantic search uses CodeGraph's
 * pre-built local index instead of AiderDesk's default (probe-based) search.
 *
 * This replaces the chunkhound-on-semantic-search-tool override, which
 * occasionally hangs while spawning the `chunkhound` CLI.
 *
 * Engine resolution
 * -----------------
 * This single-file extension is dependency-free. It does NOT vendor or
 * re-install `@colbymchenry/codegraph`. Instead, at runtime it `require`s the
 * exact same install used by the sibling `codegraph/` folder extension, by
 * resolving from:
 *   1) `${AIDER_DESK_EXTENSIONS_DIR}/codegraph/node_modules`  (preferred)
 *   2) `${__dirname}/codegraph/node_modules`                  (fallback — this
 *      file lives directly inside the extensions dir, alongside `codegraph/`)
 * That guarantees we use the identical engine version the CodeGraph extension
 * already loaded, with zero duplication.
 *
 * Safety
 * ------
 * - PASSTHROUGH-ONLY ON FAILURE: returning `undefined` lets the native
 *   semantic_search tool run. We never throw out of `onToolCalled`.
 * - 20-second hard timeout via `Promise.race`, plus honoring `signal` if the
 *   host invokes us with an AbortSignal. On timeout/abort/error → passthrough.
 * - INDEX-READ-ONLY: if `isInitialized(projectDir)` is false, we passthrough
 *   immediately. We do NOT trigger first-time indexing from inside a tool
 *   call — that would block the agent for minutes. Initial indexing is the
 *   job of the sibling `codegraph` extension (which exposes its own tools).
 *
 * Caching
 * -------
 * Opened CodeGraph instances are cached per projectDir in a module-level
 * Map to avoid reopening the on-disk DB on every search. `onUnload` closes
 * them.
 */

import * as path from 'node:path';
import { createRequire } from 'node:module';

import type { Extension, ExtensionContext, ToolCalledEvent } from '@aiderdesk/extensions';

// ---------------------------------------------------------------------------
// Runtime engine resolution (no static import of @colbymchenry/codegraph).
// ---------------------------------------------------------------------------

interface CodeGraphInstance {
  buildContext(
    query: string,
    opts: { maxNodes?: number; includeCode?: boolean; format?: 'markdown' | 'json' },
  ): Promise<string | unknown>;
  close(): void;
}

interface CodeGraphStatic {
  open(dir: string, opts: { sync: boolean }): Promise<CodeGraphInstance>;
}

interface CodeGraphModuleShape {
  CodeGraphClass: CodeGraphStatic;
  isInitialized: (dir: string) => boolean;
}

const req = createRequire(__filename);

let cachedModule: CodeGraphModuleShape | null = null;
let moduleResolutionFailed = false;

const loadCodeGraph = (context: ExtensionContext): CodeGraphModuleShape | null => {
  if (cachedModule) return cachedModule;
  if (moduleResolutionFailed) return null;

  const candidates: string[] = [];
  const extDir = process.env.AIDER_DESK_EXTENSIONS_DIR;
  if (extDir) {
    candidates.push(path.join(extDir, 'codegraph', 'node_modules'));
  }
  // Fallback: this file sits IN the extensions dir; codegraph/ is a sibling.
  candidates.push(path.join(__dirname, 'codegraph', 'node_modules'));

  try {
    const resolved = req.resolve('@colbymchenry/codegraph', { paths: candidates });
    const mod = req(resolved) as Record<string, unknown>;

    // The package's CommonJS surface exposes both named exports directly, but
    // be defensive about ESM-interop wrappers that put everything under
    // `default`.
    const root = mod as { default?: Record<string, unknown> } & Record<string, unknown>;
    const flat = (root.default && typeof root.default === 'object' ? root.default : root) as Record<string, unknown>;

    const CodeGraphClass = flat.CodeGraph as CodeGraphStatic | undefined;
    const isInitialized = flat.isInitialized as ((dir: string) => boolean) | undefined;

    if (!CodeGraphClass || typeof CodeGraphClass.open !== 'function' || typeof isInitialized !== 'function') {
      context.log(
        'CodeGraph module resolved but does not expose CodeGraph.open / isInitialized; falling back to native semantic_search',
        'warn',
      );
      moduleResolutionFailed = true;
      return null;
    }

    cachedModule = { CodeGraphClass, isInitialized };
    return cachedModule;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    context.log(
      `CodeGraph module not resolvable from candidates [${candidates.join(', ')}]; falling back to native semantic_search: ${msg}`,
      'warn',
    );
    moduleResolutionFailed = true;
    return null;
  }
};

// ---------------------------------------------------------------------------
// Per-project instance cache.
// ---------------------------------------------------------------------------

const instances = new Map<string, CodeGraphInstance>();

const getOrOpenInstance = async (
  mod: CodeGraphModuleShape,
  projectDir: string,
): Promise<CodeGraphInstance> => {
  const existing = instances.get(projectDir);
  if (existing) return existing;
  const cg = await mod.CodeGraphClass.open(projectDir, { sync: true });
  instances.set(projectDir, cg);
  return cg;
};

// ---------------------------------------------------------------------------
// Timeout / abort helpers.
// ---------------------------------------------------------------------------

const SEARCH_TIMEOUT_MS = 20_000;

class TimeoutError extends Error {
  constructor() {
    super(`CodeGraph search exceeded ${SEARCH_TIMEOUT_MS}ms`);
    this.name = 'TimeoutError';
  }
}

class AbortError extends Error {
  constructor() {
    super('CodeGraph search aborted');
    this.name = 'AbortError';
  }
}

const withTimeoutAndAbort = <T>(p: Promise<T>, signal: AbortSignal | undefined): Promise<T> => {
  let timer: NodeJS.Timeout | undefined;
  let onAbort: (() => void) | undefined;

  const guards = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => reject(new TimeoutError()), SEARCH_TIMEOUT_MS);
    if (signal) {
      if (signal.aborted) {
        reject(new AbortError());
        return;
      }
      onAbort = () => reject(new AbortError());
      signal.addEventListener('abort', onAbort, { once: true });
    }
  });

  return Promise.race([p, guards]).finally(() => {
    if (timer) clearTimeout(timer);
    if (signal && onAbort) signal.removeEventListener('abort', onAbort);
  });
};

// ---------------------------------------------------------------------------
// Extension.
// ---------------------------------------------------------------------------

export default class CodeGraphSemanticSearchExtension implements Extension {
  static metadata = {
    name: 'CodeGraph Semantic Search',
    version: '1.0.0',
    description:
      'Overrides power---semantic_search to query the locally-installed CodeGraph index (read-only, 20s timeout, falls back to native search on any failure)',
    author: 'neumachen',
    iconUrl: 'https://raw.githubusercontent.com/hotovo/aider-desk/refs/heads/main/packages/extensions/extensions/codegraph/icon.png',
    capabilities: ['search'],
  };

  async onLoad(context: ExtensionContext): Promise<void> {
    context.log('CodeGraph Semantic Search override loaded', 'info');
  }

  async onUnload(): Promise<void> {
    for (const cg of instances.values()) {
      try {
        cg.close();
      } catch {
        // swallow — unload is best-effort
      }
    }
    instances.clear();
  }

  async onToolCalled(
    event: ToolCalledEvent,
    context: ExtensionContext,
    signal?: AbortSignal,
  ): Promise<void | Partial<ToolCalledEvent>> {
    if (event.toolName !== 'power---semantic_search') {
      return undefined;
    }

    const input = event.input as { query?: string; path?: string; maxTokens?: number } | undefined;
    if (!input?.query) {
      return undefined;
    }

    const mod = loadCodeGraph(context);
    if (!mod) {
      // Resolution failure already logged; let native search run.
      return undefined;
    }

    const projectDir = context.getProjectDir();

    // INDEX-READ-ONLY: never trigger first-time indexing from a tool call.
    try {
      if (!mod.isInitialized(projectDir)) {
        context.log(
          `CodeGraph index not initialized for ${projectDir}; passing through to native semantic_search`,
          'debug',
        );
        return undefined;
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      context.log(`CodeGraph isInitialized() threw: ${msg}; passing through`, 'warn');
      return undefined;
    }

    // Honor a pre-aborted signal.
    if (signal?.aborted) {
      return undefined;
    }

    context.log(`CodeGraph semantic_search: query="${input.query}" dir="${projectDir}"`, 'info');

    try {
      const work = (async () => {
        const cg = await getOrOpenInstance(mod, projectDir);
        return cg.buildContext(input.query as string, {
          maxNodes: 50,
          includeCode: true,
          format: 'markdown',
        });
      })();

      const raw = await withTimeoutAndAbort(work, signal);

      let output = typeof raw === 'string' ? raw : JSON.stringify(raw, null, 2);

      // Optional truncation when caller hinted at a token budget. We use the
      // common rule of thumb ~4 chars/token. This is a conservative cap, not
      // a precise tokenizer.
      if (typeof input.maxTokens === 'number' && input.maxTokens > 0) {
        const maxChars = input.maxTokens * 4;
        if (output.length > maxChars) {
          output = `${output.slice(0, maxChars)}\n\n…[truncated: output exceeded ~${input.maxTokens} tokens]`;
        }
      }

      return { output };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (e instanceof TimeoutError) {
        context.log(`CodeGraph semantic_search timed out after ${SEARCH_TIMEOUT_MS}ms; falling back to native`, 'warn');
      } else if (e instanceof AbortError || signal?.aborted) {
        context.log('CodeGraph semantic_search aborted; falling back to native', 'debug');
      } else {
        context.log(`CodeGraph semantic_search failed: ${msg}; falling back to native`, 'warn');
      }
      // Drop the cached instance for this project on hard failures so the
      // next call can attempt a fresh open.
      if (!(e instanceof AbortError)) {
        const cg = instances.get(projectDir);
        if (cg) {
          try {
            cg.close();
          } catch {
            // ignore
          }
          instances.delete(projectDir);
        }
      }
      return undefined;
    }
  }
}
