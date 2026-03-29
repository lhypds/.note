use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn env_bool(name: &str, default: bool) -> bool {
    match env::var(name) {
        Ok(v) => v.to_lowercase() == "true",
        Err(_) => default,
    }
}

fn replace_spaces(line: &str) -> String {
    let mut out = String::with_capacity(line.len());
    let chars: Vec<char> = line.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        if chars[i] == ' ' {
            let start = i;
            while i < chars.len() && chars[i] == ' ' {
                i += 1;
            }
            let run = i - start;
            if run >= 2 {
                out.push(' ');
                for _ in 1..run {
                    out.push('\u{00A0}');
                }
            } else {
                out.push(' ');
            }
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }

    out
}

fn prefix_tofu(line: &str) -> String {
    let mut out = String::with_capacity(line.len() + 1);
    out.push('□');
    out.push_str(line);
    out
}

fn is_only(line: &str, ch: char) -> bool {
    !line.is_empty() && line.chars().all(|c| c == ch)
}

fn is_underline_candidate(line: &str) -> bool {
    is_only(line, '=') || is_only(line, '-')
}

fn trim_crlf(s: &str) -> String {
    s.trim_end_matches(['\n', '\r']).to_string()
}

fn convert_to_markdown(input_file: &Path, output_file: &Path, preview: bool) -> Result<(), String> {
    println!("{}", input_file.display());

    let content = fs::read_to_string(input_file)
        .map_err(|e| format!("failed to read '{}': {}", input_file.display(), e))?;

    let mut lines: Vec<String> = content.lines().map(trim_crlf).collect();

    if content.is_empty() {
        lines.clear();
    }

    let mut output_lines: Vec<String> = Vec::with_capacity(lines.len());
    let mut preview_lines: Vec<String> = Vec::new();

    let mut p = 0usize;
    while p < lines.len() {
        let line_orig = lines[p].clone();
        let mut line = line_orig.clone();
        let mut actions: Vec<String> = Vec::new();

        if line.starts_with(' ') {
            let leading_ws_count = line.chars().take_while(|c| *c == ' ').count();
            let leading = "░".repeat(leading_ws_count);
            let rest: String = line.chars().skip(leading_ws_count).collect();
            line = format!("{}{}", leading, rest);
            if preview {
                actions.push("leading_whitespace_░".to_string());
            }
        }

        let before_replace_spaces = line.clone();
        line = replace_spaces(&line);
        if preview && line != before_replace_spaces {
            actions.push("replace_spaces".to_string());
        }

        let mut output_line = String::new();
        let mut add_2_spaces = true;

        if line.is_empty() {
            output_line.clear();
        } else if p < lines.len() - 1
            && (lines[p + 1].replace('=', "").is_empty() || lines[p + 1].replace('-', "").is_empty())
            && lines[p].chars().count() == lines[p + 1].chars().count()
        {
            output_line = line.clone();
            add_2_spaces = false;
            if preview {
                actions.push("title_or_section_title".to_string());
            }
        } else if is_underline_candidate(&line)
            && (p == 0 || line.chars().count() != lines[p - 1].replace('\n', "").chars().count())
        {
            output_line = prefix_tofu(&line);
            if preview {
                actions.push("prefix_tofu".to_string());
            }
        } else if is_underline_candidate(&line)
            && (p == 0 || line.chars().count() == lines[p - 1].replace('\n', "").chars().count())
        {
            output_line = line.clone();
            add_2_spaces = false;
            if preview {
                actions.push("title_underline".to_string());
            }
        } else if line.starts_with('>') {
            output_line = prefix_tofu(&line);
            if preview {
                actions.push("prefix_tofu,escape_blockquote".to_string());
            }
        } else if line.starts_with('#') {
            output_line = prefix_tofu(&line);
            if preview {
                actions.push("prefix_tofu,escape_#".to_string());
            }
        } else if line.starts_with('$') {
            output_line = prefix_tofu(&line);
            if preview {
                actions.push("prefix_tofu,escape_$".to_string());
            }
        } else {
            output_line = line.clone();
        }

        if add_2_spaces {
            if preview {
                actions.push("add_2_spaces".to_string());
            }
            output_line.push_str("  ");
        }
        output_lines.push(format!("{}\n", output_line));

        if preview {
            if actions.is_empty() {
                actions.push("do_nothing".to_string());
            }
            preview_lines.push(format!(
                "{}: [{}],{},{}",
                p + 1,
                actions.join(","),
                line_orig,
                output_line
            ));
        }

        p += 1;
    }

    fs::write(output_file, output_lines.concat())
        .map_err(|e| format!("failed to write '{}': {}", output_file.display(), e))?;

    if preview {
        let original_name = input_file
            .file_stem()
            .and_then(|s| s.to_str())
            .ok_or_else(|| "invalid input filename".to_string())?;

        let preview_filename = format!("{}_pr.txt", original_name);
        let preview_output_dir = output_file
            .parent()
            .ok_or_else(|| "invalid output path".to_string())?;
        let preview_file = preview_output_dir.join(preview_filename);

        fs::write(preview_file, format!("{}\n", preview_lines.join("\n")))
            .map_err(|e| format!("failed to write preview file: {}", e))?;
    }

    Ok(())
}

