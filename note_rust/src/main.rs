use std::fs;
use std::io::{self, Write};
use std::path::Path;
use unicode_width::UnicodeWidthStr;

fn display_width(text: &str) -> usize {
    text.width()
}

fn is_underline_line(text: &str) -> bool {
    if text.is_empty() {
        return false;
    }
    text.chars().all(|c| c == '-') || text.chars().all(|c| c == '=')
}

fn underline_char(text: &str) -> char {
    if text.chars().all(|c| c == '-') {
        '-'
    } else {
        '='
    }
}

fn detect_line_ending(line: &str) -> String {
    if line.ends_with("\r\n") {
        "\r\n".to_string()
    } else if line.ends_with('\n') {
        "\n".to_string()
    } else {
        "".to_string()
    }
}

fn process_note(file_path: &Path) -> io::Result<()> {
    let content = fs::read_to_string(file_path)?;

    // Split lines while preserving line endings
    let mut lines = Vec::new();
    let mut current_line = String::new();

    for ch in content.chars() {
        current_line.push(ch);
        if ch == '\n' {
            lines.push(current_line.clone());
            current_line.clear();
        }
    }
    if !current_line.is_empty() {
        lines.push(current_line);
    }

    let mut fixed_count = 0;
    let max_start = if lines.len() > 3 { lines.len() - 3 } else { 0 };

    for i in 0..max_start {
        let line0 = lines[i].trim_end_matches(|c| c == '\r' || c == '\n');
        let line1 = lines[i + 1].trim_end_matches(|c| c == '\r' || c == '\n');
        let line2 = lines[i + 2].trim_end_matches(|c| c == '\r' || c == '\n');
        let line3 = lines[i + 3].trim_end_matches(|c| c == '\r' || c == '\n');

        if !line0.is_empty() {
            continue;
        }

        if line1.trim().is_empty() {
            continue;
        }

        if !is_underline_line(line2) {
            continue;
        }

        if !line3.is_empty() {
            continue;
        }

        let new_underline = underline_char(line2)
            .to_string()
            .repeat(display_width(line1));
        let ending = detect_line_ending(&lines[i + 2]);
        let new_line = format!("{}{}", new_underline, ending);

        if lines[i + 2] != new_line {
            lines[i + 2] = new_line;
            fixed_count += 1;
        }
    }

    let output = lines.join("");
    fs::write(file_path, output)?;

    println!("Fixed {} underline line(s) in: {}", fixed_count, file_path.display());

    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let mut file_path = None;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "-f" | "--file" => {
                if i + 1 < args.len() {
                    file_path = Some(args[i + 1].clone());
                    i += 2;
                } else {
                    eprintln!("Error: --file requires an argument");
                    std::process::exit(1);
                }
            }
            _ => {
                i += 1;
            }
        }
    }

    let file_path = match file_path {
        Some(path) => path,
        None => {
            print!("Enter file path: ");
            io::stdout().flush().unwrap();
            let mut input = String::new();
            io::stdin()
                .read_line(&mut input)
                .expect("Failed to read input");
            input.trim().to_string()
        }
    };

    if file_path.is_empty() {
        eprintln!("Error: no file path provided.");
        std::process::exit(1);
    }

    let absolute_path = match std::fs::canonicalize(&file_path) {
        Ok(path) => path,
        Err(_) => {
            eprintln!("Error: '{}' is not a valid file.", file_path);
            std::process::exit(1);
        }
    };

    if !absolute_path.is_file() {
        eprintln!("Error: '{}' is not a valid file.", absolute_path.display());
        std::process::exit(1);
    }

    match process_note(&absolute_path) {
        Ok(_) => println!("Processed files: 1"),
        Err(e) => {
            eprintln!("Error processing file: {}", e);
            std::process::exit(1);
        }
    }
}
