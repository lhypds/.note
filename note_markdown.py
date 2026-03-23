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


def convert_to_markdown(input_file, output_file, preview=False):
    print(f"Input: {input_file}")

    # Read
    with open(input_file, "r", encoding="UTF8") as infile:
        lines = infile.readlines()

    # Process
    output_lines = []
    preview_actions_result = {} if preview else None

    p = 0
    while p < len(lines):

        line_orig = lines[p].replace("\n", "")
        line = line_orig
        actions = []

        # replace the leading spaces with code block
        if line.startswith(" "):
            leading_ws_count = len(line) - len(line.lstrip())
            original_leading = line[0:leading_ws_count]
            replaced_leading = original_leading.replace(" ", "░")
            line = replaced_leading + line[leading_ws_count:]
            actions.append(f"replace({original_leading!r},{replaced_leading!r})")

        # replace space with non-breaking space
        # alt 0 1 6 0 or alt 2 5 5 or option space on mac
        before_replace_spaces = line
        line = replace_spaces(line)
        if line != before_replace_spaces:
            actions.append(f"replace({before_replace_spaces!r},{line!r})")

        output_line = ""

        if not line:  # If line is empty, do nothing
            output_line = ""

        # if next line is all ==== then current line is title, do nothing
        elif (
            p < len(lines) - 1
            and (lines[p + 1].replace("=", "") == "")
            and len(lines[p]) == len(lines[p + 1])
        ):
            output_line = line

        # if next line is all --- then current line is section title, do nothing
        elif (
            p < len(lines) - 1
            and (lines[p + 1].replace("-", "") == "")
            and len(lines[p]) == len(lines[p + 1])
        ):
            output_line = line

        # if line.trim() start with # then it is not a title in markdown
        # it is a comment, use \# to replace #
        elif line.startswith("#"):
            output_line = "\\" + line
            actions.append(f"replace({line!r},{output_line!r})")

        # if the line.trim() starts with $ it is not a fomular in markdown
        # it is maybe a bash input, use \$ to replace the $
        elif line.startswith("$"):
            output_line = "\\" + line
            actions.append(f"replace({line!r},{output_line!r})")

        else:
            output_line = line

        if output_line == "":
            output_lines.append("\n")
        else:
            actions.append("add_2_spaces")
            output_line += "  "
            output_lines.append(output_line + "\n")

        if preview:
            if not actions:
                actions = ["do_nothing"]
            preview_actions_result[p + 1] = (
                f"[{','.join(actions)}],{line_orig},{output_line}"
            )

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
            for line_number, action_result in preview_actions_result.items():
                preview_line = f"{line_number}: {action_result}"
                preview_outfile.write(preview_line + "\n")
        return preview_actions_result


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
