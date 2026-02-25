#!/usr/bin/env python3
"""
Component-aware prompt recommender for exported prompt packages.

Creates install recommendation lists and validation reports:
- recommended.txt
- system_critical.txt
- not_needed.txt
- optional_unmatched.txt
- install_list.txt
- invalid_entries.txt
- missing_files.txt
- summary.txt
- analysis.json
"""

from __future__ import annotations

import argparse
import glob
import json
from pathlib import Path
from typing import Dict, List, Tuple


COMPONENTS: Tuple[str, ...] = (
    "roo_code",
    "skill_code_agent",
    "skill_ip_config_manager",
    "prompt_agent_workspace",
    "aidrax_agent_standards",
    "enterprise_prompts",
    "general",
)


def parse_args(argv: List[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Recommend prompt files for install.")
    parser.add_argument("--manifest", required=True, help="Path to prompt manifest file")
    parser.add_argument("--source-dir", required=True, help="Root folder of package files")
    parser.add_argument("--target-home", required=True, help="Target home directory")
    parser.add_argument("--output-dir", required=True, help="Report output directory")
    parser.add_argument(
        "--profile",
        default="auto",
        choices=("safe", "auto", "full"),
        help="Recommendation profile",
    )
    parser.add_argument(
        "--include-critical",
        action="store_true",
        help="Include system-critical files in install list",
    )
    parser.add_argument(
        "--include-not-needed",
        action="store_true",
        help="Include tests/snapshots in install list",
    )
    return parser.parse_args(argv)


def is_not_needed(rel: str) -> bool:
    return "/__tests__/" in rel or rel.endswith(".spec.ts") or rel.endswith(".snap")


def is_system_critical(rel: str) -> bool:
    lower = rel.lower()
    if lower.endswith((".ts", ".js", ".py", ".sh")):
        return True
    if lower.startswith("roo-code/src/"):
        return True
    if lower.startswith("roo-code/webview-ui/src/components/"):
        return True
    return False


def is_prompt_content(rel: str) -> bool:
    lower = rel.lower()
    filename = Path(rel).name.lower()
    if "/prompts/" in lower or "/templates/" in lower:
        return True
    if "prompt" in filename:
        return True
    if lower.endswith("system_prompt.txt"):
        return True
    if lower.endswith("support-prompt.ts"):
        return True
    return False


def classify_component(rel: str) -> str:
    lower = rel.lower()

    if lower.startswith("roo-code/") or "/roo-code/" in lower:
        return "roo_code"
    if (
        lower.startswith("skills/code-agent/")
        or "/skills/code-agent/" in lower
        or "/aidrax-core-skills/skills/code-agent/" in lower
    ):
        return "skill_code_agent"
    if (
        lower.startswith("skills/ip-config-manager/")
        or "/skills/ip-config-manager/" in lower
        or "/aidrax-core-skills/skills/ip-config-manager/" in lower
    ):
        return "skill_ip_config_manager"
    if "aidrax_prompt_und_agenten/" in lower:
        return "prompt_agent_workspace"
    if "/aidrax-agent/standards/" in lower or lower.startswith("downloads/aidrax-agent/standards/"):
        return "aidrax_agent_standards"
    if "/aidrax-enterprise/prompts/" in lower or lower.startswith("aidrax-enterprise/prompts/"):
        return "enterprise_prompts"
    return "general"


def detect_components(target_home: Path) -> Dict[str, bool]:
    root = target_home.resolve()

    checks: Dict[str, List[str]] = {
        "roo_code": [
            "Roo-Code",
            "home/*/Roo-Code",
            "projects/Roo-Code",
            "data2/projects/Roo-Code",
        ],
        "skill_code_agent": [
            "skills/code-agent",
            "home/*/skills/code-agent",
            "Downloads/aidrax-core-skills/skills/code-agent",
            "home/*/Downloads/aidrax-core-skills/skills/code-agent",
            "data2/projects/aidrax-core-skills/skills/code-agent",
        ],
        "skill_ip_config_manager": [
            "skills/ip-config-manager",
            "home/*/skills/ip-config-manager",
            "Downloads/aidrax-core-skills/skills/ip-config-manager",
            "home/*/Downloads/aidrax-core-skills/skills/ip-config-manager",
            "data2/projects/aidrax-core-skills/skills/ip-config-manager",
        ],
        "prompt_agent_workspace": [
            "Dokumente/aidrax_prompt_und_agenten",
            "home/*/Dokumente/aidrax_prompt_und_agenten",
        ],
        "aidrax_agent_standards": [
            "aidrax-agent/standards",
            "Downloads/aidrax-agent/standards",
            "home/*/Downloads/aidrax-agent/standards",
            "data2/projects/aidrax-agent/standards",
        ],
        "enterprise_prompts": [
            "aidrax-enterprise/prompts",
            "home/*/aidrax-enterprise/prompts",
            "data2/projects/aidrax-enterprise/prompts",
        ],
        "general": ["."],
    }

    result: Dict[str, bool] = {}
    for name, patterns in checks.items():
        found = False
        for pattern in patterns:
            full_pattern = str(root / pattern)
            if glob.glob(full_pattern):
                found = True
                break
        result[name] = found
    return result


def is_valid_relative_path(rel: str) -> bool:
    if not rel.strip():
        return False
    if rel.startswith("/"):
        return False
    path = Path(rel)
    if any(part == ".." for part in path.parts):
        return False
    return True


def write_list(path: Path, values: List[str]) -> None:
    path.write_text("\n".join(values) + ("\n" if values else ""), encoding="utf-8")


def main() -> int:
    args = parse_args()

    manifest_path = Path(args.manifest).resolve()
    source_dir = Path(args.source_dir).resolve()
    target_home = Path(args.target_home).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    if not manifest_path.is_file():
        raise SystemExit(f"Manifest not found: {manifest_path}")
    if not source_dir.is_dir():
        raise SystemExit(f"Source directory not found: {source_dir}")
    if not target_home.is_dir():
        raise SystemExit(f"Target home not found: {target_home}")

    detected = detect_components(target_home)

    recommended: List[str] = []
    critical: List[str] = []
    not_needed: List[str] = []
    optional_unmatched: List[str] = []
    install_list: List[str] = []
    invalid_entries: List[str] = []
    missing_files: List[str] = []

    raw_lines = manifest_path.read_text(encoding="utf-8").splitlines()
    total_nonempty = 0

    for raw in raw_lines:
        rel = raw.strip()
        if not rel:
            continue
        if rel.startswith("#"):
            continue
        total_nonempty += 1

        if not is_valid_relative_path(rel):
            invalid_entries.append(rel)
            continue

        source_file = source_dir / rel
        if not source_file.is_file():
            missing_files.append(rel)
            continue

        component = classify_component(rel)
        component_detected = detected.get(component, False)
        noncritical = not is_system_critical(rel)
        useful = not is_not_needed(rel)

        if is_not_needed(rel):
            not_needed.append(rel)
            if args.include_not_needed or args.profile == "full":
                install_list.append(rel)
            continue

        if is_system_critical(rel):
            critical.append(rel)
            if args.include_critical or args.profile == "full":
                install_list.append(rel)
            continue

        should_install = False
        if args.profile == "full":
            should_install = True
        elif args.profile == "auto":
            should_install = component_detected or component == "general"
        elif args.profile == "safe":
            should_install = (component_detected or component == "general") and is_prompt_content(
                rel
            )

        if component != "general" and not component_detected and noncritical and useful:
            optional_unmatched.append(rel)

        if should_install:
            recommended.append(rel)
            install_list.append(rel)

    # Keep deterministic order, deduplicate, preserve original order.
    def dedupe(values: List[str]) -> List[str]:
        seen = set()
        out: List[str] = []
        for value in values:
            if value in seen:
                continue
            seen.add(value)
            out.append(value)
        return out

    recommended = dedupe(recommended)
    critical = dedupe(critical)
    not_needed = dedupe(not_needed)
    optional_unmatched = dedupe(optional_unmatched)
    install_list = dedupe(install_list)
    invalid_entries = dedupe(invalid_entries)
    missing_files = dedupe(missing_files)

    write_list(output_dir / "recommended.txt", recommended)
    write_list(output_dir / "system_critical.txt", critical)
    write_list(output_dir / "not_needed.txt", not_needed)
    write_list(output_dir / "optional_unmatched.txt", optional_unmatched)
    write_list(output_dir / "install_list.txt", install_list)
    write_list(output_dir / "invalid_entries.txt", invalid_entries)
    write_list(output_dir / "missing_files.txt", missing_files)

    detected_components = [name for name in COMPONENTS if detected.get(name, False)]
    missing_components = [name for name in COMPONENTS if not detected.get(name, False)]

    summary = {
        "profile": args.profile,
        "total_in_manifest": total_nonempty,
        "recommended_count": len(recommended),
        "system_critical_count": len(critical),
        "not_needed_count": len(not_needed),
        "optional_unmatched_count": len(optional_unmatched),
        "install_count": len(install_list),
        "invalid_entry_count": len(invalid_entries),
        "missing_file_count": len(missing_files),
        "detected_components": detected_components,
        "missing_components": missing_components,
        "include_critical": args.include_critical,
        "include_not_needed": args.include_not_needed,
    }

    summary_txt = [
        f"Profile:              {summary['profile']}",
        f"Total in manifest:    {summary['total_in_manifest']}",
        f"Recommended:          {summary['recommended_count']}",
        f"System-critical:      {summary['system_critical_count']}",
        f"Not-needed:           {summary['not_needed_count']}",
        f"Optional-unmatched:   {summary['optional_unmatched_count']}",
        f"Planned for install:  {summary['install_count']}",
        f"Invalid entries:      {summary['invalid_entry_count']}",
        f"Missing files:        {summary['missing_file_count']}",
        "Detected components:  "
        + (", ".join(detected_components) if detected_components else "(none)"),
        "Missing components:   "
        + (", ".join(missing_components) if missing_components else "(none)"),
    ]
    (output_dir / "summary.txt").write_text("\n".join(summary_txt) + "\n", encoding="utf-8")
    (output_dir / "analysis.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
