# Tests for `recommend_prompts.py`

This folder contains a small smoke-test setup used by the repository maintainer
for local verification of `recommend_prompts.py` behavior without external test
frameworks.

Files:

- `sample_src/` – small set of sample files used as the package source.
- `sample_manifest.txt` – a manifest listing some existing and some missing
  paths to exercise classification and missing-file handling.
- `run_checks.py` – a tiny test-runner that calls `recommend_prompts.main()` for
  profiles `auto`, `safe` and `full` and asserts that expected output files are
  created.

Usage:

```sh
python3 tests/run_checks.py
```

If you want to re-run individual scenarios, call `recommend_prompts.py` directly:

```sh
python3 recommend_prompts.py --manifest tests/sample_manifest.txt --source-dir tests/sample_src --target-home "$HOME" --output-dir out_full --profile full --include-critical --include-not-needed
```
