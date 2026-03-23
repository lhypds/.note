import os
import re
import argparse
from dotenv import load_dotenv

load_dotenv()
USE_NSFW_FILTER = os.getenv("USE_NSFW_FILTER", "true").lower() == "true"


def replace_spaces(line):
    # This function will be used as the replacement function in re.sub.
    # It takes a match object as argument,
    # returns a string of an underscore and spaces of length one less than the match
    def replacer(match):
        # Get the matched string
        s = match.group()
        # Return the replacement string
        return " " + " " * (len(s) - 1)

    # Use re.sub with replacer as the replacement function
    line = re.sub(" {2,}", replacer, line)
    return line


def prefix_tofu(line):
    return "□" + line


def convert_to_markdown(input_file, output_file, preview=False):
    print(f"{input_file}")

    # Read
    with open(input_file, "r", encoding="UTF8") as infile:
        lines = infile.readlines()

    # Process
    output_lines = []
    preview_lines = {} if preview else None

    # Pre-process lines
    p = 0
    while p < len(lines):
        lines[p] = lines[p].rstrip("\n").rstrip("\r")
        p += 1

    p = 0
    while p < len(lines):
        line_orig = lines[p]  # store the original line
        line = line_orig
        if preview:
            actions = []

        # Pre-process whitespaces
        # replace the leading spaces with code block
        if line.startswith(" "):
            leading_ws_count = len(line) - len(line.lstrip())
            original_leading = line[0:leading_ws_count]
            replaced_leading = original_leading.replace(" ", "░")
            line = replaced_leading + line[leading_ws_count:]
            if preview:
                actions.append(f"leading_whitespace_░")

        # replace space with non-breaking space
        # alt 0 1 6 0 or alt 2 5 5 or option space on mac
        before_replace_spaces = line
        line = replace_spaces(line)
        if line != before_replace_spaces:
            if preview:
                actions.append(f"replace_spaces")

        # Output line
        output_line = ""
        add_2_spaces = True

        if not line:  # If line is empty, do nothing
            output_line = ""

        # if next line is all '=' or all '-' and same length,
        # current line is a title/section title, do nothing
        elif (
            p < len(lines) - 1
            and (
                lines[p + 1].replace("=", "") == ""
                or lines[p + 1].replace("-", "") == ""
            )
            and len(lines[p]) == len(lines[p + 1])  # same length as next line
        ):
            output_line = line
            add_2_spaces = False
            if preview:
                actions.append("title_or_section_title")

        # if the current line has only '-' or '=' and not the same width as previous line,
        # add zero-width space to prevent it from being a title
        elif (line.replace("-", "") == "" or line.replace("=", "") == "") and (
            p == 0 or len(line) != len(lines[p - 1].replace("\n", ""))
        ):
            output_line = prefix_tofu(line)
            if preview:
                actions.append(f"prefix_tofu")

        # if the current line has only '-' or '=' and has same width as previous line
        # it is a title underline
        elif (line.replace("-", "") == "" or line.replace("=", "") == "") and (
            p == 0 or len(line) == len(lines[p - 1].replace("\n", ""))
        ):
            output_line = line
            add_2_spaces = False
            if preview:
                actions.append("title_underline")

        # if the line starts with > it is a blockquote in markdown, escape it
        elif line.startswith(">"):
            output_line = prefix_tofu(line)
            if preview:
                actions.append("prefix_tofu,escape_blockquote")

        # if line.trim() start with # then it is not a title in markdown, escape it
        elif line.startswith("#"):
            output_line = prefix_tofu(line)
            if preview:
                actions.append(f"prefix_tofu,escape_#")

        # if the line.trim() starts with $ it is not a fomular in markdown, escape it
        elif line.startswith("$"):
            output_line = prefix_tofu(line)
            if preview:
                actions.append(f"prefix_tofu,escape_$")

        else:
            output_line = line

        # Output lines append
        # Add two spaces to all not empty lines
        if add_2_spaces:
            if preview:
                actions.append("add_2_spaces")
            output_line += "  "
        output_lines.append(output_line + "\n")

        # Preview lines append
        if preview:
            if not actions:
                actions = ["do_nothing"]
            preview_lines[p + 1] = f"[{','.join(actions)}],{line_orig},{output_line}"

        # Move pointer
        p += 1

    # Write
    with open(output_file, "w", encoding="UTF8") as outfile:
        outfile.writelines(output_lines)

    # Preview (output)
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Preview actions for one file from TARGET_DIR.",
    )
    parser.add_argument(
        "filename",
        nargs="?",
        help="Filename inside TARGET_DIR. Used with --preview to process only one file.",
    )
    args = parser.parse_args()

    # Read target directory from .env file
    input_path = os.getenv("TARGET_DIR", "./")

    # Ensure input_path is a valid directory
    if not os.path.isdir(input_path):
        print(f"Error: TARGET_DIR '{input_path}' is not a valid directory.")
        exit(1)

    # Preview file (single file)
    if args.preview and not args.filename:
        print(
            "Error: --preview requires a filename, e.g. python note_markdown.py --preview filename.txt"
        )
        exit(1)
    if args.preview and args.filename:
        filename = args.filename.strip()
        if not filename.endswith(".txt"):
            filename += ".txt"

        input_file = os.path.join(input_path, filename)
        if not os.path.isfile(input_file):
            print(
                f"Error: file '{filename}' not found inside TARGET_DIR '{input_path}'."
            )
            exit(1)

        script_dir = os.path.dirname(os.path.abspath(__file__))
        output_file = os.path.join(
            script_dir, os.path.splitext(os.path.basename(input_file))[0] + "_pr.md"
        )
        convert_to_markdown(
            input_file,
            output_file,
            preview=True,
        )
        return

    # Process files
    # Create .markdown folder in the target directory
    output_path = os.path.join(input_path, ".markdown")
    if not os.path.exists(output_path):
        os.makedirs(output_path)

    # Read filter setting from .env file
    note_filter = ["Sex", "Adult"] if USE_NSFW_FILTER else []

    for filename in os.listdir(input_path):
        # Assuming all your note files have .txt extension
        if filename.endswith(" Note.txt") and not any(
            x in filename for x in note_filter
        ):
            input_file = os.path.join(input_path, filename)
            output_file = os.path.join(output_path, filename.replace(".txt", ".md"))

            convert_to_markdown(input_file, output_file)


if __name__ == "__main__":
    main()
