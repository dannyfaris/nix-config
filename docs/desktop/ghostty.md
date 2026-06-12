# Ghostty

GPU-accelerated terminal emulator. macOS-only in this configuration;
foot is the chosen terminal on Linux desktop hosts (see
[foot.md](./foot.md)).

## Selection

**Ghostty** on `mac-mini` via Homebrew cask `ghostty`, declared in
`modules/darwin/homebrew.nix` per [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
clause 1 (upstream `pkgs.ghostty.meta.platforms` is Linux-only).
User config managed via home-manager at `home/darwin/ghostty.nix`.

Future Mac hosts (`mba`, a MacBook Air) inherit the same composition.

## Rationale

**GPU rendering earns its weight on macOS.** On a Mac terminal the
operator runs interactively — no compositor doing GPU work
underneath, so Ghostty's GPU pipeline is the only path to
high-refresh, low-latency rendering. ADR-028 §History 2026-05-28
recorded the inverse decision for Linux desktop (foot inside niri
needs no GPU layer of its own).

**Cask, not nixpkgs.** `pkgs.ghostty.meta.platforms` excludes all
Darwin systems (the upstream Linux-only restriction was also the
root cause of the terminfo gap previously tracked in #167, resolved
by PR #177 moving the terminfo derivation to `modules/nixos/`).
Cask is the only declarative path for Ghostty itself until upstream
nixpkgs gains Darwin support, at which point ADR-031 Migration
trigger 1 fires.

**The easy case for silent Sparkle updates.** Ghostty's cask
installs from a `.dmg` containing `Ghostty.app` directly (cask
declaration: `app "Ghostty.app"`); the Sparkle appcast at
`https://release.files.ghostty.org/appcast.xml` ships
`.zip`-enclosure archive updates carrying the `.app` bundle. Both
are archive-style enclosures of a non-sandboxed `.app` — Sparkle's
cleanest update path. No `.pkg` installer step, no
system-extension reinstall, no admin auth required at the Sparkle
layer. The macOS-level prompt surfaces in ADR-031 §Update mechanism
stance (Gatekeeper / TCC first-encounter, Mosyle policy) still
apply.

## Alternatives considered

**Hand-installed `.app` from ghostty.org** — the pre-#13 default;
zero declarative coverage; replaced by the cask.

**iTerm2 / kitty / wezterm** — viable Mac terminals. Passed over
because Ghostty was already the operator's choice; #13's question
was the install mechanism, not the terminal selection.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "ghostty" ];
```

**User config** — `home/darwin/ghostty.nix`:

```nix
{ lib, ... }: {
  programs.ghostty = {
    enable = true;
    # package=null tells HM to skip installing Ghostty into home.packages;
    # the cask owns the .app binary. HM still writes ~/.config/ghostty/config
    # regardless of the package value.
    package = null;
    settings = {
      # auto-update = "download" is the active source of truth at runtime.
      # Per Ghostty's Swift source (AppDelegate.swift §"Sync our auto-update
      # settings" + UpdateDelegate.swift §"Called when an update is scheduled
      # to install silently"), setting auto-update drives Sparkle's
      # SPUUpdater.automaticallyChecksForUpdates = true +
      # automaticallyDownloadsUpdates = true and triggers Sparkle's
      # willInstallUpdateOnQuit delegate hook. Result: silent install on
      # next quit.
      #
      # Note: Ghostty's published config docstring for auto-update = download
      # reads "do not automatically install" — inconsistent with the delegate
      # behaviour. Runtime wins today; the CustomUserPreferences Sparkle keys
      # in modules/darwin/homebrew.nix are a hedge against Ghostty fixing this
      # discrepancy in a future release (see §Sharp edges).
      auto-update = "download";
    };
  };
}
```

**Stylix theming** — `home/darwin/ghostty.nix`:

```nix
# palette (base16 ANSI slots) + Nerd Font family, the macOS parallel
# of foot on metis. Tracks polarity automatically.
stylix.targets.ghostty.enable = true;

# ...but keep Ghostty's own macOS default size, not Stylix's scaled one
programs.ghostty.settings.font-size = lib.mkForce 13;
```

The Stylix `ghostty` target writes the active base16 scheme into
Ghostty's 16 ANSI slots (`theme = "stylix"` + a generated
`themes.stylix` block covering background / foreground / cursor /
selection / palette) and sets `font-family` to the Stylix monospace +
emoji faces (`MonaspiceAr Nerd Font`, `Noto Color Emoji` — the faces
`modules/darwin/desktop-fonts.nix` installs system-wide, #209). The
palette tracks scheme + polarity flips with no extra wiring (#256).
(The target also writes `background-opacity = 1.0` from
`stylix.opacity.terminal`'s default — inert, since we don't set
opacity; it'll appear in the emitted config as a Stylix-owned line.)

**Font-size is pinned, deliberately.** The target also sets
`font-size = fonts.sizes.terminal * 4/3` (the macOS 72→96-DPI scale);
with Stylix's default terminal size (12) that lands at 16pt, larger
than Ghostty's own macOS default. We adopt the palette and font
*family* but keep the established size, so `lib.mkForce 13` overrides
the target's value (13 is Ghostty's documented macOS default).

**Placement.** The `enable` lives in `home/darwin/ghostty.nix`,
colocated with the rest of the Ghostty config, rather than in a
stylix-targets file. The cross-platform TUI whitelist
(`home/shared/stylix-targets.nix`) is deliberately terminal-free, and
the NixOS terminal target (foot) lives in the desktop-env home bundle
— which Darwin has no analogue of. One terminal, one Darwin-only
module: the toggle belongs with it.

**Sparkle silent-update keys (belt-and-braces, inert today)** —
`modules/darwin/homebrew.nix`:

```nix
system.defaults.CustomUserPreferences."com.mitchellh.ghostty" = {
  SUEnableAutomaticChecks = true;
  SUAutomaticallyUpdate = true;
};
```

These are *inert* while Ghostty's `auto-update` is set, because
Ghostty drives Sparkle's `automaticallyChecksForUpdates` and
`automaticallyDownloadsUpdates` properties at runtime, overriding
the user-defaults values. They persist on disk because Ghostty's
`Config.zig` explicitly documents the fallback: *"If unset, we defer
to Sparkle's default behavior, which respects the preference stored
in the standard user defaults."* If a future Ghostty release changes
`auto-update = "download"` to actually match its docstring ("do not
automatically install"), unsetting `auto-update` in the HM config
flips the active source of truth to the on-disk CustomUserPreferences
keys without further code changes.

## Update behaviour

**Default (this config):** Ghostty's `auto-update = "download"` is
the active source of truth — Ghostty drives Sparkle to download +
install silently on next quit, no operator action. Subject to
ADR-031's enumerated macOS-level surfaces (Gatekeeper / TCC
first-encounter; Mosyle policy if it enforces admin for
`/Applications/` writes).

**Fallback if Mosyle prompts on every Sparkle install:**

```nix
# home/darwin/ghostty.nix
programs.ghostty.settings.auto-update = "off";

# modules/darwin/homebrew.nix
system.defaults.CustomUserPreferences."com.mitchellh.ghostty" = {
  SUEnableAutomaticChecks = false;
  SUAutomaticallyUpdate = false;
};
```

The Ghostty config flip (`auto-update = "off"`) is what actually
takes effect at runtime — Ghostty drives
`automaticallyChecksForUpdates = false`. The Sparkle-key flips
are belt-and-braces for the same future-discrepancy reason as
above. Then update Ghostty manually as needed via
`brew update && brew upgrade --cask --greedy ghostty`. The
`brew update` prefix is required because `mutableTaps = false`
means brew doesn't refresh tap metadata otherwise. `--greedy` is
required because Ghostty's cask declares `auto_updates true` —
with Sparkle now disabled, brew is the only path left.

Verify the flip took effect:

```bash
cat ~/.config/ghostty/config | grep auto-update              # → auto-update = off
defaults read com.mitchellh.ghostty SUAutomaticallyUpdate    # → 0
defaults read com.mitchellh.ghostty SUEnableAutomaticChecks  # → 0
```

## Sharp edges

**Belt-and-braces, not combined.** Ghostty's `auto-update` knob
drives Sparkle at runtime, overriding the user-defaults values
that `system.defaults.CustomUserPreferences` writes. While
`auto-update` is set, the CustomUserPreferences Sparkle keys are
inert. They are kept on disk as a hedge against Ghostty fixing the
docstring/runtime discrepancy noted below.

**Config.zig docstring vs runtime discrepancy.** Ghostty's
published documentation for `auto-update = "download"` reads
*"do not automatically install"* — but the actual runtime
behaviour (per `UpdateDelegate.swift §"Called when an update is
scheduled to install silently"`) installs on quit. A future
Ghostty release that brings the runtime in line with the docstring
would break the silent-install path. Migration trigger if observed:
flip the active source of truth to the CustomUserPreferences
Sparkle keys (already on disk) by unsetting Ghostty's `auto-update`
in the HM config.

**Sparkle reads from the standard prefs domain, not byHost.** Plain
`system.defaults.CustomUserPreferences."com.mitchellh.ghostty"` is
the correct path; no `~/Library/Preferences/ByHost/` needed. Apps
that override Sparkle's `SUDefaultsDomain` to a non-standard
domain (rare) won't honour these keys at the standard path; check
the app's `Info.plist` for a `SUDefaultsDomain` entry before
assuming.

**Stylix font-size is overridden, not inherited.** The Stylix ghostty
target computes `font-size` from `stylix.fonts.sizes.terminal` (×4/3 on
macOS). `home/darwin/ghostty.nix` pins it with `lib.mkForce 13`, so
changing the Stylix terminal size will *not* move Ghostty's size on the
Mac — retune the `mkForce` value if that's wanted. The palette and font
family, by contrast, do follow Stylix automatically. See §Configuration
→ Stylix theming.

**Verification.** After `darwin-rebuild switch`:

```bash
# Ghostty config (the active source of truth):
cat ~/.config/ghostty/config | grep auto-update   # → auto-update = download

# Sparkle keys (inert today, hedge for future):
defaults read com.mitchellh.ghostty SUAutomaticallyUpdate    # → 1
defaults read com.mitchellh.ghostty SUEnableAutomaticChecks  # → 1

# Stylix theming (#256): base16 palette + Nerd Font, pinned size:
grep -E 'theme|font-family|font-size' ~/.config/ghostty/config
#   → theme = stylix
#   → font-family = MonaspiceAr Nerd Font
#   → font-family = Noto Color Emoji
#   → font-size = 13
# and the macchina palette row (#206) now shows base16, not Ghostty defaults.
```

(Run as `system.primaryUser`, or prefix with
`sudo --user=<primary-user> -- defaults read …` from a different
account.)

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) — boundary
  rule placing Ghostty on the Mac via cask under clause 1.
- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md)
  §History 2026-05-28 — original swap of Ghostty out for foot on
  Linux desktop; Ghostty retained for macOS clients.
- #167 / PR #177 — Ghostty terminfo / `pkgs.ghostty` Darwin gap;
  closed by moving terminfo to `modules/nixos/`. The upstream
  Linux-only `meta.platforms` for `pkgs.ghostty` itself remains.
- Ghostty `auto-update` config reference —
  https://ghostty.org/docs/config/reference#auto-update
- Sparkle customisation reference —
  https://sparkle-project.org/documentation/customization/
- Homebrew `ghostty` cask source (`.dmg` cask install,
  `auto_updates true`) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/g/ghostty.rb
- Ghostty Sparkle appcast (`.zip` enclosure confirmation) —
  https://release.files.ghostty.org/appcast.xml
