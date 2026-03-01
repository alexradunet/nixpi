# Flake-Parts vs Dendritic: Analysis for Nixpi

## Context

Nixpi's `flake.nix` is 120 lines with 2 inputs (nixpkgs stable + unstable), 8 NixOS modules, 18 VM checks, devShells for 2 systems, and a template. The project already has strong modular patterns: a service factory (`mk-nixpi-service.nix`), per-feature NixOS modules in `infra/nixos/modules/`, and a hexagonal architecture. The question is whether adopting flake-parts or dendritic would meaningfully improve resilience and maintainability.

---

## What Each Tool Is

|                   | **flake-parts**                              | **dendritic**                                             |
| ----------------- | -------------------------------------------- | --------------------------------------------------------- |
| **Type**          | Framework (library)                          | Usage pattern (philosophy)                                |
| **Maintained by** | Hercules CI team (24 contributors)           | mightyiam + community                                     |
| **GitHub stars**  | 1,200+                                       | ~50                                                       |
| **Maturity**      | Production-ready, widely adopted             | Early-to-mid stage, growing                               |
| **Core idea**     | NixOS module system applied to flake outputs | Feature-centric file organization spanning config classes |
| **Dependency**    | Standalone                                   | Typically built on top of flake-parts                     |

**Key relationship:** Dendritic is a _pattern_ that usually uses flake-parts as its _framework_. You'd adopt flake-parts first, then optionally organize files the dendritic way.

---

## What Flake-Parts Would Change

### Current Nixpi flake.nix pattern

```nix
outputs = { self, nixpkgs, nixpkgs-unstable }:
  let
    forAllSystems = f: nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: f system);
    pkgsFor = system: import nixpkgs { inherit system; };
  in {
    devShells = forAllSystems (system: { default = ...; });
    checks.x86_64-linux = { vm-test-1 = ...; vm-test-2 = ...; };
    nixosModules = { default = ...; tailscale = ...; };
  };
```

### With flake-parts

```nix
outputs = inputs@{ flake-parts, nixpkgs, nixpkgs-unstable, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = ["x86_64-linux" "aarch64-linux"];
    imports = [ ./nix/dev-shell.nix ./nix/checks.nix ];

    perSystem = { pkgs, system, ... }: { /* system-specific outputs */ };
    flake = { /* nixosModules, templates */ };
  };
```

### Concrete benefits for Nixpi

1. **Eliminates `forAllSystems` boilerplate** — `perSystem` handles system enumeration automatically
2. **File splitting** — Could move 18 VM check definitions to `nix/checks.nix`, devShell to `nix/dev-shell.nix`
3. **Ecosystem modules** — Could adopt `treefmt-nix` for formatting, `pre-commit-hooks-nix` for hooks
4. **Type-checked outputs** — Module system validates flake output structure at eval time

### Concrete costs for Nixpi

1. **New input dependency** — Adds `flake-parts` to flake.lock
2. **Learning curve** — `perSystem` deferred module semantics differ from plain Nix
3. **Migration effort** — Rewrite flake.nix, update all 18 check references
4. **Debugging** — Module system error messages can be less obvious than plain Nix errors
5. **`withSystem` gotcha** — NixOS configs need `withSystem` to access per-system values, adding indirection

---

## What Dendritic Would Change

Dendritic reorganizes from **config-class-first** to **feature-first**:

```
# Current Nixpi (already feature-based within NixOS)
infra/nixos/modules/tailscale.nix    # NixOS module
infra/nixos/modules/heartbeat.nix    # NixOS module
infra/nixos/modules/matrix.nix       # NixOS module

# Dendritic pattern (cross-class features)
aspects/tailscale.nix    # NixOS + home-manager + darwin in one file
aspects/heartbeat.nix    # spans all config classes
```

### Why dendritic does NOT fit Nixpi

1. **Single config class** — Nixpi only has NixOS modules. No home-manager, no nix-darwin. Dendritic's value is spanning _multiple_ config classes.
2. **Already feature-based** — Nixpi modules are already organized by feature (`tailscale.nix`, `heartbeat.nix`, `matrix.nix`).
3. **Single-host target** — Dendritic shines for multi-host, multi-OS setups. Nixpi targets one Pi.
4. **Immature ecosystem** — Dendrix/Denful are WIP. No production-grade modules to leverage.
5. **Extra abstraction** — Would add flake-parts + dendritic tooling (import-tree, flake-aspects) for no clear gain.

---

## Comparison Matrix

| Criterion                | Current Nixpi               | + flake-parts                              | + dendritic                                  |
| ------------------------ | --------------------------- | ------------------------------------------ | -------------------------------------------- |
| **flake.nix complexity** | 120 lines, manageable       | Split across files, slightly less per-file | Same as flake-parts + pattern overhead       |
| **System enumeration**   | `forAllSystems` (6 lines)   | Built-in `perSystem`                       | Same as flake-parts                          |
| **Module organization**  | Already modular (8 modules) | Same modules, better flake-level split     | Overkill — only 1 config class               |
| **Ecosystem access**     | Manual                      | treefmt, pre-commit-hooks, devenv          | Dendrix (immature)                           |
| **New dependencies**     | 0                           | 1 (flake-parts)                            | 3+ (flake-parts, import-tree, flake-aspects) |
| **Multi-host ready**     | N/A (single Pi)             | Slightly better                            | Yes, but not needed                          |
| **Debugging ease**       | Direct Nix, clear errors    | Module system indirection                  | More indirection                             |
| **Migration effort**     | None                        | Low-medium (1-2 hours)                     | Medium-high (half day+)                      |

---

## Recommendation

### Dendritic: **No** — not a fit for Nixpi

Dendritic solves a problem Nixpi doesn't have (cross-class configuration spanning NixOS + home-manager + darwin across multiple hosts). Nixpi is a single-host, single-class (NixOS-only) project that already uses feature-based module organization. Adopting dendritic would add complexity without corresponding benefit.

### Flake-parts: **Not yet** — marginal benefit today, reconsider later

The current `flake.nix` is 120 lines and well-organized. The main gains from flake-parts would be:

- Eliminating ~6 lines of `forAllSystems` boilerplate
- Splitting the 18 check definitions into a separate file
- Access to ecosystem modules (treefmt, pre-commit-hooks)

These are real but modest benefits that don't justify the migration cost and added abstraction layer today. The project's resilience and maintainability are already well-served by:

- The `mk-nixpi-service.nix` factory (DRY service definitions)
- Feature-based NixOS modules with clear option interfaces
- 18 VM integration tests with comprehensive coverage
- Clean hexagonal architecture

**Reconsider flake-parts when:**

- `flake.nix` grows past ~250 lines
- You add a third system architecture (e.g., aarch64-darwin for macOS dev)
- You want to publish reusable `flakeModules` for other projects
- You need ecosystem modules like treefmt-nix or devenv
