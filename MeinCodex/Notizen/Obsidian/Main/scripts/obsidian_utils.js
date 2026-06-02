// Shared helpers for the vault's Templater templates.
//
// Exposed to templates via Templater's user-script mechanism: Templater scans
// `user_scripts_folder` (configured to `scripts` — see
// dot_obsidian/plugins/templater-obsidian/data.json) for `.js` files exporting
// a single function and surfaces them as `tp.user.<file_stem>(...)`. Calling
// `tp.user.obsidian_utils()` returns the helper object below.
//
// Why this file exists: slugify, the timestamp block, AKTE_DIR_RE, and the
// Bases-block insertion helpers were previously copy-pasted across
// neuer-akten.md, neuer-zakki.md, and shinki-kadai.md. Diverging copies
// silently break the conventions documented in dot_obsidian/README.md
// (filename slug rules, Akte folder regex, idempotent base-block scoping).
// One module, one definition.
//
// NOTE — duplication with dot_obsidian/plugins/mein-codex-sync/main.js:
// Obsidian plugins are loaded by Obsidian's own loader and cannot require()
// vault-relative .js files, so the sync plugin reproduces `slugify`,
// `KADAI_PATH_RE`, `ZAKKI_PATH_RE`, `UID6_RE`, and `expectedStem` verbatim.
// Keep both files in sync when editing any of those.

module.exports = function obsidian_utils() {
  // Matches an Akte project folder path: akten/YYYY/MM/<uid6>-<slug>.
  // Used by neuer-zakki / shinki-kadai to walk a candidate file's parent
  // chain looking for an enclosing Akte. Must stay aligned with the folder
  // shape produced by neuer-akten.md.
  const AKTE_DIR_RE = /^akten\/\d{4}\/\d{2}\/[a-z0-9]+-[a-z0-9-]+$/;

  // Path shapes for files managed by the sync plugin. Kept here so the
  // template-side and plugin-side definitions live next to each other in
  // documentation, even though the plugin reproduces them.
  const KADAI_PATH_RE = /^kadai\/\d{4}\/\d{2}\/\d{2}\//;
  const ZAKKI_PATH_RE = /^zakki\/\d{4}\/\d{2}\/\d{2}\//;
  const UID6_RE = /^[a-f0-9]{6}$/;

  // Sanitize a human title into a filename-safe slug.
  // NFD-fold to ASCII, lowercase, collapse non-[a-z0-9] runs to "-", trim,
  // truncate at 60 chars on a "-" boundary, fall back to "untitled" if empty.
  // Slug rules are documented in dot_obsidian/README.md ("Document ID").
  const slugify = (title) => {
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
  };

  // Compute a calendar/ISO timestamp bundle from a single `new Date()` call.
  // Returns zero-padded date parts plus three ISO variants:
  //   - localIso : YYYY-MM-DDTHH:mm:ss±HH:MM (wall-clock + tz offset)
  //   - utcIso   : YYYY-MM-DDTHH:mm:ssZ      (whole-second UTC)
  //   - startIso : YYYY-MM-DDTHH:mm:ss       (no zone — for task.start-date)
  const getTimestamps = () => {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    const YYYY = now.getFullYear();
    const MM = pad(now.getMonth() + 1);
    const DD = pad(now.getDate());
    const hh = pad(now.getHours());
    const mm = pad(now.getMinutes());
    const ss = pad(now.getSeconds());

    const tzMin = -now.getTimezoneOffset();
    const tzSign = tzMin >= 0 ? "+" : "-";
    const tzAbs = Math.abs(tzMin);
    const tzOff = `${tzSign}${pad(Math.floor(tzAbs / 60))}:${pad(tzAbs % 60)}`;

    const localIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}${tzOff}`;
    const utcIso = now.toISOString().replace(/\.\d{3}Z$/, "Z");
    const startIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}`;

    return { YYYY, MM, DD, hh, mm, ss, localIso, utcIso, startIso };
  };

  // True if the section bounded by [headingIdx+1, sectionEnd) already
  // contains a ```base block scoping to (refKey == refValue). Lets the
  // caller skip insertion so re-running the creation template on a parent
  // that already carries the block is a no-op.
  const sectionHasBaseScope = (lines, headingIdx, sectionEnd, refKey, refValue) => {
    const target = `note["${refKey}"] == "${refValue}"`;
    let inBase = false;
    for (let i = headingIdx + 1; i < sectionEnd; i++) {
      const trimmed = lines[i].trim();
      if (!inBase && /^```base\b/.test(trimmed)) { inBase = true; continue; }
      if (inBase && trimmed === "```") { inBase = false; continue; }
      if (inBase && lines[i].includes(target)) return true;
    }
    return false;
  };

  // Insert a Bases code block under `headingText` in `file`, idempotently.
  // If the heading is missing, append both the heading and the block to EOF.
  // If the heading exists but already contains a block scoped to
  // (refKey == refValue), do nothing. Otherwise insert the block at the end
  // of the section (after trimming trailing blank lines).
  //
  // Section end is "next heading H1..H6" — the regex deliberately matches
  // any Markdown heading level so H3+ subheadings terminate the section
  // instead of being swallowed into it (previous /^#{1,2}\s+/ only stopped
  // at H1/H2 and overran lower-level headings).
  const insertBaseBlockIntoSection = async (app, file, baseBlock, headingText, refKey, refValue) => {
    const content = await app.vault.read(file);
    const lines = content.split("\n");
    const headingIdx = lines.findIndex((l) => l.trim() === headingText);
    if (headingIdx === -1) {
      const trailing = content.endsWith("\n") ? "" : "\n";
      await app.vault.modify(file, content + trailing + "\n" + headingText + "\n\n" + baseBlock + "\n");
      return;
    }
    let sectionEnd = lines.length;
    for (let i = headingIdx + 1; i < lines.length; i++) {
      if (/^#{1,6}\s+/.test(lines[i])) { sectionEnd = i; break; }
    }
    if (sectionHasBaseScope(lines, headingIdx, sectionEnd, refKey, refValue)) return;
    while (sectionEnd > headingIdx + 1 && lines[sectionEnd - 1].trim() === "") sectionEnd--;
    lines.splice(sectionEnd, 0, "", ...baseBlock.split("\n"));
    await app.vault.modify(file, lines.join("\n"));
  };

  // Expected `<uid6>-<slug>` filename stem for a managed Kadai / Zakki file.
  // Returns null for files outside the managed path shapes or with a
  // non-hex uid6 prefix (legacy files that predate the slug convention).
  // Reused by the sync plugin's rename listener — keep behaviour aligned
  // with mein-codex-sync's local copy.
  const expectedStem = (file, title) => {
    const path = file.path;
    if (!KADAI_PATH_RE.test(path) && !ZAKKI_PATH_RE.test(path)) {
      return null;
    }
    const basename = file.basename;
    const dashIdx = basename.indexOf("-");
    const uid6 = dashIdx === -1 ? basename : basename.slice(0, dashIdx);
    if (!UID6_RE.test(uid6)) return null;
    return `${uid6}-${slugify(title)}`;
  };

  return {
    AKTE_DIR_RE,
    KADAI_PATH_RE,
    ZAKKI_PATH_RE,
    UID6_RE,
    slugify,
    getTimestamps,
    sectionHasBaseScope,
    insertBaseBlockIntoSection,
    expectedStem,
  };
};
