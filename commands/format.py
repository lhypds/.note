import argparse
import os
import unicodedata


# Common utility functions
def detect_line_ending(line):
    if line.endswith("\r\n"):
        return "\r\n"
    if line.endswith("\n"):
        return "\n"
    return ""


# ---- I. Underline length fixer -------------------------------------
def is_underline_line(text):
    if text == "":
        return False
    return text.replace("-", "") == "" or text.replace("=", "") == ""


def underline_char(text):
    return "-" if text.replace("-", "") == "" else "="


def format_underline_length(lines):
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

    return fixed_count


# ---- II. Blank line normalizer -------------------------------------
def normalize_underline_blank_lines(lines):
    fixed_count = 0
    i = 0

    while i < len(lines):
        trimmed = lines[i].rstrip("\r\n")
        if trimmed and trimmed.replace("=", "") == "":
            # === : exactly 2 blank lines after
            blank_count = 0
            j = i + 1
            while j < len(lines) and lines[j].rstrip("\r\n") == "":
                blank_count += 1
                j += 1
            if blank_count < 2:
                ending = detect_line_ending(lines[i])
                needed = 2 - blank_count
                for k in range(needed):
                    lines.insert(i + 1 + k, ending)
                fixed_count += needed
                i += 1 + needed + blank_count
            elif blank_count > 2:
                excess = blank_count - 2
                del lines[i + 1 : i + 1 + excess]
                fixed_count += excess
                i += 1 + 2
            else:
                i += 1 + blank_count
        elif trimmed and trimmed.replace("-", "") == "":
            # --- : exactly 2 blank lines before the title (line at i-1)
            if i >= 2:
                blank_count_before = 0
                k = i - 2
                while k >= 0 and lines[k].rstrip("\r\n") == "":
                    blank_count_before += 1
                    k -= 1
                if blank_count_before < 2:
                    ending = detect_line_ending(lines[i])
                    needed = 2 - blank_count_before
                    for _ in range(needed):
                        lines.insert(i - 1, ending)
                    fixed_count += needed
                    i += needed
                elif blank_count_before > 2:
                    excess = blank_count_before - 2
                    del lines[
                        i - 1 - blank_count_before : i - 1 - blank_count_before + excess
                    ]
                    fixed_count += excess
                    i -= excess
            # --- : exactly 1 blank line after
            blank_count_after = 0
            j = i + 1
            while j < len(lines) and lines[j].rstrip("\r\n") == "":
                blank_count_after += 1
                j += 1
            if blank_count_after < 1:
                ending = detect_line_ending(lines[i])
                lines.insert(i + 1, ending)
                fixed_count += 1
                i += 2
            elif blank_count_after > 1:
                excess = blank_count_after - 1
                del lines[i + 1 : i + 1 + excess]
                fixed_count += excess
                i += 2
            else:
                i += 1 + blank_count_after
        else:
            i += 1

    return fixed_count


# ---- III. Table formatter ------------------------------------------
def is_table_line(text):
    stripped = text.strip()
    return stripped.startswith("|") and stripped.endswith("|")


def parse_table_row(text):
    return [cell.strip() for cell in text.strip()[1:-1].split("|")]


def is_separator_cell(text):
    stripped = text.strip()
    if stripped == "":
        return False
    body = stripped.replace("-", "").replace(":", "")
    return body == "" and "-" in stripped


def is_separator_row(cells):
    return len(cells) > 0 and all(is_separator_cell(cell) for cell in cells)


def format_separator_cell(width, original):
    stripped = original.strip()
    left_colon = stripped.startswith(":")
    right_colon = stripped.endswith(":")
    dash_count = width + 2 - left_colon - right_colon
    if dash_count < 1:
        dash_count = 1
    return (
        (":" if left_colon else "") + ("-" * dash_count) + (":" if right_colon else "")
    )


def display_width(text):
    width = 0
    for ch in text:
        eaw = unicodedata.east_asian_width(ch)
        width += 2 if eaw in ("W", "F") else 1
    return width


def format_table(lines):
    fixed_count = 0
    i = 0

    while i < len(lines):
        current = lines[i].rstrip("\r\n")

        if not is_table_line(current):
            i += 1
            continue

        if i + 1 >= len(lines):
            i += 1
            continue

        next_line = lines[i + 1].rstrip("\r\n")
        if not is_table_line(next_line):
            i += 1
            continue

        separator_cells = parse_table_row(next_line)
        if not is_separator_row(separator_cells):
            i += 1
            continue

        start = i
        end = i + 2
        while end < len(lines) and is_table_line(lines[end].rstrip("\r\n")):
            end += 1

        raw_rows = [lines[index].rstrip("\r\n") for index in range(start, end)]
        endings = [detect_line_ending(lines[index]) for index in range(start, end)]
        rows = [parse_table_row(row) for row in raw_rows]

        column_count = max(len(row) for row in rows)
        normalized_rows = [row + [""] * (column_count - len(row)) for row in rows]

        widths = [0] * column_count
        for row_index, row in enumerate(normalized_rows):
            if row_index == 1 and is_separator_row(row):
                continue
            for column_index, cell in enumerate(row):
                widths[column_index] = max(widths[column_index], display_width(cell))

        formatted_rows = []
        for row_index, row in enumerate(normalized_rows):
            if row_index == 1 and is_separator_row(row):
                parts = [
                    format_separator_cell(widths[column_index], row[column_index])
                    for column_index in range(column_count)
                ]
            else:
                parts = []
                for column_index, cell in enumerate(row):
                    padding = widths[column_index] - display_width(cell)
                    parts.append(" " + cell + (" " * padding) + " ")
            formatted_rows.append("|" + "|".join(parts) + "|")

        for offset, formatted_row in enumerate(formatted_rows):
            new_line = formatted_row + endings[offset]
            if lines[start + offset] != new_line:
                lines[start + offset] = new_line
                fixed_count += 1

        i = end

    return fixed_count


# ---- Main formatting logic -----------------------------------------------
def format_note(file_path):
    with open(file_path, "r", encoding="UTF8") as file:
        lines = file.readlines()

    fixed_count = 0

    # I. Fix underline length
    # for title or section (`===` or `---`)
    # the underline line must be exactly the same length as the title line.
    fixed_count += format_underline_length(lines)

    # II. Normalize blank lines around underlines
    # 1. `===` title      : exactly 2 blank lines after
    # 2. `---` section    : exactly 2 blank lines before the title, exactly 1 after
    fixed_count += normalize_underline_blank_lines(lines)

    # III. Format tables to ensure consistent column widths before fixing underline lengths.
    fixed_count += format_table(lines)

    with open(file_path, "w", encoding="UTF8") as file:
        file.writelines(lines)

    print(f"Fixed {fixed_count} issues, file: {file_path}")


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
