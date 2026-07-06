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
  operator = import ./operator.nix;

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

  # SSH declared-edge stance (ADR-042) — the rendered authorizedKeys.keys
  # for the operator must equal, as a set, the keys the edge map derives
  # for this host. Deliberately keyed on config.networking.hostName, NOT
  # hostContext.hostName: the derivation in users.nix used hostContext, so
  # an independent hostname source keeps the check non-tautological and
  # also catches drift between the two hostname declarations. A host with
  # no sshEdges entry yields a violation string (via `or`), not an eval
  # throw — matching the file's `want` idiom. Platform-shared: both
  # platforms set the same option from the same edge data.
  sshEdges =
    config:
    let
      host = config.networking.hostName;
      want' = operator.sshEdges.${host} or null;
      have = config.users.users.${operator.name}.openssh.authorizedKeys.keys;
      # True set compare — order- AND multiplicity-insensitive (unique
      # before sort), so a one-sided dedup can't fire it spuriously:
      # trust-set membership is the stance, not list shape.
      asSet = xs: lib.sort (a: b: a < b) (lib.unique xs);
    in
    if want' == null then
      [ "sshd: host ${host} has no sshEdges entry (declared-edge whitelist, ADR-042)" ]
    else
      want (asSet have == asSet (map (src: operator.hostKeys.${src}) want'))
        "sshd: authorizedKeys for ${operator.name} on ${host} must equal the sshEdges-derived key set (ADR-042)";

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
  #
  # Guard is `== true`, not the bare value: unlike NixOS (where
  # `services.openssh.enable` defaults to `false`), nix-darwin leaves it
  # `null` on a host that doesn't import sshd (e.g. saturn, a client-only
  # laptop). `lib.optionals null` would throw — `== true` coerces the
  # tri-state to a Boolean so an sshd-less Darwin host is simply not in
  # scope (same intent as the NixOS helper above).
  sshDarwin =
    config:
    lib.optionals (config.services.openssh.enable == true) (
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
        # Exact-token match, not infix. `hasInfix "MaxAuthTries 3"` also
        # matched "MaxAuthTries 30" (#344); normalise each active line's
        # internal whitespace and compare for equality so "MaxAuthTries 3"
        # is the whole directive, not a prefix of it.
        normalize =
          l:
          lib.concatStringsSep " " (
            lib.filter (w: lib.isString w && w != "") (builtins.split "[[:space:]]+" (lib.trim l))
          );
        normalizedLines = map normalize activeLines;
        has = directive: lib.elem directive normalizedLines;
      in
      want (has "PasswordAuthentication no") "sshd: extraConfig must set PasswordAuthentication no"
      ++ want (has "PermitRootLogin no") "sshd: extraConfig must set PermitRootLogin no"
      # Operator whitelist specifically — sourced from operator.nix (as
      # modules/darwin/sshd.nix does), so a bare/different AllowUsers list
      # no longer satisfies the stance (#344).
      ++ want (has "AllowUsers ${operator.name}") "sshd: extraConfig must set AllowUsers ${operator.name} (operator whitelist)"
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
    ++ sshNixos config
    ++ sshEdges config;

  # Darwin omits the NixOS-only stances: `mutableUsers` (macOS owns user
  # creation) and `command-not-found` (option exists only on NixOS).
  darwin = config: shared config ++ sshDarwin config ++ sshEdges config;
}
