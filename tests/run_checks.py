"""Simple test runner that invokes `recommend_prompts` over the sample manifest and sample_src.
This is not a pytest-based test to avoid extra dependencies; it asserts expected output files exist.
"""
from pathlib import Path
import sys
import importlib

root = Path(__file__).resolve().parent.parent
sample_manifest = str(root / "tests" / "sample_manifest.txt")
sample_src = str(root / "tests" / "sample_src")

def run_with(args_list):
    sys.argv = ["recommend_prompts.py"] + args_list
    import recommend_prompts
    importlib.reload(recommend_prompts)
    rc = recommend_prompts.main()
    return rc

def assert_out(dirpath: Path):
    assert dirpath.exists(), f"Output dir missing: {dirpath}"
    expected = [
        "analysis.json",
        "summary.txt",
        "install_list.txt",
    ]
    for name in expected:
        p = dirpath / name
        assert p.exists(), f"Missing expected output file: {p}"

def main():
    out_auto = Path("out_auto")
    out_safe = Path("out_safe")
    out_full = Path("out_full")

    rc = run_with(["--manifest", sample_manifest, "--source-dir", sample_src, "--target-home", str(Path.home()), "--output-dir", str(out_auto), "--profile", "auto"])
    print('auto rc', rc)
    assert_out(out_auto)

    rc = run_with(["--manifest", sample_manifest, "--source-dir", sample_src, "--target-home", str(Path.home()), "--output-dir", str(out_safe), "--profile", "safe"])
    print('safe rc', rc)
    assert_out(out_safe)

    rc = run_with(["--manifest", sample_manifest, "--source-dir", sample_src, "--target-home", str(Path.home()), "--output-dir", str(out_full), "--profile", "full", "--include-critical", "--include-not-needed"])
    print('full rc', rc)
    assert_out(out_full)

    print('All checks passed.')

if __name__ == '__main__':
    main()
