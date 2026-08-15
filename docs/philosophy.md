# Operating philosophy

This document captures the principles that shape every decision in this repo. Each principle has a *why* behind it — the constraint or experience that produced the rule. When a principle conflicts with convenience, the principle wins; when in doubt, prefer the option that is most aligned with these principles.

Underneath all of them is one idea: **everything here is on purpose.** Whitelist over blanket is *only what you chose*; explicit over implicit is *say that you chose it*; honest tradeoffs is *admit what choosing it cost*. The principles below are that idea applied to different surfaces. The test any change has to pass is not "does this work" but "was this decided".

## Tight from the start

**Rule.** Don't accumulate slack expecting to clean it up later. Configurations that are "good enough for now" become permanent for everyone except the current author, and that author's future self.

**Why.** This repo is intentionally small. Every choice is reviewable in one sitting. The cost of doing it right the first time is low; the cost of letting loose ends accumulate is compounding — they tangle with each other, hide behind newer cruft, and become expensive to disentangle later.

**How it shows up.**

- Every module has a single subject.
- No "TODO: refactor this" comments left in the tree.
- New tools are scrutinised before they land, not after.

## Declarative over imperative

**Rule.** State what should be true; let nix figure out how to get there. Where state must be live rather than declared, it is a *declared layer with an owner* — never an accident.

**Why.** Imperative configuration drifts. The state of an imperatively configured machine depends on its history — what packages were installed, when, in what order, by what scripts. A declarative configuration is the machine. `nixos-rebuild switch` produces the same result whether the machine was empty or had been running for years.

But some state is genuinely *session* state rather than desired state — the colour scheme flipped ten minutes ago, the font nudged a size. Forcing it into the flake makes changing it a rebuild; leaving it undeclared lets it leak somewhere the repo cannot see. Neither is on purpose, so the boundary is drawn explicitly:

**The boundary.**

1. **Nix owns the mechanism and its option set; the live selection may be session state.** On Darwin, the theme *menu* is Nix-owned, the chosen value is not ([ADR-044](./decisions/ADR-044-linux-runtime-theme-menu.md)); on Linux, Nix declares no theme keys at all — the sidecar is the sole writer ([ADR-048](./decisions/ADR-048-noctalia-theming-delegation.md), reversing ADR-044 there). The display calibration is declared, nothing about it is live (`lib/display-profiles.nix`). The persist *whitelist* is declared, the data it protects is not ([ephemeral-root.md](./design/ephemeral-root.md)).
2. **Runtime state is sanctioned only when it has a declared home, a declared persistence policy, and exactly one writer.** One writer is why an action tree inside Noctalia's GUI-managed `settings.json` was rejected. A declared home is why `/var/lib/bluetooth` sits on the persist whitelist.

**How it shows up.**

- `programs.X` modules in home-manager preferred over hand-rolled rc files.
- Settings declared inline in nix attrsets, not as separate config files we later have to remember to track.
- Dotfiles are generated, not committed in `~/.config/...`.
- A runtime conductor — Noctalia for colour, fontconfig for faces — is a *sanctioned* layer, declared and owned, not an exception to this rule.

## Explicit over implicit

**Rule.** Make intent visible. If something is true because of a side effect or default, document it or set it explicitly.

**Why.** Implicit configuration depends on knowledge that lives in contributors' heads, not in the repo. When the contributor changes (including the contributor being you-six-months-from-now), the implicit knowledge is gone. Explicit configuration is robust to that loss.

**How it shows up.**

