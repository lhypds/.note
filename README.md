
note
====

note is a format.

Basiclly it is free to write, but there are few rules to follow:  
- Note file name should be `ABC Note`, X is the topic.  
- Title with double underline (`=`), section title with a underline (`-`).  
- The First section title will be `ABC`. Describes the topic.  


note
----

Executable that format the notes.  


note markdown
-------------

Convert note to Markdown format.  

Preview result:  
`python note_markdown.py --preview abc_note.txt`  

Helper scripts:  
`notemd.sh`  
`notemd_preview.sh`  


note tools
----------

underline_fix.py  
Fix the unederline, make the underline the same length as the title.  
`underline_fix.py` to genreate `scan_result.json`.  
Review and edit the `scan_result.json`.  
Then run `underline_fix.py --fix` to execute the fix.  

line_ending_check.py  
Check the line ending.  
