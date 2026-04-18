use std::fs;
use std::path::Path;
use unicode_width::UnicodeWidthStr;

fn display_width(text: &str) -> usize {
    text.width()
}

// ---- I. Underline length fixer -------------------------------------
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

fn format_underline_length(lines: &mut [String]) -> usize {
    let mut fixed_count = 0;

    let max_start = if lines.len() > 3 { lines.len() - 3 } else { 0 };
    for i in 0..max_start {
        let line0 = lines[i].trim_end_matches(['\r', '\n']);
        let line1 = lines[i + 1].trim_end_matches(['\r', '\n']);
        let line2 = lines[i + 2].trim_end_matches(['\r', '\n']);
        let line3 = lines[i + 3].trim_end_matches(['\r', '\n']);

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

        let new_underline = underline_char(line2).to_string().repeat(display_width(line1));
        let original = &lines[i + 2];
        let ending = detect_line_ending(original);
        let new_line = format!("{}{}", new_underline, ending);

        if *original != new_line {
            lines[i + 2] = new_line;
            fixed_count += 1;
        }
    }

    fixed_count
}

// ---- II. Blank line normalizer -------------------------------------
fn normalize_underline_blank_lines(lines: &mut Vec<String>) -> usize {
    let mut fixed_count = 0;
    let mut i = 0;

    while i < lines.len() {
        let trimmed = lines[i].trim_end_matches(['\r', '\n']);
        if !trimmed.is_empty() && trimmed.chars().all(|c| c == '=') {
            // === : exactly 2 blank lines after
            let mut blank_count: usize = 0;
            let mut j = i + 1;
            while j < lines.len() && lines[j].trim_end_matches(['\r', '\n']).is_empty() {
                blank_count += 1;
                j += 1;
            }
            if blank_count < 2 {
                let ending = detect_line_ending(&lines[i]).to_string();
                let needed = 2 - blank_count;
                for k in 0..needed {
                    lines.insert(i + 1 + k, ending.clone());
                }
                fixed_count += needed;
                i += 1 + needed + blank_count;
            } else if blank_count > 2 {
                let excess = blank_count - 2;
                lines.drain(i + 1..i + 1 + excess);
                fixed_count += excess;
                i += 3;
            } else {
                i += 1 + blank_count;
            }
        } else if !trimmed.is_empty() && trimmed.chars().all(|c| c == '-') {
            // --- : exactly 2 blank lines before the title (line at i-1)
            if i >= 2 {
                let mut blank_count_before: usize = 0;
                let mut k = i - 2;
                while lines[k].trim_end_matches(['\r', '\n']).is_empty() {
                    blank_count_before += 1;
                    if k == 0 {
                        break;
                    }
                    k -= 1;
                }
                if blank_count_before < 2 {
                    let ending = detect_line_ending(&lines[i]).to_string();
                    let needed = 2 - blank_count_before;
                    for _ in 0..needed {
                        lines.insert(i - 1, ending.clone());
                    }
                    fixed_count += needed;
                    i += needed;
                } else if blank_count_before > 2 {
                    let excess = blank_count_before - 2;
                    let start = i - 1 - blank_count_before;
                    lines.drain(start..start + excess);
                    fixed_count += excess;
                    i -= excess;
                }
            }

            // --- : exactly 1 blank line after
            let mut blank_count_after: usize = 0;
            let mut j = i + 1;
            while j < lines.len() && lines[j].trim_end_matches(['\r', '\n']).is_empty() {
                blank_count_after += 1;
                j += 1;
            }
            if blank_count_after < 1 {
                let ending = detect_line_ending(&lines[i]).to_string();
                lines.insert(i + 1, ending);
                fixed_count += 1;
                i += 2;
            } else if blank_count_after > 1 {
                let excess = blank_count_after - 1;
                lines.drain(i + 1..i + 1 + excess);
                fixed_count += excess;
                i += 2;
            } else {
                i += 1 + blank_count_after;
            }
        } else {
            i += 1;
        }
    }

    fixed_count
}

// ---- III. Table formatter ------------------------------------------
fn is_table_line(text: &str) -> bool {
    let stripped = text.trim();
    stripped.starts_with('|') && stripped.ends_with('|')
}

fn parse_table_row(text: &str) -> Vec<String> {
    text.trim()
        .strip_prefix('|')
        .and_then(|text| text.strip_suffix('|'))
        .unwrap_or("")
        .split('|')
        .map(|cell| cell.trim().to_string())
        .collect()
}

