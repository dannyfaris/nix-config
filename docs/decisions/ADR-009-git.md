# ADR-009: Git — dual identity, HTTPS+token auth

**Date**: 2026-05-06
**Status**: Accepted

> **Amendment (2026-06-18, #364): glab token moves to the OS keyring at rest on graphical hosts.** ADR-009 chose a *helper-managed* token model (gh and glab each store their own token) and accepted that the token state lives outside nix's reach — that stands. What this refines is the at-rest *encoding* of glab's token. As filed, glab persisted its GitLab personal-access token in **plaintext** in `~/.config/glab-cli/config.yml` (mode 600 but an unencrypted `glpat-…` string), while gh's token on the same host is held in the gnome-keyring Secret Service ([#104](../desktop/gnome-keyring.md)). glab 1.101.0 supports that same Secret Service: `glab auth login --use-keyring` stores the token in the OS keyring (Linux: libsecret/gnome-keyring via zalando/go-keyring over D-Bus) and **strips the plaintext `token:` from config.yml**, leaving only `use_keyring: true` — the exact parallel to gh's keyring-backed config. So on metis (and any graphical host running the Secret Service) glab now mirrors gh: still helper-managed, but encrypted at rest. Closes #364.
>
> **Headless fallback.** The keyring needs the Secret Service at *every* glab invocation, so it is unusable headless (mercury — no D-Bus Secret Service), exactly like gh's keyring. glab is installed on mercury too (via `git-work` → `git.nix`), so if a headless host ever needs a GitLab token, inject it as `GITLAB_TOKEN` from a sops secret ([ADR-018](./ADR-018-headless-secrets-sops.md)) — not `--use-keyring`. sops, not 1Password `op` (deferred, #112), is the headless mechanism.
>
> **Migration + residual risk.** The fix is an operator action, not nix code (glab stays helper-managed; there is still no `programs.glab` module): on metis, run `glab auth login --use-keyring` (re-auth, or feed the existing token via `--stdin`), which migrates the token into the keyring and removes the plaintext copy. **Smoke-test immediately after:** `glab auth status` then `glab api user` must both succeed — glab issue [#8168](https://gitlab.com/gitlab-org/cli/-/issues/8168) reported keyring-stored tokens being sent with the wrong header (→ 401) from v1.84.0 and a fix could not be confirmed; if it 401s, revoke that token and fall back to the `GITLAB_TOKEN`-via-sops path above.

> **Amendment (2026-06-05, #212): work directory `~/work/` → `~/grey-st/`.**
> The work boundary directory — and the `gitdir:` trigger that keys the
> work identity off it — is renamed from the generic `~/work/` to
> `~/grey-st/`, so the path reflects the actual work context (the
> employer, Grey St) rather than a generic label. This is a directory
> **relabel only**: the work identity itself (`Daniel Faris` /
> `daniel.faris@gotaxi.co.nz`) is unchanged, as is `~/personal/`. The
> rename applies functionally on dual-identity hosts (the gitdir trigger)
> and cosmetically on work-only mercury (convention-only dir). The body
> below has been swept to `~/grey-st/`; the original convention was
> `~/work/`. **Operational note:** activation creates the new dir but
> does not migrate repos — a work repo left under a legacy `~/work/`
> silently falls back to the personal identity, so each dual-identity
> host must `mv ~/work ~/grey-st` (or move repos individually) and verify
> `git config user.email` inside `~/grey-st/<repo>` returns the work
> address. Same employer-label correction: earlier text called the
> employer "GotaXi" — the employer is **Grey St** (which operates the Tax
> Traders and Taxi brands); the `gotaxi.co.nz` email domain is unchanged.

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

## Context

The user works on two distinct git ecosystems from this dev box:

- **Personal**, on GitHub, as `dannyfaris <daniel@faris.co.nz>`.
- **Work**, on GitLab.com, as `Daniel Faris <daniel.faris@gotaxi.co.nz>`
  (employer: Grey St, which operates the Tax Traders and Taxi brands;
  the email domain is a brand domain). Approved by employer policy to
  operate from this personal box.

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
- Work identity is applied automatically inside `~/grey-st/` via a
  `gitdir:~/grey-st/` conditional include, overriding **both** name and
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
cloned/created under `~/grey-st/` automatically picks up the work email; no
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
  Code, Codex, Antigravity, Cursor) are precisely the workflow that this would
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
normally. The token persists in `~/.config/glab-cli/config.yml` after the
interactive flow (same compromise as gh — not declarative, but stable) —
held in the OS keyring rather than plaintext when logged in with
`--use-keyring` on a graphical host (see the 2026-06-18 / #364 amendment).

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
  legacy value and the work-email override not applying inside `~/grey-st/`.

## Implementation

> **Update (post-ADR-020, 2026-05-18):** what was a single
> `modules/home/git.nix` has been split into four files to support
> work-only hosts cleanly: a shared base (`home/shared/git.nix`)
> plus three per-host pieces (`git-identity-dual.nix`,
> `git-identity-work.nix`, `gh.nix`) selected per-host via
> `hostContext.extraHomeModules`. The mechanism is documented in
> ADR-020; the original single-file snippet below remains here as a
> historical reference for what ADR-009 originally specified, but is
> no longer the live shape.

Originally configured in `modules/home/git.nix` (single file, the
combined behaviour now distributed across `home/shared/git.nix`
plus the per-host identity and forge-CLI pieces selected via
`hostContext.extraHomeModules` — `git-identity-dual.nix` + `gh.nix`
on the dual-identity UTM VM, `git-identity-work.nix` on Mercury):

```nix
{ lib, pkgs, ... }: {
  programs.git = {
    enable = true;

    # Personal default identity matches the user's GitHub handle
    # (dannyfaris) — GitHub attribution is email-based, not name-based,
    # so the name is purely cosmetic on commit logs. Under ~/grey-st/ the
    # gitdir-include below overrides BOTH name and email to the work
    # identity ("Daniel Faris" / Grey St email) so commits to the work
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
      condition = "gitdir:~/grey-st/";
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

- Directory convention: `~/grey-st/` is the work boundary. Anything cloned
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
  `~/.config/glab-cli/config.yml` — keyring-backed (no plaintext) when
  logged in with `--use-keyring` on a graphical host (2026-06-18 / #364
  amendment).
- **Project directory convention** — `~/grey-st/` for employer/GitLab work,
  `~/personal/` as the conventional sibling for personal repos. Both
  directories are ensured declaratively via
  `home.activation.ensureProjectDirs` (idempotent `mkdir -p` during
  activation; existing contents untouched). The gitdir-include condition
  is `gitdir:~/grey-st/` only — `~/personal/` doesn't need a gitdir
  condition because it inherits the personal default identity.
- The `gh repo clone` test in Slice 6 verification is the canary: it must
  produce an `https://...` URL, not `git@github.com:...`. If it does the
  latter, `git_protocol = "https"` isn't applied — investigate before
  declaring the slice done.

## See also

- [docs/identities.md](../identities.md) — the cross-tool generalisation
  of the dual-identity pattern. ADR-009 is the canonical git instance
  and currently the sole participating tool; Claude Code (#137) was
  investigated as the second adopter and declined (see identities.md
  §"Tools that opted out"). New tools that grow per-identity state
  should refer there before wiring their split.
