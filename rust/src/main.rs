mod commands;

const HELP: &str = "Usage: note <command> [options]

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
              -d, --directory <dir>   Directory to create the file in. Default: ../";

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
        "format" => commands::format::main(command_args),
        "markdown" => commands::markdown::main(command_args),
        "create" => commands::create::main(command_args),
        // fallback: treat all args as format arguments (e.g. note -f file.txt)
        _ => commands::format::main(argv),
    }
}
