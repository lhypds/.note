use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

fn home_dir() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
}

fn parse_noterc() -> Vec<PathBuf> {
    let noterc = home_dir().join(".noterc");

    if !noterc.exists() {
        return vec![];
    }

    let content = match fs::read_to_string(&noterc) {
        Ok(c) => c,
        Err(_) => return vec![],
    };

    let mut paths = Vec::new();
    for line in content.lines() {
        if let Some(value) = line.strip_prefix("notePath=") {
            for part in value.split(';') {
                let part = part.trim();
                if part.is_empty() {
                    continue;
                }
                let expanded = if part.starts_with('~') {
                    home_dir().join(&part[2..])
                } else {
                    PathBuf::from(part)
                };
                paths.push(expanded);
            }
        }
    }
    paths
}

fn collect_txt_files(dirs: &[PathBuf]) -> Vec<String> {
    let mut files = Vec::new();
    for dir in dirs {
        collect_recursive(dir, &mut files);
    }
    files
}

fn collect_recursive(dir: &Path, files: &mut Vec<String>) {
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_recursive(&path, files);
        } else if path.extension().and_then(|e| e.to_str()) == Some("txt") {
            if let Some(s) = path.to_str() {
                files.push(s.to_string());
            }
        }
    }
}

fn open_file(path: &str) {
    if let Err(e) = super::opener::open_path(Path::new(path)) {
        eprintln!("{}", e);
    }
}

fn file_name(path: &str) -> &str {
    Path::new(path)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(path)
}

/// 'Drugs Note' -> 'drugs' — the topic, as `note create` spells it.
fn note_title(stem: &str) -> &str {
    stem.strip_suffix(" note").unwrap_or(stem)
}

fn is_subsequence(query: &str, text: &str) -> bool {
    let mut chars = text.chars();
    query.chars().all(|q| chars.any(|c| c == q))
}

/// Rank a note against the query; lower is nearer, `None` means no match.
fn match_rank(query: &str, path: &str) -> Option<(u8, usize)> {
    let name = file_name(path).to_lowercase();
    let stem = Path::new(path)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or(path)
        .to_lowercase();
    let title = note_title(&stem);

    if title == query {
        return Some((0, 0));
    }
    if stem == query || name == query {
        return Some((1, 0));
    }
    if title.starts_with(query) || stem.starts_with(query) {
        return Some((2, 0));
    }
    if let Some(index) = stem.find(query) {
        return Some((3, index));
    }
    if is_subsequence(query, &stem) {
        return Some((4, 0));
    }
    None
}

fn find_nearest(files: &[String], query: &str) -> Option<String> {
    let query = query.trim().to_lowercase();
    files
        .iter()
        // Shorter names are the nearer match; the path keeps ties stable.
        .filter_map(|path| {
            match_rank(&query, path).map(|rank| (rank, file_name(path).chars().count(), path))
        })
        .min()
        .map(|(_, _, path)| path.clone())
}

pub fn main(argv: &[String]) {
    let query = argv.join(" ").trim().to_string();

    let paths = parse_noterc();
    if paths.is_empty() {
        eprintln!("No notePath entries found in ~/.noterc");
        std::process::exit(1);
    }

    let existing: Vec<PathBuf> = paths.into_iter().filter(|p| p.is_dir()).collect();
    if existing.is_empty() {
        eprintln!("None of the notePath directories exist.");
        std::process::exit(1);
    }

    let files = collect_txt_files(&existing);
    if files.is_empty() {
        eprintln!("No note files found.");
        std::process::exit(1);
    }

    if !query.is_empty() {
        match find_nearest(&files, &query) {
            Some(path) => {
                println!("Opening: {}", path);
                open_file(&path);
            }
            None => {
                eprintln!("No note matching '{}'.", query);
                std::process::exit(1);
            }
        }
        return;
    }

    let entries: Vec<String> = files
        .iter()
        .map(|f| {
            let name = Path::new(f)
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or(f);
            format!("{}\t{}", name, f)
        })
        .collect();
    let input = entries.join("\n");

    let tmp_path = std::env::temp_dir().join(format!("note_open_{}.txt", std::process::id()));

    let tmp_file = match fs::File::create(&tmp_path) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("Error creating temp file: {}", e);
            std::process::exit(1);
        }
    };

    let status = Command::new("fzf")
        .args([
            "--ansi",
            "--delimiter", "\t",
            "--with-nth", "1",
            "--header", "Type to search note name",
        ])
        .stdin(Stdio::piped())
        .stdout(tmp_file)
        .spawn()
        .and_then(|mut child| {
            if let Some(stdin) = child.stdin.take() {
                let mut stdin = stdin;
                let _ = stdin.write_all(input.as_bytes());
            }
            child.wait()
        });

    let selected_line = fs::read_to_string(&tmp_path)
        .unwrap_or_default()
        .trim()
        .to_string();
    let _ = fs::remove_file(&tmp_path);

    let selected = selected_line.rsplit('\t').next().unwrap_or("").to_string();

    match status {
        Ok(s) if s.success() && !selected.is_empty() => open_file(&selected),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            eprintln!("fzf not found. Please install fzf to use the open command.");
            std::process::exit(1);
        }
        _ => {}
    }
}
