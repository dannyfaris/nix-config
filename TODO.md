# nix-config Roadmap

Prioritised roadmap and task tracking. Completed milestones live in git
history and the ADRs under [docs/decisions/](./docs/decisions/); this
file tracks open work.

## Good → Great

Opinionated improvements surfaced by a maturity review (2026-05-26).
Each item names the cost of the current shape and what "great" looks
like; see git log for the full review.

### Do soon

- [ ] **`shared/` migration** — introduce `home/core/shared/` and
      `modules/core/shared/` and move modules that already satisfy the
      cross-platform contract (shell, prompt, direnv, multiplexer,
      editor, git*, cli-utils, agent-clis*, gh). Leaves `nixos/` for
      genuinely Linux-bound modules (macchina, nix-tooling NH_FLAKE).
      Closes the gap between PRD §5.1 and the tree on disk; gets
      strictly more expensive once `macos-workstation` lands. Pure
      rename + import-path refactor; `nix flake check` catches any
      mistake. **M, low risk.**
- [ ] **Fix `nrs` abbreviation** — `home/core/nixos/shell.nix:16`
      expands to `sudo nixos-rebuild switch`, contradicting `nh os switch`
      as the canon. Replace with `nos = "nh os switch"`. Trains muscle
      memory in the right direction. **S, low.**
- [ ] **Drop duplicated `system` arg from `lib/mk-host.nix`** — let
      `nixpkgs.hostPlatform` from `hardware-configuration.nix` carry
      the platform. The mk-host comment already telegraphs the refactor;
      removes a tripping hazard at 6+ hosts. **S, low.**
- [ ] **Delete superseded runbooks** —
      `docs/runbooks/headless-bootstrap-aws.md` and
      `headless-bootstrap-metis.md`. The ADR superseding rule exists
      because ADRs are referenced from code; runbooks aren't. Git
      history is the right archive. **S, low.**

### Trigger-driven

- [ ] **Promote `hostContext` to a typed module** —
      `options.hostContext = lib.mkOption {...}` with sensible defaults;
      `flakePath` becomes a default rather than a per-host literal.
      **Trigger:** 4th host *or* `shared/` migration landing —
      whichever comes first. ADR-019 names the ~5-field threshold;
      we're at 3.
- [ ] **`shared-purity` lint** — single `scripts/lint-shared-purity.sh`
      that greps `modules/core/shared/` and `home/core/shared/` for
      platform conditionals (`stdenv.isDarwin`, `pkgs.stdenv.isLinux`,
      etc.). Wired into `parts/checks.nix` via `git-hooks.nix` as an
      extra hook (framework now exists post-ADR-025). The other two
      lints PRD §8.1 named are moot: `role-purity` disappears with the
      role layer (planned ADR-027); `tier-deps` has nothing to enforce
      while `experimental/` is empty. **Trigger:** once `shared/` exists.
- [ ] **`_local-linux` mini-role** — bundle systemd-boot +
      NetworkManager + Tailscale, currently duplicated across
      `nixos-vm` and `metis`. **Trigger:** when `mothership` (the
      linux-workstation host) lands and the duplication becomes
      fourfold. Don't pre-empt; ADR-013 anticipates this exact
      pressure point.

## Bus-factor — sops decryption identity for the operator

Option A landed 2026-05-25 (operator's Mac SSH key added to
`.sops.yaml`; `secrets/secrets.yaml` re-keyed to all three recipients).
B below is a belt-and-braces extension.

- [ ] **Option B — VM host-key backup.** Store the VM's
      `/etc/ssh/ssh_host_ed25519_key` (and `.pub`) as a 1Password
      secure note. Lets the VM identity be restored on a fresh
      machine if both the VM disappears AND the Mac dies. Operator-
      only step. Cost: an out-of-band copy of a host identity that
      should ideally not leave the host.

### Follow-ups

