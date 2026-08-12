import os
import shutil
import subprocess
import sys


def _editor_command():
    """$VISUAL, then $EDITOR, split so values like 'code -w' work."""
    for var in ("VISUAL", "EDITOR"):
        value = os.environ.get(var, "").strip()
        if value:
            return value.split()
    return None


def open_file(path):
    """Hand a note to the system's default application.

    On Linux there is not always a desktop session to hand it to — a headless
    server has no xdg-open at all — so fall back to the user's editor, run in
    the foreground because it is a terminal program, before giving up.
    """
    if sys.platform == "darwin":
        subprocess.run(["open", path])
        return
    if sys.platform == "win32":
        os.startfile(path)  # type: ignore[attr-defined]
        return

    if shutil.which("xdg-open"):
        subprocess.run(["xdg-open", path])
        return

    editor = _editor_command()
    if editor:
        subprocess.run([*editor, path])
        return

    print(
        f"Cannot open '{path}': xdg-open is not installed and neither $VISUAL "
        "nor $EDITOR is set.",
        file=sys.stderr,
    )
