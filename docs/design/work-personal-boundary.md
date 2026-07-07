# Work/personal boundary — a threat model, then a proportionate cut

**Status:** Proposed — design note (`docs/design/`). Not built. #570 (extends ADR-020; upstream of #560; adjacent #557, #568, #555). Drafted 2026-07-07. Expect an ADR recording the chosen boundary strength and its accepted residuals.

## Summary

The work/personal split on shared hosts is a naming convention, not a security boundary: a single git `includeIf gitdir:~/grey-st/` swaps the commit author, and everything else — tokens, SSH keys, keyring, agent auth, containers — is shared under one Unix user with no partition. This note writes the **threat model first** (what is defended, in which direction, against which adversary), then weighs isolation mechanisms against it. Its central technical finding, demonstrated on metis: **within one Unix user, file permissions provide no isolation** — a process in the work tree reads every personal credential and vice versa — so any real boundary needs an *execution* boundary (separate user, sandbox, or dedicated host) or credentials behind a *policy broker* (scoped/short-lived tokens), never a permissions "partition." The recommended cut is proportionate and layered; the boundary-strength decision and the accepted residual risk are the operator's, posed explicitly in Unresolved questions.

## Motivation

metis is chartered as a shared work + personal dev box; neptune and saturn are the same dual-identity shape, all running both identities as the single `dbf` account (census: `git-multi-identity.nix` imports). nixos-vm shares that shape but is retiring alongside mercury (ADR-042), so the *durable* dual-identity set the boundary must serve is three hosts — metis, neptune, saturn — not a moving target. mercury was the lone strong-form boundary — a whole host for work — and its retirement removes the fleet's only real work/personal isolation, which is part of why this note is timely.

