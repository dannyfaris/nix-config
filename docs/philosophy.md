# Operating philosophy

This document captures the principles that shape every decision in this repo.
Each principle has a *why* behind it — the constraint or experience that
produced the rule. When a principle conflicts with convenience, the principle
wins; when in doubt, prefer the option that is most aligned with these
principles.

## Tight from the start

**Rule.** Don't accumulate slack expecting to clean it up later. Configurations
that are "good enough for now" become permanent for everyone except the
current author, and that author's future self.

**Why.** This repo is intentionally small. Every choice is reviewable in one
sitting. The cost of doing it right the first time is low; the cost of letting
loose ends accumulate is compounding — they tangle with each other, hide
behind newer cruft, and become expensive to disentangle later.

**How it shows up.**
- Every module has a single subject.
- No "TODO: refactor this" comments left in the tree.
- New tools are scrutinised before they land, not after.

## Declarative over imperative

**Rule.** State what should be true; let nix figure out how to get there. Avoid
imperative shell scripts, runtime-only configuration, and side-effects buried
in startup hooks.

**Why.** Imperative configuration drifts. The state of an imperatively
configured machine depends on its history — what packages were installed,
when, in what order, by what scripts. A declarative configuration is the
machine. `nixos-rebuild switch` produces the same result whether the machine
was empty or had been running for years.

**How it shows up.**
- `programs.X` modules in home-manager preferred over hand-rolled rc files.
- Settings declared inline in nix attrsets, not as separate config files we
  later have to remember to track.
- Dotfiles are generated, not committed in `~/.config/...`.

## Explicit over implicit

**Rule.** Make intent visible. If something is true because of a side effect or
default, document it or set it explicitly.

**Why.** Implicit configuration depends on knowledge that lives in
contributors' heads, not in the repo. When the contributor changes (including
the contributor being you-six-months-from-now), the implicit knowledge is
gone. Explicit configuration is robust to that loss.

**How it shows up.**
- The `home-manager.useGlobalPkgs` flag is set explicitly even though the
  default would work, because the implication (that the system's
  `allowUnfreePredicate` propagates) is load-bearing.
- Comments next to non-obvious settings explain *why*, not *what*.
- Decisions that are subtle get their own ADR rather than being inferred from
  the code.

## Whitelist over blanket

**Rule.** Default to denying things; allow specific items by name. Never
replace a whitelist with a blanket allow.

**Why.** Blanket permissions hide the moment when something new is added —
the new thing slips in silently. A whitelist forces a deliberate choice each
time, with the moment of choice visible in version control.

**How it shows up.**
- `nixpkgs.config.allowUnfreePredicate` lists each unfree package by name.
  Adding a new unfree dependency requires a deliberate edit; nothing slips
  through.
- Firewall rules are explicit; no "open everything internally" shortcuts.
- Per-tool dependency adoption is reviewed; no "install a category of tools
  in case they're useful" patterns.

## Single source of truth

**Rule.** For any piece of state, exactly one place is authoritative. Other
references mirror or point to it.

**Why.** Multiple sources of truth drift. The most painful failures are the
ones where two records disagree and you don't know which is correct.

**How it shows up.**
- `users.mutableUsers = false` — `passwd` changes don't persist; the file is
  the only source of user state.
- Hashed user passwords come from sops-encrypted files referenced by the
  module; they're not duplicated in `/etc/shadow` outside of nix's control.
- Operator identity (username, home paths, authorised SSH keys) lives in
  `lib/operator.nix` and is imported by every module that needs it. Was
  scattered as duplicated literals across four files until #49.
- After Tier 3, `docs/` is canonical for design rationale. AI memory files
  point here rather than duplicating content.

## No premature abstraction; YAGNI

**Rule.** Don't introduce a flag, a wrapper, or a layer until there's a
concrete need. Don't add `enable` toggles to modules until something actually
wants to disable them. Don't decompose a structure into sub-structures until
the size demands it.

**Why.** Speculative abstractions are usually wrong because they're built on
guesses about future requirements. They become permanent infrastructure that
the next change has to navigate around. Concrete abstractions, by contrast,
are right by construction — they exist because something specific demanded
them.

**How it shows up.**
- `home/{shared,nixos}/` files don't expose `enable` flags. The day a host wants
  to disable, say, the editor, that's when the flag earns its place.
- Module decomposition matches actual size and concern boundaries, not
  hypothetical future shape.
- New tools are added when they earn their place, not pre-emptively because
  "we might want them".

## Most-communicative term naming

**Rule.** Name files and modules by whichever term is most communicative to a
reader: role names where the role is more recognisable than any one tool;
tool names where the tool *is* the role; collective category names where
multiple tools serve one role with no umbrella tool.

**Why.** Names are read far more often than they're written. The cost of a
wordy or forced name is paid every time someone reads the tree. The right
test is: which name does a reader parse fastest with full understanding?

**How it shows up.**
- See [taxonomy.md](./taxonomy.md) for the applied principle and examples.
- ADR-012 captures this as a formal decision.

## Honest tradeoffs

**Rule.** Every choice has consequences both ways. Document the negative ones
along with the positive. Document migration triggers — the circumstances
under which a decision should be revisited.

**Why.** Documentation that omits tradeoffs becomes unfalsifiable
salesmanship. Documentation that records tradeoffs honestly is useful when
the world changes — the migration triggers tell you what to look for, and
the recorded negatives tell you what was already known.

**How it shows up.**
- Every ADR has a "Consequences" section with explicit ✗ items and ⚠
  migration triggers.
- "What this DOESN'T solve" is sometimes a more useful section than "what
  this solves".
