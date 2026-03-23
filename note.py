import argparse
import os
import unicodedata


def display_width(text):
    width = 0
    for ch in text:
        eaw = unicodedata.east_asian_width(ch)
        width += 2 if eaw in ("W", "F") else 1
    return width


def is_underline_line(text):
    if text == "":
        return False
    return text.replace("-", "") == "" or text.replace("=", "") == ""


def underline_char(text):
    return "-" if text.replace("-", "") == "" else "="


def detect_line_ending(line):
    if line.endswith("\r\n"):
        return "\r\n"
    if line.endswith("\n"):
        return "\n"
    return ""


def note(file_path):
    with open(file_path, "r", encoding="UTF8") as file:
        lines = file.readlines()

    fixed_count = 0
    max_start = len(lines) - 3

    for i in range(max_start):
        line0 = lines[i].rstrip("\r\n")
        line1 = lines[i + 1].rstrip("\r\n")
        line2 = lines[i + 2].rstrip("\r\n")
        line3 = lines[i + 3].rstrip("\r\n")

        if line0 != "":
            continue

        if line1.strip() == "":
            continue

        if not is_underline_line(line2):
            continue

        if line3 != "":
            continue

        new_underline = underline_char(line2) * display_width(line1)
        original = lines[i + 2]
        ending = detect_line_ending(original)
        new_line = new_underline + ending

        if original != new_line:
            lines[i + 2] = new_line
            fixed_count += 1

    with open(file_path, "w", encoding="UTF8") as file:
        file.writelines(lines)

    print(f"Fixed {fixed_count} underline line(s) in: {file_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Fix section underline length for one note file."
    )
    parser.add_argument(
        "--file",
        "-f",
        dest="file_path",
        help="Target note file path.",
    )
    args = parser.parse_args()

    file_path = args.file_path
    if not file_path:
        file_path = input("Enter file path: ").strip()

    if not file_path:
        print("Error: no file path provided.")
        raise SystemExit(1)

    file_path = os.path.abspath(file_path)

    if not os.path.isfile(file_path):
        print(f"Error: '{file_path}' is not a valid file.")
        raise SystemExit(1)

    note(file_path)
    print("Processed files: 1")


if __name__ == "__main__":
    main()
