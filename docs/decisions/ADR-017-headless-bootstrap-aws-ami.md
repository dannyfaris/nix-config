# ADR-017: Headless bootstrap path — AWS NixOS AMI

**Date**: 2026-05-18
**Status**: Accepted

## Context

PRD §11.3 and §12 left the bootstrap path for `headless` instances as a deferred decision, to be resolved when the first concrete instance was provisioned. The candidate approaches were (a) `nixos-anywhere` + `disko` from a rescue or kexec environment on a provider that doesn't ship NixOS images, and (b) a vendor-provided NixOS image where bootstrap reduces to clone-and-rebuild.

The first concrete instance is Mercury — a work-only dev box on AWS EC2 (Graviton, aarch64). AWS publishes official NixOS AMIs at https://nixos.github.io/amis/, covering both x86_64 and aarch64 across all regions and tracking both stable and unstable channels. The PRD's "bus-factor" success criterion (PRD §11.6 — another competent operator can rebuild in an afternoon) is a real consideration.

## Decision

Headless hosts on AWS bootstrap from the official NixOS AMI at https://nixos.github.io/amis/, combined with the `${modulesPath}/virtualisation/amazon-image.nix` module from nixpkgs. `nixos-anywhere` and `disko` are not used for AWS hosts. The AMI selection is done at provision time, picking the latest image that matches the flake's pinned nixpkgs channel and the host's target architecture and region.

The amazon-image module handles the platform-specific load: GRUB on the EBS root volume, EC2 metadata service for instance-id and SSH-key injection on first boot, cloud-init for hostname resolution, and host-key generation. The host directory's `hardware.nix` is therefore typically near-empty after first boot — just the `nixpkgs.hostPlatform` setting and whatever `nixos-generate-config --show-hardware-config` produces, which the amazon-image module subsumes most of.

This decision is scoped to AWS. The bootstrap path for headless hosts on other providers (Hetzner with their NixOS image, DigitalOcean/Vultr/Linode without one) is a separate question to resolve when one of those becomes the first concrete instance. `nixos-anywhere` + `disko` remains the assumed answer for providers without a NixOS image, but is not committed.

## Rationale

The path the AMI route avoids: building disko configurations, holding a working rescue or kexec environment in another tool, and the failure modes that come with kicking off a remote network installer from an SSH shell on a temporary base OS. With a NixOS AMI, the target system boots into NixOS on first start, host keys exist before the operator first SSHs in, and the first `nixos-rebuild switch` replaces the AMI's stock configuration with this flake's. Each step is a known operation rather than a one-shot bootstrap dance.

The cost is acceptable in the AWS case because the AMI is well-maintained — the nixos.github.io/amis index is the canonical publication channel for NixOS-on-AWS, kept current across releases and architectures. On a provider where no NixOS image exists, the calculus inverts and `nixos-anywhere` becomes the obvious choice; that's a per-provider call rather than a single rule for all headless hosts.

`disko` was considered for declarative disk layout but rejected for this slice: on EC2 the AMI ships a working EBS root configuration that the amazon-image module already knows about, and the value disko provides — disk-layout-as-code — pays off where the disks vary across machines, not on a standardised cloud platform where every instance gets the same EBS topology. If a future headless host has interesting storage (e.g. an additional encrypted volume), disko earns its keep then.

## Consequences

- ✓ Bootstrap reduces to: launch AMI → harvest host SSH key for sops → clone repo → `nixos-rebuild switch`. The non-obvious step (sops recipient onboarding) is documented in `docs/runbooks/headless-bootstrap-aws.md`.
- ✓ The bus-factor test holds for AWS hosts as soon as the runbook exists. Another competent operator with this repo + 1Password access (for the sops age key seed if relevant) can rebuild Mercury in an afternoon.
- ✓ No external tooling beyond standard `nix` and `aws` CLIs needs to be installed on the operator's machine.
- ✗ The decision doesn't generalise to non-AWS providers. Each new provider class will require its own ADR if the bootstrap path differs.
- ✗ The AMI's stateVersion needs to match the AMI's NixOS release on the host file. A drift between the AMI's release and the flake's nixpkgs channel doesn't immediately break things (nixos-rebuild from unstable against an older stateVersion is fine), but the operator has to pick the right value at provision time and document it. The runbook calls this out explicitly.
- ⚠ Migration trigger: if AWS withdraws or stops updating the official AMIs, the path collapses to `nixos-anywhere` from an Amazon Linux rescue instance — the same pattern this decision specifically avoids. Worth re-evaluating at that point. None currently anticipated.

## Implementation

The amazon-image module is imported in `hosts/<aws-host>/default.nix` via `"${modulesPath}/virtualisation/amazon-image.nix"`. Host-specific platform modules from the VM (`boot-systemd.nix`, `networking-networkmanager.nix`) are not imported on AWS hosts — amazon-image supplies the equivalents. The `hostContext.flakePath` and `hostContext.hostName` parameters (ADR-019) carry forward unchanged from the VM pattern.

The bootstrap runbook lives at `docs/runbooks/headless-bootstrap-aws.md` and is the canonical procedural reference; this ADR captures the why, not the how.