The split today governs *which name signs a commit*. It does not govern *what code can touch*. Concretely, a build script, a test, a transitive dependency, or an agent operating inside `~/grey-st/platform` (the employer's monorepo) executes as `dbf` with read access to the personal GitHub token, the personal SSH fleet key (a lateral-movement credential — per ADR-042's edge map the metis key logs into the personal workstation neptune, so a key read is a pivot onto a crown-jewel host, not just a local secret), the personal browser's keyring, and the Claude/Cursor credentials — and, symmetrically, a personal experiment reads the work GitLab token and the employer's code. `docs/identities.md` already concedes the split is "best-effort, not enforced"; this note is the promotion of that admission into a modelled, decided boundary — the same convention→enforcement arc the repo applied to stances (#551), the tailnet (#556), and SSH edges (ADR-042).

The forces any boundary must satisfy, in rough priority:

1. **F1 — Model before mechanism.** The boundary's *strength* must be derived from a written threat model (assets, directions, adversaries, accepted residuals), not chosen by taste. ADR-032 proportionality: the lightest mechanism that holds the modelled guarantee.
2. **F2 — Defend the dominant vector.** Whatever the top-likelihood attack is, the mechanism must actually stop it — not an easier adjacent one.
3. **F3 — Asymmetric obligation.** Personal credentials are the operator's own risk to accept; the *employer's* code and credentials carry a confidentiality obligation the operator cannot unilaterally spend. The two directions may warrant different strengths.
4. **F4 — Ergonomic cost ceiling.** A boundary crossed a hundred times a day gets bypassed in practice, and a bypassed boundary is worse than an honest convention (the issue's own framing). Daily friction is a first-class constraint, not an afterthought.
5. **F5 — Declarative and legible.** The boundary lives in this repo, reviewable, not in imperative host state; what crosses it deliberately (this repo, shared tools) is named.
6. **F6 — Host-provisioning constraint (operator, recorded 2026-07-06).** Host-level separation, if ever chosen, is realised by *new dedicated hosts*, never by re-purposing existing fleet hosts (the #387 tower/metis re-role is explicitly not an identity-separation move). Intra-host mechanisms operate on hosts as they are.
7. **F7 — Agent surface.** Agents run with broad permissions, act on untrusted input (issues, web, dependency trees), and are increasingly autonomous — the boundary must have an answer for "an agent working the work repo holds only work auth."

## Design

### The threat model (this is the load-bearing artifact)

**Assets, by identity.** *Personal:* the GitHub token (`repo`/`workflow`/`gist` scopes → push to personal repos, trigger CI), the SSH fleet key (reaches neptune + mercury), personal browser sessions and 1Password vault, Claude/Cursor OAuth. *Work:* the GitLab token (→ the Tax Traders `platform` monorepo, ticket infra), the employer's source itself (confidentiality obligation), any work secrets under `~/grey-st`.

**Directions.** *work → personal:* work's large external dependency surface reaches the operator's personal credentials. *personal → work:* the operator's ad-hoc personal activity reaches the employer's IP and credentials. F3 makes these non-symmetric: the operator owns the first risk and merely holds the second.

**Adversary classes, ranked by likelihood × impact:**

1. **Build/test-time dependency execution — HIGH × HIGH, the dominant vector.** `go build`, `npm ci`, `cargo build`, a test invoking arbitrary code: any of these runs untrusted third-party code as `dbf` the moment the operator builds a project. It needs *no targeting* — a single poisoned transitive dependency in the work monorepo exfiltrates the personal token on the next build. This is #568's supply-chain threat pointed *inward* at the credential surface, and it is the vector the mechanism must defeat to be worth building.
2. **Misdirected or prompt-injected agent — MEDIUM-and-rising × HIGH.** An agent in the work tree, holding the full `dbf` environment, injected via a malicious issue / poisoned file / web fetch into reading and exfiltrating credentials — or simply misdirected (wrong tree, wrong token on a push). The issue flags this as the highest-leverage single cut, and F7 exists for it.
3. **Compromised browser session — LOW-MEDIUM × MEDIUM-HIGH.** A personal browser or extension reaching the keyring / local tokens. The largest untrusted-content surface, but a lower-probability path to *credentials* specifically.

The model's conclusion: the boundary must defeat **execution reading credentials across the identity line**, with the build/test loop and agent execution as the two paths that matter. Vectors that are *only* about commit attribution (the status quo's concern) are not in scope — that is already handled by git.

### Why the obvious mechanism fails (demonstrated, not assumed)

The cheapest-sounding cut — "partition the credential surface within the one `dbf` user" — **does not work**, and the design must not rest on it. Verified on metis 2026-07-07 (De-risk evidence): every credential is a `mode-600 dbf` file (`~/.config/gh/hosts.yml`, `~/.config/glab-cli/config.yml`, `~/.ssh/id_ed25519`, `~/.claude/.credentials.json`) and gnome-keyring serves any process on the user bus. A process's working directory is cosmetic; same UID means same access. File permissions isolate *users*, and there is only one user — so they isolate nothing here. Real isolation therefore requires one of two mechanism classes: an **execution boundary** (a different UID, a sandbox/namespace, a container, or a separate host — something that changes what the process can see), or a **credential broker** (tokens that are short-lived and/or scoped so that reading the on-disk artifact yields little — moving the trust from the filesystem to an issuing policy). The apparent third path — mandatory access control (SELinux/AppArmor) or per-process kernel keyring ACLs, where the kernel denies a same-UID read that permissions would allow — folds into these on inspection: AppArmor/landlock confinement *is* an execution boundary in effect (and is the realistic NixOS form; SELinux is not wired on this fleet), and kernel session-keyrings are a broker form that today's credentials do not use (they are plain `dbf` files plus gnome-keyring, not kernel-keyring-held). So the two classes are exhaustive in practice — but by argument, not omission.

### The recommended cut (a lean; the strength decision is the operator's)

Layered, each layer independently valuable, ordered by leverage-per-cost:

- **Layer 1 — per-identity agent + credential scoping (cheapest, highest-leverage, do first).** Point agents and tooling at per-identity credential sets so that a session in the work tree holds *only* work auth and a personal session holds only personal auth — the exact cut #570 names. Realised through the credential-broker path (scoped/short-lived tokens where the provider supports it; per-tree tool config), *not* file permissions. This shrinks blast radius and defangs the *misdirection* half of adversary 2, but by itself does not stop a determined same-UID read (adversary 1).
- **Layer 2 — confine the untrusted execution (where the real boundary lives).** Run the work tree's build/test loop and agent execution in a confined context (bwrap/landlock/systemd-run hardening, or a #555 microVM guest) that cannot see personal credentials. This is the layer that actually defeats the dominant vector. **Feasibility is unproven and is the thing to prototype next** — dev loops are notoriously sandbox-hostile (language servers, file watchers, dependency network access), and F4 means a confinement that wrecks the inner loop will be bypassed. The de-risk prototype (Unresolved questions) must show a work build/test/agent cycle running confined *without* intolerable friction before this layer is committed.
- **Layer 3 — dedicated hosts (the strong form, reserved).** Per F6, host-level strength is new dedicated hosts, provisioned deliberately, never re-slicing metis. This is the escalation when intra-host residuals become unacceptable — and F3 suggests it may be reached for the *work* direction specifically before the personal one, since the employer-IP obligation is the harder residual to accept under intra-host isolation.

How this meets the forces: F1 (mechanism derived from the model above, not asserted); F2 (Layer 2 targets the dominant build/test vector head-on); F3 (Layer 3 is available for the work direction independently, honouring the asymmetric obligation); F4 (Layer 1 is friction-free, Layer 2 is explicitly gated on a friction de-risk); F5 (all layers land as repo modules, with this repo itself the named deliberate boundary-crosser); F6 (intra-host layers on hosts as-is, dedicated hosts as the recorded later step); F7 (Layer 1 *is* the agent answer).

## De-risk evidence

Verified against branch `main` and the running metis host, 2026-07-07:

- **The single-signal boundary** — declared census: `home/shared/git-identity-dual.nix:23-30` (`gitdir:~/grey-st/` swaps author only), `lib/operator.nix` identities, `docs/identities.md` ("best-effort, not enforced"). Four of five hosts import `git-multi-identity.nix` (metis/neptune/nixos-vm/saturn); mercury alone was work-only-by-being-a-separate-host, and is retiring.
- **No isolation within the user (the load-bearing demonstration)** — from a shell in `~/grey-st/platform`, `test -r` succeeds on all four credential files (`~/.config/gh/hosts.yml`, `~/.config/glab-cli/config.yml`, `~/.ssh/id_ed25519`, `~/.claude/.credentials.json`) and `org.freedesktop.secrets` is reachable on the user bus. Permissions confirmed `600 dbf`. No contents were read. This is the empirical basis for "file-permission partition is not a mechanism."
- **No execution isolation exists to build on** — census grep for `firejail|bubblewrap|bwrap|landlock|ProtectSystem|DynamicUser|systemd-run` returned zero hits; Firefox on metis has a single stub profile, no work/personal split; docker is rootless (Linux) / colima VM (Darwin), available to the whole user.
- **ADR-020 has no security migration trigger** — its only trigger concerns code-organisation (`extraHomeModules` count); there is no prior isolation stance for this note to extend, so it breaks new ground rather than amending a posture.

Unverified, stated rather than implied:

- **Layer 2 feasibility** — whether a work dev build/test/agent loop can run usefully confined (bwrap/landlock/#555 guest) *within* F4's friction ceiling is **not tested**; it is the primary implementation-gating de-risk and must be prototyped before Layer 2 is committed.
- **Provider support for scoped/short-lived tokens** — whether GitHub/GitLab/agent auth can be issued narrowly enough to make Layer 1's broker path meaningful is unconfirmed per provider.
- **The threat model's likelihood ranking** is reasoned, not measured; it should survive operator challenge but rests on judgement, not incident data (the repo has none for this).

## Drawbacks

- **The honest strong form is a separate machine, and it is friction the operator has already lived and is now removing.** mercury *was* Layer 3 for the work side; its retirement is a deliberate consolidation. Re-introducing host-level separation (even as new hardware) partly reverses a simplification just made — the note must not pretend the strong form is cheap.
- **Layer 2 may be infeasible at acceptable friction** — if the de-risk fails, the note collapses to Layer 1 (blast-radius reduction, not isolation) plus Layer 3 (dedicated hosts), and the middle ground the operator asked about may simply not exist on a single dev box. That is a possible and legitimate outcome.
- **A partial boundary can be worse than none** if it breeds false confidence — "work runs sandboxed" that silently leaks through an unconfined language-server helper is more dangerous than a known-soft convention. Any Layer 2 needs an enforcement check (a stance/probe proving the confinement actually holds), or it is theatre — the repo's own set≠enforced lesson.
- **Agents resist scoping** — Layer 1 assumes agent tooling can be pinned to per-identity credentials; if an agent insists on a single global auth (as Claude Code effectively did in #137), Layer 1's agent half is limited to *directing* rather than *confining* it.

## Cost

The standing price of any adopted layer: a second axis of state to keep declarative and coherent (per-identity credential sets, confinement rules) on top of the existing per-host and per-platform axes — and, if Layer 3 is ever taken, the recurring cost of another physical host (power, maintenance, the fleet's own attack surface). Named so the ADR states it rather than discovering it.

## Rationale & alternatives

- **Do nothing (keep the convention).** Wins F4 (zero friction) and nothing else; fails F1/F2/F3 outright. Legitimate *only* if the operator, having read the threat model, accepts the full residual — which is a decision the model now makes explicit rather than implicit.
- **Credential-surface partition by file permissions (the intuitive fix).** Rejected on evidence, not taste: demonstrated non-functional within one UID (De-risk). Named because it is the first thing anyone reaches for and the note must close the door on it.
- **Separate Unix users on the shared host.** Real isolation (different UID restores permission semantics), and the `extraHomeModules` wiring supports it — but fails F4 hardest: two logins/sessions, duplicated agent auth and tool state, constant `su`/session-switching on a box whose whole purpose is fluid movement between work and personal repos. High-friction real-isolation is exactly the boundary that gets bypassed. Kept as a live alternative to Layer 2 (it trades friction for feasibility-certainty — it definitely *works*, it just costs daily), but not the lean.
- **The layered cut (recommended).** The only option that derives from the model, targets the dominant vector (Layer 2), honours the asymmetric obligation (Layer 3 for work), and keeps daily friction near zero for the common case (Layer 1) — at the cost of Layer 2's unproven feasibility, which is why it is gated on a de-risk rather than asserted.

## Prior art

- **This repo's own history:** mercury is the worked strong-form (isolation-by-separate-host); `docs/identities.md` is the honest prior admission that the split is unenforced; #137 recorded that Claude Code could not be scoped per-tree and opted out — a direct constraint on Layer 1's agent half.
- **Dev containers / devcontainer.json** (VS Code, GitHub Codespaces) are the mainstream form of Layer 2: per-project containerised toolchains that confine build/test. Evidence both that the pattern is proven at scale *and* that it carries real inner-loop friction — the exact F4 tension to prototype against.
- **Per-identity credential helpers** (git `includeIf` is one; `gh`/`glab` per-host config, `direnv`-scoped env, 1Password Service Accounts) are the Layer 1 building blocks; `docs/identities.md` already names direnv as the standard mechanism-primitive for future per-tree env, unused today.
- Industry framing: the "malicious dependency reads `~/.aws/credentials` at build time" supply-chain class is well documented; the defence is universally an execution boundary (container/sandbox/CI-only build), never file permissions in the developer's own account — corroborating the De-risk finding.

## Unresolved questions

The operator's decisions, deliberately not pre-made here (the whole note is upstream of them):

- **Boundary strength and accepted residuals** — the F1 decision. Having read the threat model, which residual risk is accepted, and at which layer does the operator want to stop? (Recommendation offered: Layer 1 now, Layer 2 gated on the friction de-risk; Layer 3 reserved.)
- **Asymmetric strength (F3)** — is the employer-IP obligation acceptable under intra-host isolation, or does the *work* direction specifically require Layer 3 (a dedicated host) while the personal direction stays intra-host? This may split the decision by direction.
- **neptune (and saturn)** — do the other dual-identity hosts get the same treatment as metis, or is metis (the primary shared dev box) the only in-scope host for the first cut?
- **Layer 2 feasibility** — the gating de-risk: prototype a confined work build/test/agent loop and measure the friction before committing. Owned by the implementing session.
- **Agent scoping specifics** — which agents can actually be pinned to per-identity credentials vs. only directed (per #137's finding).
- Out of scope: #560's roaming semantics (this note is *upstream* — the boundary decided here is #560's input, not the reverse), disk-encryption domains (#557 — whether per-identity home encryption participates is deferred to that note's frame), and any change to git's author-routing (already correct).

## Future possibilities

- **#560 derives from this boundary** — which mutable state roams onto which host follows from the identity boundary decided here, rather than being chosen per-store; recorded so #560 consumes this rather than re-deciding it.
- **Dedicated-host trigger** — the condition that would move the work direction to Layer 3: intra-host confinement proving infeasible or insufficient, or an employer requirement for physical separation. Phrased for #562 watching once it exists.
- **#557 interaction** — if per-identity home encryption ever becomes desirable, the boundary defined here is the natural domain line; parked, not committed.
- **An enforcement stance for the boundary** — once a mechanism lands, a stance/probe proving the confinement actually holds (a work-context process demonstrably *cannot* read a personal credential) is the set≠enforced closure, mirroring ADR-042's probe rung.
