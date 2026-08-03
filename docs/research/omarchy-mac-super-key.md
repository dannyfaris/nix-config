# Making the Super Key Behave Like macOS Command on NixOS + Niri + Noctalia v5: How Omarchy Does It and How to Port It

## TL;DR

- Omarchy does NOT use a remapping daemon for its Mac-like clipboard by default - it uses Hyprland's native `sendshortcut` dispatcher (`Super+C → Ctrl+Insert`, `Super+V → Shift+Insert`, `Super+X → Ctrl+X`) plus normal `bind` entries; the Ctrl+Insert/Shift+Insert trick is the clever bit that makes copy/paste work inside terminals without hijacking Ctrl+C's SIGINT.
- You CANNOT replicate this in Niri's config: Niri (Smithay-based, not wlroots) has no `sendshortcut`/`pass` equivalent, so an input-remapping daemon is mandatory. Use **xremap** (not keyd) - it has a dedicated, tested Niri client that reads the focused window's `app_id`, whereas keyd-application-mapper cannot see Wayland windows.
- Recommended split for this repo: adopt Omarchy's clipboard/app-command layer via xremap as a **user** service with `withNiri = true` — which converges with the repo's already-recorded plan (the reserved `Super+letter` layer in [keybinds.md](../desktop/keybinds.md), realized under #323). Two repo-specific corrections to the generic advice below: niri's `Mod` **is** `Super` and today carries live `Mod+letter`/`Mod+number` navigation binds, so **retiring/relocating those Super-namespace niri binds is a prerequisite** sequenced with the xremap layer — not "nothing to change"; and `Hyper` here is `Ctrl+Alt` produced by keyd at the evdev layer ([keyd.md](../desktop/keyd.md)), a separate substrate that stays. The immediately actionable piece is the **non-terminal (GUI) remap block**; the in-terminal copy/paste behaviour is an **open design fork** for #323, not a settled recommendation.

## Key Findings

### Mechanism (Omarchy)

Omarchy's "universal clipboard" is implemented entirely in Hyprland config, in `~/.local/share/omarchy/default/hypr/bindings/clipboard.conf`, sourced from `hyprland.conf`. The three core binds are, verbatim:

```
bindd = SUPER, C, Universal copy, sendshortcut, CTRL, Insert,
bindd = SUPER, V, Universal paste, sendshortcut, SHIFT, Insert,
bindd = SUPER, X, Universal cut, sendshortcut, CTRL, X,
bindd = SUPER CTRL, V, Clipboard manager, exec, omarchy-launch-walker -m clipboard
```

`sendshortcut` synthesises a keypress and sends it to the focused window. The genius is the choice of target chords: `Ctrl+Insert` (copy) and `Shift+Insert` (paste) are understood by GTK, Qt, Chromium/Electron, VTE terminals, and most X11/XWayland apps as copy/paste - and crucially they do NOT collide with Ctrl+C (SIGINT) in a terminal. So `Super+C` copies in a terminal without killing the running process. Cut uses plain `Ctrl+X` (there's no terminal collision to dodge), which is why the manual notes cut is "not in terminal". As the manual puts it: "Usually on Linux, you need Ctrl + Shift + C/V to copy'n'paste in the terminal and Ctrl + C/V to do it everywhere else. These Omarchy unified clipboard hotkeys work everywhere (except the file manager)."

Everything else Mac-like in Omarchy is a plain Hyprland `bind`:

- Window management (`Super+W` close, `Super+F` fullscreen, `Super+1-4` workspaces, `Super+Arrow` focus, etc.) - these are just Hyprland binds using SUPER as the hardcoded modifier.
- App launchers (`Super+Return` terminal, `Super+Shift+Return` browser, etc.).
- Notifications (`Super+comma` dismiss latest notification - note this is NOT "settings" in Omarchy).

Omarchy does NOT remap `Super+A` (select all), `Super+T` (new tab), or `Super+W` (close tab) to their Ctrl equivalents by default - `Super+W` is "close window" at the compositor level, and `Super+T` toggles tiling/floating. The Mac-style select-all / new-tab / close-tab / text-navigation remaps only exist in community guides. Discussion #3296 ("Give your PC a Cmd key (⌘)") layers extra `sendshortcut` binds such as `bindd = ALT, C, Universal copy (ALT), sendshortcut, CTRL, C,`, and the Chris Prinz Medium article ("Resurrecting a 12 year old Macbook with Omarchy Linux") adds text-navigation binds like `bindd = ALT, UP, Move to start of paragraph, sendshortcut, CTRL, UP,`. So "full Command-key parity" is a community add-on, not shipped Omarchy.

`$mainMod` is not used - SUPER is hardcoded throughout the defaults (Issues #1115, #1362), which is why community members who want to move window management off Super have to unbind extensively.

### macOS parity vs divergence (Omarchy's shipped behaviour)

Faithful to macOS:

- `Super+C/V` copy/paste works system-wide including terminals - the headline win.
- Clipboard history via `Super+Ctrl+V`.
- Super-driven window and workspace management feels Mac/`⌘`-adjacent.

Diverges / breaks:

- **File manager (Nautilus) and AI CLIs (OpenCode, Claude Code)**: the manual explicitly states these are the exceptions - "The two exceptions to this uniformity is the file manager (Nautilus) and AI Agent CLIs (OpenCode, Claude Code). There you'll unfortunately have to make do with Ctrl + C/X/V for clipboard operations." This is because the `sendshortcut` target chords aren't honoured by those apps.
- **`Super+X` cut does not work in terminals** (only `Ctrl+Insert`/`Shift+Insert` have terminal-safe equivalents; `Ctrl+X` in a shell is a readline/emacs prefix, not cut).
- **Stuck-modifier bug**: Hyprland Discussion #14099, titled "sendshortcut dispatcher leaves synthetic modifier key in pressed state, corrupting subsequent keyboard shortcuts" (reported on Hyprland v0.54.3), describes the `sendshortcut` dispatcher leaving a synthetic modifier key pressed, corrupting subsequent shortcuts - the reporter notes "Also after: Ctrl+C stops working in the affected terminal", with the only recovery being to toggle `hyprctl keyword input:kb_options "" && hyprctl keyword input:kb_options "compose:caps"`. Intermittent but real.
- **Select-all/new-tab/close-tab are NOT remapped** by default (see above).
- No `$mainMod`; hardcoded SUPER makes conflicts with app-level Super shortcuts common (Issues #2375, #1362).

### Why Niri changes everything

Niri deliberately has no mechanism to send synthetic keys to a focused window. The Niri maintainer confirmed in Discussion #1420 that there is no `pass`/`sendshortcut` equivalent: "Not atm. The global shortcuts portal will pave the way to this; for a niri-specific way it's not very clear to me how it should be represented in the config", explicitly contrasting with "In Hyprland there's pass and sendshortcut for sending keys to other apps." Niri binds can only run `spawn`/`spawn-sh` actions or internal compositor actions - they cannot inject `Ctrl+Insert` into the focused app. Therefore Omarchy's entire clipboard mechanism is non-portable to Niri's config, and you need a userspace evdev/uinput remapper.

### Daemon choice: xremap, decisively

- **keyd**: kernel-level, extremely low latency, trivial NixOS module (`services.keyd`), but `keyd-application-mapper` **cannot detect Wayland windows**. keyd Issue #694 ("keyd-application-mapper doesn't detect wayland?") reports, running keyd v2.4.3 under a KDE Plasma 6 Wayland session: "X detected... and no wayland windows are detected at all." The NixOS module also historically didn't wire up application-specific config properly (nixpkgs #241557). Global (non-app-aware) remaps work fine; app-aware remaps do not under Niri. This is disqualifying because you need app-awareness (terminal vs GUI vs Nautilus).
- **xremap**: evdev/uinput based, works on X11 and Wayland, and has a dedicated **Niri client** (cargo feature `niri`, maintained by @saurabhsharan per the README maintainers list) that reads the focused window's `app_id` via Niri's IPC socket (`$NIRI_SOCKET`) for `application: only:/not:` filters. The xremap nix-flake exposes `services.xremap.withNiri` and a `demo-niri-user` output; the maintainers' own test matrix marks Niri as tested-working in **User** service mode (and implemented-but-untested in System mode). (The Niri client and window-title matching have been present since well before the current release - the current release is xremap 0.15.9, with Niri prebuilt binaries dated 2026-06-01; I was unable to independently confirm the exact introduction versions, so treat any specific version attribution with caution and check the CHANGELOG if it matters.)

Confidence: high that xremap is the correct tool; high that it must run as a **user** service (so it inherits `$NIRI_SOCKET` from your graphical session).

## Details

### Recommended architecture for your setup

1. **Retire the Super-namespace niri *navigation* binds first (repo prerequisite).** Unlike the generic case this doc was first drafted for, `Hyper` and `Super` are *both* already in play here. `Hyper` = `Ctrl+Alt`, produced from Caps Lock by keyd at the evdev layer ([keyd.nix](../../modules/nixos/keyd.nix), [keyd.md](../desktop/keyd.md)) and generated onto niri's window-management binds from the capability registry (`lib/capabilities.nix`, [ADR-039](../decisions/ADR-039-capability-registry.md) / #384) — that layer stays. But niri's `Mod` **is** `Super`, and [home/nixos/niri.nix](../../home/nixos/niri.nix) today binds `Mod+←/↓/↑/→`, `Mod+H/J/K/L`, `Mod+1‑9`, `Mod+W`, `Mod+Return`, `Mod+Space`, `Mod+O` and the `Mod+Shift` screenshot family. The recorded plan (the niri.nix comments and #323) is that the Super-namespace **navigation** binds **retire** when the Super app-command layer lands: `Mod+arrows` and `Mod+H/J/K/L` vacate `Super+arrows`/`Super+letters` for the real remap consumers (text-nav line/document motions, app-command letters), while `Mod+1‑9` retires because workspace focus **consolidates onto `Hyper+1‑9`** ([keybinds.md](../desktop/keybinds.md)'s generated table), not to free `Super+number`. The binds keybinds.md deliberately keeps on `Super` stay (`Super+W` close-window, `Super+Return` terminal, `Super+Space` launcher, the `Super+Shift` screenshots). So the first chunk of work is relocating/retiring those niri navigation binds, sequenced before or with the xremap layer — *not* "leave Niri's binds alone".

2. **Do the clipboard/app-command remapping in xremap, not in Niri KDL.** Because Niri can't send synthetic keys, xremap becomes the single place where `Super+C → Ctrl+C` etc. live. This also means the remap is genuinely global (works in XWayland apps via app_id too).

3. **Layering direction: xremap rewrites *below* niri, not above it.** An earlier draft had this backwards — it claimed a niri bind on `Mod+C` "would consume the event before xremap's output matters". The opposite is true: xremap grabs the input devices at evdev (`EVIOCGRAB`) and re-emits synthetic events through `uinput`, *below* the compositor — so **xremap rewrites first and niri only ever sees xremap's output**, never the original chord. The consequence to design around: a generic xremap remap like `Super-w → Ctrl-w` would silently **break niri's `Mod+W` close-window bind**, because niri would receive `Ctrl+W`, not `Super+W`. This is exactly why [keybinds.md](../desktop/keybinds.md) keeps `Super+W` as the niri `close-window` WM action and **defers the `Ctrl+W` tab-close remap to #323** — `Super+W` belongs to niri, not to an xremap remap, in the current recorded design. Any `Super+letter` niri still binds (after the navigation retirement above) must be *excluded* from the xremap keymap, or xremap will shadow it.

### xremap key remaps (the Omarchy-equivalent layer)

xremap uses evdev, so it emits real key events that the focused app then interprets — and it can make that app-aware. The **settled, immediately-actionable layer is the non-terminal (GUI) remap**: outside the terminal, map `Super+C/V/X/A/…` → the `Ctrl+…` equivalent, matching the reserved `Super+letter` app-command namespace in [keybinds.md](../desktop/keybinds.md) (excluding the letters niri keeps, e.g. `W`). What happens *inside the terminal* is **not** settled — see the fork below.

You'll need to discover each app's `app_id` (run xremap with logging, or `niri msg windows`). Typical terminal app_ids: `Alacritty`, `com.mitchellh.ghostty`, `kitty`, `org.wezfurlong.wezterm`, `foot`.

### Terminal behaviour — open design fork (#323)

The repo has not decided how (or whether) `Super+C/V` should behave *inside the terminal*, and this doc deliberately does not pick a winner — it is a fork for #323 (into which the copy/paste ask, #356, was folded). Two coherent options:

**Option A — terminal carve-out (the repo's current recorded taxonomy).** [keybinds.md](../desktop/keybinds.md) *excludes* the `Super+letter` remaps in the terminal: there, `Ctrl+key` already means SIGINT / delete-word / flow-control, and the terminal handles its own copy/paste analogues (foot's `Ctrl+Shift+C`/`Ctrl+Shift+V`). Simple — no synthetic-chord machinery, no primary-vs-clipboard ambiguity. The real cost: `Super+C` does nothing in the terminal, so muscle memory forks between GUI (`Super+C`) and terminal (`Ctrl+Shift+C`) — the exact non-uniformity macOS users notice most.

**Option B — Omarchy-style SIGINT-safe in-terminal remap.** Mirror Omarchy: in the terminal map `Super+C → Ctrl+Insert`, `Super+V → Shift+Insert`, preserving `Ctrl+C`'s SIGINT for a uniform `Super+C` everywhere. But it does **not** work out-of-the-box on this repo's stack, for two concrete reasons:

- **foot is the repo's terminal, and foot is not VTE.** The Omarchy trick relies on `Ctrl+Insert`=copy / `Shift+Insert`=paste-clipboard, a GTK/VTE convention. Verified against `man foot.ini` on this host: foot's default `primary-paste` is `Shift+Insert`, which pastes the **primary selection, not the clipboard**, and foot has **no default `Ctrl+Insert` copy binding** (its clipboard defaults are `Ctrl+Shift+C`/`Ctrl+Shift+V`). So Option B needs explicit `foot.ini` key-binding additions (declarable via home-manager `programs.foot`) *and* a deliberate decision about **primary-vs-clipboard** semantics for `Shift+Insert`.
- **zellij sits between foot and the CLI, in legacy key-encoding.** The agentic panes run zellij inside foot with `support_kitty_keyboard_protocol = false` ([home/shared/multiplexer.nix](../../home/shared/multiplexer.nix)) — a load-bearing setting per #323's register row (do *not* naively re-enable it; legacy mode is the prerequisite for zellij catching a paste bind at all). Any in-terminal chord design must be **legacy-encoding-safe** and account for zellij intercepting/forwarding the chord on its way to the inner CLI.

Neither is adopted here; #323 owns the decision.

### NixOS configuration (declarative)

The snippet below is an **illustrative template**, not drop-in config: it embodies Option B's terminal block (which Option A omits), and it assumes the Super-namespace niri navigation binds have already been retired (§Recommended architecture). Read it as the xremap half of the keyd+xremap split, gated on the #323 fork.

Flake input:

```nix
# flake.nix
inputs.xremap.url = "github:xremap/nix-flake";
```

Home-Manager module (recommended - runs as a user service so `$NIRI_SOCKET` is visible):

```nix
# home.nix
imports = [ inputs.xremap.homeManagerModules.default ];

services.xremap = {
  withNiri = true;          # enables the Niri app_id client
  watch = true;             # auto-pick up new devices
  config = {
    modmap = [];
    keymap = [
      # Option B only (see §Terminal behaviour — open design fork): the
      # in-terminal SIGINT-safe block. Under Option A (the current taxonomy)
      # this whole block is omitted. As written it also needs foot.ini
      # key-binding additions — Ctrl+Insert/Shift+Insert are not foot defaults.
      {
        name = "Terminal clipboard (SIGINT-safe, Omarchy-style)";
        application.only = [
          "Alacritty"
          "com.mitchellh.ghostty"
          "kitty"
          "foot"
        ];
        remap = {
          "Super-c" = "Ctrl-Insert";   # copy, does not send SIGINT
          "Super-v" = "Shift-Insert";  # paste
          # deliberately NO Super-x in terminals (mirrors Omarchy)
        };
      }
      {
        name = "Everywhere-else clipboard + editing";
        # generic block LAST so specific overrides win
        application.not = [
          "Alacritty" "com.mitchellh.ghostty" "kitty" "foot"
          "org.gnome.Nautilus"    # leave Nautilus on Ctrl, like Omarchy
        ];
        remap = {
          "Super-c" = "Ctrl-c";
          "Super-v" = "Ctrl-v";
          "Super-x" = "Ctrl-x";
          "Super-a" = "Ctrl-a";   # select all (community add-on)
          "Super-z" = "Ctrl-z";
          "Super-s" = "Ctrl-s";
          "Super-t" = "Ctrl-t";   # new tab
          # NB: NO Super-w here — niri owns Mod+W as close-window (keybinds.md);
          # remapping Super-w → Ctrl-w at evdev would shadow it (see §Layering
          # direction; the Ctrl+W tab-close remap is deferred to #323).
          "Super-f" = "Ctrl-f";   # find
        };
      }
    ];
  };
};
```

Important ordering note: xremap applies the FIRST matching rule, so put the terminal-specific block before the generic `not:` block (as above). Add yourself to the `input`/`uinput` group and (via the flake) the udev rule so xremap runs without sudo. Set `serviceMode = "user"` (the flake default is `"system"`); User mode is the only combination the maintainers mark as tested-working for Niri, and it is required so xremap inherits `$NIRI_SOCKET` from your session.

The keyd+xremap division of labour is the repo's recorded design intent, not yet a running fact: keyd is **deployed today** and owns the substrate (Caps→`Hyper` = `Ctrl+Alt`) at evdev ([keyd.nix](../../modules/nixos/keyd.nix), [keyd.md](../desktop/keyd.md)); xremap is the **planned** app-aware `Super+letter` chord layer ([keybinds.md](../desktop/keybinds.md)) — it appears in no `.nix` file or `flake.lock` yet (Recommendation 1 adds it). Keep that division — pure key-position/substrate remaps in keyd, app-aware chord remaps in xremap.

### Niri KDL interactions

- The `Hyper` (`Ctrl+Alt`) window-management binds — generated from the registry — stay; they are a different modifier from `Super` and don't collide with the remaps.
- niri's `Mod` **is** `Super`. Because xremap rewrites below the compositor (§Layering direction), any surviving `Mod+letter` bind that overlaps a remapped `Super+letter` is either (a) a navigation bind that must **retire** in the Super-namespace retirement, or (b) a bind niri deliberately **keeps** (`Mod+W` close-window, `Mod+Return`, `Mod+Space`, the `Mod+Shift` screenshots) — in which case that letter must be **excluded** from the xremap keymap. Reconcile the two lists against [keybinds.md](../desktop/keybinds.md), not by assuming Super is unbound.
- Niri gotcha unrelated to xremap: key repeat can break with a too-minimal config unless an `input { keyboard { xkb {} } }` block is present (niri issue #357).

### Noctalia v5 interactions

Noctalia is a shell (bar/launcher/notifications/etc.), driven by IPC binds you place in Niri KDL. The v5 docs give binds such as `Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }`, `Mod+S { spawn-sh "noctalia msg panel-toggle control-center"; }`, and `Mod+Comma { spawn-sh "noctalia msg settings-toggle"; }`. These are `spawn-sh` binds and do not interact with xremap's clipboard remaps as long as they're not on the same chords. If you want `Super+comma` to open Noctalia settings (Mac `⌘,` = Preferences), bind it in Niri to the Noctalia IPC call rather than remapping it in xremap. Noctalia v5 is explicitly beta.

## Recommendations

1. **First**: retire/relocate the Super-namespace *navigation* binds in `home/nixos/niri.nix` (§Recommended architecture) — `Mod+arrows`/`Mod+H/J/K/L` vacate `Super+arrows`/`Super+letters` for the remaps, and `Mod+1‑9` folds into `Hyper+1‑9` — then add the xremap flake input and enable `services.xremap` via Home-Manager with `withNiri = true` and `serviceMode = "user"`. Start with **only the non-terminal (GUI) `Super→Ctrl` block** — excluding the letters niri keeps (`W`, …). Rebuild, log out/in, verify a GUI `Super+C` copies. **On-box, verify xremap's niri `app_id` detection actually fires** — the open verification gate #323 and keybinds.md both flag (set ≠ enforced; runtime-verify).
2. **Then**: Discover your actual terminal/editor app_ids (`niri msg windows` or xremap debug log) and correct the `application.only`/`.not` lists. Wrong app_ids are the #1 cause of "it doesn't work".
3. **Then**: Add the select-all/new-tab/find remaps to taste. Test Electron apps (VS Code, Discord) - if a specific app ignores the remap, add an app-specific override block or set the shortcut inside the app.
4. **Nautilus / GUI file managers** stay on `Ctrl` (Omarchy's documented exception; add them to `application.not`). The **terminal** case — including AI CLIs running inside foot/zellij — is **not** settled here: it is the open fork (§Terminal behaviour — open design fork). Don't hard-code Option B's `Ctrl+Insert` trick as if decided.
5. **Window management stays on `Hyper` (`Ctrl+Alt`), generated from the registry.** Don't import Omarchy's Super-based tiling binds — but note this is *not* "leave niri's Super binds alone": the repo's own Super-namespace *navigation* binds are being **retired** to clear the `Super+letter` space (§Recommended architecture).

Thresholds that change the recommendation:

- If xremap under Niri shows unacceptable latency or app_id detection flakiness for you, fall back to keyd for global (non-app-aware) `Super→Ctrl`-style remaps and accept the loss of the terminal-safe distinction (you'd then lose SIGINT-safe copy).
- If Niri gains a `sendshortcut`/global-shortcuts-portal mechanism (tracked upstream), you could move the clipboard layer into the compositor and drop the daemon.

## Caveats

- **This revision has been reconciled against the actual repo** (the original draft could not see it — that caveat is now retired). The corrections above reflect the live config: niri's `Mod`=`Super` with retiring navigation binds ([home/nixos/niri.nix](../../home/nixos/niri.nix)), `Hyper`=`Ctrl+Alt` via keyd ([keyd.nix](../../modules/nixos/keyd.nix)), foot's non-VTE defaults, and zellij's legacy-encoding constraint ([multiplexer.nix](../../home/shared/multiplexer.nix)). Still **unverified**: on-box behaviour (xremap niri `app_id` detection — the #323 gate) and the upstream claims flagged below (exact xremap version history, Noctalia v5 beta).
- App_ids must be verified on your machine; the ones listed are typical but not guaranteed. Also note Niri's own caution that app_ids are not unique (niri Discussion #1851), so a `only:` filter can match more windows than you expect.
- The Omarchy `sendshortcut` stuck-modifier bug is a Hyprland issue and does not affect the xremap approach, but xremap has its own edge cases (must run as user service, needs `$NIRI_SOCKET`).
- Niri's xremap "System" service mode is untested upstream; use User mode.
- Exact xremap version numbers for when Niri support / window-title matching landed could not be independently verified against the CHANGELOG; the current release (0.15.9) supports both. Re-check upstream if a precise version matters.
- Noctalia v5 is beta; IPC bind names may change.
- Search results for Omarchy and Noctalia go stale fast; the config paths and binds here reflect the current `master`/v5 docs at time of writing (August 2026) and should be re-checked against the live repo.
