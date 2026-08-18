import os
import subprocess
import sublime
import sublime_plugin


class RunCommandOnSave(sublime_plugin.EventListener):
    def on_post_save_async(self, view):
        file_path = view.file_name()
        if not file_path:
            return

        if not file_path.endswith((".txt",)):
            return

        cmd = [os.path.expanduser("~/code/gcc3/note/.note/note"), "format", file_path]
        try:
            subprocess.Popen(
                cmd,
                cwd=os.path.dirname(file_path),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
        except Exception as e:
            sublime.error_message("Run on save failed:\n{}".format(e))
