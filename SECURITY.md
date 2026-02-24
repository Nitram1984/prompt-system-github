# Security Notes

## Scope

Dieses Repository enthaelt Tooling fuer Prompt-Analyse und Deployment.
Es soll ohne persoenliche Daten betrieben und veroeffentlicht werden.

## Safe Usage

- Committe keine sensiblen Prompt-Inhalte oder Secrets.
- Verwende nur relative, nicht-sensitive Pfade im `prompt_manifest.txt`.
- Pruefe `precheck/` Reports vor jedem produktiven Install.
- Nutze zuerst `--analyze-only` und `--dry-run`.

## Monitoring

- Drift-Monitoring sollte aktiv sein (`systemd --user` Timer).
- Bei Drift: `monitor/last_diff_*.txt` pruefen, dann nur bewusst Baseline uebernehmen.

## Disclosure

Wenn du ein Sicherheitsproblem im Tooling findest, eroefne ein privates Security-Issue
oder melde es direkt an den Maintainer, bevor Details oeffentlich geteilt werden.
