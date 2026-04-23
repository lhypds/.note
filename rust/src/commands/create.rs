use std::fs;
use std::path::PathBuf;
use std::process::Command;
use unicode_width::UnicodeWidthStr;

fn display_width(text: &str) -> usize {
    text.width()
}

pub fn run(name: &str, directory: &str) -> Result<(), String> {
    let file_name = format!("{}.txt", name);
    let file_path = PathBuf::from(directory).join(&file_name);

    let title = name;
    let title_underline = "=".repeat(display_width(title));

    // Support `note`
    let section_block = if name.ends_with("Note") {
        let section = name[..name.len() - 4].trim_end();
        let section_underline = "-".repeat(display_width(section));
        format!("{}\n{}\n\n\n", section, section_underline)
    } else {
        String::new()
    };

    let content = format!(
        "\n{}\n{}\n\n\n{}",
        title, title_underline, section_block
    );

    fs::write(&file_path, content)
        .map_err(|e| format!("failed to write '{}': {}", file_path.display(), e))?;

    println!("Created: {}", file_path.display());

    // Open the note with the system default application
    #[cfg(target_os = "macos")]
    Command::new("open")
        .arg(&file_path)
        .spawn()
        .map_err(|e| format!("failed to open '{}': {}", file_path.display(), e))?;

    #[cfg(target_os = "windows")]
    Command::new("cmd")
        .args(["/c", "start", "", &file_path.to_string_lossy()])
        .spawn()
        .map_err(|e| format!("failed to open '{}': {}", file_path.display(), e))?;

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    Command::new("xdg-open")
        .arg(&file_path)
        .spawn()
        .map_err(|e| format!("failed to open '{}': {}", file_path.display(), e))?;

    Ok(())
}

pub fn main(argv: &[String]) {
    let mut name: Option<String> = None;
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
                name = Some(arg.to_string());
                i += 1;
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
