
.note
=====


`note` is a format for `txt` files.  

Basiclly it is free to write. There are few rules to follow:  
- Note file name should be `ABC Note`, `ABC` is the topic.  
- Title with double underline (`=`), section title with a underline (`-`).  
- The First section title will be `ABC`. Describes the topic.  


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
| `search`   | `note search`                                 | Search note content and note names interactively using fzf. Selecting a file opens it with the system default application. |
| `open`     | `note open`                                   | Fuzzy search note file names (not content) using fzf, then open the selected file with the system default application. |
| `delete`   | `note delete`                                  | Fuzzy search note file names using fzf, then delete the selected file after `y/N` confirmation. |
| `create`   | `note create "ABC" [-d\|--directory <dir>]`   | Create a new note file `ABC Note.txt`. `-d`/`--directory` sets the target directory (defaults to the current directory). |
| `format`   | `note format "ABC Note.txt"`                  | Fix section underline lengths in the note file. See [doc](./doc) to set up Format on Save for VS Code or Sublime Text. |
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
