use std::fs;
use std::path::{Path, PathBuf};

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
    format!("□{}", line)
}

fn is_underline_candidate(line: &str) -> bool {
    !line.is_empty() && (line.chars().all(|c| c == '=') || line.chars().all(|c| c == '-'))
}

fn is_markdown_image(line: &str) -> bool {
    if !line.starts_with("![") {
        return false;
    }
    if let Some(close_bracket) = line.find("](") {
        close_bracket > 1 && line.ends_with(')')
    } else {
        false
    }
}

fn trim_crlf(s: &str) -> String {
    s.trim_end_matches(['\n', '\r']).to_string()
}

const HTML_PREFIX: &str = "###HTML###";

/// Returns the lowercase tag name if `line` starts with `<tagname`.
fn html_tag_at_start(line: &str) -> Option<String> {
    let lower = line.to_lowercase();
    if !lower.starts_with('<') {
        return None;
    }
    let tag: String = lower[1..]
        .chars()
        .take_while(|c| c.is_ascii_alphanumeric())
        .collect();
    if tag.is_empty() {
        return None;
    }
    Some(tag)
}

/// Count occurrences of `<tag>` or `<tag ` (opening tags) in `line`, case-insensitive.
fn count_open_tags(line: &str, tag: &str) -> usize {
    let lower = line.to_lowercase();
    let tag = tag.to_lowercase();
    let mut count = 0usize;
    let mut i = 0usize;
    while i < lower.len() {
        if lower[i..].starts_with('<') {
            let after_lt = &lower[i + 1..];
            if after_lt.starts_with(&tag) {
                let after_tag = &after_lt[tag.len()..];
                if after_tag.starts_with(|c: char| c == '>' || c.is_whitespace()) {
                    count += 1;
                }
            }
        }
        i += 1;
    }
    count
}

/// Count occurrences of `</tag>` (with optional whitespace before `>`) in `line`, case-insensitive.
fn count_close_tags(line: &str, tag: &str) -> usize {
    let lower = line.to_lowercase();
    let tag = tag.to_lowercase();
    let prefix = format!("</{}" , tag);
    let mut count = 0usize;
    let mut i = 0usize;
    while i < lower.len() {
        if lower[i..].starts_with(&prefix) {
            let after = &lower[i + prefix.len()..];
            if after.trim_start_matches(|c: char| c.is_whitespace()).starts_with('>') {
                count += 1;
            }
        }
        i += 1;
    }
    count
}

/// Count self-closing occurrences of `<tag ... />` in `line`, case-insensitive.
fn count_self_closing_tags(line: &str, tag: &str) -> usize {
    let lower = line.to_lowercase();
    let tag = tag.to_lowercase();
    let open = format!("<{}", tag);
    let mut count = 0usize;
    let mut i = 0usize;
    while i < lower.len() {
        if lower[i..].starts_with(&open) {
            let after = &lower[i + open.len()..];
            if after.starts_with(|c: char| c == '/' || c == '>' || c.is_whitespace()) {
                if let Some(end) = lower[i..].find('>') {
                    if lower[i..i + end + 1].ends_with("/>") {
                        count += 1;
                    }
                }
            }
        }
        i += 1;
    }
    count
}

