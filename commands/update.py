import json
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile

GITHUB_API_URL = "https://api.github.com/repos/lhypds/.note/releases/latest"


def get_current_version_and_build():
    """Run 'note --version' and parse version + build type."""
    try:
        result = subprocess.run(
            ["note", "--version"],
            capture_output=True,
            text=True,
            check=True,
        )
        output = result.stdout.strip()
    except FileNotFoundError:
        print("Error: 'note' command not found in PATH.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error: 'note --version' failed: {e}")
        sys.exit(1)

    # Expected format: "v0.0.6 (python)"  or  "v0.0.6 (rust)"
    parts = output.split()
    if not parts:
        print(f"Error: unexpected output from 'note --version': {output!r}")
        sys.exit(1)

    version = parts[0].lstrip("v")
    build_type = "python"
    if len(parts) >= 2:
        build_type = parts[1].strip("()")

    return version, build_type


def parse_version(version_str):
    """Return a tuple of ints for semver comparison, e.g. '0.0.6' -> (0, 0, 6)."""
    return tuple(int(x) for x in version_str.lstrip("v").split("."))


def get_latest_release():
    """Fetch the latest GitHub release metadata."""
    req = urllib.request.Request(
        GITHUB_API_URL,
        headers={"User-Agent": "note-updater"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        print(f"Error: could not fetch latest release from GitHub: {e}")
        sys.exit(1)


def find_asset_url(assets, filename):
    """Return the browser_download_url for the named asset, or None."""
    for asset in assets:
        if asset["name"] == filename:
            return asset["browser_download_url"]
    return None


def download_file(url, dest_path):
    """Download url → dest_path, showing a simple progress indicator."""
    print(f"  Downloading {os.path.basename(dest_path)} ...")
    req = urllib.request.Request(url, headers={"User-Agent": "note-updater"})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            total = int(response.headers.get("Content-Length", 0))
            downloaded = 0
            chunk_size = 65536
            with open(dest_path, "wb") as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        pct = downloaded * 100 // total
                        print(f"\r  Progress: {pct}%", end="", flush=True)
        print()
    except Exception as e:
        print(f"\nError: download failed: {e}")
        sys.exit(1)


def extract_archive(archive_path, extract_dir):
    """Extract a zip archive (with or without .zip extension)."""
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    print(f"  Extracting to {extract_dir} ...")
    try:
        with zipfile.ZipFile(archive_path, "r") as zf:
            zf.extractall(extract_dir)
    except zipfile.BadZipFile as e:
        print(f"Error: archive is not a valid zip file: {e}")
        sys.exit(1)


def find_install_sh(base_dir):
    """Walk base_dir and return the path to the first install.sh found."""
    for root, _dirs, files in os.walk(base_dir):
        if "install.sh" in files:
            return os.path.join(root, "install.sh")
    return None


def main(argv=None):
    argv = list(argv or [])
    force = "-f" in argv or "--force" in argv

    # ── 1. Current version ────────────────────────────────────────────────────
    current_version, build_type = get_current_version_and_build()
    print(f"Current version : v{current_version} ({build_type})")

    # ── 2. Latest release ─────────────────────────────────────────────────────
    print("Checking for updates ...")
    release = get_latest_release()
    latest_tag = release.get("tag_name", "")
    latest_version = latest_tag.lstrip("v")
    print(f"Latest version  : v{latest_version}")

    # ── 3. Compare ────────────────────────────────────────────────────────────
    try:
        current_tuple = parse_version(current_version)
        latest_tuple = parse_version(latest_version)
    except ValueError:
        print("Error: could not parse version numbers.")
        sys.exit(1)

    if current_tuple >= latest_tuple:
        if not force:
            print("Already up to date.")
            return
        print("Already up to date, but forcing reinstall.")

    print(f"Update available : v{current_version} → v{latest_version}")

    # ── 4. Resolve asset filename ─────────────────────────────────────────────
    if build_type == "python":
        asset_filename = f"dot_note_python_v{latest_version}.zip"
    else:
        asset_filename = f"dot_note_rust_v{latest_version}.zip"

    download_url = find_asset_url(release.get("assets", []), asset_filename)
    if not download_url:
        print(f"Error: release asset '{asset_filename}' not found in latest release.")
        available = [a["name"] for a in release.get("assets", [])]
        if available:
            print("  Available assets: " + ", ".join(available))
        sys.exit(1)

    # ── 5. Create updates directory ───────────────────────────────────────────
    updates_dir = os.path.expanduser("~/.note/updates")
    os.makedirs(updates_dir, exist_ok=True)

    archive_path = os.path.join(updates_dir, asset_filename)

    # ── 6. Download ───────────────────────────────────────────────────────────
    download_file(download_url, archive_path)

    # ── 7. Extract ────────────────────────────────────────────────────────────
    extract_dir = os.path.join(updates_dir, f"note_v{latest_version}")
    extract_archive(archive_path, extract_dir)

    # ── 8. Find and run install.sh ────────────────────────────────────────────
    install_sh = find_install_sh(extract_dir)
    if not install_sh:
        print("Error: install.sh not found inside the extracted archive.")
        sys.exit(1)

    os.chmod(install_sh, 0o755)
    print(f"  Running install.sh ...")
    result = subprocess.run(
        ["bash", install_sh],
        cwd=os.path.dirname(install_sh),
    )
    if result.returncode != 0:
        print(f"Error: install.sh exited with code {result.returncode}.")
        sys.exit(result.returncode)

    print(f"\nnote has been updated to v{latest_version}.")
