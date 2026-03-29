
How to Setup on VS Code
=======================


1. Install `Run on Save` (Author: `emeraldwalk`) extension in Marketplace of VS Code.  

2. Add the following configuration to `settings.json`.

Modify the `note.py` path.

```json
"emeraldwalk.runonsave": {
    "commands": [
        {
            "match": "\\ Note.txt$",
            "cmd": "python3 ~/code/gcc3/note/.note/note.py -f \"${file}\""
        }
    ]
}
```

Or if use binary build from Rust or Python. (faster)  

```json
"emeraldwalk.runonsave": {
    "commands": [
        {
            "match": "\\ Note.txt$",
            "cmd": "~/code/gcc3/note/.note/note -f \"${file}\""
        }
    ]
},
```

3. Restart VS Code.
