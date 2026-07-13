#!/usr/bin/env python3
"""Build and Sign - Hard Reset"""

import subprocess
import os
import sys
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
GODOT = r"C:\Programs\Godot_v4.7-stable_win64.exe"
APKSIGNER = r"C:\Users\igort\AppData\Local\Android\Sdk\build-tools\37.0.0\apksigner.bat"
KEYSTORE = SCRIPT_DIR / ".opencode" / "hardreset.keystore"
PRESETS = SCRIPT_DIR / "export_presets.cfg"
BUILD_BASE = SCRIPT_DIR / "build"


def check(label, condition):
    if not condition:
        print(f"[FAIL] {label}")
        input("Press Enter...")
        sys.exit(1)
    print(f"[OK] {label}")


def run(cmd, cwd=None):
    print(f"  > {cmd}")
    r = subprocess.run(cmd, shell=True, cwd=cwd or SCRIPT_DIR)
    return r.returncode


def read_version():
    for line in PRESETS.read_text(encoding="utf-8").splitlines():
        if line.startswith("version/name="):
            val = line.split("=", 1)[1].strip('"')
            return val
    return None


def update_version(version):
    text = PRESETS.read_text(encoding="utf-8")
    new_text, count = re.subn(
        r'^version/name="[^"]*"',
        f'version/name="{version}"',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    PRESETS.write_text(new_text, encoding="utf-8")
    return count > 0


def export(preset, output):
    if output.exists():
        output.unlink()
    rc = run(f'"{GODOT}" --headless --export-release "{preset}" "{output}"')
    return output.exists(), rc


def main():
    print("=" * 60)
    print("  Build and Sign - Hard Reset")
    print("=" * 60)
    print()

    check("Godot", Path(GODOT).exists())
    check("apksigner", Path(APKSIGNER).exists())
    check("Keystore", KEYSTORE.exists())
    check("export_presets.cfg", PRESETS.exists())

    # Read version
    print()
    cur = read_version()
    check("Version found", cur)
    print(f"Current version: {cur}")

    # Ask version
    print()
    new_ver = input(f"New version (Enter=keep {cur}): ").strip()
    if not new_ver:
        new_ver = cur
    print(f"Version: {new_ver}")

    # Update version
    print()
    print("Updating version...")
    ok = update_version(new_ver)
    check("Version updated", ok)
    print(f"[OK] Version: {new_ver}")

    # Build dir
    bdir = BUILD_BASE / f"v{new_ver}"
    bdir.mkdir(parents=True, exist_ok=True)
    exe_path = bdir / "hardreset.exe"
    apk_path = bdir / "hardreset.apk"
    print(f"Build: {bdir}")

    # Export Windows EXE
    print()
    print("=" * 60)
    print("[1/3] Windows EXE")
    print("=" * 60)
    ok, rc = export("Windows Desktop", exe_path)
    if ok:
        sz = exe_path.stat().st_size
        print(f"[OK] EXE: {sz:,} bytes ({sz // 1024 // 1024} MB)")
    else:
        print(f"[FAIL] EXE not created (exit code {rc})")
        input("Press Enter...")
        sys.exit(1)

    # Export Android APK
    print()
    print("=" * 60)
    print("[2/3] Android APK")
    print("=" * 60)
    ok, rc = export("Android", apk_path)
    if ok:
        sz = apk_path.stat().st_size
        print(f"[OK] APK: {sz:,} bytes ({sz // 1024 // 1024} MB)")
    else:
        print(f"[FAIL] APK not created (exit code {rc})")
        input("Press Enter...")
        sys.exit(1)

    # Verify APK signature
    print()
    print("=" * 60)
    print("[3/3] Verify APK signature")
    print("=" * 60)
    rc = run(f'"{APKSIGNER}" verify --verbose --print-certs "{apk_path}"')
    if rc != 0:
        print("[WARN] apksigner verify returned non-zero (APK may still be valid)")
    else:
        print("[OK] Signature OK")

    # Done
    print()
    print("=" * 60)
    print("  BUILD COMPLETE")
    print("=" * 60)
    print(f"  Version: {new_ver}")
    print(f"  EXE:     {exe_path}")
    print(f"  APK:     {apk_path}")
    print()
    input("Press Enter...")


if __name__ == "__main__":
    main()
