use std::fs;
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

fn detect_line_ending(line: &str) -> &str {
    if line.ends_with("\r\n") {
        "\r\n"
    } else if line.ends_with('\n') {
        "\n"
    } else {
        ""
    }
}

pub fn run(file_path: &Path) -> Result<(), String> {
    let content = fs::read_to_string(file_path)
        .map_err(|e| format!("failed to read '{}': {}", file_path.display(), e))?;

    let mut lines: Vec<String> = {
        let mut v = Vec::new();
        let mut current = String::new();
        for ch in content.chars() {
            current.push(ch);
            if ch == '\n' {
                v.push(current.clone());
                current.clear();
            }
        }
        if !current.is_empty() {
            v.push(current);
        }
        v
    };

    let mut fixed_count = 0;
    let max_start = if lines.len() > 3 { lines.len() - 3 } else { 0 };

    for i in 0..max_start {
        let line0 = lines[i].trim_end_matches(['\r', '\n']).to_string();
        let line1 = lines[i + 1].trim_end_matches(['\r', '\n']).to_string();
        let line2 = lines[i + 2].trim_end_matches(['\r', '\n']).to_string();
        let line3 = lines[i + 3].trim_end_matches(['\r', '\n']).to_string();

        if !line0.is_empty() { continue; }
        if line1.trim().is_empty() { continue; }
        if !is_underline_line(&line2) { continue; }
        if !line3.is_empty() { continue; }

        let new_underline = underline_char(&line2)
            .to_string()
            .repeat(display_width(&line1));
        let ending = detect_line_ending(&lines[i + 2]);
        let new_line = format!("{}{}", new_underline, ending);

        if lines[i + 2] != new_line {
            lines[i + 2] = new_line;
            fixed_count += 1;
        }
    }

    // Ensure exactly 2 blank lines after a `===` title underline.
    let mut i = 0;
    while i < lines.len() {
        let trimmed = lines[i].trim_end_matches(['\r', '\n']);
        if !trimmed.is_empty() && trimmed.chars().all(|c| c == '=') {
            // Count blank lines immediately following the underline.
            let mut blank_count = 0;
            let mut j = i + 1;
            while j < lines.len() && lines[j].trim_end_matches(['\r', '\n']).is_empty() {
                blank_count += 1;
                j += 1;
            }
            if blank_count < 2 {
                let ending = detect_line_ending(&lines[i]);
                let blank_line = format!("{}", ending);
                let needed = 2 - blank_count;
                for k in 0..needed {
                    lines.insert(i + 1 + k, blank_line.clone());
                }
                fixed_count += needed;
                i += 1 + needed + blank_count;
            } else if blank_count > 2 {
                let excess = blank_count - 2;
                lines.drain(i + 1..i + 1 + excess);
                fixed_count += excess;
                i += 1 + 2;
            } else {
                i += 1 + blank_count;
            }
        } else {
            i += 1;
        }
    }

    // Ensure exactly 1 blank line after a `---` section title underline.
    let mut i = 0;
    while i < lines.len() {
        let trimmed = lines[i].trim_end_matches(['\r', '\n']);
        if !trimmed.is_empty() && trimmed.chars().all(|c| c == '-') {
            let mut blank_count = 0;
            let mut j = i + 1;
            while j < lines.len() && lines[j].trim_end_matches(['\r', '\n']).is_empty() {
                blank_count += 1;
                j += 1;
            }
            if blank_count < 1 {
                let ending = detect_line_ending(&lines[i]);
                let blank_line = format!("{}", ending);
                lines.insert(i + 1, blank_line);
                fixed_count += 1;
                i += 2;
            } else if blank_count > 1 {
                let excess = blank_count - 1;
                lines.drain(i + 1..i + 1 + excess);
                fixed_count += excess;
                i += 2;
            } else {
                i += 1 + blank_count;
            }
        } else {
            i += 1;
        }
    }

    fs::write(file_path, lines.concat())
        .map_err(|e| format!("failed to write '{}': {}", file_path.display(), e))?;

    Ok(())
}

pub fn main(argv: &[String]) {
    let file_path = match argv.first() {
        Some(p) => p.clone(),
        None => {
            eprintln!("Error: no file path provided.");
            std::process::exit(1);
        }
    };

    let absolute_path = match std::fs::canonicalize(&file_path) {
        Ok(p) => p,
        Err(_) => {
            eprintln!("Error: '{}' is not a valid file.", file_path);
            std::process::exit(1);
        }
    };

    if !absolute_path.is_file() {
        eprintln!("Error: '{}' is not a valid file.", absolute_path.display());
        std::process::exit(1);
    }

    match run(&absolute_path) {
        Ok(_) => println!("Processed files: 1"),
        Err(e) => {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
    }
}
