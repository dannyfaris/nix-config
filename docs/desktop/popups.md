# Floating popup windows (TUI utilities)

A reusable convention for launching small TUI/utility apps as floating, sized, centered popup windows on niri — so each new one (clipboard recall, and future scratchpad/picker-style tools) looks and behaves consistently instead of re-deciding window placement ad hoc. This is a cross-cutting convention doc (it spans tools), not a per-tool selection. It is forward-looking: the convention is defined here per the doc-before-code workflow, and [#99](https://github.com/dannyfaris/nix-config/issues/99) (clipboard history) is the first tool to apply it. Tracked as [#308](https://github.com/dannyfaris/nix-config/issues/308).

## Convention

A popup is any window whose `app-id` is `popup.<tool>`. A single niri `window-rule` matching that namespace owns the placement; each tool conforms by adopting the app-id. Adding a popup later is a mechanical application of the pattern, not a fresh decision.

- **Identity:** `app-id = popup.<tool>` (e.g. `popup.clipse`), stamped at launch by the spawning command (`foot --app-id=popup.clipse -e clipse`).
- **Match:** one `window-rule` matching the regex `^popup\.` (niri matches app-id anywhere in the string, so an anchored prefix namespaces cleanly).
- **Placement:** `open-floating = true` (force float), `open-focused = true` (summon takes focus), centered — niri centers new floating windows by default, so no explicit position is set.
- **Size:** proportional default (see below), overridable per-tool.
- **Model:** spawn-fresh — the window is created on each invocation, not hidden and re-shown (see "Spawn-fresh vs persistent-toggle").

Intended shape of the rule (to land with the first consumer, #99):

```nix
programs.niri.settings.window-rules = [
  {
    # Floating sized-popup convention for TUI utilities (#308).
    # Any window whose app-id is "popup.<tool>" opens as a centered,
    # proportionally-sized floating window. New popups conform by
    # adopting the app-id prefix; this rule is the single home for the
    # geometry. Per-tool deviation = a later, more specific rule.
    matches = [ { app-id = "^popup\\."; } ];
    open-floating = true;
    open-focused  = true;
    default-column-width.proportion  = 0.5;  # width  as a fraction of the screen
    default-window-height.proportion = 0.5;  # height — only applies to floating windows
    # centering: niri centers new floating windows by default — no position rule.
  }
];
```

The spawning command is inline at the keybind site for now (`foot --app-id=popup.<tool> -e <tool>`); there is deliberately no launcher-wrapper abstraction yet (see "Deferred: launcher wrapper").

## Sizing policy: proportional

The default size is **proportional** (`default-column-width.proportion` + `default-window-height.proportion`, starting at `0.5 × 0.5`), not fixed pixels.

The reasoning is that a proportion is *derived* from the display — it scales across whatever monitor metis drives and adapts to a future host — whereas a fixed pixel size is a constant guessed against one screen. The obvious precedent for fixed sizing is Omarchy's `875 × 600`, but that figure has no documented rationale anywhere — no inline comment, no commit message (every commit touching the line is a mechanical refactor or syntax migration), no issue or discussion. It is one person's taste fixed in pixels, so "match Omarchy" carries no engineering weight to inherit. Going proportional loses nothing and lets us actually document the *why* in one line, per the repo's one-comment-per-non-obvious-setting rule.

The specific fraction (`0.5`) is a starting default, not a tuned value — the right footprint is easier to feel than to spec, so it is tuned on real wear (same posture as the fuzzel layout defaults). A tool that wants a different footprint deviates with its own later, more specific `window-rule` (e.g. a wide system monitor, or a small calculator) — exactly how Omarchy carves out its un-centered Calculator exception. Both proportional and fixed-pixel overrides are natively expressible, so a per-app fixed size remains available where a proportion genuinely doesn't fit.

## Spawn-fresh vs persistent-toggle

There are two models for "summon a small floating utility window":

- **Spawn-fresh** — launch a new process each time; close it when done. Stateless, no daemon. (Our convention; also Omarchy's.)
- **Persistent-toggle** — keep the window alive and hidden, toggle its visibility (the scratchpad / drop-down-terminal lineage: i3/sway scratchpad, Hyprland + pyprland). Preserves in-process UI state and gives instant show/hide.

**Decision: spawn-fresh is the default; persistent-toggle is deferred with no current consumer.**

Toggle is the heavier abstraction *specifically on niri*, which has no native scratchpad. The maintainer deferred it to "on top of a future floating layer"; a native hide/show PR ([niri #2807](https://github.com/niri-wm/niri/pull/2807)) was closed in November 2025, and hidden workspaces ([niri #2997](https://github.com/niri-wm/niri/pull/2997)) remain an unmerged draft. So every toggle option today is third-party (a daemon such as [nirius](https://sr.ht/~tsdh/nirius/), or `niri msg` scripts), and all of them *leak*: with no hidden workspace, the "scratch"/"stash" workspace stays visible at the bottom of the workspace stack. Choosing toggle means setting precedent on thin ground and accepting a daemon plus a visible-workspace leak — only worth it for a genuinely state-in-process utility.

The first consumer does not need it. A clipboard-history TUI is the textbook case the toggle precedent points at, but [clipse](https://github.com/savedra1/clipse) specifically splits into a persistent **listener** (`clipse -listen`, writes all history to `clipboard_history.json` on disk) and a stateless **picker** (`clipse`, reads that file on launch). The valuable state lives on disk, written by the always-on listener; the picker holds only ephemeral UI state (scroll, filter, selection) that a recall workflow doesn't care to resume. So spawn-fresh is state-equivalent for clipse, and toggle would buy nothing for the leak and daemon it costs.

If a future popup genuinely holds meaningful state in-process, the sanctioned path is `nirius`' `focus-or-spawn` primitive (focuses an existing matching window or spawns it) as the low-cost middle ground — preserving state without committing to full hide/show or the workspace leak — adopted **per-tool**, not as the default. Until such a tool exists, no toggle machinery lands.

## Adding a new popup

1. Bind a key (in `home/nixos/niri.nix`) to `spawn = [ "foot" "--app-id=popup.<tool>" "-e" "<tool>" ]`.
2. Nothing else — the `^popup\.` rule already floats, focuses, centers, and sizes it.

Per-tool deviation (different size, anchored placement) = add a later `window-rule` matching the specific `app-id`; niri applies the last matching rule's non-null values, so the specific rule wins over the namespace default.

## Deferred: launcher wrapper

Omarchy routes popups through a wrapper (`omarchy-launch-tui`) that derives the app-id from the command name, guaranteeing every popup's identity conforms to the rule. We deliberately do **not** adopt this yet. A wrapper makes app-id conformance *structural* rather than *disciplinary* — worth it once enough bindsites exist that a hand-typed `--app-id` will eventually drift. At one or two popups the bind sits beside the rule and the discipline holds trivially, so a wrapper is premature abstraction (CLAUDE.md: "the lightest mechanism that holds the guarantee, escalating only on repeated evidence"). The escalation path is recorded so it can be adopted later without touching the rule; the app-id namespace and single rule are the durable part either way.

## Sharp edges

**niri bug #3420 — `default-floating-position` ignored under `open-floating`.** As of niri 25.11, combining `open-floating = true` with an explicit `default-floating-position` centered the window instead of honouring the position ([niri #3420](https://github.com/niri-wm/niri/issues/3420)). Harmless for this convention (we *want* centering), but it means anchored-and-floating placement is not reliable yet — verify against the pinned niri version before a per-tool rule relies on an anchor.

**niri has no native scratchpad, and emulations leak.** See "Spawn-fresh vs persistent-toggle". This is the reason the convention stays spawn-fresh; revisit only if niri lands a hidden-workspace / floating-layer feature.

**`xdg-terminal-exec` is not adopted.** Omarchy launches popups via `xdg-terminal-exec` for terminal-agnosticism. It is an unratified XDG proposal with best-effort backward-compat; for a single-operator declarative config, hardcoding `foot` is simpler and lower-maintenance. The indirection would only pay off to swap terminals fleet-wide, which we don't.

**`--app-id` reliability is a terminal property.** foot's `--app-id` is reliable; this is itself a reason not to abstract over terminals prematurely (other emulators have had `--class`/`--app-id` regressions). If a popup's rule mysteriously doesn't match, confirm the real app-id with `niri msg pick-window`.

**Overview visibility is not separately controllable.** Unlike Hyprland special-workspaces, niri has no per-window "hide from overview"; a floating popup appears in the Mod+O overview like any window. Recorded as a deliberate non-decision, not an omission.

## References

- [#308](https://github.com/dannyfaris/nix-config/issues/308) — this convention (intent, scope, prior-art research thread).
- [#99](https://github.com/dannyfaris/nix-config/issues/99) — clipboard history; first consumer of the convention.
- [niri.md](./niri.md) — compositor selection; window-rules are part of niri-flake's settings surface.
- [foot.md](./foot.md) — terminal the popups run in; `--app-id` is the identity lever.
- [keybinds.md](./keybinds.md) — where popup binds live in the modifier-namespace model.
- niri window rules — https://github.com/niri-wm/niri/wiki/Configuration:-Window-Rules
- niri floating windows — https://github.com/niri-wm/niri/wiki/Floating-Windows
- nirius (deferred toggle path) — https://sr.ht/~tsdh/nirius/