fn is_separator_cell(text: &str) -> bool {
    let stripped = text.trim();
    if stripped.is_empty() {
        return false;
    }
    let body = stripped.replace('-', "").replace(':', "");
    body.is_empty() && stripped.contains('-')
}

fn is_separator_row(cells: &[String]) -> bool {
    !cells.is_empty() && cells.iter().all(|cell| is_separator_cell(cell))
}

fn format_separator_cell(width: usize, original: &str) -> String {
    let stripped = original.trim();
    let left_colon = stripped.starts_with(':');
    let right_colon = stripped.ends_with(':');
    let mut dash_count = width + 2 - usize::from(left_colon) - usize::from(right_colon);
    if dash_count < 1 {
        dash_count = 1;
    }

    format!(
        "{}{}{}",
        if left_colon { ":" } else { "" },
        "-".repeat(dash_count),
        if right_colon { ":" } else { "" }
    )
}

fn format_table(lines: &mut Vec<String>) -> usize {
    let mut fixed_count = 0;
    let mut i = 0;

    while i < lines.len() {
        let current = lines[i].trim_end_matches(['\r', '\n']);
        if !is_table_line(current) {
            i += 1;
            continue;
        }

        if i + 1 >= lines.len() {
            i += 1;
            continue;
        }

        let next_line = lines[i + 1].trim_end_matches(['\r', '\n']);
        if !is_table_line(next_line) {
            i += 1;
            continue;
        }

        let separator_cells = parse_table_row(next_line);
        if !is_separator_row(&separator_cells) {
            i += 1;
            continue;
        }

        let start = i;
        let mut end = i + 2;
        while end < lines.len() && is_table_line(lines[end].trim_end_matches(['\r', '\n'])) {
            end += 1;
        }

        let raw_rows: Vec<String> = (start..end)
            .map(|index| lines[index].trim_end_matches(['\r', '\n']).to_string())
            .collect();
        let endings: Vec<String> = (start..end)
            .map(|index| detect_line_ending(&lines[index]).to_string())
            .collect();
        let rows: Vec<Vec<String>> = raw_rows.iter().map(|row| parse_table_row(row)).collect();

        let column_count = rows.iter().map(|row| row.len()).max().unwrap_or(0);
        if column_count == 0 {
            i = end;
            continue;
        }

        let normalized_rows: Vec<Vec<String>> = rows
            .into_iter()
            .map(|mut row| {
                row.resize(column_count, String::new());
                row
            })
            .collect();

        let mut widths = vec![0; column_count];
        for (row_index, row) in normalized_rows.iter().enumerate() {
            if row_index == 1 && is_separator_row(row) {
                continue;
            }
            for (column_index, cell) in row.iter().enumerate() {
                widths[column_index] = widths[column_index].max(display_width(cell));
            }
        }

        let mut formatted_rows = Vec::new();
        for (row_index, row) in normalized_rows.iter().enumerate() {
            let parts: Vec<String> = if row_index == 1 && is_separator_row(row) {
                (0..column_count)
                    .map(|column_index| format_separator_cell(widths[column_index], &row[column_index]))
                    .collect()
            } else {
                row.iter()
                    .enumerate()
                    .map(|(column_index, cell)| {
                        let padding = widths[column_index] - display_width(cell);
                        format!(" {}{} ", cell, " ".repeat(padding))
                    })
                    .collect()
            };
            formatted_rows.push(format!("|{}|", parts.join("|")));
        }

        for (offset, formatted_row) in formatted_rows.iter().enumerate() {
            let new_line = format!("{}{}", formatted_row, endings[offset]);
            if lines[start + offset] != new_line {
                lines[start + offset] = new_line;
                fixed_count += 1;
            }
        }

        i = end;
    }

    fixed_count
}

// ---- Main formatting logic -----------------------------------------------
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

    // I. Fix underline length
    // for title or section (`===` or `---`)
    // the underline line must be exactly the same length as the title line.
    fixed_count += format_underline_length(&mut lines);

    // II. Normalize blank lines around underlines
    // 1. `===` title      : exactly 2 blank lines after
    // 2. `---` section    : exactly 2 blank lines before the title, exactly 1 after
    fixed_count += normalize_underline_blank_lines(&mut lines);

    // III. Format tables to ensure consistent column widths.
    fixed_count += format_table(&mut lines);

    fs::write(file_path, lines.concat())
        .map_err(|e| format!("failed to write '{}': {}", file_path.display(), e))?;

    println!("Fixed {} issues, file: {}", fixed_count, file_path.display());
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
