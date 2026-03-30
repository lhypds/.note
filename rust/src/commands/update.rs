use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, exit};

const GITHUB_API_URL: &str =
    "https://api.github.com/repos/lhypds/.note/releases/latest";

// ── helpers ──────────────────────────────────────────────────────────────────

fn get_current_version_and_build() -> (String, String) {
    let output = Command::new("note")
        .arg("--version")
        .output()
        .unwrap_or_else(|_| {
            eprintln!("Error: 'note' command not found in PATH.");
            exit(1);
        });

    if !output.status.success() {
        eprintln!("Error: 'note --version' failed.");
        exit(1);
    }

    let raw = String::from_utf8_lossy(&output.stdout).trim().to_string();
    // Expected: "v0.0.6 (rust)"  or  "v0.0.6 (python)"
    let parts: Vec<&str> = raw.split_whitespace().collect();
    if parts.is_empty() {
        eprintln!("Error: unexpected output from 'note --version': {:?}", raw);
        exit(1);
    }

    let version = parts[0].trim_start_matches('v').to_string();
    let build_type = if parts.len() >= 2 {
        parts[1].trim_matches(|c| c == '(' || c == ')').to_string()
    } else {
        "rust".to_string()
    };

    (version, build_type)
}

fn parse_version(s: &str) -> Vec<u64> {
    s.trim_start_matches('v')
        .split('.')
        .map(|p| p.parse::<u64>().unwrap_or(0))
        .collect()
}

fn get_latest_release() -> serde_json::Value {
    let response = ureq::get(GITHUB_API_URL)
        .set("User-Agent", "note-updater")
        .call()
        .unwrap_or_else(|e| {
            eprintln!("Error: could not fetch latest release from GitHub: {}", e);
            exit(1);
        });

    response.into_json::<serde_json::Value>().unwrap_or_else(|e| {
        eprintln!("Error: failed to parse GitHub API response: {}", e);
        exit(1);
    })
}

fn find_asset_url(assets: &serde_json::Value, filename: &str) -> Option<String> {
    let arr = assets.as_array()?;
    for asset in arr {
        if asset["name"].as_str() == Some(filename) {
            if let Some(url) = asset["browser_download_url"].as_str() {
                return Some(url.to_string());
            }
        }
    }
    None
}

fn download_file(url: &str, dest: &Path) {
    println!(
        "  Downloading {} ...",
        dest.file_name().unwrap_or_default().to_string_lossy()
    );

    let response = ureq::get(url)
        .set("User-Agent", "note-updater")
        .call()
        .unwrap_or_else(|e| {
            eprintln!("\nError: download failed: {}", e);
            exit(1);
        });

    let total: u64 = response
        .header("Content-Length")
        .and_then(|v| v.parse().ok())
        .unwrap_or(0);

    let mut reader = response.into_reader();
    let mut file = fs::File::create(dest).unwrap_or_else(|e| {
        eprintln!("Error: cannot create file {}: {}", dest.display(), e);
        exit(1);
    });

    let mut downloaded: u64 = 0;
    let mut buf = [0u8; 65536];
    loop {
        let n = io::Read::read(&mut reader, &mut buf).unwrap_or_else(|e| {
            eprintln!("\nError: download failed: {}", e);
            exit(1);
        });
        if n == 0 {
            break;
        }
        file.write_all(&buf[..n]).unwrap_or_else(|e| {
            eprintln!("\nError: write failed: {}", e);
            exit(1);
        });
        downloaded += n as u64;
        if total > 0 {
            let pct = downloaded * 100 / total;
            print!("\r  Progress: {}%", pct);
            io::stdout().flush().ok();
        }
    }
    println!();
}

fn extract_archive(archive_path: &Path, extract_dir: &Path) {
    if extract_dir.exists() {
        fs::remove_dir_all(extract_dir).unwrap_or_else(|e| {
            eprintln!("Error: could not remove {}: {}", extract_dir.display(), e);
            exit(1);
        });
    }
    fs::create_dir_all(extract_dir).unwrap_or_else(|e| {
        eprintln!("Error: could not create {}: {}", extract_dir.display(), e);
        exit(1);
    });

    println!("  Extracting to {} ...", extract_dir.display());

    let file = fs::File::open(archive_path).unwrap_or_else(|e| {
        eprintln!("Error: cannot open archive: {}", e);
        exit(1);
    });
    let mut zip = zip::ZipArchive::new(file).unwrap_or_else(|e| {
        eprintln!("Error: archive is not a valid zip file: {}", e);
        exit(1);
    });

    for i in 0..zip.len() {
        let mut entry = zip.by_index(i).unwrap_or_else(|e| {
            eprintln!("Error: zip entry error: {}", e);
            exit(1);
        });
        let out_path = extract_dir.join(entry.mangled_name());
        if entry.is_dir() {
            fs::create_dir_all(&out_path).ok();
        } else {
            if let Some(parent) = out_path.parent() {
                fs::create_dir_all(parent).ok();
            }
            let unix_mode = entry.unix_mode();
            let mut out_file = fs::File::create(&out_path).unwrap_or_else(|e| {
                eprintln!("Error: cannot create {}: {}", out_path.display(), e);
                exit(1);
            });
            io::copy(&mut entry, &mut out_file).unwrap_or_else(|e| {
                eprintln!("Error: extraction failed: {}", e);
                exit(1);
            });
            drop(out_file);
            // Restore Unix permissions stored in the zip entry (e.g. 0o755 for executables)
            #[cfg(unix)]
            if let Some(mode) = unix_mode {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&out_path, fs::Permissions::from_mode(mode)).ok();
            }
        }
    }
}

