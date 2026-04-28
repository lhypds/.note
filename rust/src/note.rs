mod commands;

const HELP: &str = "Usage: note <command> [options]

Commands:
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

  update    Update note to the latest release from GitHub.

            note update [-f]

            Options:
              -f, --force             Reinstall even if already up to date.";

const VERSION: &str = env!("APP_VERSION");

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let argv = &args[1..];

    if argv.is_empty() {
        println!("{}", HELP);
        return;
    }

    let command = argv[0].as_str();
    let command_args = &argv[1..];

    match command {
        "-h" | "--help" => println!("{}", HELP),
        "-v" | "--version" => println!("v{} (rust)", VERSION),
        "format" => commands::format::main(command_args),
        "markdown" => commands::markdown::main(command_args),
        "create" => commands::create::main(command_args),
        "update" => commands::update::main(command_args),
        _ => {}
    }
}
