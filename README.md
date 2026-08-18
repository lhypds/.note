
.note
=====


.note is structured plain text designed to be read directly by humans. Rendering is optional, not required.  

Basiclly it is free to write. There are few rules to follow:  
- Note file name should be `ABC Note`, `ABC` is the topic.  
- Title with double underline (`=`), section title with a underline (`-`).  
- The First section title will be `ABC`. Describes the topic.  


install
-------

macOS and Linux, from the latest release:  
```sh
curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh
```

Windows, from PowerShell:  
```powershell
irm https://raw.githubusercontent.com/lhypds/.note/main/get.ps1 | iex
```

`get.sh` installs into `/usr/local/bin` when that is writable, otherwise `~/.local/bin`. Pass options through the pipe with `sh -s --`:  
```sh
curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh -s -- --prefix "$HOME/.local"
curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sudo sh   # system-wide
```

Each release publishes one archive per platform, named `dot_note_rust_v<version>_<os>_<arch>.zip`:  

| Platform      | published |
|---------------|-----------|
| macOS arm64   | yes       |
| Linux x86_64  | yes       |
| Linux arm64   | yes       |
| Windows       | no        |

The Linux build is statically linked against musl, so it runs on any distribution including Alpine.  

On Intel Macs and on Windows, build from source instead — see below — or download a release and run its `install.sh`.  


note
----

Executable.  

Written in Rust, in the `rust` folder. `cargo` is required — use `brew install rust` to install it.  

Run `./build.sh` to build; it generates the `note` executable at the repository root.  
Run `note` with the commands below.  

Release  
`release.sh` builds every platform archive into the `release` folder and then publishes them with `release_gh.sh`. Run it on macOS: it builds the macOS archives natively and cross-builds the Linux ones in Docker. `--no-linux` skips the Docker step, `--linux-x86-only` skips the arm64 half, `--no-publish` stops before GitHub.  

`build_linux.sh` does the Linux cross-build on its own (`--arch x86_64|arm64`). Docker must be running.


commands
--------

| Command    | Usage                                       | Description |
|------------|----------------------------------------------|-------------|
| `format`   | `note format "ABC Note.txt"`                  | Fix section underline lengths in the note file. See [doc](./doc) to set up Format on Save for VS Code or Sublime Text. |
| `search`   | `note search`                                 | Search note content and note names interactively using fzf. Selecting a file opens it with the system default application. |
| `open`     | `note open [<query>]`                         | Fuzzy search note file names (not content) using fzf, then open the selected file with the system default application. With `<query>`, fzf is skipped and the nearest matching note opens directly — `note open drugs` opens `Drugs Note.txt`. |
| `create`   | `note create "ABC" [-d\|--directory <dir>]`   | Create a new note file `ABC Note.txt`. `-d`/`--directory` sets the target directory (defaults to the current directory). |
| `delete`   | `note delete`                                  | Fuzzy search note file names using fzf, then delete the selected file after `y/N` confirmation. |
| `markdown` | `note markdown "ABC Note.txt" [--preview]`    | Convert the note to Markdown, output to a `.markdown` folder. `--preview` also generates a preview action log file. |

`search`, `open`, and `delete` require [fzf](https://github.com/junegunn/fzf) to be installed (`note open <query>` does not, it matches names on its own) (`brew install fzf`, or your distribution's package manager on Linux), and read note paths from `~/.noterc` under the `notePath` key (semicolon-separated):  
```
notePath=~/Dropbox/Note;~/Dropbox/Note.video;
```

Selected files open with the system default application — `open` on macOS, `xdg-open` on Linux. On a headless Linux machine, where there is no `xdg-open`, note falls back to `$VISUAL` and then `$EDITOR`.  


License
-------

MIT License, see [LICENSE](LICENSE).  
