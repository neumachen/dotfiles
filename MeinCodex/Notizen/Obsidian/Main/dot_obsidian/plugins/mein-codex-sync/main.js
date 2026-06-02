"use strict";

// MeinCodex Sync — local Obsidian plugin.
//
// Two listeners installed on plugin load:
//
//   1. vault.on("rename", ...): when a file is renamed/moved, rewrite that
//      file's `path:` and `filename:` frontmatter so the per-note system
//      fields stay aligned with the actual location. Pairs with Obsidian's
//      built-in `alwaysUpdateLinks` (which handles wikilink targets).
//
//   2. metadataCache.on("changed", ...): when the `title:` frontmatter of a
//      managed note (Kadai under kadai/YYYY/MM/DD/, Zakki under
//      zakki/YYYY/MM/DD/) changes, recompute <uid6>-<slug> and rename the
//      file via app.fileManager.renameFile. The first metadata-changed
//      event per file path is treated as the indexing pass and skipped, so
//      pre-existing legacy files are NOT mass-renamed at startup. Bulk
//      migration belongs in a one-off script.
//
// Lifecycle: listeners are registered via this.registerEvent(...), so
// Obsidian disposes them automatically on plugin unload/reload. No
// globalThis bookkeeping needed (the previous Templater-startup version
// kept its own offref guards because nothing else managed the listener
// lifetime — that's no longer true).
//
// NOTE — duplication with scripts/obsidian_utils.js (the Templater
// user-script): Obsidian plugins are loaded by Obsidian's own loader and
// cannot require() a vault-relative .js file at runtime, so KADAI_PATH_RE,
// ZAKKI_PATH_RE, UID6_RE, slugify, and expectedStem are reproduced here
// verbatim. Keep both copies in sync when editing any of them.

const obsidian = require("obsidian");

const KADAI_PATH_RE = /^kadai\/\d{4}\/\d{2}\/\d{2}\//;
const ZAKKI_PATH_RE = /^zakki\/\d{4}\/\d{2}\/\d{2}\//;
const UID6_RE = /^[a-f0-9]{6}$/;

// Sanitize a human title into a filename-safe slug. See dot_obsidian/README.md
// ("Document ID") for the rule statement. Must stay byte-identical to the
// copy in scripts/obsidian_utils.js.
function slugify(title) {
  let s = title
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  if (s.length > 60) {
    s = s.slice(0, 60).replace(/-+$/g, "");
    const lastDash = s.lastIndexOf("-");
    if (lastDash > 30) s = s.slice(0, lastDash);
  }
  return s || "untitled";
}

// Expected `<uid6>-<slug>` filename stem for a managed Kadai / Zakki file.
// Returns null for files outside the managed path shapes or with a
// non-hex uid6 prefix (legacy files that predate the slug convention).
function expectedStem(file, title) {
  const path = file.path;
  if (!KADAI_PATH_RE.test(path) && !ZAKKI_PATH_RE.test(path)) {
    return null;
  }
  const basename = file.basename;
  const dashIdx = basename.indexOf("-");
  const uid6 = dashIdx === -1 ? basename : basename.slice(0, dashIdx);
  if (!UID6_RE.test(uid6)) return null;
  return `${uid6}-${slugify(title)}`;
}

class MeinCodexSyncPlugin extends obsidian.Plugin {
  async onload() {
    // seen: paths the metadata listener has already observed at least once.
    // The first metadataCache.changed event per path is the startup
    // indexing pass and is intentionally skipped.
    //
    // pending: paths currently being renamed by listener #2, used as a
    // re-entry guard so the cascade (metadataCache.changed → renameFile →
    // metadataCache.changed for the new path) doesn't loop.
    this.seen = new Set();
    this.pending = new Set();

    this.registerEvent(
      this.app.vault.on("rename", async (file, oldPath) => {
        if (!file || file.extension !== "md") return;
        if (oldPath === file.path) return;
        // Carry the "already-seen" mark across the rename so the post-rename
        // metadataCache.changed event isn't mistaken for an indexing pass.
        if (this.seen.has(oldPath)) {
          this.seen.delete(oldPath);
          this.seen.add(file.path);
        }
        try {
          await this.app.fileManager.processFrontMatter(file, (fm) => {
            if ("path" in fm) fm.path = file.path;
            if ("filename" in fm) fm.filename = file.basename;
          });
        } catch (_) {}
      })
    );

    this.registerEvent(
      this.app.metadataCache.on("changed", async (file, _data, cache) => {
        if (!file || file.extension !== "md") return;
        if (!this.seen.has(file.path)) {
          this.seen.add(file.path);
          return;
        }
        if (this.pending.has(file.path)) return;
        const title = cache && cache.frontmatter && cache.frontmatter.title;
        if (typeof title !== "string" || !title.trim()) return;
        const want = expectedStem(file, title);
        if (!want || file.basename === want) return;
        const newPath = `${file.parent.path}/${want}.md`;
        if (this.app.vault.getAbstractFileByPath(newPath)) return;
        this.pending.add(file.path);
        try {
          await this.app.fileManager.renameFile(file, newPath);
        } catch (_) {
          this.pending.delete(file.path);
          return;
        }
        this.pending.delete(file.path);
      })
    );
  }

  // onunload is implicit: registerEvent hands ownership to Obsidian's
  // Component lifecycle. No explicit teardown needed.
}

module.exports = MeinCodexSyncPlugin;
