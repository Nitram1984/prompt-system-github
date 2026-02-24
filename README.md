# Prompt System (Sanitized)

Strukturiertes Prompt-Deployment mit Sicherheitsklassifizierung, Komponenten-Erkennung
und Drift-Monitoring via `systemd --user`.

Dieses Repo ist fuer GitHub ohne persoenliche Daten vorbereitet:

- keine absoluten Nutzerpfade im Code
- keine privaten Prompt-Inhalte im Repo
- nur Tooling + Beispiel-Manifest

## Inhalte

- `install_prompts.sh`: Analyze + Deployment mit Profilen (`safe|auto|full`)
- `recommend_prompts.py`: Klassifiziert in `recommended/system_critical/not_needed/...`
- `bin/run_analyze_check.sh`: Drift-Check gegen Baseline
- `bin/install_systemd_user.sh`: Installiert user-level service/timer
- `systemd/*.service|*.timer`: Templates fuer Monitoring
- `prompt_manifest.example.txt`: Beispiel fuer eigene Manifest-Datei
- `.github/workflows/ci.yml`: CI mit Syntax-, Lint- und Smoke-Tests
- `tests/smoke_test.sh`: End-to-End-Test fuer Analyze + Dry-Run

## Quick Start

```bash
cd prompt-system-github
cp prompt_manifest.example.txt prompt_manifest.txt
# prompt_manifest.txt mit echten relativen Zielpfaden fuellen

./install_prompts.sh --analyze-only --target-home /
./install_prompts.sh --dry-run --target-home /
```

## Deployment-Profile

- `safe`: minimale, prompt-fokussierte Auswahl
- `auto`: komponentenbasiert (empfohlen)
- `full`: alles aus dem Manifest

## systemd Monitoring

```bash
./bin/install_systemd_user.sh
systemctl --user status prompt-system-analyze.timer
```

Details: `MONITORING.md`

## Qualitaet

Jeder Push/PR auf `main` wird automatisch geprueft:

- Bash-Syntax (`bash -n`)
- Shellcheck (in CI)
- Python-Compile-Check
- End-to-End Smoke-Test (`tests/smoke_test.sh`)

## Datenschutz

- Keine privaten Prompt-Dateien einchecken.
- `prompt_manifest.txt` nur mit nicht-sensitiven relativen Pfaden versionieren.
- Laufzeitdaten (`precheck/`, `backups/`, `monitor/`) sind in `.gitignore`.

Mehr dazu: `MONITORING.md` und `SECURITY.md`.
