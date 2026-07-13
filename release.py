#!/usr/bin/env python3
"""Release - Hard Reset"""

import subprocess
import sys
from pathlib import Path
from datetime import datetime

SCRIPT_DIR = Path(__file__).parent.resolve()
BUILD_BASE = SCRIPT_DIR / "build"
LINKS_DIR = SCRIPT_DIR / ".release"


def check(label, condition):
    if not condition:
        print(f"[FAIL] {label}")
        input("Press Enter...")
        sys.exit(1)
    print(f"[OK] {label}")


def run(cmd):
    print(f"  > {cmd}")
    r = subprocess.run(cmd, shell=True, cwd=SCRIPT_DIR)
    return r.returncode


def get_repo_slug():
    """Get 'owner/repo' from git remote URL."""
    r = subprocess.run(
        "git remote get-url origin",
        shell=True, capture_output=True, text=True, cwd=SCRIPT_DIR,
    )
    url = r.stdout.strip()
    # https://github.com/igetpaid/HardReset.git -> igetpaid/HardReset
    # git@github.com:igetpaid/HardReset.git -> igetpaid/HardReset
    slug = url.split("github.com:")[-1].split("github.com/")[-1]
    if slug.endswith(".git"):
        slug = slug[:-4]
    return slug


def find_latest_build():
    latest_ver = None
    latest_dir = None
    if not BUILD_BASE.exists():
        return None, None
    for d in BUILD_BASE.iterdir():
        if d.is_dir() and d.name.startswith("v"):
            ver = d.name[1:]
            if latest_ver is None or ver > latest_ver:
                latest_ver = ver
                latest_dir = d
    return latest_ver, latest_dir


def main():
    print("=" * 60)
    print("  Release - Hard Reset")
    print("=" * 60)
    print()

    # Check tools
    for tool in ["gh", "git"]:
        r = subprocess.run(f"where {tool}", shell=True, capture_output=True)
        check(tool, r.returncode == 0)

    # Find build
    print()
    ver, bdir = find_latest_build()
    check("Build found", ver)
    print(f"[OK] Build: v{ver}")

    exe = bdir / "hardreset.exe"
    apk = bdir / "hardreset.apk"

    # Check git status
    print()
    r_status = subprocess.run(
        "git status --short", shell=True, capture_output=True, text=True, cwd=SCRIPT_DIR,
    )
    r_log = subprocess.run(
        'git log -1 --format="%h %s"', shell=True, capture_output=True, text=True, cwd=SCRIPT_DIR,
    )
    dirty = r_status.stdout.strip()
    last_commit = r_log.stdout.strip()

    print(f"  Last commit: {last_commit}")
    if dirty:
        print(f"  WARNING: Uncommitted changes:")
        for line in dirty.splitlines():
            print(f"    {line}")
        print()
        print("  Tag will be created on current commit.")
        print("  Files above will NOT be in the tagged commit.")
        print()
        choice = input("  1 = Commit all changes first, 2 = Tag as-is, n = Cancel: ").strip()
        if choice == "n" or choice == "":
            print("Cancelled.")
            input("Press Enter...")
            return
        if choice == "1":
            msg = input(f"  Commit message (Enter='Release v{ver}'): ").strip()
            if not msg:
                msg = f"Release v{ver}"
            rc = run(f'git add -A')
            if rc != 0:
                print("[FAIL] git add failed")
                input("Press Enter...")
                sys.exit(1)
            rc = run(f'git commit -m "{msg}"')
            if rc != 0:
                print("[FAIL] git commit failed")
                input("Press Enter...")
                sys.exit(1)
            print("[OK] Committed")
        else:
            print("[OK] Tagging without commit")

    # Preview
    print()
    print("=" * 60)
    print("  RELEASE PREVIEW")
    print("=" * 60)
    print(f"  Version: v{ver}")
    print()
    print(f"  [EXE] {'{:,}'.format(exe.stat().st_size)} bytes" if exe.exists() else "  [EXE] MISSING")
    print(f"  [APK] {'{:,}'.format(apk.stat().st_size)} bytes" if apk.exists() else "  [APK] MISSING")

    # Tags
    print()
    r = subprocess.run(f"git tag -l v{ver}", shell=True, capture_output=True, text=True, cwd=SCRIPT_DIR)
    existing_tags = subprocess.run("git tag -l v*", shell=True, capture_output=True, text=True, cwd=SCRIPT_DIR).stdout.strip()
    if existing_tags:
        print("  Tags:")
        for t in existing_tags.splitlines():
            print(f"    {t}")
    if r.returncode == 0 and r.stdout.strip():
        print(f"  WARNING: v{ver} already tagged!")

    # Confirm
    print()
    ok = input(f"Release v{ver}? (y/n): ").strip()
    if ok.lower() not in ("y", "yes"):
        print("Cancelled.")
        input("Press Enter...")
        return

    # Tag
    print()
    if r.returncode != 0 or not r.stdout.strip():
        rc = run(f'git tag -a "v{ver}" -m "Release v{ver}"')
        print("[OK] Tagged" if rc == 0 else "[FAIL] Tag failed")
    else:
        print("[OK] Tag exists")

    # Push
    print()
    rc = run(f'git push origin "v{ver}"')
    if rc != 0:
        print("[FAIL] Push failed")
        input("Press Enter...")
        sys.exit(1)
    print("[OK] Pushed")

    # Release
    print()
    if not exe.exists():
        print("[FAIL] EXE missing")
        input("Press Enter...")
        sys.exit(1)
    if not apk.exists():
        print("[FAIL] APK missing")
        input("Press Enter...")
        sys.exit(1)

    rc = run(
        f'gh release create "v{ver}" '
        f'--title "Hard Reset v{ver}" '
        f'--notes "Hard Reset v{ver}" '
        f'"{exe}#hardreset.exe (Windows)" '
        f'"{apk}#hardreset.apk (Android)"'
    )
    if rc != 0:
        print("[FAIL] Release creation failed")
        input("Press Enter...")
        sys.exit(1)
    print("[OK] Release created")

    # Links
    print()
    slug = get_repo_slug()
    LINKS_DIR.mkdir(exist_ok=True)
    links_file = LINKS_DIR / f"{ver}_links.txt"
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    links_file.write_text(
        f"Hard Reset v{ver}\n"
        f"Date: {now}\n"
        f"\n"
        f"Release: https://github.com/{slug}/releases/tag/v{ver}\n"
        f"EXE:     https://github.com/{slug}/releases/download/v{ver}/hardreset.exe\n"
        f"APK:     https://github.com/{slug}/releases/download/v{ver}/hardreset.apk\n",
        encoding="utf-8",
    )
    print(f"[OK] Links: {links_file}")

    # Done
    print()
    print("=" * 60)
    print(f"  RELEASE COMPLETE v{ver}")
    print(f"  https://github.com/{slug}/releases/tag/v{ver}")
    print("=" * 60)
    print()
    input("Press Enter...")


if __name__ == "__main__":
    main()
