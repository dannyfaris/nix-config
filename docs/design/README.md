# Design notes

The doc-before-code working-out of a non-trivial change: the problem and intent, the forces a solution must satisfy, the options weighed, the chosen decision, its architecture, the de-risk evidence, and the open items left for implementation.

Where [`decisions/`](../decisions/) records the *terse, frozen* ADR (the decision and its consequences) and [`research/`](../research/) captures *point-in-time* evidence that feeds a choice, a design note is the *fuller, proposed* working-out that sits between them — it leads with the problem, weighs the alternatives, and records the design before the code lands. A note is **Proposed / in-flight** while the work is being designed; when it lands, the direction-change is recorded as an ADR in `decisions/` and the mechanism guides the implementation.

## Writing a design note

1. **Copy the template.** Start from [`_template.md`](./_template.md) — `cp _template.md <descriptive-name>.md` — and fill each section, replacing the inline *italic prompts*. The template is the artifact's shape; this README is when and how to use it; [`design-loop.md`](./design-loop.md) is the *why* behind the loop the note moves through.
2. **Lead with intent.** Write the Summary and Motivation first — the problem and the forces — before any mechanism. Solution-first drafts are the failure mode the loop exists to catch.
3. **De-risk before you commit to the design.** Test the load-bearing assumption and record the result in De-risk evidence. A note is a proposal, not a guarantee; an unverified claim is stated as unverified.
4. **Weigh the alternatives.** Name the options and why the chosen one wins *against the stated forces*. The choice should be legible, not asserted.
5. **Peer-review before commit**, as elsewhere in the repo (see [`../workflow.md`](../workflow.md)).
6. **On acceptance it graduates.** A landed note's direction-change is recorded as an ADR in [`decisions/`](../decisions/) (the frozen *what*), while the note's mechanism guides the implementation and the living reference is reconciled in the *same change* as the code. The note itself is left in place as the proposed-design record; its Status header tracks where it sits on the two axes (decision-state ⊥ build-state).

## Conventions

- **Lead with intent.** The problem and the design objective come first; the decision and architecture come *after* the forces and the options, never before them.
- **Weigh the alternatives.** Name the options considered and why the chosen one wins against the stated forces — the choice should be legible, not asserted.
- **De-risk honestly.** Record what was verified and where; keep the open items — what is still to confirm at implementation — explicit. A design note is a proposal, not a guarantee.
- **Drawbacks and Cost are distinct.** Drawbacks are reasons-against the whole direction (strongest while Proposed); Cost is the standing price of the direction once chosen, and is optional — omit it when there is nothing non-obvious to record.
- One subject per note; dated / issue-linked; soft-wrapped — as elsewhere in `docs/`.

## Index

- **[colour-conductor.md](./colour-conductor.md)** — live, reproducible, durable desktop theming: Stylix as the single theming authority, live switching across a Nix-declared menu of named themes via home-manager specialisations, Noctalia demoted to a themed-by-Nix shell. Reverses ADR-036's "Noctalia as sole theming authority" (#411 / Epic E #427).

- **[wiki.md](./wiki.md)** — the personal OS's memory layer: `~/wiki`, an LLM-maintained Obsidian vault in the karpathy LLM-wiki shape, background-synced fleet-wide (mercury excluded) via home-manager's `services.git-sync`, with git carrying vault config for mobile parity and nix stopping at the vault wall (#506).

- **[design-loop.md](./design-loop.md)** — the repo's own design loop: how design work moves (intent → forces → options → decision → de-risk → reconcile), the artifact lifecycle (frozen record vs living reference vs proposal), and the enforcement-first spine for human + AI-agent collaboration. *Proposed; mutable by design.*

- **[macos-live-theme-switching.md](./macos-live-theme-switching.md)** — runtime polarity + theme switching on neptune with no rebuild: macOS appearance state as the polarity authority, native-first surface config (Ghostty dual-theme, fish/bat OSC), a `dark-mode-notify` fan-out for JankyBorders + themed wallpaper pools. Sibling to colour-conductor.md (#499).

- **[remote-desktop-access.md](./remote-desktop-access.md)** — remote *control* of the metis niri desktop from the operator's MacBook over Tailscale (distinct from view-only screencast): forces (private transport, client-sized headless display, low-latency HW encode, declarative), with Sunshine/Moonlight (KMS + uinput + forced-EDID) leading and wayvnc the alternative. Compositor virtual-output support is one consideration, not the subject. Core-thinking framing note. *Proposed; not built.*

- **[fleet-ssh-identity.md](./fleet-ssh-identity.md)** — fleet SSH trust as a declared edge whitelist (destination → source hosts) derived into per-host `authorizedKeys` and stance-asserted; SSH CA and Tailscale SSH declined on today's evidence, with the migration triggers that would reverse the decision recorded for #562 watching. Reconciles #524's any→any direction (#558; frozen in ADR-042). *Accepted; not built.*

- **[work-personal-boundary.md](./work-personal-boundary.md)** — the work/personal split, examined as a candidate security boundary and **rejected**: the operator accepted the residual risk (fluent daily work↔personal movement makes a crossing-heavy boundary self-defeating; overhead disproportionate for a single-operator fleet). Retained as the reasoned record — its threat model and central finding (file permissions give no isolation within one Unix user; a real boundary needs an execution boundary or a credential broker) stand, and it names `direnv` per-tree scoping as the lightweight partial mitigation available if appetite shifts. Extends ADR-020; simplifies #560 (#570). *Rejected; not built.*

- **[fleet-service-isolation.md](./fleet-service-isolation.md)** — how sandboxed a hosted service is (one of #387's two axes): default native NixOS service, promoted along the spectrum (native → OCI container → microVM guest → dedicated host) only by a named property (no clean packaging, breaking-release cadence, untrusted code, neighbour blast-radius). Only native + container are adopted tiers (container verified buildable in the pin, for keeper #386); guest and dedicated-host are named seams (guest gated on #555). A host-agnostic `services` capability; trimmed after adversarial self-review from ladder-as-policy to rule-plus-seams. *Proposed; not built.*

- **[fleet-service-placement.md](./fleet-service-placement.md)** — *where* a hosted service runs (the other #387 axis): the operator's criticality classes developed into conditional placement rules with triggers, not placements — watchers across the failure-domain boundary (the fleet violates this today: all alerts terminate at metis's own ntfy), hardware-coupled services with their hardware, uptime-expecting services firing ADR-030's posture question before any purchase, new always-on roles as M720q assignments before purchases. Corrects the products-host case against the operator's own later always-on/bursty split and offers dissolving "products" as a placement category (HA sui generis; the rest decompose). Carries the #557/#553 provisioning-window couplings. Jointly with the isolation sibling, the "central homelab ADR" (#387). *Proposed; not built.*