- [ ] **One-shot, do once on the Mac**: install the age identity at
      `~/.config/sops/age/keys.txt` so the Mac can run `sops` /
      `sops updatekeys` directly. The recipient is already on
      `.sops.yaml`; this is just the matching private key:

      ```sh
      mkdir -m 700 -p ~/.config/sops/age
      nix shell nixpkgs#ssh-to-age -c \
        ssh-to-age -private-key -i ~/.ssh/id_ed25519 \
                                -o ~/.config/sops/age/keys.txt
      chmod 600 ~/.config/sops/age/keys.txt
      ```

- [ ] **Ergonomic follow-up**: extend `just setup-sops-identity` to
      take a positional `key-path` (defaulting to
      `/etc/ssh/ssh_host_ed25519_key` so the existing host-side flow
      is preserved). Then `just setup-sops-identity ~/.ssh/id_ed25519`
      replaces the one-shot above for future operator clones.

## Pending roles

- [ ] **`linux-workstation` role** — pending `mothership` hardware
      (x86_64 desktop). Recover desktop modules (niri + waybar +
      Stylix + fuzzel + ghostty + mako) from git tag
      `tier3-desktop-deferred`. The deferral is hardware-driven, not
      design-driven: niri requires `EGL_EXT_device_drm`, which UTM's
      Apple Virtualization Framework GPU does not expose. References:
      sodiboo/system (niri-flake idioms), eduardofuncao/nixferatu
      (Niri+Stylix end-to-end).
- [ ] **`macos-workstation` role** — design landed (PRD §3 +
      ADRs 013–016); no code yet. Will land on `mba` and `mac-mini`.

## Carryover when new hosts land

Small per-host onboarding checks and deferrals that surface as each
new host comes up.

- [ ] **`~/.gitconfig` precedence trap** (per ADR-009): a legacy
      `~/.gitconfig` from any pre-nix setup silently overrides
      `~/.config/git/config` (XDG, nix-managed) and defeats the
      gitdir-conditional work-identity. Verify the file does not exist
      before declaring identity setup correct.
- [ ] **`home.sessionVariables` freshness**: a freshly-set env var
      from home-manager needs a *truly fresh* shell to land —
      `exec fish` inherits exported state from the parent and triggers
      `__HM_SESS_VARS_SOURCED`'s early-return. Disconnect+reconnect
      the ssh/mosh session for clean pickup.
- [ ] **SSH key generation** (per ADR-010): deferred because no
      non-git SSH-out workflow existed on the VM. Surfaces on hosts
      that need SSH-out beyond git (cloud control planes, host-to-host,
      etc.). Policy when generating: ed25519 + passphrase + ssh-agent;
      agent forwarding from Mac stays OFF.
- [ ] **OSC52 paste investigation** — nix-config side is correct;
      the Mac-side Ghostty likely has `clipboard-write = ask` as the
      default. Resolve when `linux-workstation` lands with foot and
      the round-trip can be exercised end-to-end. See ADR-011.
- [ ] **`foot.terminfo` on headless hosts** — when
      `linux-workstation` lands and foot becomes the workstation
      terminal, add `pkgs.foot.terminfo` to
      `modules/core/nixos/system-packages.nix` (same pattern as the
      existing `ghostty.terminfo` line, additive). Ghostty terminfo
      stays — Mac client → headless hosts is still load-bearing.

## For future consideration

Considered, not currently pursuing. Listed so we don't reconsider from
scratch each time the question recurs.

- **atuin** (encrypted shell history with cross-machine sync). Killer
  feature would be unifying history across nixos-vm + mercury + metis
  (and future hosts). Not adopting because mercury is work-only by an
  explicit boundary (see `mercury_push_boundary.md` memory); syncing
  mercury's history into a personal stream crosses the same boundary
  in the opposite direction. A "nixos-vm + metis only" carve-out is
  the only safe shape and friction is small enough today that fzf
  Ctrl-R suffices. Revisit if (a) cross-host history recall becomes a
  real pain point, or (b) the work/personal host split changes shape.
  See ADR-006 "skipped tier with rationale".

- **1Password service-account tokens for sops** (Bus-factor Option C).
  Documented in ADR-018's "future direction" section. Bigger surgery
  than the current bus-factor gap warrants; revisit if 1Password
  becomes the root of trust for other reasons.
