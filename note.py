import sys

from commands import create as create_command
from commands import format as format_command
from commands import markdown as markdown_command


HELP = """Usage: note <command> [options]

Commands:
  format    Fix section underline lengths in a note file.

            note format -f <file>

            Options:
              -f, --file <file>       Target note file path.

  markdown  Convert a note file to Markdown.
            Output is written to a .markdown/ folder next to the input file.

            note markdown -f <file> [--preview]

            Options:
              -f, --file <file>       Path to the .txt file to process.
              --preview               Also write a preview action log file.

  create    Create a new note file.

            note create -n <name> [-d <directory>]

            Options:
              -n, --name <name>       Name of the note. Creates '<name> Note.txt'.
              -d, --directory <dir>   Directory to create the file in. Default: ../
"""


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)

    if not argv:
        print(HELP)
        return

    command = argv[0]
    command_args = argv[1:]

    if command in ("-h", "--help"):
        print(HELP)
        return

    if command == "create":
        create_command.main(command_args)
        return

    if command == "format":
        format_command.main(command_args)
        return

    if command == "markdown":
        markdown_command.main(command_args)
        return

    format_command.main(argv)


if __name__ == "__main__":
    main()
