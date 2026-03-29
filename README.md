
.note
=====


note is a format.

Basiclly it is free to write, but there are few rules to follow:  
- Note file name should be `ABC Note`, `ABC` is the topic.  
- Title with double underline (`=`), section title with a underline (`-`).  
- The First section title will be `ABC`. Describes the topic.  


note
----

Executable that format the notes.  

* Python version  
Use `setup.sh` to setup and use `build.sh` to build.  
`build.sh` generates both `note` and `notemd`.  

* Rust version  
Rust version is faster.  
`cd note_rust` run `build.sh` to build.  
`cargo` is required, use `brew install rust` to install.  

Either python or rust will generate `note` executable.  
Then you can run `note` command to format the notes.  

`./note [-f|--file] abc_note.txt` will format the note.  

* Format on Save  
Refer [doc](https://github.com/lhypds/.note/tree/main/doc) to setup `Format on Save` for text editors.  
Support setup for VS Code and Sublime Text.  


note markdown
-------------

Convert note to Markdown format.  
`python note_markdown.py`  
Or use executable `./notemd` after running `build.sh`.  

* Path to note files  
It will use the `NOTE_DIR` as path.  
Or set with `--path` option.  
If both not set, it will use `../` as default path.  

* Preview result  
`python note_markdown.py --preview abc_note.txt`  
Output `abc_note_pr.md` and `abc_note_pr.txt`.  

* Helper scripts  
`note_markdown.sh`  
`preview.sh`  
`mdclear.sh`  


note tools
----------

underline_fix.py  
Fix the unederline, make the underline the same length as the title.  
`underline_fix.py` to genreate `scan_result.json`.  
Review and edit the `scan_result.json`.  
Then run `underline_fix.py --fix` to execute the fix.  

line_ending_check.py  
Check the line ending.  
