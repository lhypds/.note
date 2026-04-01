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


def format_note(file_path):
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

    # Ensure exactly 2 blank lines after a `===` title underline.
    i = 0
    while i < len(lines):
        trimmed = lines[i].rstrip("\r\n")
        if trimmed and trimmed.replace("=", "") == "":
            # Count blank lines immediately following the underline.
            blank_count = 0
            j = i + 1
            while j < len(lines) and lines[j].rstrip("\r\n") == "":
                blank_count += 1
                j += 1
            if blank_count < 2:
                ending = detect_line_ending(lines[i])
                blank_line = ending
                needed = 2 - blank_count
                for k in range(needed):
                    lines.insert(i + 1 + k, blank_line)
                fixed_count += needed
                i += 1 + needed + blank_count
            elif blank_count > 2:
                excess = blank_count - 2
                del lines[i + 1 : i + 1 + excess]
                fixed_count += excess
                i += 1 + 2
            else:
                i += 1 + blank_count
        else:
            i += 1

    # Ensure exactly 1 blank line after a `---` section title underline.
    i = 0
    while i < len(lines):
        trimmed = lines[i].rstrip("\r\n")
        if trimmed and trimmed.replace("-", "") == "":
            blank_count = 0
            j = i + 1
            while j < len(lines) and lines[j].rstrip("\r\n") == "":
                blank_count += 1
                j += 1
            if blank_count < 1:
                ending = detect_line_ending(lines[i])
                lines.insert(i + 1, ending)
                fixed_count += 1
                i += 1 + 1
            elif blank_count > 1:
                excess = blank_count - 1
                del lines[i + 1 : i + 1 + excess]
                fixed_count += excess
                i += 1 + 1
            else:
                i += 1 + blank_count
        else:
            i += 1

    with open(file_path, "w", encoding="UTF8") as file:
        file.writelines(lines)


def build_parser():
    parser = argparse.ArgumentParser(
        description="Fix section underline length for one note file."
    )
    parser.add_argument(
        "file_path",
        help="Target note file path.",
    )
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    file_path = os.path.abspath(args.file_path)

    if not os.path.isfile(file_path):
        print(f"Error: '{file_path}' is not a valid file.")
        raise SystemExit(1)

    format_note(file_path)
    print("Processed files: 1")


if __name__ == "__main__":
    main()
