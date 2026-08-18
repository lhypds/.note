
How to Setup on VS Code
=======================


1. Install `Run on Save` (Author: `emeraldwalk`) extension in Marketplace of VS Code.  

2. Add the following configuration to `settings.json`.

Modify the `note` executable path.

```json
"emeraldwalk.runonsave": {
    "commands": [
        {
            "match": "\\ Note.txt$",
            "cmd": "~/code/gcc3/note/.note/note format \"${file}\""
        }
    ]
},
```

If `note` is already on your PATH, the bare command works too.  

```json
"emeraldwalk.runonsave": {
    "commands": [
        {
            "match": "\\ Note.txt$",
            "cmd": "note format \"${file}\""
        }
    ]
},
```

3. Restart VS Code.
