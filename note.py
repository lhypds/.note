import os
import sys

from commands import create as create_command
from commands import format as format_command
from commands import markdown as markdown_command
from commands import search as search_command
from commands import update as update_command

_VERSION_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "VERSION")
VERSION = open(_VERSION_FILE).read().strip()

HELP = """Usage: note <command> [options]

Commands:
  search    Search note content using fzf across paths in ~/.noterc.

            note search

  create    Create a new note file.

            note create <name> [-d <directory>]

            Arguments:
              <name>                  Basename of the note file.
                                     e.g. 'ABC Note' creates 'ABC Note.txt'.
            Options:
              -d, --directory <dir>   Directory to create the file in. Default: .

  format    Fix section underline lengths in a note file.

            note format <file>

            Arguments:
              <file>                  Target note file path.

  markdown  Convert a note file to Markdown.
            Output is written to a .markdown/ folder in the current directory.

            note markdown <file> [--preview]

            Arguments:
              <file>                  Path to the .txt file to process.
            Options:
              --preview               Also write a preview action log file.

  update    Check for a newer release on GitHub and install it if available.

            note update [-f]

            Options:
              -f, --force             Reinstall even if already on the latest version.
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

    if command in ("-v", "--version"):
        print(f"v{VERSION} (python)")
        return

    if command == "search":
        search_command.main()
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

    if command == "update":
        update_command.main(command_args)
        return


if __name__ == "__main__":
    main()