pub fn run(input_file: &Path, output_file: &Path, preview: bool) -> Result<(), String> {
    println!("{}", input_file.display());

    let content = fs::read_to_string(input_file)
        .map_err(|e| format!("failed to read '{}': {}", input_file.display(), e))?;

    // I. Pre-process lines
    // Remove trailing newlines and carriage returns, and store lines in a vector
    let mut lines: Vec<String> = if content.is_empty() {
        Vec::new()
    } else {
        content.lines().map(trim_crlf).collect()
    };

    // Mark HTML blocks with ###HTML###
    let void_elements = ["div", "img"];
    let mut p = 0usize;
    while p < lines.len() {
        if let Some(tag) = html_tag_at_start(&lines[p]) {
            if void_elements.contains(&tag.as_str()) {
                lines[p] = format!("{}{}", HTML_PREFIX, lines[p]);
                p += 1;
            } else {
                let mut depth: i32 = 0;
                while p < lines.len() {
                    let l = lines[p].clone();
                    depth += count_open_tags(&l, &tag) as i32;
                    depth -= count_close_tags(&l, &tag) as i32;
                    depth -= count_self_closing_tags(&l, &tag) as i32;
                    lines[p] = format!("{}{}", HTML_PREFIX, lines[p]);
                    p += 1;
                    if depth <= 0 {
                        break;
                    }
                }
            }
        } else {
            p += 1;
        }
    }

    // II. Process lines
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

        let before = line.clone();
        line = replace_spaces(&line);
        if preview && line != before {
            actions.push("replace_spaces".to_string());
        }

        let mut output_line = String::new();
        let mut add_2_spaces = true;

        if line_orig.starts_with(HTML_PREFIX) {
            output_line = line_orig[HTML_PREFIX.len()..].to_string();
            add_2_spaces = false;
            if preview {
                actions.push("do_nothing,html_block".to_string());
            }
        } else if line.is_empty() {
            output_line.clear();

        } else if p < lines.len() - 1
            && (lines[p + 1].replace('=', "").is_empty()
                || lines[p + 1].replace('-', "").is_empty())
            && lines[p].chars().count() == lines[p + 1].chars().count()
        {
            output_line = line.clone();
            add_2_spaces = false;
            if preview {
                actions.push("title_or_section_title".to_string());
            }

        } else if is_underline_candidate(&line)
            && (p == 0
                || line.chars().count() != lines[p - 1].trim_end_matches(['\n', '\r']).chars().count())
        {
            output_line = prefix_tofu(&line);
            if preview {
                actions.push("prefix_tofu".to_string());
            }

        } else if is_underline_candidate(&line)
            && (p == 0
                || line.chars().count() == lines[p - 1].trim_end_matches(['\n', '\r']).chars().count())
        {
            output_line = line.clone();
            add_2_spaces = false;
            if preview {
                actions.push("title_underline".to_string());
            }

        // Escape blockquote, heading, and code line
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

        // Markdown image, syntax: ![alt text](image_url)
        } else if is_markdown_image(&line) {
            output_line = line.clone();
            add_2_spaces = false;
            if preview {
                actions.push("do_nothing,markdown_image".to_string());
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
        let preview_dir = output_file
            .parent()
            .ok_or_else(|| "invalid output path".to_string())?;
        let preview_file = preview_dir.join(preview_filename);
        fs::write(preview_file, format!("{}\n", preview_lines.join("\n")))
            .map_err(|e| format!("failed to write preview file: {}", e))?;
    }

    Ok(())
}

pub fn main(argv: &[String]) {
    let _ = dotenvy::dotenv();

    let mut preview = false;
    let mut file: Option<String> = None;

    let mut i = 0usize;
    while i < argv.len() {
        match argv[i].as_str() {
            "--preview" => {
                preview = true;
                i += 1;
            }
            arg if !arg.starts_with('-') => {
                file = Some(arg.to_string());
                i += 1;
            }
            arg => {
                eprintln!("Error: unrecognized argument '{}'.", arg);
                std::process::exit(1);
            }
        }
    }

    let mut file_path = match file {
        Some(f) => f.trim().to_string(),
        None => {
            eprintln!("Error: no file path provided.");
            std::process::exit(1);
        }
    };

    if !file_path.ends_with(".txt") {
        file_path.push_str(".txt");
    }

    let input_file = PathBuf::from(&file_path);
    if !input_file.is_file() {
        eprintln!("Error: file '{}' not found.", file_path);
        std::process::exit(1);
    }

    let output_path = std::env::current_dir()
        .unwrap_or_else(|_| PathBuf::from("."))
        .join(".markdown");
    if !output_path.exists() {
        if let Err(e) = fs::create_dir_all(&output_path) {
            eprintln!("Error creating output directory: {}", e);
            std::process::exit(1);
        }
    }

    let stem = input_file
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("output");
    let output_file = output_path.join(format!("{}.md", stem));

    if let Err(e) = run(&input_file, &output_file, preview) {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
    println!("Processed files: 1");
}
