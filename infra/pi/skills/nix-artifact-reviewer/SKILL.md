---
name: nix-artifact-reviewer
description: Checklist-driven review for evaluating Nix packages and npm dependencies before adoption.
---

# Nix Artifact Reviewer Skill

Use this skill when evaluating a new package (Nix, npm, or other) for adoption into the Nixpi project.

## Purpose

Ensure every dependency meets freshness, security, maintenance, and size standards before it enters the project. Enforce the Nix-first principle: prefer Nix packages over npm/pip/cargo when a suitable equivalent exists.

## Review Checklist

### 1. Nix-First Alternatives

Before adopting any non-Nix dependency, search for a Nix equivalent:

```bash
nix search nixpkgs <functionality>
```

- If a Nix package exists and covers the use case, use it instead.
- Document why the Nix alternative is or isn't suitable.

### 2. Freshness

```bash
nix eval nixpkgs#<pkg>.version   # Nix package version
```

- **Nix packages**: version must not lag upstream by more than 2 major versions.
- **npm packages**: must have been published within the last 18 months.
- Flag stale packages. `gray-matter` (last published 2019) is an example of a banned dependency.

### 3. Security

```bash
nix eval nixpkgs#<pkg>.meta.knownVulnerabilities
```

- Check for known CVEs in the package and its transitive dependencies.
- For npm packages, run `npm audit` and review findings.
- Any critical or high severity vulnerability is a blocking issue.

### 4. Maintenance

- **Maintainer count**: `nix eval nixpkgs#<pkg>.meta.maintainers` — at least 1 active maintainer required.
- **Upstream activity**: check the source repository for recent commits (within 12 months).
- **Issue/PR responsiveness**: review whether the maintainers respond to issues.

### 5. Closure Size

```bash
nix path-info -rsSh $(nix build nixpkgs#<pkg> --no-link --print-out-paths)
```

- Evaluate the closure size impact on the system.
- Flag packages that add more than 100MB to the closure without justification.
- Prefer packages with minimal transitive dependencies.

### 6. License Compatibility

- Verify license is compatible with the project (MIT, Apache-2.0, BSD preferred).
- Flag copyleft licenses (GPL) for review — they may impose constraints.

## Verdict

After completing the checklist, issue one of:

- **approve**: Package meets all criteria. Safe to adopt.
- **conditional-approve**: Package is acceptable with noted conditions (e.g., "pin to version X", "replace when Nix alternative matures").
- **reject**: Package fails one or more critical criteria. Document the reasons and suggest alternatives.

## Required Output

Produce a structured review:

```
Package: <name>
Source: <nix | npm | other>
Version: <version evaluated>

1. Nix-First: [pass | n/a | fail — alternative: <pkg>]
2. Freshness: [pass | warn — last published <date> | fail]
3. Security: [pass | fail — <CVE details>]
4. Maintenance: [pass | warn | fail]
5. Closure Size: [pass | warn — <size> | fail]
6. License: [pass | review — <license>]

Verdict: [approve | conditional-approve | reject]
Conditions: <if applicable>
```
