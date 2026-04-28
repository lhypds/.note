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
    #[cfg(target_os = "macos")]
    let _ = Command::new("open").arg(path).spawn();

    #[cfg(target_os = "windows")]
    let _ = Command::new("cmd").args(["/c", "start", "", path]).spawn();

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    let _ = Command::new("xdg-open").arg(path).spawn();
}

pub fn main(_argv: &[String]) {
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

    let quoted: Vec<String> = existing
        .iter()
        .map(|p| format!("'{}'", p.display()))
        .collect();
    let quoted_str = quoted.join(" ");

    let reload_cmd = format!(
        "grep -r --include='*.txt' -l {{q}} {} 2>/dev/null || true",
        quoted_str
    );

    let initial_files = collect_txt_files(&existing);
    let initial_input = initial_files.join("\n");

    let tmp_path = std::env::temp_dir().join(format!("note_search_{}.txt", std::process::id()));

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
            "--disabled",
            "--query", "",
            "--bind", &format!("change:reload:{}", reload_cmd),
            "--preview", "grep -n --color=always {q} {}",
            "--preview-window", "right:60%:wrap",
            "--header", "Type to search note content",
        ])
        .stdin(Stdio::piped())
        .stdout(tmp_file)
        .spawn()
        .and_then(|mut child| {
            if let Some(stdin) = child.stdin.take() {
                let mut stdin = stdin;
                let _ = stdin.write_all(initial_input.as_bytes());
            }
            child.wait()
        });

    let selected = fs::read_to_string(&tmp_path)
        .unwrap_or_default()
        .trim()
        .to_string();
    let _ = fs::remove_file(&tmp_path);

    match status {
        Ok(s) if s.success() && !selected.is_empty() => open_file(&selected),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            eprintln!("fzf not found. Please install fzf to use the search command.");
            std::process::exit(1);
        }
        _ => {}
    }
}
