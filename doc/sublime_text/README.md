
Setup for Sublime Text
======================


1.1 
Open Sublime Text.  
Go to `Settings` -> `Browse Packages...` and open the `User` folder.  

or

1.2
On macOS, double click `open_user_folder.command` to open the `User` folder.

2. 
Copy the `run_command_on_save.py` to the `User` folder.  

3. 
Modify the `note.py` path in `run_command_on_save.py`.  

```python
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

        # Here replace the `note.py` path.
        cmd = ["python3", os.path.expanduser("~/code/gcc3/note/.note/note.py"), "-f", file_path]
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
```

4. 
Restart Sublime Text.