- The `home-manager.useGlobalPkgs` flag is set explicitly even though the default would work, because the implication (that the system's `allowUnfreePredicate` propagates) is load-bearing.
- Comments next to non-obvious settings explain *why*, not *what*.
- Decisions that are subtle get their own ADR rather than being inferred from the code.

## Whitelist over blanket

**Rule.** Default to denying things; allow specific items by name. Never replace a whitelist with a blanket allow.

**Why.** Blanket permissions hide the moment when something new is added — the new thing slips in silently. A whitelist forces a deliberate choice each time, with the moment of choice visible in version control.

**How it shows up.**

- `nixpkgs.config.allowUnfreePredicate` lists each unfree package by name. Adding a new unfree dependency requires a deliberate edit; nothing slips through.
- Firewall rules are explicit; no "open everything internally" shortcuts.
- Per-tool dependency adoption is reviewed; no "install a category of tools in case they're useful" patterns.
- Scope is whitelisted too: an addition nobody asked for is a blanket allow on the diff. See [workflow.md](./workflow.md) §"Implement only what was asked" for the procedure.

## Single source of truth

**Rule.** For any piece of state, exactly one place is authoritative. Other references mirror or point to it.

**Why.** Multiple sources of truth drift. The most painful failures are the ones where two records disagree and you don't know which is correct.

**How it shows up.**

- `users.mutableUsers = false` — `passwd` changes don't persist; the file is the only source of user state.
- Hashed user passwords come from sops-encrypted files referenced by the module; they're not duplicated in `/etc/shadow` outside of nix's control.
- Operator identity (username, home paths, authorised SSH keys) lives in `lib/operator.nix` and is imported by every module that needs it. Was scattered as duplicated literals across four files until #49.
- `docs/` is canonical for design rationale. AI memory files point here rather than duplicating content.
- Rationale is single-sourced like state: a *why* longer than a few lines lives in one canonical home (an ADR or `docs/<area>/`) with one-line pointers from code, never restated inline. See [ADR-032](./decisions/ADR-032-proportionate-enforcement-and-rationale.md) and [workflow.md](./workflow.md) §"Rationale lives in one place".

## No premature abstraction; YAGNI

**Rule.** Don't introduce a flag, a wrapper, or a layer until there's a concrete need. Don't add `enable` toggles to modules until something actually wants to disable them. Don't decompose a structure into sub-structures until the size demands it.

**Why.** Speculative abstractions are usually wrong because they're built on guesses about future requirements. They become permanent infrastructure that the next change has to navigate around. Concrete abstractions, by contrast, are right by construction — they exist because something specific demanded them.

**How it shows up.**

- `home/{shared,nixos}/` files don't expose `enable` flags. The day a host wants to disable, say, the editor, that's when the flag earns its place.
- Module decomposition matches actual size and concern boundaries, not hypothetical future shape.
- New tools are added when they earn their place, not pre-emptively because "we might want them".
- A `modules/{nixos,darwin}` twin-pair collapses into one `lib/mk-*.nix` constructor only where the two bodies differ in platform-constant *values* — host-context and home-manager collapse this way, each taking explicit per-platform args stated at its two call sites, with no central platform record. A constructor spanning a *logic* difference is exactly the speculative abstraction the next divergence has to navigate around, so pairs differing in logic, option surface, or upstream module semantics (firewall, sshd, nix-daemon) stay two files. A third pattern sits between the two: a pure-logic *core* may be single-sourced without collapsing the shells — the stylix-palette twins share their selection semantics via `lib/palette-for.nix` yet stay two files, because their engine imports differ (`inputs.stylix.nixosModules.stylix` vs `.darwinModules.stylix`). See #541.
- Enforcement machinery is sized to the severity it guards — the lightest mechanism that holds the guarantee (convention → `grep`-lint → bespoke parser), escalating only on repeated evidence. Building the gate before the evidence is itself a speculative abstraction. See [ADR-032](./decisions/ADR-032-proportionate-enforcement-and-rationale.md).

## Most-communicative term naming

**Rule.** Name files and modules by whichever term is most communicative to a reader: role names where the role is more recognisable than any one tool; tool names where the tool *is* the role; collective category names where multiple tools serve one role with no umbrella tool.

**Why.** Names are read far more often than they're written. The cost of a wordy or forced name is paid every time someone reads the tree. The right test is: which name does a reader parse fastest with full understanding?

**How it shows up.**

- See [taxonomy.md](./taxonomy.md) for the applied principle and examples.
- ADR-012 captures this as a formal decision.

## Honest tradeoffs

**Rule.** Every choice has consequences both ways. Document the negative ones along with the positive. Document migration triggers — the circumstances under which a decision should be revisited.

**Why.** Documentation that omits tradeoffs becomes unfalsifiable salesmanship. Documentation that records tradeoffs honestly is useful when the world changes — the migration triggers tell you what to look for, and the recorded negatives tell you what was already known.

**How it shows up.**

- Every ADR has a "Consequences" section with explicit ✗ items and ⚠ migration triggers.
- "What this DOESN'T solve" is sometimes a more useful section than "what this solves".

## Set is not enforced

**Rule.** *Set* is what the configuration declares; *enforced* is what the running system actually does. The gap between the two — canonically written **set ≠ enforced** — is where a change is correct on paper and inert in production. A change asserting a runtime, security, or network-posture property is done when that behaviour has been observed on a host, not when it evaluates or merges. Where it is unclear which layer enforces a property, probe it empirically first.

**Why.** [#336](https://github.com/dannyfaris/nix-config/issues/336) is the worked example: a firewall rule was removed that was never the gate — tailscale's `ts-input` pre-empts the NixOS firewall. Eval passed, and a two-reviewer adversarial pass missed it; a runtime probe caught it. Reasoning and review both read the declaration; only a probe reads the enforcement.

**How it shows up.**

- The design loop's de-risk rung is this principle applied to design: the load-bearing assumption is tested before the design is committed to, not after ([design-loop.md](./design/design-loop.md) §De-risk evidence).
- [ADR-047](./decisions/ADR-047-macos-window-manager-yabai.md)'s yabai trial is the sharpest evidence yet — four diagnoses made during the trial were wrong, three of the four would have shipped as fixes, and every one was caught by running something on the box rather than by reasoning or review; the two conclusions held most confidently from source-reading were among those falsified.
- The behavioural coverage this rule wants on the NixOS side — VM tests for the stances — is a standing gap, tracked in [#303](https://github.com/dannyfaris/nix-config/issues/303).
- [workflow.md](./workflow.md) §"Runtime claims are probe-verified" is the choreography that discharges this rule: how a probe is designed before the change lands, run, and recorded.
