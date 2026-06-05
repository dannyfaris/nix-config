# nix-config Roadmap

Prioritised roadmap and task tracking. Completed milestones live in git
history and the ADRs under [docs/decisions/](./docs/decisions/); this
file tracks open work.

## Good → Great

Opinionated improvements surfaced by a maturity review (2026-05-26).
Each item names the cost of the current shape and what "great" looks
like; see git log for the full review.

### Trigger-driven

- [ ] **`_local-linux` mini-bundle** — bundle systemd-boot +
      NetworkManager + Tailscale, currently duplicated across
      `nixos-vm` and `metis`. **Trigger:** when `mothership` (a future
      Linux desktop host) lands and the duplication becomes fourfold.
      Don't pre-empt — per ADR-027 a bundle earns its place when ≥ 2
      hosts share the grouping under a coherent named capability.

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
      `.sops.yaml`; this is just the matching private key. Folded
      into [docs/runbooks/darwin-bootstrap.md](./docs/runbooks/darwin-bootstrap.md)
      step 4 — closes when mac-mini's first activation lands.

      ```sh
      mkdir -m 700 -p ~/.config/sops/age
      nix shell nixpkgs#ssh-to-age -c \
        ssh-to-age -private-key -i ~/.ssh/id_ed25519 \
                                -o ~/.config/sops/age/keys.txt
      chmod 600 ~/.config/sops/age/keys.txt
      ```

## Pending hosts

- [ ] **`mothership`** — second Linux desktop host. Pending hardware.
      Will compose foundation + bundles + standalone modules per
      ADR-027, reusing the `desktop-env` bundle landed for metis
      (ADR-028 + ADR-029: niri + foot + greetd; Stylix-driven for
      TUI/foot/GTK/Qt/niri-chrome; per-tool selections for launcher,
      notifications, status bar, browser, IDE via `docs/desktop/`).
      References: sodiboo/system (niri-flake idioms),
      eduardofuncao/nixferatu (Niri+Stylix end-to-end).
- [ ] **`mac-mini`** — macOS host via nix-darwin (epic #11). Darwin
      scaffolding landed in stages: `nix-darwin` input + flake
      plumbing (`parts/darwin.nix`, `lib/mk-darwin-host.nix`);
      `modules/darwin/` foundation + leaf modules (users, sops,
      firewall, sshd, nix-daemon-darwin, host-context,
      home-manager, stylix-palette); `modules/darwin/linux-builder.nix`
      (pending merge — see open PR list);
      `home/darwin/macchina-shell-init.nix`; the per-host palette
      entry in `lib/host-palettes.nix`. **Outstanding**: the host
      file itself (`hosts/mac-mini/default.nix` + `mkDarwinHost`
      invocation in `parts/darwin.nix`), and the operator-side
      pre-bootstrap + first `nix run nix-darwin -- switch --flake .#mac-mini`
      on the actual Mac. See [docs/runbooks/darwin-bootstrap.md](./docs/runbooks/darwin-bootstrap.md).
      Once activated, the host-list updates in CLAUDE.md / PRD §11.3
      and the project-memory "live fleet" entry follow as a sweep.
- [ ] **`mba`** — MacBook Air via nix-darwin. Follows mac-mini's
      bring-up; the Darwin scaffolding is shared. Filed as a
      placeholder once mac-mini's activation sequence is documented
      and any host-shape divergences (laptop power/lid, Wi-Fi-only
      networking) surface.

## Carryover when new hosts land

Small per-host onboarding checks and deferrals that surface as each
new host comes up.

- [ ] **`~/.gitconfig` precedence trap** (per ADR-009): a legacy
      `~/.gitconfig` from any pre-nix setup silently overrides
      `~/.config/git/config` (XDG, nix-managed) and defeats the
      gitdir-conditional work-identity. Verify the file does not exist,
      then confirm `git config user.email` inside `~/grey-st/<repo>`
      returns the work address, before declaring identity setup correct.
- [ ] **`home.sessionVariables` freshness**: a freshly-set env var
      from home-manager needs a *truly fresh* shell to land —
      `exec fish` inherits exported state from the parent and triggers
      `__HM_SESS_VARS_SOURCED`'s early-return. Disconnect+reconnect
      the ssh session for clean pickup.
- [ ] **SSH key generation** (per ADR-010): deferred because no
      non-git SSH-out workflow existed on the VM. Surfaces on hosts
      that need SSH-out beyond git (cloud control planes, host-to-host,
      etc.). Policy when generating: ed25519 + passphrase + ssh-agent;
      agent forwarding from Mac stays OFF.
- [ ] **OSC52 paste investigation** — nix-config side is correct;
      the Mac-side Ghostty likely has `clipboard-write = ask` as the
      default. Resolve once metis's desktop env lands (ADR-028) and the
      ghostty-to-ghostty round-trip can be exercised end-to-end. See
      ADR-011.

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
