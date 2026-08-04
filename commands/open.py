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


def collect_txt_files(dirs):
    files = []
    for d in dirs:
        for root, _, names in os.walk(d):
            for name in names:
                if name.endswith(".txt"):
                    files.append(os.path.join(root, name))
    return files


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

    files = collect_txt_files(existing)
    if not files:
        print("No note files found.", file=sys.stderr)
        sys.exit(1)

    entries = [f"{os.path.basename(path)}\t{path}" for path in files]

    fzf_cmd = [
        "fzf",
        "--ansi",
        "--delimiter", "\t",
        "--with-nth", "1",
        "--header", "Type to search note name",
    ]

    try:
        result = subprocess.run(
            fzf_cmd, input="\n".join(entries), text=True, stdout=subprocess.PIPE
        )
    except FileNotFoundError:
        print("fzf not found. Please install fzf to use the open command.", file=sys.stderr)
        sys.exit(1)

    selected = result.stdout.strip()
    if result.returncode == 0 and selected:
        open_file(selected.split("\t")[-1])


if __name__ == "__main__":
    main()
