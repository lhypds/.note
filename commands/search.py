import os
import subprocess
import sys


def parse_noterc():
    noterc = os.path.expanduser("~/.noterc")
    paths = []
    if not os.path.exists(noterc):
        return paths
    with open(noterc, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("notePath="):
                value = line[len("notePath="):]
                for p in value.split(";"):
                    p = p.strip()
                    if p:
                        paths.append(os.path.expanduser(p))
    return paths


def open_file(path):
    platform = sys.platform
    if platform == "darwin":
        subprocess.run(["open", path])
    elif platform == "win32":
        os.startfile(path)  # type: ignore[attr-defined]
    else:
        subprocess.run(["xdg-open", path])


def main():
    paths = parse_noterc()
    if not paths:
        print("No notePath entries found in ~/.noterc", file=sys.stderr)
        sys.exit(1)

    existing = [p for p in paths if os.path.isdir(p)]
    if not existing:
        print("None of the notePath directories exist.", file=sys.stderr)
        sys.exit(1)

    quoted = " ".join(f"'{p}'" for p in existing)
    reload_cmd = (
        f"grep -r --include='*.txt' -l {{q}} {quoted} 2>/dev/null || true"
    )

    initial = subprocess.run(
        ["grep", "-r", "--include=*.txt", "-l", "", *existing],
        capture_output=True, text=True
    )

    fzf_cmd = [
        "fzf",
        "--ansi",
        "--disabled",
        "--query", "",
        "--bind", f"change:reload:{reload_cmd}",
        "--preview", "grep -n --color=always {q} {}",
        "--preview-window", "right:60%:wrap",
        "--header", "Type to search note content",
    ]

    try:
        result = subprocess.run(fzf_cmd, input=initial.stdout, text=True, stdout=subprocess.PIPE)
    except FileNotFoundError:
        print("fzf not found. Please install fzf to use the search command.", file=sys.stderr)
        sys.exit(1)

    if result.returncode == 0 and result.stdout.strip():
        open_file(result.stdout.strip())


if __name__ == "__main__":
    main()
