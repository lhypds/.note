import argparse
import os
import subprocess
import sys
import unicodedata


def display_width(text):
    width = 0
    for ch in text:
        eaw = unicodedata.east_asian_width(ch)
        width += 2 if eaw in ("W", "F") else 1
    return width


def create_note(name, directory="."):
    file_name = f"{name}.txt"
    file_path = os.path.join(directory, file_name)

    title = name
    title_underline = "=" * display_width(title)

    # Support `note`
    if name.endswith("Note"):
        section = name[:-5].rstrip()
        section_underline = "-" * display_width(section)
        section_block = f"{section}\n{section_underline}\n\n\n"
    else:
        section_block = ""

    content = f"\n" f"{title}\n" f"{title_underline}\n" f"\n" f"\n" f"{section_block}"

    with open(file_path, "w", encoding="UTF8") as f:
        f.write(content)

    print(f"Created: {file_path}")

    # Open the note with the system default application
    if sys.platform == "darwin":
        subprocess.run(["open", file_path])
    elif sys.platform == "win32":
        os.startfile(file_path)
    else:
        subprocess.run(["xdg-open", file_path])


def build_parser():
    parser = argparse.ArgumentParser(description="Create a new note file.")
    parser.add_argument(
        "name",
        help="Basename of the note file (e.g. 'ABC Note' creates 'ABC Note.txt').",
    )
    parser.add_argument(
        "--directory",
        "-d",
        default=".",
        help="Directory to create the note in. Defaults to current directory.",
    )
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    create_note(args.name, args.directory)


if __name__ == "__main__":
    main()
