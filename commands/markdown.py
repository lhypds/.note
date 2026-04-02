import argparse
import os
import re

from dotenv import load_dotenv

load_dotenv()


def replace_spaces(line):
    def replacer(match):
        s = match.group()
        return " " + " " * (len(s) - 1)

    line = re.sub(" {2,}", replacer, line)
    return line


def prefix_tofu(line):
    return "□" + line


def convert_to_markdown(input_file, output_file, preview=False):
    print(f"{input_file}")

    with open(input_file, "r", encoding="UTF8") as infile:
        lines = infile.readlines()

    output_lines = []
    preview_lines = {} if preview else None

    # I. Pre-process lines
    # Remove trailing newlines and carriage returns
    p = 0
    while p < len(lines):
        lines[p] = lines[p].rstrip("\n").rstrip("\r")
        p += 1

    # mark HTML blocks with ###HTML###
    VOID_ELEMENTS = {
        "div",
        "img",
    }
    p = 0
    while p < len(lines):
        line = lines[p]
        m = re.match(r"^<([a-zA-Z][a-zA-Z0-9]*)", line)
        if m:
            tag = m.group(1).lower()
            if tag in VOID_ELEMENTS:
                lines[p] = "###HTML###" + lines[p]
                p += 1
                continue
            depth = 0
            while p < len(lines):
                l = lines[p]
                depth += len(re.findall(rf"<{tag}(?:\s|>)", l, re.IGNORECASE))
                depth -= len(re.findall(rf"</{tag}\s*>", l, re.IGNORECASE))
                depth -= len(re.findall(rf"<{tag}[^>]*/>", l, re.IGNORECASE))
                lines[p] = "###HTML###" + lines[p]
                p += 1
                if depth <= 0:
                    break
            continue
        p += 1

    # II. Process lines
    p = 0
    while p < len(lines):
        line_orig = lines[p]
        line = line_orig
        if preview:
            actions = []

        if line.startswith(" "):
            leading_ws_count = len(line) - len(line.lstrip())
            original_leading = line[0:leading_ws_count]
            replaced_leading = original_leading.replace(" ", "░")
            line = replaced_leading + line[leading_ws_count:]
            if preview:
                actions.append("leading_whitespace_░")

        before_replace_spaces = line
        line = replace_spaces(line)
        if line != before_replace_spaces and preview:
            actions.append("replace_spaces")

        output_line = ""
        add_2_spaces = True

        if line_orig.startswith("###HTML###"):
            output_line = line_orig[len("###HTML###") :]
            add_2_spaces = False
            if preview:
                actions.append("do_nothing,html_block")

        elif not line:
            output_line = ""

        elif (
            p < len(lines) - 1
            and (
                lines[p + 1].replace("=", "") == ""
                or lines[p + 1].replace("-", "") == ""
            )
            and len(lines[p]) == len(lines[p + 1])
        ):
            output_line = line
            add_2_spaces = False
            if preview:
                actions.append("title_or_section_title")

        elif (line.replace("-", "") == "" or line.replace("=", "") == "") and (
            p == 0 or len(line) != len(lines[p - 1].replace("\n", ""))
        ):
            output_line = prefix_tofu(line)
            if preview:
                actions.append("prefix_tofu")

        elif (line.replace("-", "") == "" or line.replace("=", "") == "") and (
            p == 0 or len(line) == len(lines[p - 1].replace("\n", ""))
        ):
            output_line = line
            add_2_spaces = False
            if preview:
                actions.append("title_underline")

        # Escape blockquote, heading, and code line
        elif line.startswith(">"):
            output_line = prefix_tofu(line)
            if preview:
                actions.append("prefix_tofu,escape_blockquote")

        elif line.startswith("#"):
            output_line = prefix_tofu(line)
            if preview:
                actions.append("prefix_tofu,escape_#")

        elif line.startswith("$"):
            output_line = prefix_tofu(line)
            if preview:
                actions.append("prefix_tofu,escape_$")

        # Markdown image, syntax: ![alt text](image_url)
        elif re.match(r"!\[.*\]\(.*\)", line):
            output_line = line
            add_2_spaces = False
            if preview:
                actions.append("do_nothing,markdown_image")

        else:
            output_line = line

        if add_2_spaces:
            if preview:
                actions.append("add_2_spaces")
            output_line += "  "

        output_lines.append(output_line + "\n")

        if preview:
            if not actions:
                actions = ["do_nothing"]
            preview_lines[p + 1] = f"[{','.join(actions)}],{line_orig},{output_line}"

        p += 1

    with open(output_file, "w", encoding="UTF8") as outfile:
        outfile.writelines(output_lines)

    if preview:
        original_name = os.path.splitext(os.path.basename(input_file))[0]
        preview_filename = f"{original_name}_pr.txt"
        preview_output_dir = os.path.dirname(output_file)
        preview_file = os.path.join(preview_output_dir, preview_filename)
        with open(preview_file, "w", encoding="UTF8") as preview_outfile:
            for line_number, action_result in preview_lines.items():
                preview_line = f"{line_number}: {action_result}"
                preview_outfile.write(preview_line + "\n")
        return preview_lines


def build_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "file",
        help="Path to the .txt file to process.",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Preview actions for the file.",
    )
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    input_file = args.file.strip()
    if not input_file.endswith(".txt"):
        input_file += ".txt"

    if not os.path.isfile(input_file):
        print(f"Error: file '{input_file}' not found.")
        raise SystemExit(1)

    output_path = os.path.join(os.getcwd(), ".markdown")
    if not os.path.exists(output_path):
        os.makedirs(output_path)

    base = os.path.basename(input_file)
    output_file = os.path.join(output_path, os.path.splitext(base)[0] + ".md")

    convert_to_markdown(input_file, output_file, preview=args.preview)
    print("Processed files: 1")


if __name__ == "__main__":
    main()
