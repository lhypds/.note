
.note
=====


.note is structured plain text designed to be read directly by humans. Rendering is optional, not required.  

Basiclly it is free to write. There are few rules to follow:  
- Note file name should be `ABC Note`, `ABC` is the topic.  
- Title with double underline (`=`), section title with a underline (`-`).  
- The First section title will be `ABC`. Describes the topic.  


install
-------

macOS, from the latest release:  
```sh
curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh
```

Windows, from PowerShell:  
```powershell
irm https://raw.githubusercontent.com/lhypds/.note/main/get.ps1 | iex
```

`get.sh` installs the rust build into `/usr/local/bin` when that is writable, otherwise `~/.local/bin`. Pass options through the pipe with `sh -s --`:  
```sh
curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh -s -- --prefix "$HOME/.local"
curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh -s -- --variant python
curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sudo sh   # system-wide
```

Release archives are built on Apple silicon. On Linux, on Intel Macs, and on Windows until a Windows build is published, build from source instead — see below — or download a release and run its `install.sh`.  


note
----

Executable.  

Use `setup.sh` to setup and use `build.sh` to build.  

* Python version  
`python` and `pip` is required.  

* Rust version  
Locate at `rust` folder.  
Rust version is faster and the executable is a single file.  
`cargo` is required, use `brew install rust` to install.  

Run `build.sh` to select Python or Rust.  
Either python or rust version generates `note` executable.  
Run `note` command with commands.  

Release  
`release.sh` to build `dot_note.zip` to `release` folder.


commands
--------

| Command    | Usage                                       | Description |
|------------|----------------------------------------------|-------------|
| `format`   | `note format "ABC Note.txt"`                  | Fix section underline lengths in the note file. See [doc](./doc) to set up Format on Save for VS Code or Sublime Text. |
| `search`   | `note search`                                 | Search note content and note names interactively using fzf. Selecting a file opens it with the system default application. |
| `open`     | `note open`                                   | Fuzzy search note file names (not content) using fzf, then open the selected file with the system default application. |
| `create`   | `note create "ABC" [-d\|--directory <dir>]`   | Create a new note file `ABC Note.txt`. `-d`/`--directory` sets the target directory (defaults to the current directory). |
| `delete`   | `note delete`                                  | Fuzzy search note file names using fzf, then delete the selected file after `y/N` confirmation. |
| `markdown` | `note markdown "ABC Note.txt" [--preview]`    | Convert the note to Markdown, output to a `.markdown` folder. `--preview` also generates a preview action log file. |

`search`, `open`, and `delete` require [fzf](https://github.com/junegunn/fzf) to be installed (`brew install fzf`), and read note paths from `~/.noterc` under the `notePath` key (semicolon-separated):  
```
notePath=~/Dropbox/Note;~/Dropbox/Note.video;
```


tools scripts
-------------

underline_fix.py  
Fix the unederline, make the underline the same length as the title.  
`underline_fix.py` to genreate `scan_result.json`.  
Review and edit the `scan_result.json`.  
Then run `underline_fix.py --fix` to execute the fix.  

line_ending_check.py  
Check the line ending.  


License
-------

MIT License, see [LICENSE](LICENSE).  
