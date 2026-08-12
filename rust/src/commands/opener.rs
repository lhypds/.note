use std::path::Path;
use std::process::Command;

/// Whether a command is on the PATH.
#[cfg(not(any(target_os = "macos", target_os = "windows")))]
fn on_path(cmd: &str) -> bool {
    std::env::var_os("PATH").is_some_and(|paths| {
        std::env::split_paths(&paths).any(|dir| dir.join(cmd).is_file())
    })
}

/// $VISUAL, then $EDITOR, split into a program and its arguments so that
/// values like "code -w" work.
#[cfg(not(any(target_os = "macos", target_os = "windows")))]
fn editor_command() -> Option<Vec<String>> {
    for var in ["VISUAL", "EDITOR"] {
        if let Ok(value) = std::env::var(var) {
            let parts: Vec<String> = value.split_whitespace().map(String::from).collect();
            if !parts.is_empty() {
                return Some(parts);
            }
        }
    }
    None
}

/// Hand a note to the system's default application.
///
/// On Linux there is not always a desktop session to hand it to — a headless
/// server has no xdg-open at all — so fall back to the user's editor, run in
/// the foreground because it is a terminal program, before giving up.
pub fn open_path(path: &Path) -> Result<(), String> {
    let failed = |e: std::io::Error| format!("failed to open '{}': {}", path.display(), e);

    #[cfg(target_os = "macos")]
    {
        Command::new("open").arg(path).spawn().map_err(failed)?;
        Ok(())
    }

    #[cfg(target_os = "windows")]
    {
        Command::new("cmd")
            .args(["/c", "start", ""])
            .arg(path)
            .spawn()
            .map_err(failed)?;
        Ok(())
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        if on_path("xdg-open") {
            Command::new("xdg-open").arg(path).spawn().map_err(failed)?;
            return Ok(());
        }

        match editor_command() {
            Some(parts) => {
                Command::new(&parts[0])
                    .args(&parts[1..])
                    .arg(path)
                    .status()
                    .map_err(failed)?;
                Ok(())
            }
            None => Err(format!(
                "no way to open '{}': xdg-open is not installed and neither \
                 $VISUAL nor $EDITOR is set.",
                path.display()
            )),
        }
    }
}
