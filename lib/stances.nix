# Machine-checkable assertions for the CLAUDE.md §"Deliberate stances —
# do not relax without asking" table. Each entry returns a list of
# human-legible violation strings for one evaluated host `config` — an
# empty list means every stance that host is subject to still holds.
# parts/checks.nix renders the list into a CI-gated derivation per host,
# so flipping a stance (e.g. `users.mutableUsers = true`) fails CI
# instead of building green and auto-merging. See ADR-033.
#
# Config-level, not behavioural: these prove a stance is *set* in the
# evaluated config — the fast (pure-eval, no VM), host-matrix-wide net.
# Proving the stance is *enforced at runtime* (sshd actually rejecting a
# password) needs a NixOS VM test, deliberately deferred per ADR-033.
#
# Platform split mirrors where each option exists: `mutableUsers` and
# `programs.command-not-found` are NixOS-only; the SSH posture lands via
# structured `settings.*` on NixOS but a free-form `extraConfig` text
# block on nix-darwin (see modules/{nixos,darwin}/sshd.nix). The
# nix-daemon stances (`warn-dirty`, the unfree whitelist) are shared.
{ lib }:
let
  # Record a violation message unless the condition holds.
  want = cond: msg: lib.optional (!cond) msg;

  # Shared across both platforms — set in modules/shared/nix-daemon.nix,
  # imported by both foundations.
  shared =
    config:
    want (
      config.nix.settings.warn-dirty or null == false
    ) "nix.settings.warn-dirty must be false (dirty-repo warning is noise)"
    ++ want (
      (config.nixpkgs.config.allowUnfree or false) == false
    ) "nixpkgs.config.allowUnfree must not be a blanket true — keep the allowUnfreePredicate whitelist"
    ++
      want (config.nixpkgs.config ? allowUnfreePredicate)
        "nixpkgs.config.allowUnfreePredicate must be set (the unfree whitelist that fails loudly on a new unfree package)";

  # SSH posture, NixOS shape — only asserted when the host runs sshd
  # (the stance is "if SSH is enabled, it is hardened"; a host without
  # sshd is not in scope and would otherwise trip on upstream defaults).
  sshNixos =
    config:
    lib.optionals config.services.openssh.enable (
      let
        s = config.services.openssh.settings;
      in
      want (s.PasswordAuthentication == false) "sshd: PasswordAuthentication must be false"
      ++ want (s.PermitRootLogin == "no") "sshd: PermitRootLogin must be \"no\""
      ++ want (s.AllowGroups == [ "wheel" ]) "sshd: AllowGroups must be [ \"wheel\" ] (account whitelist)"
      ++ want (s.MaxAuthTries == 3) "sshd: MaxAuthTries must be 3"
      ++ want (s.LoginGraceTime == "30s") "sshd: LoginGraceTime must be \"30s\""
    );

  # SSH posture, Darwin shape — nix-darwin's services.openssh is a thin
  # wrapper, so the hardening lives as text in `extraConfig` rather than
  # typed `settings.*`. Assert the required directives are present.
  sshDarwin =
    config:
    lib.optionals config.services.openssh.enable (
      let
        # Match against *active* directive lines only. A commented-out
        # directive (`# PasswordAuthentication no`) leaves the posture
        # weakened, so it must NOT satisfy the check — but its text still
        # contains the infix, which a raw `hasInfix` over the whole
        # extraConfig blob can't distinguish. Filter to non-comment,
        # non-blank lines first.
        activeLines = lib.filter (
          l:
          let
            t = lib.trim l;
          in
          t != "" && !(lib.hasPrefix "#" t)
        ) (lib.splitString "\n" config.services.openssh.extraConfig);
        has = directive: lib.any (l: lib.hasInfix directive l) activeLines;
      in
      want (has "PasswordAuthentication no") "sshd: extraConfig must set PasswordAuthentication no"
      ++ want (has "PermitRootLogin no") "sshd: extraConfig must set PermitRootLogin no"
      ++ want (has "AllowUsers ") "sshd: extraConfig must set an AllowUsers whitelist"
      ++ want (has "MaxAuthTries 3") "sshd: extraConfig must set MaxAuthTries 3"
      ++ want (has "LoginGraceTime 30s") "sshd: extraConfig must set LoginGraceTime 30s"
    );
in
{
  nixos =
    config:
    shared config
    ++ want (
      config.users.mutableUsers == false
    ) "users.mutableUsers must be false (this flake is the sole source of truth for user state)"
    ++
      want (config.programs.command-not-found.enable == false)
        "programs.command-not-found.enable must be false (flakes don't generate programs.sqlite; it silently fails)"
    ++ sshNixos config;

  # Darwin omits the NixOS-only stances: `mutableUsers` (macOS owns user
  # creation) and `command-not-found` (option exists only on NixOS).
  darwin = config: shared config ++ sshDarwin config;
}
