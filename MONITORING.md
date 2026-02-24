# Prompt-System Monitoring

Dieser Ordner nutzt einen festen `systemd --user` Timer fuer regelmaessige Drift-Checks.

## Komponenten

- Service: `prompt-system-analyze.service`
- Timer: `prompt-system-analyze.timer`
- Check-Script: `bin/run_analyze_check.sh`

## Was wird geprueft

Bei jedem Lauf wird `install_prompts.sh --analyze-only` ausgefuehrt und die aktuelle
`analysis.json` gegen die gespeicherte Baseline verglichen.

Abweichungen (Drift) werden gemeldet bei:

- Anzahl Manifest-Eintraege
- `recommended/system_critical/not_needed/optional_unmatched`
- `install_count`
- `invalid_entry_count`
- `missing_file_count`
- erkannte / fehlende Komponenten

## Status- und Log-Dateien

- Baseline: `monitor/baseline_auto_root.json`
- Aktueller Zustand: `monitor/current_auto_root.json`
- Pending bei Drift: `monitor/pending_auto_root.json`
- Diff: `monitor/last_diff_auto_root.txt`
- Alerts: `monitor/alerts.log`
- History: `monitor/history.log`
- Lauf-Logs: `monitor/logs/`

## Bedienung

```bash
# manueller Check
./bin/run_analyze_check.sh --profile auto --target-home /

# Baseline bewusst aktualisieren (wenn Aenderung gewollt ist)
./bin/run_analyze_check.sh --profile auto --target-home / --accept-current

# systemd units installieren (user-level)
./bin/install_systemd_user.sh

# Timer-Status
systemctl --user status prompt-system-analyze.timer
systemctl --user list-timers --all | rg prompt-system-analyze
journalctl --user -u prompt-system-analyze.service -n 100 --no-pager
```