fn find_install_sh(base_dir: &Path) -> Option<PathBuf> {
    fn walk(dir: &Path) -> Option<PathBuf> {
        let rd = fs::read_dir(dir).ok()?;
        for entry in rd.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if let Some(found) = walk(&path) {
                    return Some(found);
                }
            } else if path.file_name().and_then(|n| n.to_str()) == Some("install.sh") {
                return Some(path);
            }
        }
        None
    }
    walk(base_dir)
}

// ── public entry point ────────────────────────────────────────────────────────

pub fn main(argv: &[String]) {
    let force = argv.iter().any(|a| a == "-f" || a == "--force");

    // 1. Current version
    let (current_version, build_type) = get_current_version_and_build();
    println!("Current version : v{} ({})", current_version, build_type);

    // 2. Latest release
    println!("Checking for updates ...");
    let release = get_latest_release();
    let latest_tag = release["tag_name"].as_str().unwrap_or("").to_string();
    let latest_version = latest_tag.trim_start_matches('v').to_string();
    println!("Latest version  : v{}", latest_version);

    // 3. Compare
    let current_tuple = parse_version(&current_version);
    let latest_tuple = parse_version(&latest_version);

    if current_tuple.is_empty() || latest_tuple.is_empty() {
        eprintln!("Error: could not parse version numbers.");
        exit(1);
    }

    if current_tuple >= latest_tuple {
        if !force {
            println!("Already up to date.");
            return;
        }
        println!("Already up to date, but forcing reinstall.");
    } else {
        println!(
            "Update available : v{} → v{}",
            current_version, latest_version
        );
    }

    // 4. Resolve asset filename
    let asset_filename = if build_type == "python" {
        format!("dot_note_python_v{}.zip", latest_version)
    } else {
        format!("dot_note_rust_v{}.zip", latest_version)
    };

    let empty_assets = serde_json::Value::Array(vec![]);
    let assets = release.get("assets").unwrap_or(&empty_assets);
    let download_url = find_asset_url(assets, &asset_filename).unwrap_or_else(|| {
        eprintln!(
            "Error: release asset '{}' not found in latest release.",
            asset_filename
        );
        if let Some(arr) = assets.as_array() {
            let names: Vec<&str> = arr
                .iter()
                .filter_map(|a| a["name"].as_str())
                .collect();
            if !names.is_empty() {
                eprintln!("  Available assets: {}", names.join(", "));
            }
        }
        exit(1);
    });

    // 5. Create updates directory
    let updates_dir = dirs_home().join(".note").join("updates");
    fs::create_dir_all(&updates_dir).unwrap_or_else(|e| {
        eprintln!("Error: could not create updates dir: {}", e);
        exit(1);
    });

    let archive_path = updates_dir.join(&asset_filename);

    // 6. Download
    download_file(&download_url, &archive_path);

    // 7. Extract
    let extract_dir = updates_dir.join(format!("dot_note_v{}", latest_version));
    extract_archive(&archive_path, &extract_dir);

    // 8. Find and run install.sh
    let install_sh = find_install_sh(&extract_dir).unwrap_or_else(|| {
        eprintln!("Error: install.sh not found inside the extracted archive.");
        exit(1);
    });

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&install_sh, fs::Permissions::from_mode(0o755))
            .unwrap_or_else(|e| {
                eprintln!("Error: could not chmod install.sh: {}", e);
                exit(1);
            });
    }

    println!("  Running install.sh ...");
    let status = Command::new("bash")
        .arg(&install_sh)
        .current_dir(install_sh.parent().unwrap())
        .status()
        .unwrap_or_else(|e| {
            eprintln!("Error: failed to run install.sh: {}", e);
            exit(1);
        });

    if !status.success() {
        eprintln!(
            "Error: install.sh exited with code {}.",
            status.code().unwrap_or(-1)
        );
        exit(status.code().unwrap_or(1));
    }

    println!("`note` has been updated to v{}.", latest_version);
}

fn dirs_home() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
}
