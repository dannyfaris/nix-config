# ADR-009: Git — dual identity, HTTPS+token auth

**Date**: 2026-05-06
**Status**: Accepted

## Context

The user works on two distinct git ecosystems from this dev box:

- **Personal**, on GitHub, as `dannyfaris <daniel@faris.co.nz>`.
- **Work**, on GitLab.com, as `Daniel Faris <daniel.faris@gotaxi.co.nz>`
  (employer: GotaXi). Approved by employer policy to operate from this
  personal box.

Note the asymmetry in the **name** convention: personal commits use the
user's GitHub handle (`dannyfaris`) for visual consistency with their
GitHub profile; work commits use the user's real name (`Daniel Faris`) per
typical employer / GitLab conventions. Either convention is valid —
GitHub attribution is email-based, so the name is purely cosmetic on
commit logs. The two emails are what actually route each commit to the
right account.

The setup needs to:

1. Apply the right identity (name + email) per repo, automatically, without
   manual switching.
2. Authenticate to both GitHub and GitLab without friction.
3. Work seamlessly from agent-CLI contexts (Claude Code, Codex, etc.) where
   manual passphrase entry is hostile to the workflow.

## Decision

**Dual identity** via git's `includeIf` directive:

- Personal is the default identity, applied everywhere:
  `name = "dannyfaris"`, `email = "daniel@faris.co.nz"`.
- Work identity is applied automatically inside `~/work/` via a
  `gitdir:~/work/` conditional include, overriding **both** name and
  email: `name = "Daniel Faris"`, `email = "daniel.faris@gotaxi.co.nz"`.

**Auth is HTTPS + token-based**, with `gh` and `glab` registered as git
credential helpers — *not* SSH-key-based.

`programs.gh.settings.git_protocol = "https"` is set explicitly to ensure
gh produces HTTPS clone URLs (not SSH), making the credential-helper path
the only path used.

No SSH keys are generated or configured for git access. (See ADR-010 for
the broader SSH stance.)

## Rationale

### Dual identity via gitdir

Git's `includeIf` mechanism is the standard idiom for this. Anything
cloned/created under `~/work/` automatically picks up the work email; no
manual switching, no risk of accidentally committing personal email to a
work repo.

### Why HTTPS over SSH

The tradeoff between SSH-key git auth and HTTPS-token git auth is usually
flipped — SSH is "the nicer way" because once configured it just works.
On a headless dev box that runs agent CLIs (see [ADR-008](./ADR-008-agent-clis.md)),
the calculus reverses:

- **Encrypted SSH keys** create real friction. Agents run non-interactively;
  a `git push` that prompts for a passphrase is a workflow break. Even with
  ssh-agent, fresh shells (cron, systemd units, agents invoked from a new
  zellij pane before keys are loaded) fail. The four agent CLIs (Claude
  Code, Codex, Gemini, Cursor) are precisely the workflow that this would
  hurt — they invoke git on the user's behalf without ceremony.
- **Unencrypted SSH keys** would solve that, but at-rest plaintext keys on
  any box are a stance the user wants to avoid where possible.
- **HTTPS + token-based auth** sidesteps the issue entirely: gh and glab
  manage tokens internally, register themselves as git's HTTPS credential
  helpers, and the auth path works for interactive use, agents, cron, and
  any other context without ceremony.

Tokens are also more granular than SSH keys: per-token scopes, individual
revocation, expiry. This is a security improvement specific to git access,
not a downgrade.

### Why `git_protocol = "https"` is set explicitly

Current home-manager already defaults `programs.gh.settings.git_protocol`
to `"https"`, so cloning via `gh repo clone` produces HTTPS URLs without
this option. We set it anyway, for two reasons:

1. **Explicit-over-implicit** (philosophy.md). The HTTPS-only stance is
   load-bearing for the rest of the design (no SSH keys for git → no
   passphrase friction → agent CLIs work). Pinning the option makes the
   stance visible in config rather than relying on an upstream default
   that could shift in a future home-manager release.
2. **Belt-and-suspenders** against future home-manager schema changes.
   If the default ever flips, this config is unaffected.

The driver here is the broader auth model (HTTPS + token), not this one
flag. The flag is hygiene; the architecture is in the rest of the
section.

### What about glab?

glab handles the GitLab side, also via credential-helper integration. There
is **no `programs.glab.gitCredentialHelper` equivalent** to gh's home-manager
module, so the credential helper for gitlab.com must be wired manually
inside `programs.git.settings.credential."https://gitlab.com".helper`.

Why this matters: `glab auth login` writes its own glab config (in
`~/.config/glab-cli/`) and *then* tries to write a git credential helper
entry to `~/.config/git/config`. But under home-manager, that path is a
read-only symlink into the nix store. Without a pre-declared helper, glab
fails at startup with `could not lock config file ... Read-only file
system` — before it even prompts for the token.

With the helper declaratively in place, `git config` short-circuits when
glab tries to write the same value, and `glab auth login` completes
normally. Token persists in `~/.config/glab-cli/hosts.yml` after the
interactive flow (same compromise as gh — not declarative, but stable).

## Consequences

- ✓ No passphrase prompts ever in the git path; agent CLIs work without
  ceremony.
