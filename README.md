
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


command: search
---------------

`search` - Search note content using fzf.  
`note search`  
Opens an interactive fzf session to search text inside all note files.

Reads paths from `~/.noterc` under the `notePath` key (semicolon-separated):  
```
notePath=~/Dropbox/Note;~/Dropbox/Note.video;
```

Requires `fzf` to be installed (`brew install fzf`).  
Selecting a file opens it with the system default application.


command: create
---------------

`create` - Create a new note file.  
`note create "ABC Note"`  
It will create `ABC Note.txt` in the current directory.

`[-d|--directory]`  
Specify the directory to create the note in. Defaults to current directory.  
`note create "ABC Note" --directory path/to/directory`  


command: format
---------------

`format` - Format the note file.  
`note format "ABC Note.txt"`  
It will fix section underline lengths in the note file.  

* Format on Save  
Refer [doc](./doc) to setup `Format on Save` for text editors.  
Support setup for VS Code and Sublime Text.  


command: markdown
-----------------

`markdown` - Convert note to Markdown format.  
`note markdown "ABC Note.txt"`  
It will convert `ABC Note.txt` to `ABC Note.md`,  
and output to `.markdown` folder in the current directory.  

`--preview`  
`note markdown "ABC Note.txt" --preview` will also generate a preview action log file.  


tools scripts
-------------

underline_fix.py  
Fix the unederline, make the underline the same length as the title.  
`underline_fix.py` to genreate `scan_result.json`.  
Review and edit the `scan_result.json`.  
Then run `underline_fix.py --fix` to execute the fix.  

line_ending_check.py  
Check the line ending.  
