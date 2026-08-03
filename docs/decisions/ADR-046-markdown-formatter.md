---
date: 2026-08-03
status: Accepted, Implementation pending (wired in #435 PR B)
---

# ADR-046: Markdown formatter — dprint with `textWrap:never`

> Adopts **dprint** (markdown plugin, `textWrap:never` + `emphasisKind:asterisks`) as the repo's deterministic markdown formatter, wired through the existing treefmt-nix seam. This **reverses** [docs/workflow.md](../workflow.md) §"Markdown is soft-wrapped"'s "there is no tree-wide reflow PR" reservation: the soft-wrap convention moves from a hand-authored, PR-checkbox-enforced habit to a mechanically-enforced one. `textWrap:never` *is* the soft-wrap rule expressed as a formatter (it collapses intra-paragraph newlines to one line per paragraph); `emphasisKind:asterisks` unifies emphasis on the repo's already-dominant `*` marker. Landing is split into two PRs: **PR A** (this ADR + convention-prose retirement + a values-only YAML-frontmatter precursor on the ADR headers dprint would otherwise join) is docs-only; **PR B** wires dprint and runs the one-off reflow atomically. Decided in [#435](https://github.com/dannyfaris/nix-config/issues/435).

## Context

The soft-wrap convention (§"Markdown is soft-wrapped") has been an unenforced habit: authored by hand, checked only by a PR-template checkbox. An unenforced textual convention drifts — some files are hard-wrapped, some soft, some mixed mid-file — and the drift is silent until a reviewer notices. #435 is the decision to mechanize it: pick a deterministic markdown formatter, wire it through the treefmt seam every other formatter (nixfmt, shfmt) already uses, and reflow the tree once so the whole corpus reaches a single fixpoint.

The issue named dprint as the work product, which the repo's own [workflow.md](../workflow.md) §"Issues specify the work, not the work product" cautions against. So the candidates were re-weighed from first principles against the actual flake pins rather than rubber-stamped — see Rationale.

The load-bearing forces:

1. **Churn-minimization.** A one-off reflow touches most of the ~156 tracked `.md` files. The formatter that changes the *fewest* bytes beyond the intended reflow (no gratuitous list-renumbering, marker-flipping, or emphasis-inversion) leaves the cleanest review and the smallest ongoing diff noise.
2. **Hermetic / offline.** The formatter must run inside the Nix build sandbox with no network fetch — plugins loaded from the local store, not downloaded at format time.
3. **Wrap-semantics fidelity.** The convention is *true soft-wrap* — one line per paragraph, not semantic line breaks. The formatter must express exactly that, not an approximation.

## Decision

**1. dprint is the markdown formatter**, wired through the existing treefmt-nix `programs.dprint` module in `parts/formatter.nix` (the same seam as nixfmt and shfmt). The wiring config:

```nix
programs.dprint = {
  enable = true;
  includes = [ "*.md" ];   # module default is includes = [ ".*" ] (all files);
                           # without this, dprint contends with nixfmt/shfmt on every tracked file
  excludes = [ "docs/desktop/keybinds.md" ];   # carries the generated hyper-bindings region the
                                               # keybinds-table check byte-diffs against the registry
                                               # emitter; formatter and generator must not fight
  settings = {
    markdown = { textWrap = "never"; emphasisKind = "asterisks"; };
    plugins = pkgs.dprint-plugins.getPluginList (p: [ p.dprint-plugin-markdown ]);
  };
};
```

`getPluginList` resolves the plugin `.wasm` from the local nixpkgs store path — no network at format time (force 2).

**2. `textWrap = "never"`** collapses intra-paragraph newlines to a single line per paragraph. This *is* the soft-wrap convention expressed mechanically; list items, table rows, and fenced code keep their line structure (force 3).

**3. `emphasisKind = "asterisks"`** unifies emphasis markers on `*`. The repo already runs ~14:1 in favour of `*` (5513 `*x*` occurrences vs 383 `_x_`, measured), so this churns the 383-occurrence minority, not the majority. The default (no `emphasisKind`) would flip all 5513 to `_` — a far larger churn (force 1).

**4. Scope boundary — dprint is NOT added to `systemPackages`, `home.packages`, or the dev-shell.** A bare `dprint` is inert without the treefmt-generated `--config` + plugin path; hand-runs route through `nix fmt`. Dev-shell parity was an open question in the issue and is deliberately declined.

**5. Landing splits into two PRs.** PR A (this ADR + the §4 convention-prose retirement + the frontmatter precursor) is docs-only and rides CI's cheap docs-only leg. PR B wires the config (item 1) and runs the one-off `nix fmt` reflow, atomically. Splitting keeps the selection record and the bulk churn reviewable independently and lets the expensive reflow ride the cheap leg.

## Rationale

**Candidates weighed.** All three candidates ship a treefmt-nix module (`dprint.nix`, `prettier.nix`, `mdformat.nix`, all present at the pinned treefmt-nix rev), so architectural cost is equal — none needs a bespoke hook. The decision turns on the three forces:

| Candidate                    | Wrap control                                                                                                          | Hermetic/offline                                          | Churn character                                                                             | Verdict                                  |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ---------------------------------------- |
| **dprint** + markdown plugin | `textWrap:never` = exactly one line per paragraph — the repo's soft-wrap semantic                                     | Yes — `getPluginList` loads the local `.wasm`; no network | Prose reflow (intended) + table re-pad + emphasis unify to `*` (the measured 14:1 majority) | **Chosen**                               |
| Prettier                     | `proseWrap: preserve\|never\|always` — has `never`, but always renumbers ordered lists and rewrites list-marker style | Node-based; runs offline but heavier closure              | Reflows list markers + table pipes aggressively; more incidental churn                      | Rejected — noisier                       |
| mdformat                     | Conservative; `--wrap no` exists but GFM tables need plugins; default keeps `_` emphasis                              | Python; offline                                           | Least churn, but weakest GFM-table + wrap-config story; leaves emphasis on `_`              | Rejected — under-powered for this corpus |

Prettier meets wrap and hermetic, but its always-on list renumbering and marker rewriting inflate the reflow churn beyond the intended prose-reflow (force 1). mdformat is the most conservative, but its GFM-table handling needs a plugin stack and its default leaves emphasis on `_` — the opposite of the repo's majority, so it would churn the 5513, not the 383 (force 1 again). dprint wins on all three forces simultaneously: `textWrap:never` is the exact wrap semantic (force 3), the wasm plugin is store-local (force 2), and `asterisks` targets the minority marker for the minimal emphasis churn (force 1).

**Keep-convention (do nothing) is rejected** on #435's own mandate — an unenforced convention is precisely the problem #435 exists to fix.

**The measured evidence (not asserted):**

- **`textWrap:never` fidelity** — a fixture run on the pinned dprint 0.55.2 + markdown-plugin 0.20.0 collapsed a two-line paragraph to one line and left frontmatter, list items, table rows, and fenced code intact.
- **The 5513:383 asterisk ratio** — a repo-wide count of `*x*` vs `_x_` emphasis spans; `asterisks` churns the 383, the default would churn the 5513.
- **treefmt-nix module parity** — all three `.nix` modules are present at the pinned rev, so no candidate carries a bespoke-hook penalty.

## Frontmatter precursor and the census/design-note safety proof

**The one real hazard.** An ADR's `**Date**: …` line + newline + `**Status**: …` line is a single CommonMark paragraph (an intra-paragraph newline), so `textWrap:never` would **join them** into `**Date**: … **Status**: …` on one line. This affects the 45 real ADR headers (`docs/decisions/ADR-*.md`). Untreated, the reflow produces ugly joined headers.

**The precursor (PR A).** Move each joined `**Date**`/`**Status**` pair into a leading YAML frontmatter block:

```yaml
---
date: <value>
status: <value>
---
```

This is **values-only** — it mirrors each ADR's current inline values verbatim and invents no schema. A YAML frontmatter block is passed through untouched by dprint (runtime-verified: `textWrap:never` joined the surrounding prose while leaving the `---` block byte-identical). The header hazard therefore disappears before the reflow ever runs.

**#441 fence.** [#441](https://github.com/dannyfaris/nix-config/issues/441) owns the real frontmatter *convention* (the schema, required keys, the template). This precursor is expedient and mirror-only; it does **not** pre-decide #441. The two ADR-format *template examples* — the fenced `**Date**`/`**Status**` blocks inside `docs/decisions/README.md` and `docs/nix-config-prd.md` — are left as-is: they are documentation of the header shape, and reconciling that template to a frontmatter shape is #441's schema call, not this PR's.

**The lints stay safe (proven on fixtures).** Both `scripts/lint-host-census.sh` and `scripts/lint-design-note.sh` were re-run against reflowed fixtures:

- **Census lint** extracts host names from col-0-anchored list items. `textWrap:never` has nothing to reflow in a bullet (list items are not wrappable paragraphs), so both marked CLAUDE.md census regions extract the identical host set and all `CENSUS:` marker comments are byte-preserved.
- **Design-note lint** requires a `**Status:**` header and an ordered set of H2 sections. Each lives in its own blank-line-delimited block, which `never` leaves whole; the only effect on a note is cosmetic GFM-table pipe re-padding, which the parser ignores.

Both lints live in `checks-without-hosts` (exclusion-derived — no allowlist edit), so once dprint is wired (PR B) a reflow that broke a region would fail the census/design-note lint in the *same* CI run.

## Consequences

- ✓ The soft-wrap convention becomes mechanically enforced instead of a hand-authored habit — no more silent drift, no more mixed-wrap files.
- ✓ Enforcement reuses the existing treefmt seam: no bespoke hook, and the `treefmt` check already gates every PR including docs-only ones.
- ✓ The emphasis-marker inconsistency (`*` vs `_`) is resolved to the measured majority at minimal churn.
- ✓ The frontmatter precursor lands the ADR headers in a shape #441 can build the real schema on, without pre-empting it.
- ✗ One-time reflow churn touches most tracked `.md` files (PR B). Kept in its own commit for clean review; blame/bisect on prose is rarely load-bearing (workflow.md §"Markdown is soft-wrapped").
- ✗ Issue and PR *bodies* remain hand-authored soft-wrap — the formatter cannot reach `gh` descriptions, so the PR-template checkbox is reworded, not removed.
- ⚠ Migration trigger: if #441's chosen schema diverges from the `{ date, status }` shape used here, the 45 ADR frontmatter blocks are re-shaped under #441 — the precursor is deliberately minimal to keep that cost small.

## Rulings recorded (operator-settled in #435)

- **Formatter = dprint** with `textWrap:never` + `emphasisKind:asterisks`, hermetic wasm plugins; chosen over Prettier / mdformat / keep-convention on the measured churn evidence above.
- **Frontmatter precursor = values-only**, mirroring current inline values on the affected ADR headers; #441 owns the real schema.
- **Two PRs:** PR A docs-only (this ADR + prose retirement + precursor); PR B wires dprint and reflows atomically.
- **No `.git-blame-ignore-revs`.** No in-repo precedent, workflow.md de-rates prose-blame, and it is a separate convention decision (a committed file + per-clone `blame.ignoreRevsFile`, not fleet-synced) — declined as unrequested scope; a one-line follow-up if ever wanted.
- **dprint not in `systemPackages` / dev-shell.** A bare dprint is inert without the generated config; hand-runs route through `nix fmt`.

## References

- [#435](https://github.com/dannyfaris/nix-config/issues/435) — the decision record (formatter selection + reflow).
- [#441](https://github.com/dannyfaris/nix-config/issues/441) — YAML frontmatter convention; downstream owner of the frontmatter schema.
- [docs/workflow.md](../workflow.md) §"Markdown is soft-wrapped" — the convention this ADR mechanizes; its "no tree-wide reflow" reservation is reversed here.
- [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) — the proportionate-enforcement basis (lightest mechanism that holds the guarantee) for moving from PR-checkbox to formatter.
- [ADR-037](./ADR-037-doc-mutability-contracts.md) — why the retired convention prose is edited in place, not superseded.
