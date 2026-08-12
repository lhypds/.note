use std::fs;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use unicode_width::UnicodeWidthStr;

fn display_width(text: &str) -> usize {
    text.width()
}

fn get_main_note_path() -> Option<String> {
    let noterc = dirs::home_dir()?.join(".noterc");
    let file = fs::File::open(noterc).ok()?;
    for line in BufReader::new(file).lines().flatten() {
        if let Some(value) = line.strip_prefix("notePath=") {
            let first = value.split(';').next().unwrap_or("").trim();
            if !first.is_empty() {
                let expanded = if first.starts_with('~') {
                    let home = dirs::home_dir()?;
                    home.join(first.trim_start_matches("~/"))
                        .to_string_lossy()
                        .into_owned()
                } else {
                    first.to_string()
                };
                return Some(expanded);
            }
        }
    }
    None
}

pub fn run(topic: &str, directory: &str) -> Result<(), String> {
    let title = format!("{} Note", topic);
    let file_name = format!("{}.txt", title);
    let file_path = PathBuf::from(directory).join(&file_name);

    let title_underline = "=".repeat(display_width(&title));

    let section_underline = "-".repeat(display_width(topic));
    let section_block = format!("{}\n{}\n\n", topic, section_underline);

    let content = format!(
        "\n{}\n{}\n\n\n{}",
        title, title_underline, section_block
    );

    fs::write(&file_path, content)
        .map_err(|e| format!("failed to write '{}': {}", file_path.display(), e))?;

    println!("Created: {}", file_path.display());

    // Open the note with the system default application. The note is written
    // either way, so failing to open it is a warning, not a failed create —
    // which is what a headless machine with no $EDITOR gets.
    if let Err(e) = super::opener::open_path(&file_path) {
        eprintln!("{}", e);
    }

    Ok(())
}

pub fn main(argv: &[String]) {
    let mut topic: Option<String> = None;
    let mut directory = ".".to_string();

    let mut i = 0usize;
    while i < argv.len() {
        match argv[i].as_str() {
            "--directory" | "-d" => {
                if i + 1 < argv.len() {
                    directory = argv[i + 1].clone();
                    i += 2;
                } else {
                    eprintln!("Error: --directory requires an argument.");
                    std::process::exit(1);
                }
            }
            arg if !arg.starts_with('-') => {
                topic = Some(arg.to_string());
                i += 1;
            }
            arg => {
                eprintln!("Error: unrecognized argument '{}'.", arg);
                std::process::exit(1);
            }
        }
    }

    let topic = match topic {
        Some(t) => t,
        None => {
            eprintln!("Error: no topic provided.");
            std::process::exit(1);
        }
    };

    if directory == "." {
        if let Some(note_path) = get_main_note_path() {
            directory = note_path;
        }
    }

    if let Err(e) = run(&topic, &directory) {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}