fn parse_args() -> (bool, Option<String>, Option<String>) {
    let args: Vec<String> = env::args().collect();
    let mut preview = false;
    let mut path: Option<String> = None;
    let mut filename: Option<String> = None;

    let mut i = 1usize;
    while i < args.len() {
        match args[i].as_str() {
            "--preview" => {
                preview = true;
                i += 1;
            }
            "--path" => {
                if i + 1 >= args.len() {
                    eprintln!("Error: --path requires a value.");
                    std::process::exit(1);
                }
                path = Some(args[i + 1].clone());
                i += 2;
            }
            arg => {
                if filename.is_none() {
                    filename = Some(arg.to_string());
                    i += 1;
                } else {
                    eprintln!("Error: unrecognized argument '{}'.", arg);
                    std::process::exit(1);
                }
            }
        }
    }

    (preview, path, filename)
}

fn main() {
    let _ = dotenvy::dotenv();

    let mut note_dir = env::var("NOTE_DIR").unwrap_or_else(|_| "../".to_string());
    let use_nsfw_filter = env_bool("USE_NSFW_FILTER", true);

    let (preview, path, filename) = parse_args();

    if let Some(p) = path {
        note_dir = p;
    }

    if !Path::new(&note_dir).is_dir() {
        note_dir = "../".to_string();
    }

    if preview && filename.is_none() {
        println!(
            "Error: --preview requires a filename, e.g. python note_markdown.py --preview filename.txt"
        );
        std::process::exit(1);
    }

    if preview {
        let mut file = filename.unwrap_or_default().trim().to_string();
        if !file.ends_with(".txt") {
            file.push_str(".txt");
        }

        let input_file = Path::new(&note_dir).join(&file);
        if !input_file.is_file() {
            println!(
                "Error: file '{}' not found inside NOTE_DIR '{}'.",
                file, note_dir
            );
            std::process::exit(1);
        }

        let exe_path = match env::current_exe() {
            Ok(p) => p,
            Err(_) => PathBuf::from("."),
        };
        let script_dir = exe_path
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."));

        let stem = input_file
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("preview");
        let output_file = script_dir.join(format!("{}_pr.md", stem));

        if let Err(e) = convert_to_markdown(&input_file, &output_file, true) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
        println!("Processed files: 1");
        return;
    }

    let output_path = Path::new(&note_dir).join(".markdown");
    if !output_path.exists() {
        if let Err(e) = fs::create_dir_all(&output_path) {
            eprintln!("Error creating output directory '{}': {}", output_path.display(), e);
            std::process::exit(1);
        }
    }

    let note_filter: Vec<&str> = if use_nsfw_filter {
        vec!["Sex", "Adult"]
    } else {
        vec![]
    };

    let mut processed_count = 0usize;

    let entries = match fs::read_dir(&note_dir) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("Error reading NOTE_DIR '{}': {}", note_dir, e);
            std::process::exit(1);
        }
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }

        let Some(filename) = path.file_name().and_then(|s| s.to_str()) else {
            continue;
        };

        if filename.ends_with(" Note.txt") && !note_filter.iter().any(|f| filename.contains(f)) {
            let input_file = Path::new(&note_dir).join(filename);
            let output_file = output_path.join(filename.replace(".txt", ".md"));

            if let Err(e) = convert_to_markdown(&input_file, &output_file, false) {
                eprintln!("Error processing '{}': {}", filename, e);
                std::process::exit(1);
            }
            processed_count += 1;
        }
    }

    println!("Processed files: {}", processed_count);
}
