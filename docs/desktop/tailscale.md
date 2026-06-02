# Tailscale

Mesh-VPN baseline on every host the operator uses interactively.

## Selection

**NixOS hosts** — `services.tailscale.enable = true` via
`modules/nixos/tailscale.nix` (see that file for the daemon /
firewall configuration; out of scope for #13's cask work).
Imported per-host by `hosts/metis/default.nix` and
`hosts/nixos-vm/default.nix`. `mercury` does not import it today
(headless work host; no Tailscale membership at present).

**Darwin hosts** — Homebrew cask `tailscale-app` (the Standalone
variant, NOT the MAS sandboxed build), declared in
`modules/darwin/homebrew.nix` per [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
clause 1 (`pkgs.tailscale` on Darwin ships only the daemon/CLI;
the `NetworkExtension`-grade GUI VPN is not in nixpkgs). Currently
managed on `mac-mini`; future Mac hosts (`mba`, a MacBook Air)
inherit.

## Rationale

Tailscale for macOS ships in two variants: the Standalone build
(`Tailscale-X.Y.Z-macos.pkg` from `pkgs.tailscale.com`, what the
cask installs) and the MAS sandboxed build (App Store). The cask
installs the Standalone; this section explains why.

**Standalone variant, not MAS.** The Standalone build has full
networking capability via `NetworkExtension` system extension. The
MAS variant is sandboxed and cannot provide equivalent networking.
Tailscale's own documentation restricts the Sparkle-based system
policies to the Standalone variant.

**Cask, not nixpkgs, on Darwin.** `pkgs.tailscale` on Darwin is
the daemon/CLI ("Node agent for Tailscale, a mesh VPN built on
WireGuard"). The macOS GUI `.app` is delivered as
`Tailscale-X.Y.Z-macos.pkg`, which registers the `NetworkExtension`
system extension via macOS's standard installer mechanism (the
cask's zap-trash listing includes
`io.tailscale.ipn.macos.network-extension`, which is what that
registration produces). A nix-built tarball cannot replicate that
registration without re-implementing the pkg's preinstall scripts
and running a privileged operation at activation. Cask is the only
declarative path for the GUI; ADR-031 Migration trigger 1 fires if
upstream nixpkgs gains a Darwin GUI build.

## Alternatives considered

**MAS Tailscale variant** — sandboxed; does not honour the
Sparkle-based system policies. Rejected.

**ZeroTier / WireGuard direct** — different mesh / VPN models.
Out of scope to switch; operator's mesh is already on Tailscale.

## Configuration

**NixOS side** — see `modules/nixos/tailscale.nix` (already in
place; not modified by #13).

**Darwin cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "tailscale-app" ];
```

**Sparkle silent-update keys** — same module:

```nix
system.defaults.CustomUserPreferences."io.tailscale.ipn.macsys" = {
  SUEnableAutomaticChecks = true;
  SUAutomaticallyUpdate = true;
};
```

Tailscale's "Customize Tailscale using system policies" KB documents
these exact keys and attributes them to Sparkle, restricted to the
Standalone variant.

## Update behaviour

**Default (this config):** Sparkle checks on its schedule. The
Sparkle appcast at `https://pkgs.tailscale.com/stable/appcast.xml`
ships `.zip`-enclosure updates with no `sparkle:installationType="package"`
attribute — Sparkle treats the archive as a standard `.app`-bundle
replacement, so the silent install path applies. Empirical:
confirm post-activation that updates do not surface authorization
prompts; if they do, the `.zip` is wrapping a `.pkg` payload and
falls into the package-installer bucket per ADR-031 §Investigation
guidance step 4.

Two additional surfaces are NOT covered by Sparkle silent install:

- **First-install `.pkg`.** The initial `brew install --cask tailscale-app`
  runs the Tailscale `.pkg` installer (registers the NetworkExtension
  system extension; macOS prompts for the system-extension grant).
  One-time per Mac.
- **Subsequent system-extension updates.** macOS may surface its
  own system-extension authorization prompt on each NetworkExtension
  update independently of Sparkle. Not suppressible from this
  layer; expect occasional Apple prompts even with Sparkle silent.

For the typical case (point releases not bumping the system
extension), Sparkle silent applies cleanly.

**Fallback if Mosyle prompts on every Sparkle install:** flip both
Sparkle keys above to `false`, then update manually via
`brew update && brew upgrade --cask --greedy tailscale-app` as
needed. The `brew update` prefix is required because
`mutableTaps = false` means brew doesn't refresh tap metadata
otherwise. `--greedy` required because the cask declares
`auto_updates true` — with Sparkle disabled, brew is the only
update path left.

## Cross-platform notes

NixOS hosts and Darwin hosts authenticate to the same tailnet but
via different login flows — `tailscale up --auth-key` (NixOS, CLI)
vs. browser auth via the GUI .app (Darwin). No shared device
identity; each host is approved separately in the tailnet admin
console.

## Sharp edges

**Bundle ID asymmetry.** The macOS app bundle ID is
`io.tailscale.ipn.macsys`; the pkg installer ID is
`com.tailscale.ipn.macsys`. Use the *app* bundle ID for everything
runtime (Sparkle keys, `defaults read`, NSUserDefaults). The
installer ID is only used by `pkgutil --pkg-info` and uninstall
flows.

**MAS variant silently ignores Sparkle keys.** If a future operator
installs the MAS Tailscale by mistake, the keys above are no-ops.
The cask-only declaration prevents this on managed hosts.

**System-extension prompts are not Sparkle's fault.** See §Update
behaviour above. If a NetworkExtension reinstall triggers an Apple
authorisation prompt, the fix isn't in this config — accept the
occasional prompt, or pin Tailscale to a known version (sidestepping
the trigger entirely).

**First-run auth flow is manual.** Tailscale's login completes via
browser; not automated by this configuration.

**Verification.** After `darwin-rebuild switch`:

```bash
defaults read io.tailscale.ipn.macsys SUAutomaticallyUpdate    # → 1
defaults read io.tailscale.ipn.macsys SUEnableAutomaticChecks  # → 1
```

(Run as `system.primaryUser`, or prefix with
`sudo --user=<primary-user> -- defaults read …` from a different
account.)

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) — boundary
  rule placing Tailscale on the Mac via cask under clause 1.
- Tailscale system policies KB —
  https://tailscale.com/docs/features/tailscale-system-policies
- Tailscale Sparkle appcast (`.zip`-enclosure confirmation) —
  https://pkgs.tailscale.com/stable/appcast.xml
- Sparkle customisation reference —
  https://sparkle-project.org/documentation/customization/
- Sparkle package-updates docs (`.pkg`-vs-`.zip` enclosure
  semantics) — https://sparkle-project.org/documentation/package-updates/
- Homebrew `tailscale-app` cask source (`.pkg` installer,
  `auto_updates true`, system-extension zap-trash) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/t/tailscale-app.rb
