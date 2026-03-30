use std::fs;
use std::path::PathBuf;
use unicode_width::UnicodeWidthStr;

fn display_width(text: &str) -> usize {
    text.width()
}

pub fn run(name: &str, directory: &str) -> Result<(), String> {
    let file_name = format!("{}.txt", name);
    let file_path = PathBuf::from(directory).join(&file_name);

    let title = name;
    let title_underline = "=".repeat(display_width(title));
    let section = name;
    let section_underline = "-".repeat(display_width(section));

    let content = format!(
        "\n{}\n{}\n\n\n{}\n{}\n\n\n",
        title, title_underline, section, section_underline
    );

    fs::write(&file_path, content)
        .map_err(|e| format!("failed to write '{}': {}", file_path.display(), e))?;

    println!("Created: {}", file_path.display());
    Ok(())
}

pub fn main(argv: &[String]) {
    let mut name: Option<String> = None;
    let mut directory = ".".to_string();

    let mut i = 0usize;
    while i < argv.len() {
        match argv[i].as_str() {
            "--name" | "-n" => {
                if i + 1 < argv.len() {
                    name = Some(argv[i + 1].clone());
                    i += 2;
                } else {
                    eprintln!("Error: --name requires an argument.");
                    std::process::exit(1);
                }
            }
            "--directory" | "-d" => {
                if i + 1 < argv.len() {
                    directory = argv[i + 1].clone();
                    i += 2;
                } else {
                    eprintln!("Error: --directory requires an argument.");
                    std::process::exit(1);
                }
            }
            arg => {
                eprintln!("Error: unrecognized argument '{}'.", arg);
                std::process::exit(1);
            }
        }
    }

    let name = match name {
        Some(n) => n,
        None => {
            eprintln!("Error: no name provided.");
            std::process::exit(1);
        }
    };

    if let Err(e) = run(&name, &directory) {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}
