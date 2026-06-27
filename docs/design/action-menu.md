# The cross-platform action menu — registry-emitted action data and a per-platform renderer over it

**Status:** Proposed — design note (`docs/design/`). Build-state: sliced — slice 1 (the `actions.json` data contract: emitter, `packages.actions-json`, conformance lint, unit tests) is built; slice 2 (the renderer) is not yet designed. #437 (data) + #442 (renderer) · extends [ADR-039](../decisions/ADR-039-capability-registry.md) §Implementation steps 4–5 (consumes §2's descriptive dimension + §6's flat palette).

## Summary

The cross-platform action menu is one exercise with two halves — **where the action data lives** and **what paints it** — and this note covers both, delivered in slices. **Slice 1 (built):** the capability registry emits `actions.json`, a flat Nix-authoritative dataset projected from the registry and installed read-only, as the data home — keeping the action entries out of Noctalia's GUI-managed `settings.json`. Each host emits its own file from one shared schema; each entry carries resolved descriptive metadata, its display chord, and the registry's raw per-platform realization payload as *dispatch source* (`action` / `handler`, no typed execution contract). **Slice 2 (to design, #442):** a per-platform renderer (Noctalia launcher provider on Linux, `hs.chooser` on macOS) reads that file and paints a flat type-to-filter menu, turning the dispatch source into an actual invocation. Data and renderer share one loop because designing the contract without the consumer that shapes it is what produced this loop's hardest frictions.

## Motivation

The action menu is the missing "pillar 2" from the Omarchy benchmark (launcher-strategy.md §1) — a single keystroke to a searchable palette of system / session / window actions, which scrollable-tiling niri has no native analogue for. It is one exercise with two halves: the **data** (where the entries live, single-sourced from the registry) and the **renderer** (what paints them, per platform). This note covers both, built in deliberate sequence (ADR-039 §Impl steps 4→5): the data contract first — as the acid test of the runtime/declarative boundary — then the renderer over it.

The registry (ADR-039) already emits **config a tool owns and treats as read-only** — niri binds, Hammerspoon `hs.hotkey.bind` lines, the `keybinds.md` table region. The action menu (Epic C, #425) has no settled data home yet, and it is a *different* kind of emission: the first time the registry emits **data a runtime tool consumes** rather than a tool's own config. That makes it the acid test of the runtime/declarative boundary (Epic E, #427) the registry must honour before the keyboard-first interaction surface (#442) depends on it.

The obvious home — entries inside Noctalia — is a trap. [ADR-036](../decisions/ADR-036-noctalia-shell-linux-desktop.md) makes Noctalia's `settings.json` deliberately runtime/GUI-managed and *not* flake-reproducible. An action tree there would either fight that posture (two writers) or drift from the registry (hand-maintained in the GUI) — defeating the single-source point.

Concrete uses the dataset must serve: a Linux renderer (Noctalia launcher provider / `fuzzel --dmenu`) and a macOS renderer (`hs.chooser`) each reading the *same* contract; every entry both displaying its keybind (the cheatsheet half of ADR-039 §6's unified palette) and being invocable (the action half).

**Forces — what any design must honour:**

- **Single-source / no-drift.** The registry stays the one source; the dataset is a pure projection, never a second place to author entries.
- **Boundary honesty (the load-bearing force).** Nix-authoritative *data* must not live in GUI-managed runtime *state* (the ADR-036 trap). The writer is the flake; the reader is the renderer, read-only.
- **Faithful to the as-built schema, no forecast.** The registry is realization-typed and flat (ADR-039 §2/§6). The contract derives from that — it neither resurrects the superseded `command.{linux,darwin}` / `children` sketch, nor invents an execution abstraction ahead of the renderer that would consume it.
- **Share the contract, specialize the verbs.** One schema; per-host files whose dispatch source differs (cross-platform-action-menu.md §1).
- **Proportional enforcement (ADR-032).** Validate with the lightest mechanism that holds the guarantee.
- **Prove before depend.** The emit-a-runtime-file pattern and its boundary must be validated end-to-end before #442 builds a renderer on it.

These forces govern **slice 1**, the data contract. Slice 2's forces — cross-platform UX parity, the renderer staying runtime-installed (not Nix-pinned), the dispatch-execution path — are developed when that slice is designed.

## Design

### Slice 1 — the data contract (`actions.json`) *(built)*

`actions.json` is a projection of the registry: the **descriptive** dimension (resolved per-platform), the **chord** dimension (display form), and the **realization payload carried through verbatim** as the source a renderer dispatches from. A flat array (ADR-039 §6 — no hierarchy), one file per host, same schema. The Linux file:

```json
{
  "version": 1,
  "platform": "linux",
  "actions": [
    {
      "id": "spawn-terminal",
      "label": "Open terminal",
      "description": "Open a terminal window",
      "keywords": ["terminal", "shell", "console", "foot"],
      "chord": "Hyper+Return",
      "dispatch": { "action": { "spawn": "foot" } }
    },
    {
      "id": "focus-workspace-3",
      "label": "Focus workspace 3",
      "description": "Switch focus to the numbered workspace",
      "keywords": ["workspace", "desktop", "switch", "space"],
      "chord": "Hyper+3",
      "dispatch": { "action": { "focus-workspace": 3 } }
    }
  ]
}
```

The macOS file is the same schema, specialized — descriptive fields resolve through the platform override, and `dispatch` carries the handler name:

```json
{
  "id": "shrink-column",
  "label": "Shrink window width",
  "description": "Decrease the focused window's width",
  "keywords": ["resize", "shrink", "narrower", "width"],
  "chord": "Hyper+−",
  "dispatch": { "handler": "shrinkWindow" }
}
```

Field by field:

| Field | Source in the registry | Notes |
|---|---|---|
| `id` | `cap.id` | Stable key; unique within the file. |
| `label` / `description` / `keywords` | `descriptiveFor <platform> cap` | The exported per-platform-override → shared-default resolution the registry already provides for the palette/doc consumers — the `descriptiveFor` definition in `lib/capabilities.nix` notes it serves "the future palette/doc consumers (#442/#437)"; ADR-039 §2 is the frozen why. |
| `chord` | `tierChordDisplay cap.chord` | The friendly *tier* form (`Hyper+←`), identical to the `keybinds.md` table — the cheatsheet half of the unified palette. |
| `dispatch` | the platform's realization payload, verbatim | Carries the realization's payload under a field named for the realization: `action` (the niri-action attrset) or `handler` (the Hammerspoon handler name). **No `type` discriminator and no enum** — only realizations that actually emit appear, so there are no dead arms. The renderer reads the file's top-level `platform` and the present field; how it *executes* (a `niri msg` call, an in-process Lua call, an IPC envelope) is the renderer's to decide (#442), not pre-committed here. |

`dispatch` is the registry's realization **carried as source, not rendered as a command.** This is deliberate: the realization payload is authored as a niri-flake KDL bind value (it is what `niriBindsFor` feeds `programs.niri.settings.binds`), which is *not* the same grammar as a `niri msg action` invocation — pre-rendering that command is renderer-coupled and host-gated (see §De-risk and §Rationale). The contract carries the source faithfully and leaves the rendering to the consumer that can verify it.

**Inclusion rule:** an entry appears in platform P's file **iff the capability has a realization on P** (it is dispatchable) — the same filter the niri (`isNiriAction`) and Hammerspoon (`isHsHandler`) emitters already apply. Consequence, quantified in §De-risk: today the Linux file is all 37 `niri-action` caps; the macOS file is the 8 `hammerspoon-handler` caps only. **Digit families do not collapse** (unlike the `keybinds.md` table's `1‑9` row): each workspace is individually invocable, so each emits its own entry.

**Emission — per-host file, shared schema.** Each host's build resolves its own entries from the one registry: metis emits Linux, neptune macOS. The walking skeleton exposes the file as a per-system flake package (`packages.actions-json`), exactly as #457 exposes `packages.keybinds-table`, which is what the validation check builds and inspects. The concrete on-disk path the renderer reads is renderer-coupled and pinned when #442 lands; #437 settles that the path is flake-owned and read-only, not which directory.

**Validation — the acid test.** Mirrors the #457 harness, adapted from "doc region" to "data artifact":

- *Emitter* in `lib/capabilities.nix`: `actionsFor <platform> <registry>` (pure, parametrised for tests) + `actionsLinux` / `actionsDarwin`, rendered via `(pkgs.formats.json {}).generate`.
- *Unit tests* in `lib/tests/capabilities.nix` (the existing `lib.runTests` `lib-capabilities` check): descriptive override applied, chord rendered, `dispatch` carries the platform's realization payload verbatim, inclusion filter correct.
- *Conformance lint* in `parts/checks.nix`: a pure-eval `actionsContractFailures` list → `mkReportCheck` (parallel to `collisions`): required keys present, `dispatch` carries exactly the field expected for the file's platform, `chord` non-empty, `id` unique.

There is **no generate-and-diff check** as #457 has — `actions.json` is a build artifact, not a committed file, so nothing in-tree can drift. The boundary itself (read-only, flake-emitted) is enforced *structurally* (a store path cannot be mutated), not by a runtime assertion.

**Meeting the forces.** Single-source/no-drift and faithful-to-schema-no-forecast: the file is a pure `descriptiveFor`/`tierChordDisplay` projection plus the realization payload carried verbatim — no new authoring surface, no execution abstraction invented before its consumer. Boundary honesty: flake-written, read-only, never inside Noctalia's mutable state. Share-contract-specialize-verbs: one schema, per-host payloads. Proportional: an eval lint, not an external validator. Prove-before-depend: the emitter + tests + lint land now — and per ADR-037 / the design-loop's *co-locate-rule-with-enforcement*, the contract is not honest until that check exists (see §Drawbacks).

### Slice 2 — the renderer *(to design, #442)*

The renderer is this loop's next design phase, not specified here — it earns its own intent → options → de-risk pass. The scaffold of what it must do: read this host's `actions.json` read-only; present a flat, type-to-filter menu (ADR-039 §6 — the unified palette: action menu and keybind cheatsheet in one surface); and on selection turn the entry's `dispatch` source into a real invocation. Leading per-platform candidates from the research (cross-platform-action-menu.md, launcher-strategy.md §4): a **Noctalia launcher provider** (v4 `custom-commands`, or a v5 `readFile` plugin) on Linux and **`hs.chooser`** on macOS — fuzzel excluded (#385). The load-bearing question it must settle is the **dispatch-execution shape** — how a `dispatch` payload becomes a real `niri msg` call / in-process Lua call / IPC message — which is renderer-coupled and on-box-gated (§De-risk evidence), and is exactly why slice 1 carried the payload as source rather than pre-rendering it. The renderer choice, read path, and dispatch execution are this loop's open items (§Unresolved questions).

## De-risk evidence

Two load-bearing assumptions were tested **before** committing to this design.

**1. The registry has enough to emit `actions.json` with no new authoring surface, and it serializes cleanly per platform.** Tested by prototyping the full projection against the real registry (`lib/capabilities.nix` at `d550540`, eval on neptune/aarch64-darwin, `nix eval --impure --json`):

- Round-trips to valid JSON for both platforms. Descriptive overrides resolve (macOS shows "window" vocabulary, Linux "column"); `chord` renders the tier form; the realization payload carries through verbatim.
- **Counts: Linux 37, macOS 8.** Linux projects all 37 `niri-action` caps (19 base + 9 focus-workspace + 9 move-to-workspace). macOS projects only the 8 `hammerspoon-handler` caps (6 geometry + 2 spawn) — **none** of the directional-focus / move / workspace / Mission-Control entries, because those are bound by the hand-authored Karabiner *substrate*, which ADR-039 §4 says the registry does not yet own as a `karabiner-remap` realization. Confirms the inclusion rule is faithful to as-built and quantifies the macOS-thinness drawback below.

**2. The dispatch representation — refuted a typed execution envelope, before building it.** An earlier draft had `dispatch` carry a typed envelope (`{ "type": "niri-action", "action": {…} }`). Two independent adversarial reviews broke it, and their load-bearing claims verify against the code:

- The realization `action` payload is the **niri-flake KDL bind value** (`niriBindsFor` at `lib/capabilities.nix:793` feeds it to `programs.niri.settings.binds`), which is *not* the `niri msg action` CLI/IPC grammar — they are not 1:1 (leading-dash args need `--`, `spawn` is an array needing argv-splat + quoting). A typed envelope serializing the config payload pushes that grammar-reconstruction into every renderer, duplicated across bash/Luau/Lua — single-source inverted.
- A `dispatch.type` enum would ship with `karabiner-remap` and `menu/command` **emitted by nothing** (ADR-039 §2 lists them "not yet emitted") — a discriminated union forecast ahead of the consumer (#442) that would branch on it, the repo's named failure mode (design-loop §Motivation). The nearest prior art — the keybinds-table emitter in the same file — deliberately emits flat strings and **discards** the realization dimension.

The revision (carry the realization payload as *source*, no `type`, execution deferred to #442) is the direct response.

**Still unverified — slice 2's de-risk inputs, deliberately off slice 1's critical path:** (1) the `niri msg action` dispatch grammar — needs verification on **metis** (niri does not run on neptune, this host), and the dispatch *shape* is renderer-coupled (an in-process `hs.chooser` calls a Lua handler directly; an external renderer shells out); both are #442's to de-risk against a real renderer. (2) End-to-end renderer consumption — #442. (3) `(pkgs.formats.json {}).generate` vs `builtins.toJSON` — an implementation detail.

## Drawbacks

- **Slice 1 ships before its slice-2 consumer.** The data file no renderer reads until slice 2 — superficially the design-loop's named failure mode (abstraction ahead of implementation). Two things answer it: the build sequencing is deliberate (ADR-039 §Impl 4→5 — prove the boundary before the renderer depends on it), and per **co-locate-rule-with-enforcement / ADR-037** the contract is only honest once its check exists, so the emitter + conformance check *are* the enforcement the rule ships with (and the check is itself a consumer of the shape). With the renderer now in the same loop, the old cross-doc-boundary version of this risk is gone; what remains is ordinary staged delivery.
- **Carried payload no consumer reads yet.** Choosing (Q) over a descriptive-only file means `dispatch` carries the realization payload that nothing consumes until #442 — a small YAGNI residue, accepted so the file is a genuine *action* dataset rather than a cheatsheet-in-JSON.
- **The macOS acid test is shallow.** At 8 entries — all window-geometry/spawn, no navigation — the macOS file validates the *mechanism* but not a rich dataset. The pattern is proven thin on the platform where the registry is least complete.
- **A second emitter family to maintain.** Another projection in `lib/capabilities.nix` plus its tests and lint.

## Cost

The standing price is dataset coupling: every realization the registry gains (`karabiner-remap`, `menu/command`) must also flow through this emitter, and the macOS file stays thin until those land (#428). Acceptable — the same single-source coupling the niri/Hammerspoon emitters already carry — but "the action menu is sparse on macOS" is a real state of the world until then.

## Rationale & alternatives

- **Host entries in Noctalia `settings.json`.** Rejected — the ADR-036 trap; GUI-managed, not flake-reproducible, two writers. The force the note exists to honour.
- **A typed `dispatch` execution envelope** (`{ type, action/handler }`). Rejected after adversarial review (§De-risk): it serializes the niri *config-bind* grammar, not the dispatch grammar, so it pushes non-1:1 reconstruction into every renderer; its `type` enum ships dead arms; and it forecasts #442's branch structure — against the keybinds-table prior art, which discarded realization entirely.
- **Pre-render the dispatch command string in Nix** (e.g. `"niri msg action set-column-width -- -10%"`). Rejected *for #437*: the rendering is renderer-coupled (an in-process `hs.chooser` wants a call, not a string) and the `niri msg` grammar is unverifiable from this host (neptune; niri runs only on metis). Carrying the payload as source and rendering in #442 — on metis, against a real renderer — is the de-risked path. (This is the natural place the rendering logic lands later: once, in Nix, where niri-flake's types live.)
- **Single dual-platform file** (both platforms' entries, renderer filters). Rejected (operator's call): ships every host the other platform's verbs and pushes platform-selection into the renderer.
- **`command.{linux,darwin}` / `children` hierarchy** (cross-platform-action-menu.md sketch). Rejected — superseded by the as-built flat, realization-typed schema (ADR-039 §2/§6).
- **Descriptive + chord only, no dispatch payload.** Considered (purest YAGNI; an exact match to the keybinds-table prior art). Passed over for carrying the payload so `actions.json` is a real action dataset true to the issue's intent, not a cheatsheet duplicated into JSON.
- **Do nothing / fold the data home into #442.** Impact: #442 would invent a data home ad hoc under renderer pressure — most likely reaching straight for Noctalia GUI state (the trap) — and the boundary stays unproven. The acid test is the point.

## Prior art

Within the repo: the #457/#461 keybinds-table harness is the direct precedent — a registry emitter → fragment package → CI check → writer script — and the design-loop names it the live instance of "generate the reference from the source." This note adapts that harness from a *doc region* to a *data artifact* (dropping the diff-check, since nothing is committed). The same emitter is also the cautionary precedent against over-typing: it emits flat strings and discards the realization dimension, which is why this note carries the realization payload as opaque *source* rather than a typed execution contract.

Cross-platform option analysis lives in the research notes, not restated: [cross-platform-action-menu.md](../research/cross-platform-action-menu.md) (the share-contract/specialize-renderer principle, the per-platform emission sketch), [launcher-strategy.md](../research/launcher-strategy.md) §4 (Omarchy's `omarchy-menu` benchmark; renderer Option A/B), [noctalia-plugin-system.md](../research/noctalia-plugin-system.md) (the v5 `readFile` + `launcher_provider` lifecycle — the hook a Noctalia renderer would use to read this file).

## Unresolved questions

- **Slice 2 design (this loop's next iteration):** the per-platform renderer choice (Noctalia provider vs `hs.chooser`); the **dispatch-execution shape** (`niri msg` string / in-process Lua call / IPC), de-risked on **metis** against a real renderer; and the concrete read path the renderer reads `actions.json` from.
- **Slice 1 implementation details (resolved):** `(pkgs.formats.json {}).generate` chosen for rendering; the conformance lint landed as a `mkReportCheck` *and* live `lib.runTests` guards.
- **Out of scope (other issues):** `karabiner-remap` / `menu/command` realizations and the menu-only system / session / theme actions that use them (#428); the availability lint (ADR-039 §8); Noctalia theming posture (#406).

## Future possibilities

- **Descriptive-only cheatsheet entries on macOS** — projecting the navigation/workspace caps that have no realization (no `dispatch`) so the cheatsheet half is complete even where dispatch isn't wired, once #442 settles the action/cheatsheet split. (Deliberately out of scope now — committed to the realization-only inclusion rule for #437.)
- **Menu-only actions** (lock, power, theme-switch) entering the registry as `menu/command` realizations — the actions a user most wants in a menu, which the window-management-only skeleton does not yet carry.
- **`karabiner-remap` realizations** enriching the macOS file from 8 toward parity with Linux (#428).
- **A machine-readable JSON Schema** emitted as its own artifact, if an external consumer ever needs to validate the file independently.
