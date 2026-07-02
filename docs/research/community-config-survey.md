# Community config survey — patterns worth mining

Status: **research note, not a decision.** Captured 2026-07-02 from a three-batch systematic survey of 36 public NixOS / nix-darwin / blended configs, conducted via parallel deep-reads (38 agents, ~2M tokens). Repos were scouted first (flake.nix + tree); only those with novel patterns not already present in this fleet were deep-read. Nothing here is adopted; each item is a pattern to evaluate against our own principles. Feeds the active macOS theme-switching (#499), TUI colour conductor (#411), and any future hardening / CI work.

Batch 1 deep-reads: Misterio77/nix-config, nmasur/dotfiles, NotAShelf/nyx, fufexan/dotfiles, srid/nixos-config, kclejeune/system, ryan4yin/nix-config, malob/nixpkgs, cmacrae/config.
Batch 2 deep-reads: Aylur/dotfiles, isabelroses/dotfiles, pinpox/nixos, linyinfeng/dotfiles, EmergentMind/nix-config, sei40kr/dotfiles.
Batch 3 deep-reads: Mic92/dotfiles, viperML/dotfiles, TLATER/dotfiles.

Skipped as not novel (scouts): mitchellh/nixos-config, hlissner/dotfiles, LGUG2Z/nixos-config, dustinlyons/nixos-config, gvolpe/nix-config, truxnell/nix-config, sioodmy/dotfiles, berbiche/dotfiles, yuanw/nix-home, spikespaz/dotfiles, donovanglover/nix-config, Ruixi-rebirth/flakes, vimjoyer/nixconf, Frost-Phoenix/nixos-config, IogaMaster/dotfiles, rxyhn/yuki, librephoenix/nixos-config, moni-dz/nix-config.

---

## 1. Strategic verdict

**No single repo combines this fleet's full stack (flake-parts + foundation+bundles + Stylix + design tokens + capability registry + ADR cadence + eval-time stance assertions + sops + nix-homebrew + AeroSpace + Niri).** The move is the same as prior-art.md's conclusion: compose a small set of targeted references, don't adopt any config wholesale.

The survey produced three categories of actionable output:

1. **Direct drops** — one-to-five line additions that improve the fleet with no design work (§2 Darwin, §3 NixOS/Nix, §4 Claude Code).
2. **Design inputs** — patterns that inform in-flight issues without being drop-in adoptable (§5 open issues).
3. **Patterns to avoid** — temptations with a specific reason not to adopt (§8).

---

## 2. macOS / Darwin findings

### 2.1 `com.apple.spaces.spans-displays = 0` — AeroSpace correctness prerequisite

**Source:** isabelroses/dotfiles `modules/darwin/preferences/wm.nix`

AeroSpace requires per-display spaces. This is usually clicked during initial macOS setup and forgotten. Declaring it makes a future reinstall reproduce correctly:

```nix
system.defaults.CustomUserPreferences = {
  "com.apple.spaces"."spans-displays" = 0;
  "com.apple.WindowManager" = {
    EnableStandardClickToShowDesktop = 0;
    HideDesktop = 0;
  };
};
```

### 2.2 `~/.gitconfig` removal activation on Darwin

**Source:** isabelroses/dotfiles `home/isabel/git.nix`

macOS git and some tools write `~/.gitconfig`, which silently shadows the XDG config home-manager generates, making `programs.git` settings have no effect on Darwin:

```nix
home.activation.removeExistingGitconfig =
  lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f ~/.gitconfig
  '';
```

A practical onboarding trap for the first Darwin host.

### 2.3 Homebrew hardening

**Source:** isabelroses/dotfiles `modules/darwin/brew/`

Three independent additions, all compatible with nix-homebrew:

```nix
homebrew = {
  caskArgs.require_sha = true;      # refuse cask installs without a checksum
  onActivation.cleanup = "zap";     # remove unlisted formulae + their files on activation
};

environment.variables = {
  HOMEBREW_NO_ANALYTICS         = "1";
  HOMEBREW_NO_INSECURE_REDIRECT = "1";
};
```

`cleanup = "zap"` makes Homebrew state deterministic — what's declared is what exists, consistent with the fleet's whitelist > blanket stance. The environment variables are a zero-cost posture alignment.

### 2.4 NSGlobalDomain key-repeat settings

**Source:** hadal84/nix-darwin, grapefizz/dotfiles

Absent without these, holding `j` in vim does nothing after the first keypress:

```nix
NSGlobalDomain = {
  ApplePressAndHoldEnabled = false; # key repeat instead of accent picker
  InitialKeyRepeat = 15;
  KeyRepeat = 2;
};
```

### 2.5 NSGlobalDomain text substitution disable

**Source:** hadal84/nix-darwin

Fires in any native text field; smart quotes cause grief when pasting into terminals or code editors:

```nix
NSGlobalDomain = {
  NSAutomaticSpellingCorrectionEnabled = false;
  NSAutomaticQuoteSubstitutionEnabled  = false;
  NSAutomaticDashSubstitutionEnabled   = false;
};
```

### 2.6 Dock autohide tuning

**Source:** hadal84/nix-darwin

Companion knobs to the existing `autohide = true`:

```nix
dock = {
  autohide-delay         = 0.0;  # no hover-pause
  autohide-time-modifier = 0.5;  # animation speed in seconds
  mineffect              = "scale";
};
```

### 2.7 `.DS_Store` suppression on network / USB drives

**Source:** hadal84/nix-darwin

Prevents `.DS_Store` noise on shared filesystems and external-drive git repos:

```nix
CustomUserPreferences."com.apple.desktopservices" = {
  DontWriteNetworkStores = true;
  DontWriteUSBStores     = true;
};
```

### 2.8 Wallpaper as code via `home.activation` + `desktoppr`

**Source:** grapefizz/dotfiles

`pkgs.desktoppr` is in nixpkgs on aarch64-darwin (confirmed). Sets the wallpaper declaratively on `nh darwin switch`:

```nix
home.activation.setWallpaper =
  lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.desktoppr}/bin/desktoppr "$wallpaper_path"
  '';
```

Complementary to the runtime fan-out in #499: activation sets the wallpaper for the current theme on rebuild; the runtime script switches it live. Both paths use the same binary. See also the comment posted to #499.

### 2.9 macOS application firewall with stealth mode

**Source:** isabelroses/dotfiles `modules/darwin/security/firewall.nix`

```nix
networking.applicationFirewall = {
  enable           = true;
  blockAllIncoming = false;
  allowSignedApp   = false;
  allowSigned      = true;
  enableStealthMode = true; # ICMP / ping requests silently dropped
};
```

`blockAllIncoming = false` is permissive — would need deliberate review before tightening on an untrusted network.

### 2.10 macOS SSH client hardening

**Source:** isabelroses/dotfiles `home/isabel/ssh.nix`

The fleet has `knownHosts` wiring (see §3.1) but no home-manager SSH client hardening:

```nix
programs.ssh = {
  enableDefaultConfig = false;
  settings."*" = {
    forwardAgent    = false;
    addKeysToAgent  = "no";
    hashKnownHosts  = true;
    controlMaster   = "no";
    compression     = true;
  };
};
```

`forwardAgent = false` and `addKeysToAgent = "no"` prevent credential forwarding unless explicitly opted in per-host.

### 2.11 Touch ID sudo `reattach` — the missing half for tmux/Ghostty

**Source:** Mic92/dotfiles `darwinModules/sudo.nix`

Without `reattach`, Touch ID sudo breaks inside tmux/screen/iTerm because the PAM session is detached from the GUI agent. Most configs set `touchIdAuth = true` and wonder why it only works in the native macOS Terminal. Neptune already has `touchIdAuth = true`; the `reattach` line is the piece that makes it work in Ghostty/tmux:

```nix
security.pam.services.sudo_local.touchIdAuth = true;
security.pam.services.sudo_local.reattach    = true;
```

### 2.12 Darwin launchd gcroot cleanup daemon

**Source:** Mic92/dotfiles `darwinModules/nix-daemon.nix`

Neptune has no equivalent to the NixOS gcroot cleanup service. Dead symlinks in `/nix/var/nix/gcroots/auto` block collection indefinitely. A weekly launchd daemon covers three vectors: stale symlinks, stale temproots, and broken (dangling) symlinks:

```nix
launchd.daemons.nix-cleanup-gcroots = {
  script = ''
    set -eu
    ${pkgs.findutils}/bin/find /nix/var/nix/gcroots/auto /nix/var/nix/gcroots/per-user \
      -type l -mtime +30 -delete || true
    ${pkgs.findutils}/bin/find /nix/var/nix/temproots -type f -mtime +10 -delete || true
    ${pkgs.findutils}/bin/find /nix/var/nix/gcroots -xtype l -delete || true
  '';
  serviceConfig.StartCalendarInterval = [{ Weekday = 0; Hour = 3; Minute = 30; }];
};
```

### 2.13 SSH CA `certAuthority` wildcard knownHosts — scalable fleet trust store

**Source:** Mic92/dotfiles `darwinModules/openssh.nix`

Rather than committing per-host pubkeys (§3.1), register two CA trust entries with wildcard hostname patterns. New fleet hosts are trusted automatically once the CA signs their host certificate:

```nix
programs.ssh.knownHosts.ssh-ca = {
  certAuthority = true;
  hostNames     = [ "*.r" "*.i" "*.thalheim.io" ];
  publicKeyFile = ./ssh-ca.pub;
};
```

Lower priority for a four-host fleet but the right end-state as the fleet grows. The per-host pubkey approach in §3.1 is simpler for the current scale.

---

## 3. NixOS / Nix settings

### 3.1 Fleet-wide `knownHosts` from committed pubkeys

**Source:** Misterio77/nix-config

Commit each host's `ssh_host_ed25519_key.pub` and construct `programs.ssh.knownHosts` at eval time. Cross-host SSH from neptune → mercury/metis never gets a TOFU prompt:

```nix
programs.ssh.knownHosts = lib.genAttrs hosts (hostname: {
  publicKeyFile = ../../${hostname}/ssh_host_ed25519_key.pub;
  extraHostNames = [ "${hostname}.local" ]
    ++ lib.optional (hostname == config.networking.hostName) "localhost";
});
```

Also integrates cleanly with sops-nix host-key management — the same committed key drives both.

### 3.2 Nix access token injection via sops secret + `!include`

**Source:** EmergentMind/nix-config `modules/hosts/common/nix.nix`

Injects a GitHub PAT for `nix flake update` rate-limit avoidance without storing it in the Nix store:

```nix
nix.extraOptions =
  lib.optionalString (config ? "sops")
    "!include ${config.sops.secrets."tokens/nix-access-tokens".path}";
```

The secret file format is `extra-access-tokens = github.com=<PAT>`. The `config ? "sops"` guard prevents circular eval on hosts without sops.

### 3.3 `accept-flake-config = false`

**Source:** isabelroses/dotfiles `modules/base/nix/nix.nix`

Prevents a hostile flake from injecting trusted substituters or sandbox bypasses. Nearly every surveyed repo omits this:

```nix
nix.settings.accept-flake-config = false;
```

### 3.4 `nix.generateRegistryFromInputs` + `generateNixPathFromInputs`

**Source:** linyinfeng/dotfiles

Auto-populates the flake registry and `NIX_PATH` from flake inputs. Replaces the manual `nix.registry` and `nix.nixPath` boilerplate, makes `nix run nixpkgs#foo` use the pinned nixpkgs:

```nix
nix = {
  generateRegistryFromInputs = true;
  generateNixPathFromInputs   = true;
  linkInputs                  = true;
};
```

### 3.5 `min-free` / `max-free` GC thresholds + `fallback = true`

**Source:** EmergentMind/nix-config

`min-free`/`max-free` prevents out-of-disk build failures. `fallback = true` is appropriate for neptune when the binary cache is temporarily unreachable:

```nix
nix.settings = {
  min-free  = 128000000;   # 128MB — trigger reactive GC
  max-free  = 1000000000;  # 1GB cap
  fallback  = true;
};
```

### 3.6 `nix-daemon` in `minor.slice` with `CPUWeight = "idle"`

**Source:** linyinfeng/dotfiles

Prevents large builds from stealing CPU from interactive workloads on desktop hosts (metis):

```nix
systemd.services.nix-daemon.serviceConfig = {
  Slice     = "minor.slice";
  CPUWeight = "idle";
};
```

### 3.7 `hardenService` — reusable systemd hardening baseline

**Source:** NotAShelf/nyx

A library function applying `PrivateTmp`, `ProtectSystem=strict`, `NoNewPrivileges`, `MemoryDenyWriteExecute`, `RestrictNamespaces`, and a safe `SystemCallFilter` using `mkOptionDefault` — so individual services can still override any field. Useful for any custom systemd services on the fleet's Linux hosts.

### 3.8 `dbus-broker` switch hang workaround

**Source:** srid/nixos-config

Live bug as of July 2026: reloading dbus-broker during `nixos-rebuild switch` stalls because long-lived clients hold the bus:

```nix
systemd.services.dbus-broker.reloadIfChanged      = lib.mkForce false;
systemd.services.dbus-broker.restartIfChanged     = lib.mkForce false;
systemd.user.services.dbus-broker.reloadIfChanged  = lib.mkForce false;
systemd.user.services.dbus-broker.restartIfChanged = lib.mkForce false;
```

Goes in `modules/nixos/foundation.nix` with a comment pointing to the upstream issue; remove once resolved.

### 3.9 `system.configurationRevision = self.shortRev or self.dirtyShortRev or "dirty"`

**Source:** isabelroses/dotfiles `modules/base/system/revision.nix`

Makes the active git revision queryable at runtime. One line, zero cost.

### 3.10 Niri `block-out-from "screen-capture"` for credential managers

**Source:** EmergentMind/nix-config `home/common/optional/desktops/niri/rules.kdl`

Prevents credential manager windows appearing in screenshots or screencasts:

```
window-rule {
  match app-id="^org\.keepassxc\.KeePassXC$"
  block-out-from "screencast"
}
```

Zero coupling, drop-in addition to the niri config on metis.

### 3.11 `lock-secrets-before-suspend` systemd user service

**Source:** Mic92/dotfiles `nixosModules/niri/default.nix`

A `Before = sleep.target; WantedBy = sleep.target` oneshot service locks KWallet and rbw before the host suspends. Independent of desktop environment; applicable to metis:

```nix
systemd.user.services.lock-secrets-on-suspend = {
  description = "Lock secrets before suspend";
  before    = [ "sleep.target" ];
  wantedBy  = [ "sleep.target" ];
  serviceConfig = {
    Type      = "oneshot";
    ExecStart = pkgs.writeShellScript "lock-secrets" ''
      ${pkgs.libsecret}/bin/secret-tool lock --collection=kdewallet 2>/dev/null || true
      ${pkgs.rbw}/bin/rbw lock 2>/dev/null || true
    '';
  };
};
```

### 3.12 `SSH_ASKPASS` on pure-Wayland hosts (niri without xserver)

**Source:** Mic92/dotfiles `nixosModules/niri/default.nix`, TLATER/dotfiles

NixOS gates `programs.ssh.enableAskPassword` on `services.xserver.enable`. Niri hosts set `xserver.enable = false`, so NixOS exports `SSH_ASKPASS=""` — silently disabling SSH GUI password dialogs. Two opposed stances, both principled:

- **Mic92 (enable):** `programs.ssh.enableAskPassword = true; programs.ssh.askPassword = <wrapper>;` — restores GUI dialogs for SSH agent operations.
- **TLATER (disable):** `environment.extraInit = "unset SSH_ASKPASS";` — prevents any GUI from hijacking terminal SSH prompts; correct for hosts where SSH is driven from a terminal rather than a GUI agent.

For metis (primary SSH client via terminal): the TLATER approach (unset) is the right call. Note this in `modules/nixos/foundation.nix` if SSH_ASKPASS is ever a problem.

### 3.13 udev rule validation with `udevadm verify` in `checkPhase`

**Source:** TLATER/dotfiles `nixos-config/udev.nix`

A custom `services.udev.rules` option wraps each rule text in a `writeTextFile` derivation whose `checkPhase` runs `udevadm verify`. Syntactically invalid rules fail `nix build` rather than silently landing broken — consistent with the fleet's `lib/stances.nix` eval-check philosophy:

```nix
config.services.udev.packages = lib.mapAttrsToList (name: text:
  pkgs.writeTextFile {
    inherit name text;
    destination = "/lib/udev/rules.d/${name}";
    checkPhase = ''
      ${lib.getExe' pkgs.systemd "udevadm"} verify $out/lib/udev/rules.d/${name}
    '';
  }
) config.services.udev.rules;
```

Adopt if any fleet host gains udev rules.

### 3.14 Credential-to-env-var `preStart` for services that accept only inline credentials

**Source:** Mic92/dotfiles `nixosModules/fluent-bit.nix`

When a service accepts credentials only as inline values (not file paths), a `preStart` script reads the systemd credential and writes a `RuntimeDirectory`-backed `EnvironmentFile` with `umask 0077`. The secret never touches the Nix store or process argv:

```nix
systemd.services.<name>.serviceConfig = {
  LoadCredential  = "my-secret:${secretFile}";
  EnvironmentFile = "-/run/<name>/env";
};
systemd.services.<name>.preStart = ''
  umask 0077
  printf 'MY_SECRET=%s\n' "$(cat "$CREDENTIALS_DIRECTORY/my-secret")" \
    > /run/<name>/env
'';
```

Generalises to any service with a sops secret that must surface as an env var.

### 3.15 `nix-ld` + `envfs` with graphics-conditional library set

**Source:** Mic92/dotfiles `nixosModules/fhs-compat.nix`

Two-tier FHS compat: base ABI shim on all hosts, Wayland/Vulkan/GTK libraries only when `hardware.graphics.enable` is true. Uses an existing NixOS hardware signal rather than a hostname list:

```nix
programs.nix-ld.libraries =
  with pkgs; [ acl attr bzip2 dbus ... ]
  ++ lib.optionals (config.hardware.graphics.enable) [
    pipewire libxkbcommon mesa libdrm libglvnd gtk3 vulkan-loader ...
  ];
```

Relevant for metis if unpackaged Linux binaries (proprietary developer tools) are ever needed.

### 3.16 `angrr` — content-aware GC with path-regex policies

**Source:** TLATER/dotfiles `nixos-config/default.nix`

Standard `nix.gc` removes generations by age/count only. `angrr` adds per-path-regex policies — clean `.direnv/` entries after 14 days, `result` symlinks after 3 days, keep only the last 5 system profiles plus booted+current:

```nix
services.angrr.settings = {
  temporary-root-policies = {
    direnv = { path-regex = "/\\.direnv/"; period = "14d"; };
    result = { path-regex = "/result[^\\/]*$"; period = "3d"; };
  };
  profile-policies.system = {
    profile-paths  = [ "/nix/var/nix/profiles/system" ];
    keep-latest-n  = 5;
    keep-booted-system  = true;
    keep-current-system = true;
  };
};
```

Caveat: `angrr` is unstable-only. Use the `disabledModules` + explicit unstable import pattern (§3.17) if adopting before it lands in stable.

### 3.17 `disabledModules` + explicit unstable import for selective service upgrades

**Source:** TLATER/dotfiles

Rather than upgrading all of nixpkgs to unstable, disable a specific module from stable and re-import it from the unstable input:

```nix
disabledModules = [ "services/misc/angrr.nix" ];
imports = [ "${flake-inputs.nixpkgs-unstable}/nixos/modules/services/misc/angrr.nix" ];
```

Useful if any service needs unstable before the stable channel catches up.

### 3.18 Atuin cross-platform sync: systemd timer (Linux) + launchd agent (Darwin)

**Source:** Mic92/dotfiles

Canonical template for a `home/shared/` module that needs scheduled background work on both metis (Linux) and neptune (Darwin):

```nix
lib.mkMerge [
  (lib.mkIf pkgs.stdenv.isLinux {
    systemd.user.timers.atuin-sync.Timer.OnUnitActiveSec = "1h";
    systemd.user.services.atuin-sync.Service = {
      Type     = "oneshot";
      ExecStart = "${pkgs.atuin}/bin/atuin sync";
      IOSchedulingClass = "idle";
    };
  })
  (lib.mkIf pkgs.stdenv.isDarwin {
    launchd.agents.atuin-sync.config = {
      ProgramArguments = [ "${pkgs.atuin}/bin/atuin" "sync" ];
      StartInterval = 3600;
      ProcessType   = "Background";
    };
  })
]
```

### 3.19 Per-host nix binary-cache signing key sealed with `systemd-creds`

**Source:** TLATER/dotfiles `nixos-config/nix.nix`

Each host generates its own binary-cache signing keypair on first boot. The private key is immediately encrypted with `systemd-creds encrypt` (TPM2-bound if available) and stored in `/etc/credstore.encrypted/`; it never exists unencrypted at rest. The nix-daemon loads it via `LoadCredentialEncrypted`. Zero out-of-band secret distribution required.

Worth knowing for a future NixOS host that exports a binary cache; not immediately applicable to the current fleet.

### 3.20 `NoDisplay=true` desktop entry suppression

**Source:** TLATER/dotfiles

Suppresses or replaces a `.desktop` entry without rebuilding the package. Useful for hiding auto-generated launcher entries on metis's fuzzel surface:

```nix
xdg.dataFile."applications/emacs.desktop".text = ''
  [Desktop Entry]
  NoDisplay=true
'';
```

---

## 4. Claude Code configuration

### 4.1 `/nix/store` scan deny list

**Source:** srid/nixos-config

`rg`, `grep`, `find`, `fd`, `bfs` against `/nix*` can exhaust a session. Note: do **not** adopt `CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1"` from the same module — that conflicts with the fleet's memory system:

```nix
home.file.".claude/settings.json" = {
  force = true;
  text = builtins.toJSON {
    permissions.deny = [
      "Bash(bfs /nix*)"
      "Bash(grep * /nix*)"
      "Bash(rg * /nix*)"
      "Bash(find /nix*)"
      "Bash(fd * /nix*)"
    ];
  };
};
```

### 4.2 `git add .` / `git add -A` in deny list; `git push` in `ask`

**Source:** sei40kr/dotfiles `modules/home/claude-code.nix`

`git add .` can accidentally stage `.env` or secrets. `git push` affects the remote and is hard to reverse — the right tier is `ask`, not `allow`:

```nix
permissions = {
  deny = [ "Bash(git add .)" "Bash(git add -A)" ];
  ask  = [ "Bash(git push:*)" ];
};
```

The fleet's Claude Code permissions should be audited against this model.

### 4.3 Claude Code skills as derivation outputs

**Source:** Mic92/dotfiles `home-manager/modules/ai.nix`

Skills from a flake input land in `~/.claude/skills/` as nix-managed store paths via `home.file`:

```nix
home.file.".claude/skills/${name}".source = skillDerivation;
```

The repo already version-controls `.claude/` as shared infra; this extends that to skill installation, making skills reproducible and auditable as part of the home closure.

### 4.4 `CLAUDE.md` as a committed home dotfile with per-tool runtime instructions

**Source:** Mic92/dotfiles

They version-control a `home/.claude/CLAUDE.md` alongside the repo-root one, adding per-tool runtime guidance (e.g. "use `pueue` for commands >10s", "use `nix log` for build failures", "target `x86_64-linux` for NixOS tests on macOS"). The repo-root CLAUDE.md is the AI/contributor entry point; the home-dotfile layer adds host-operator specifics not shared with public contributors.

---

## 5. Active issues: #499 and #411

### 5.1 Ghostty native dual-theme — solves #499's Ghostty surface

**Source:** malob/nixpkgs, kclejeune/system

No shell scripting, no launchd agent. The macOS appearance signal drives the switch:

```nix
programs.ghostty.settings = {
  theme         = "light:light,dark:dark";
  window-theme  = "system";
};
programs.ghostty.themes = {
  light = <light-palette-derivation>;
  dark  = <dark-palette-derivation>;
};
```

The only Nix-side work is generating both a dark and a light palette variant from `lib/host-palettes.nix`. The mechanism is native Ghostty; this is almost certainly the right approach for #499's Ghostty surface.

### 5.2 Fan-out scripts list — composable theme-switch architecture for #499

**Source:** pinpox/nixos

Each app module appends its own polarity-switch script to a central list; the daemon invokes them all. Adding a new surface is a one-liner in the app's own module, not a change to a central script:

```nix
# each app module contributes:
pinpox.services.theme-switcher.scripts = [ "${appThemeSwitcher}" ];
```

This is the right composition model for #499: Ghostty, JankyBorders, wallpaper each append their hook independently.

### 5.3 Screen transition before theme swap

**Source:** linyinfeng/dotfiles `home-manager/profiles/niri/default.nix`

On NixOS/niri, firing `niri msg action do-screen-transition --delay-ms 500` *before* setting the theme animates the change rather than flashing it. The macOS parallel is triggering any transition animation before the `defaults write` call — worth designing into the #499 fan-out script ordering.

### 5.4 Pre-baked per-polarity colour strings for AeroSpace / JankyBorders

**Source:** pinpox/nixos `home-manager/modules/sway/default.nix`

Both polarity colour strings baked at Nix build time; the runtime script selects which to apply:

```nix
darkColors  = "active_color = 0xff${tokens.dark.focus.hex}; inactive_color = 0xff${tokens.dark.muted.hex};";
lightColors = "active_color = 0xff${tokens.light.focus.hex}; inactive_color = 0xff${tokens.light.muted.hex};";
```

For JankyBorders specifically: two store-path config files, one per polarity; the switcher rewrites the live path symlink and sends SIGHUP.

### 5.5 Fish `[light]`/`[dark]` .theme sections — removes Fish from #411's surface

**Source:** malob/nixpkgs

Fish 3.7+ auto-switches on OSC terminal background-change notifications. A `.theme` file with both sections, activated once at `home-manager switch`, means Fish self-manages when Ghostty flips:

```nix
xdg.configFile."fish/themes/my-theme.theme".text = ''
  [light]
  ${config.colors.myscheme.light.fishThemeSection}
  [dark]
  ${config.colors.myscheme.dark.fishThemeSection}
'';
```

### 5.6 bat `theme = "auto"` — removes bat from #411's surface

**Source:** malob/nixpkgs

bat 0.24+ supports automatic light/dark via OSC 11 terminal background query. Given both variants, bat self-manages:

```nix
programs.bat.config = {
  theme       = "auto";
  theme-dark  = "my-dark";
  theme-light = "my-light";
};
```

### 5.7 Foot colour slot names — direct reference for #411

**Source:** pinpox/nixos `home-manager/modules/foot/default.nix`

The exact foot config option names for wiring Stylix colours:

```nix
colors = {
  background = "${base00}";
  foreground = "${base05}";
  regular0   = "${base00}";  # black
  regular1   = "${base08}";  # red
  regular2   = "${base0B}";  # green
  regular3   = "${base0A}";  # yellow
  regular4   = "${base0D}";  # blue
  regular5   = "${base0E}";  # magenta
  regular6   = "${base0C}";  # cyan
  regular7   = "${base05}";  # white
  bright0    = "${base03}";  # bright black
  # ...bright1–7
};
```

### 5.8 Zellij theme slot names — direct reference for #411

**Source:** pinpox/nixos `home-manager/modules/zellij/default.nix`

The exact Zellij `themes.<name>` option shape:

```nix
programs.zellij.settings.themes.my-theme = {
  fg     = "#${base05}";
  bg     = "#${base00}";
  black  = "#${base00}";
  red    = "#${base08}";
  green  = "#${base0B}";
  yellow = "#${base0A}";
  blue   = "#${base0D}";
  magenta = "#${base0E}";
  cyan   = "#${base0C}";
  white  = "#${base05}";
  orange = "#${base09}";
};
```

### 5.9 `console.colors` — NixOS 16-slot array shape for #411

**Source:** isabelroses/dotfiles `modules/nixos/catppuccin.nix`

The exact NixOS option shape (16-element array in ANSI slot order):

```nix
console.colors = lib.mkIf themeEnabled [
  base00 base08 base0B base0A  # 0–3
  base0D base0E base0C base05  # 4–7
  base03 base08 base0B base0A  # 8–11 (bright)
  base0D base0E base0C base07  # 12–15
];
```

### 5.10 Stylix base16 → downstream semantic slot with `mkForce` — #411 plumbing pattern

**Source:** EmergentMind/nix-config `home/common/optional/desktops/noctalia.nix`

The exact plumbing pattern for wiring Stylix-derived values into a downstream tool that has its own defaults:

```nix
colors = {
  surface    = lib.mkForce "#${config.lib.stylix.colors.base00}";
  mOnSurface = lib.mkForce "#${config.lib.stylix.colors.base03}";
  mPrimary   = lib.mkForce "#${config.lib.stylix.colors.base02}";
  mError     = lib.mkForce "#${config.lib.stylix.colors.base08}";
};
```

### 5.11 No-default typed colorscheme registry — completeness guarantee

**Source:** sei40kr/dotfiles `modules/home/term-shared.nix`

Every field is required (no default). Adding a new colorscheme without populating every tool-alias entry fails Nix eval — you cannot add a theme without covering all surfaces:

```nix
colorschemeThemeType = lib.types.submodule {
  options = {
    kitty   = lib.mkOption { type = lib.types.str; }; # no default
    bat     = lib.mkOption { type = lib.types.str; };
    zellij  = lib.mkOption { type = lib.types.str; };
  };
};
```

Relevant to `lib/host-palettes.nix`: the tool-alias layer should consider the same no-default pattern so adding a new theme requires filling all slots.

### 5.12 Build-time GTK palette artefact injection via `overrideAttrs`

**Source:** AlexNabokikh/nix-config `modules/desktop/gtk.nix`

Generates a typed SCSS colour file from the palette at Nix build time and injects it into a package derivation via `overrideAttrs`. Not relevant to macOS directly, but demonstrates the pre-bake-at-build-time / inject-at-activation pattern relevant to #499's "provision all variants into the store" goal:

```nix
palette = pkgs.writeText "colors.scss" ''
  $lavender: ${catppuccinColor "lavender"};
  $base: ${catppuccinColor "base"};
'';
colloid-gtk-theme.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    cp ${palette} src/sass/_color-palette.scss
  '';
})
```

See also the comment posted to #411.

---

## 6. CI and testing patterns

### 6.1 Upstream-TODO CI check

**Source:** pinpox/nixos `.github/workflows/check-upstream-todos.yml`

Greps for `TODO` comments containing `github.com/*/pull/*` or `*/issues/*` URLs, queries the GitHub API, and fails if the referenced PR is merged or issue closed. The fleet accumulates upstream-workaround annotations; without this they rot silently. Requires a `public_repo:read`-scoped GitHub token in Actions secrets.

### 6.2 PR closure diff as auto-updated comment

**Source:** isabelroses/dotfiles `.github/workflows/diff.yml`

`lix-diff-action` dynamically discovers all `nixosConfigurations` and `darwinConfigurations`, builds before/after toplevels, and posts a closure diff as an auto-updated PR comment. Catches unexpected transitive additions before merge. Requires a Nix-enabled runner; doubles CI time.

### 6.3 Port-collision eval check

**Source:** isabelroses/dotfiles `modules/flake/checks/port-collector.nix`

Walks all declared service ports at eval time and fails `nix flake check` on conflicts. The same structural pattern as `lib/capabilities.nix`'s keybind collision lint, applied to service ports. Relevant if the fleet grows to host more services.

### 6.4 `lib.debug.runTests` unit-test harness for lib functions

**Source:** isabelroses/dotfiles `modules/flake/checks/lib.nix`

The fleet has `lib/stances.nix` for invariant assertions but no unit-test harness for helpers (`lib/theme-tokens.nix`, `lib/capabilities.nix`, `lib/host-palettes.nix`). `lib.debug.runTests` runs inside a `runCommandLocal` derivation so tests gate `nix flake check` with no network access:

```nix
let res = lib.debug.runTests {
  testHelperFn = {
    expr     = lib.myHelper { input = "x"; };
    expected = "x-out";
  };
};
in assert res == []; pkgs.runCommandLocal "lib-tests" {} "touch $out"
```

### 6.5 `flint --fail-if-multiple-versions` lockfile diamond-dep check

**Source:** TLATER/dotfiles `checks/default.nix`

Fails if any transitive flake input appears at more than one version despite `follows` declarations — catches the silent version mismatch between `nixpkgs` versions across inputs:

```nix
lockfile = checkLib.mkLint {
  name        = "nix-lockfile";
  fileset     = ../flake.lock;
  checkInputs = [ flint ];
  script      = "flint --fail-if-multiple-versions";
};
```

Compatible with the fleet's existing `parts/checks.nix` structure. Lightweight addition.

---

## 7. Library and composition patterns

### 7.1 `mkOutOfStoreSymlink` as a first-class escape hatch

**Source:** ryan4yin/nix-config, Aylur/dotfiles, kclejeune/system

For config files edited iteratively without a rebuild cycle:

```nix
xdg.configFile."aerospace/aerospace.toml".source =
  config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nix-config/home/darwin/aerospace.toml";
```

The AeroSpace TOML and niri KDL are both candidates — both are edited frequently during layout iteration. Trade-off: the file is no longer store-managed (no atomic activation, no rollback); suitable as a deliberate escape hatch, not a default.

### 7.2 Profile option with `readOnly = true`

**Source:** AlexNabokikh/nix-config `modules/profile/preferences.nix`

A single read-only `profile` option covering fonts, cursor theme, icon theme, and appearance makes every other module read from one typed, validated record. No module can accidentally shadow it. Comparable to the fleet's `hostContext` but covers the full appearance surface:

```nix
options.profile = lib.mkOption {
  readOnly = true;
  type = lib.types.submodule { options = { email = …; appearance = …; fonts = …; }; };
};
config.profile = { … single assignment … };
```

### 7.3 `_module.args.catppuccinColor` injection

**Source:** AlexNabokikh/nix-config `modules/catppuccin.nix`

Reads `palette.json` from the catppuccin flake at eval time via `builtins.fromJSON`, then injects a helper as a module arg. Every module calls `catppuccinColor "lavender"` directly — no explicit import:

```nix
_module.args.catppuccinColor = name: flavorColors.${name}.hex;
```

Conceptually similar to `lib/theme-tokens.nix` but injected automatically rather than imported. The injection mechanism is the learnable part.

### 7.4 Structured monitor registry with exactly-one-primary assertion

**Source:** EmergentMind/nix-config `modules/hosts/common/monitors.nix`, Misterio77/nix-config

A home-manager submodule for `monitors` (name, primary, width, height, refreshRate, scale, workspace) with an eval-time assertion:

```nix
config.assertions = [{
  assertion =
    (lib.length config.monitors == 0) ||
    (lib.length (lib.filter (m: m.primary) config.monitors) == 1);
  message = "Exactly one monitor must be set to primary.";
}];
```

Analogous to `lib/capabilities.nix` applied to display topology. Worth considering when neptune gains an external monitor or metis's kanshi config needs to be single-sourced.

### 7.5 `cssWithTheme` — Stylix base16 → CSS `@define-color` variables

**Source:** cmacrae/config

If any Darwin or NixOS surface needs hand-authored CSS, this bridges the Stylix token layer into CSS without per-property repetition:

```nix
cssWithTheme = file:
  lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: value: "@define-color ${name} #${value};") theme)
  + builtins.readFile file;
```

### 7.6 Pure-Nix hex-to-decimal colour helpers

**Source:** fufexan/dotfiles `lib/colors/`

For any surface where the colour conductor needs to emit CSS `rgba()` or do arithmetic on hex palette values:

```nix
hexToDec = v: …; # "ff" -> 255
rgba = c: "rgba(${r}, ${g}, ${b}, .5)";
xcolors = attrs: lib.mapAttrs (_: hexToDec) attrs;
```

### 7.7 `versionGate` — auto-yield a patched package when nixpkgs catches up

**Source:** viperML/dotfiles `misc/lib/default.nix`

An overlay package automatically becomes a no-op once nixpkgs ships the required version, instead of silently staying pinned:

```nix
versionGate = newPkg: stablePkg:
  if builtins.compareVersions (lib.getVersion newPkg) (lib.getVersion stablePkg) >= 0
  then newPkg
  else lib.warn "Package ${lib.getName newPkg} reached version..." stablePkg;
```

Directly applicable to the JankyBorders and AeroSpace overlay packages, which are currently maintained as custom derivations. Wire once; the overlay auto-retires when nixpkgs ships a sufficiently recent version.

### 7.8 Module-level assertions enforcing inter-module dependencies

**Source:** viperML/dotfiles `modules/nixos/ssh-server.nix`

The fleet's `lib/stances.nix` covers fleet-wide invariants. Module-level `assertions` are the per-module analogue — eval fails if a declared prerequisite is missing:

```nix
assertions = [{
  assertion   = config.services.tailscale.enable;
  description = "ssh-server.nix requires tailscale";
}];
```

Lightweight to add to any module that has a hard runtime dependency on another module being enabled.

---

## 8. Patterns to avoid

**Auto-discovery imports** (import-tree, haumea, blueprint, rakeLeaves, mkModuleTree, ez-configs, nixos-unified autoWire) — all trade explicit > implicit for convenience. The fleet's foundation+bundles model with deliberate imports is load-bearing for the "every addition must be a deliberate, endorsed choice" stance. Auto-discovery silently activates a module when a file lands in the right directory. Do not adopt.

**`allowUnfree = true` blanket** — confirmed across almost every surveyed repo. `lib/stances.nix` + `allowUnfreePredicate` whitelist is right.

**Ghostty `home-manager specialisations` for theme switching** — requires a full HM activation per theme flip. Conflicts with the instant-feedback expectation for appearance changes, and is fragile tooling. The native Ghostty `theme = "dark:...,light:..."` mechanism (§5.1) achieves the same goal without specialisations.

**`uvx mcp-nixos` or runtime PyPI fetch for MCP servers** — breaks reproducibility. MCP servers should be nixpkgs packages or flake inputs, not fetched at activation.

**`home-manager.backupFileExtension = "backup"` as a permanent setting** — silently renames conflicting dotfiles instead of surfacing the conflict. Acceptable as a one-off bootstrap measure on a new host, but should not be a permanent module setting.

**`mutableUsers` / `initialPassword`** — weaker posture than the fleet's `mutableUsers = false` stance (enforced by `lib/stances.nix`). Do not adopt.

**`accept-flake-config` left at default** (see §3.3) — a small but real attack surface; set it explicitly.

**Flat import lists without capability-bundle grouping** — all surveyed repos using flat lists lack the bundle model's explicit, auditable capability scope. Do not trade the bundle structure for flat-list convenience.

**nix-maid as a home-manager replacement (viperML)** — viperML's own tool with limited external adoption. The fleet is committed to home-manager as a NixOS module across all four hosts; migrating would be a large surface-area reversal with no community support and no payoff.

**npins + classic Nix instead of flakes (viperML)** — the fleet is fully flake-based with flake-parts. The viperML `importFilesToAttrs`/`dirToAttrs` helpers and `overlayVersion` with npins revision are workarounds for the non-flake world and do not translate.

**`security.sudo.enable = false` + polkit-only privilege escalation (viperML)** — removes sudo and replaces it with a polkit rule granting `wheel` full `manage-units`. Breaks `nh os switch`, `nixos-rebuild`, and the CLAUDE.md break-glass paths. The fleet's deliberate stance is key-only SSH + `wheel` sudoers, not polkit-only.

**`system.etc.overlay.enable` + `userborn` (Mic92)** — experimental NixOS features (overlayfs `/etc`, systemd-based user management). The fleet's `users.mutableUsers = false` stance is enforced by `lib/stances.nix`; its semantics against `userborn` are unverified. Worth watching, not adopting.

**`nohz_full` kernel tickless tuning (Mic92)** — only meaningful for specific latency-sensitive workloads on specific hardware (configured for a particular laptop's core layout). Adding fleet-wide without per-host profiling is cargo-culting.

**Hercules CI scheduled effects for automated package updates (Mic92)** — requires a self-hosted Hercules CI instance. The fleet uses GitHub Actions + `nix flake check`. Introducing a separate CI system contradicts the single-tool CI posture.

---

## 9. Open questions

- Does neptune's current `default.nix` set `com.apple.spaces.spans-displays = 0`? If not, is AeroSpace behaving correctly with multiple displays? (§2.1)
- Is `~/.gitconfig` silently shadowing home-manager's git config on neptune? (§2.2)
- Does `modules/darwin/touch-id.nix` set `reattach = true`? If not, does Touch ID sudo work inside Ghostty/tmux on neptune? (§2.11)
- Does the current CI surface closure growth to reviewers? If not, `lix-diff-action` addresses this. (§6.2)
- Does neptune have a `system.primaryUser` declaration? Required for nix-darwin 25.05+. (isabelroses — not catalogued above as it was a one-liner noted in the scout summary)
- Should `lib/host-palettes.nix`'s tool-alias layer use no-default options to enforce completeness? (§5.11)
- Are the JankyBorders and AeroSpace overlay packages candidates for `versionGate` wiring? (§7.7)
- Should Claude Code skills be installed as nix-managed store paths via `home.file` rather than manually? (§4.3)

---

This is a living research note (Refs, never Closes, per [workflow.md](../workflow.md)). Update as repos move or new references surface.
