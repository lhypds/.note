import os
import subprocess
import sys

from commands import opener


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
    opener.open_file(path)


def note_title(stem):
    """'Drugs Note' -> 'drugs' — the topic, as 'note create' spells it."""
    lowered = stem.lower()
    if lowered.endswith(" note"):
        lowered = lowered[: -len(" note")]
    return lowered


def is_subsequence(query, text):
    it = iter(text)
    return all(ch in it for ch in query)


def match_rank(query, path):
    """Rank a note against the query; lower is nearer, None means no match."""
    name = os.path.basename(path)
    stem = os.path.splitext(name)[0].lower()
    name = name.lower()
    title = note_title(stem)

    if title == query:
        return (0, 0)
    if stem == query or name == query:
        return (1, 0)
    if title.startswith(query) or stem.startswith(query):
        return (2, 0)
    index = stem.find(query)
    if index != -1:
        return (3, index)
    if is_subsequence(query, stem):
        return (4, 0)
    return None


def find_nearest(files, query):
    query = query.strip().lower()
    ranked = []
    for path in files:
        rank = match_rank(query, path)
        if rank is not None:
            # Shorter names are the nearer match; the path keeps ties stable.
            ranked.append((rank, len(os.path.basename(path)), path))
    if not ranked:
        return None
    return min(ranked)[2]


def main(argv=None):
    query = " ".join(argv or []).strip()

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

    if query:
        nearest = find_nearest(files, query)
        if nearest is None:
            print(f"No note matching '{query}'.", file=sys.stderr)
            sys.exit(1)
        print(f"Opening: {nearest}")
        open_file(nearest)
        return

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
