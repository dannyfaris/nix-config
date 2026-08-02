# Single source of truth for the operator identity. Imported via Nix
# `let`-binding (not NixOS option) — the option-layer pattern is reserved
# for `hostContext` where imports-evaluation-timing demands it; the
# operator record is plain data that any module needs at any phase.
#
# Consumed by (today):
#   - modules/nixos/users.nix         — user declaration + edge-derived
#                                       SSH keys (hostKeys/sshEdges, ADR-042)
#   - modules/nixos/networking-networkmanager.nix
#                                     — networkmanager group membership
#   - modules/nixos/home-manager.nix  — HM attr-name + homeDirectory
#   - modules/nixos/host-context.nix  — flakePath default
#   - modules/darwin/users.nix        — user declaration (subset managed
#                                       by nix-darwin) + edge-derived SSH keys
#   - modules/darwin/home-manager.nix — HM attr-name + homeDirectory
#   - modules/darwin/host-context.nix — flakePath default
#   - home/shared/ssh.nix             — fleet matchBlock User (#517)
#   - lib/stances.nix                 — AllowUsers whitelist + the
#                                       SSH-edges stance (hostKeys/sshEdges)
#
# The sibling `modules/darwin/users.nix` (listed above) consumes the
# same record with the `darwinHome` field. The deliberate split between
# `linuxHome` and `darwinHome` records the platform-rooted home location
# once; consumers pick the right one for their layer.
#
# Why a plain attrset and not a NixOS option: an option layer would
# require an `imports` evaluation timing dance for any module that wants
# to use it during its own imports — see `host-context.nix`'s comment
# block for the trap. An identity record is plain data; treating it as
# such avoids the trap by construction.
#
# Per #49.
{
  name = "dbf";
  description = "Daniel";

  # Platform-rooted home paths. Consumers pick the right one for the
  # layer they're in; the home-manager NixOS-module path uses linuxHome,
  # the Darwin equivalent (modules/darwin/home-manager.nix) uses darwinHome.
  linuxHome = "/home/dbf";
  darwinHome = "/Users/dbf"; # consumed by the Darwin users + home-manager modules

  # Flake checkout directory name, joined with the per-platform home to
  # produce the full filesystem path (e.g. /home/dbf/nix-config on Linux,
  # /Users/dbf/nix-config on Darwin). Drives the NH_FLAKE default in
  # `hostContext.flakePath`.
  flakeRepoDirname = "nix-config";

  # Fleet SSH trust as declared data (ADR-042): per-host user keys plus
  # the trust topology, derived per host into openssh.authorizedKeys.keys
  # by the system layer on each platform:
  #   - NixOS: modules/nixos/users.nix (renders /etc/ssh/authorized_keys.d/dbf).
  #   - Darwin: modules/darwin/users.nix (renders /etc/ssh/nix_authorized_keys.d/dbf,
  #     consumed by nix-darwin's AuthorizedKeysCommand drop-in).
  # Each derives its own list by looking up its hostContext.hostName in
  # sshEdges and mapping the named sources through hostKeys. The *why* of
  # the edge model (declared-edge whitelist over the flat any→any matrix)
  # lives in docs/design/fleet-ssh-identity.md; ADR-042 freezes it.
  #
  # hostKeys — one user key PER HOST (#524), each labelled with its origin:
  # generated on that host, private key never moves; a compromised host
  # revokes by deleting its one line. Per-host keys are passphrase-less
  # (operator-endorsed carve-out, ADR-010 §History). A backup key
  # (e.g. on a YubiKey) would append here rather than becoming parallel
  # state. Only enrolled hosts appear; the rest
  # enrol at their bootstrap events.
  hostKeys = {
    neptune = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEG7lLmu/lPjyPp1dW3QdA1UcPWi4+e/YEDxvj2UZaHW dbf@neptune";
    metis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1ho1kVtwsaB6ylZPzQfoWu9mJqA0gITxNEWpX5T9jT dbf@metis";
    alcyone = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICO05VMXeuyBNwKjN73V9zk81q9RYglnyLCLVg+aC+P5 dbf@alcyone";
    alnair = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJO5+tWeSk9j/1OZoa9x8Rvy5QuFt9Zso0kNcjbs5FKk dbf@alnair";
  };

  # sshEdges — destination host → the source hosts whose keys it accepts.
  # Every host that runs sshd (and saturn, pending its flip) needs an
  # entry: the derivation indexes this by hostName, so a missing host
  # throws at eval (whitelist, not silent-empty default — an absent edge
  # is a loud build failure, never a quietly keyless host). This is the
  # interim edge map toward the target topology (ADR-042; design note
  # §target shape) — self-edges are deliberately absent (no host SSHes
  # itself); saturn is empty until its destination flip (no sshd today).
  sshEdges = {
    metis = [
      "neptune"
      "alcyone"
      "alnair"
    ];
    neptune = [
      "metis"
      "alcyone"
      "alnair"
    ];
    saturn = [ ];
    # Alcyone (#631, ADR-042) — accepts neptune + alnair (saturn joins at
    # its destination flip); a workstation *source* into metis and
    # neptune since its fleet enrolment.
    alcyone = [
      "neptune"
      "alnair"
    ];
    # Alnair (#636, ADR-042) — roaming laptop: accepts the operator's
    # workstation sources alcyone + neptune (no metis edge, operator call);
    # a source into every active host since its fleet enrolment (operator
    # call — the laptop reaches the whole fleet from the road).
    alnair = [
      "alcyone"
      "neptune"
    ];
    # Electra (#637, ADR-042) — service-tier PURE sink: accepts the
    # operator's workstation sources (no metis edge, mirroring alnair's
    # call — metis exits via #387/#641), and never becomes a source — no
    # outbound key exists on the host at all (hosts/electra/default.nix).
    electra = [
      "alcyone"
      "alnair"
      "neptune"
    ];
  };

  # The operator's git identities — one record per identity, the single
  # source for the git author name/email AND the statusline account label
  # (#339, retiring the four literal sites: git-identity-{dual,work}.nix and
  # the two hardcoded emails in claude-statusline.sh's account case). The
  # `label` is the identity's short display name (metadata, not statusline-
  # specific presentation): "Personal" for personal code, "Grey St." (the
  # employer, Grey St) for work. Consumers:
  #   - home/shared/git-identity-dual.nix — personal default + the
  #     ~/grey-st/ gitdir-include (name + email of both).
  #   - home/shared/agent-clis.nix — generates the email→label map the
  #     Claude statusline sources (statusline-identities.sh).
  # The personal `name` is the GitHub handle (attribution is email-based, so
  # the name is cosmetic on commit logs); the work `name` is the real name
  # (employer convention on the work GitLab). See ADR-009, docs/identities.md.
  identities = {
    personal = {
      name = "dannyfaris";
      email = "daniel@faris.co.nz";
      label = "Personal";
    };
    work = {
      name = "Daniel Faris";
      email = "daniel.faris@gotaxi.co.nz";
      label = "Grey St.";
    };
  };
}