- ✓ Per-token scopes give finer-grained access control than SSH keys.
- ✓ Tokens can be revoked individually without disrupting other access.
- ✓ Auto-applied identity per directory; no possibility of cross-pollination.
- ✗ First-time `gh auth login` and `glab auth login` are interactive,
  not declarative. The token state lives in `~/.config/{gh,glab-cli}/`,
  outside nix's reach — same compromise that already exists for the
  existing `gh` setup.
- ✗ HTTPS clones are slightly slower than SSH for very large repos; not a
  concern for any repo this user works on.
- ⚠ Migration trigger: if a workplace requires SSH-only access (some do
  for security policy), the work side would need an SSH key. The
  symmetrical setup would still apply: HTTPS for github.com, SSH for
  gitlab.workco.com via a host-aliased SSH config — at which point ADR-010
  also revises.
- ⚠ Precedence trap on systems migrating from a pre-nix git setup: git
  reads `~/.config/git/config` (XDG, where home-manager writes) *first*,
  then `~/.gitconfig` (legacy) *after*, with later values overriding
  earlier ones. A stray `~/.gitconfig` silently overrides nix-managed
  values, including the gitdir conditional include. Verify the legacy
  file does not exist before declaring the identity setup correct. On
  the current host this manifested as `user.name` resolving to a stale
  legacy value and the work-email override not applying inside `~/work/`.

## Implementation

> **Update (post-ADR-020, 2026-05-18):** what was a single
> `modules/home/git.nix` has been split into four files to support
> work-only hosts cleanly: a shared base (`home/core/nixos/git.nix`)
> plus three per-host pieces (`git-identity-dual.nix`,
> `git-identity-work.nix`, `gh.nix`) selected per-host via
> `hostContext.extraHomeModules`. The mechanism is documented in
> ADR-020; the original single-file snippet below remains here as a
> historical reference for what ADR-009 originally specified, but is
> no longer the live shape.

Originally configured in `modules/home/git.nix` (single file, the
combined behaviour now distributed across `home/core/nixos/git.nix`
plus the per-host identity and forge-CLI pieces selected via
`hostContext.extraHomeModules` — `git-identity-dual.nix` + `gh.nix`
on the dual-identity UTM VM, `git-identity-work.nix` on Mercury):

```nix
{ lib, pkgs, ... }: {
  programs.git = {
    enable = true;

    # Personal default identity matches the user's GitHub handle
    # (dannyfaris) — GitHub attribution is email-based, not name-based,
    # so the name is purely cosmetic on commit logs. Under ~/work/ the
    # gitdir-include below overrides BOTH name and email to the work
    # identity ("Daniel Faris" / GotaXi email) so commits to the work
    # GitLab show the user's real name (employer convention).
    settings = {
      user = {
        name = "dannyfaris";
        email = "daniel@faris.co.nz";
      };

      init.defaultBranch = "main";
      pull.rebase = true;

      # glab as git credential helper for gitlab.com — wired declaratively
      # because there's no programs.glab.gitCredentialHelper equivalent
      # to gh's. Without this, glab auth login fails trying to write the
      # read-only nix-managed git config.
      credential."https://gitlab.com".helper = [
        ""
        "${lib.getExe pkgs.glab} auth git-credential"
      ];
    };

    includes = [{
      condition = "gitdir:~/work/";
      contents.user = {
        name = "Daniel Faris";
        email = "daniel.faris@gotaxi.co.nz";
      };
    }];
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";   # explicit; matches the home-manager default — see Rationale
    gitCredentialHelper.enable = true;
  };

  home.packages = [ pkgs.glab ];
}
```

Note on the `settings` shape: current home-manager prefers
`programs.git.settings.user.{name,email}` and
`programs.git.settings.<key>` over the older `programs.git.userName`,
`programs.git.userEmail`, and `programs.git.extraConfig`. The older
attribute paths still work via backward-compatibility aliases but emit
`trace:` deprecation warnings during eval; the `settings.*` shape used
above avoids those.

Notes:

- Directory convention: `~/work/` is the work boundary. Anything cloned
  under it gets the work identity. Personal repos can live anywhere else.
- Commit signing is **not configured** for either identity. Neither GitHub
  personal nor GitLab work requires it. If signing becomes a requirement,
  add `signingKey` and `commit.gpgsign = true` per identity (or use SSH
  signing).
- glab is a `home.packages` entry; there's no `programs.glab` module, so
  the credential helper for gitlab.com is wired manually in
  `programs.git.settings.credential."https://gitlab.com".helper` (see
  Rationale § "What about glab?"). Authentication still runs interactively
  via `glab auth login` (token-paste flow); the token persists in
  `~/.config/glab-cli/hosts.yml`.
- **Project directory convention** — `~/work/` for employer/GitLab work,
  `~/personal/` as the conventional sibling for personal repos. Both
  directories are ensured declaratively via
  `home.activation.ensureProjectDirs` (idempotent `mkdir -p` during
  activation; existing contents untouched). The gitdir-include condition
  is `gitdir:~/work/` only — `~/personal/` doesn't need a gitdir
  condition because it inherits the personal default identity.
- The `gh repo clone` test in Slice 6 verification is the canary: it must
  produce an `https://...` URL, not `git@github.com:...`. If it does the
  latter, `git_protocol = "https"` isn't applied — investigate before
  declaring the slice done.
