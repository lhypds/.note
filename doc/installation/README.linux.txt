
Linux: Installing note
======================


This archive holds a `note` build for one Linux architecture, plus the
`install.sh` that puts it on your PATH.


Install
-------

Run the installer from inside this directory:
`./install.sh`

It copies `note` to /usr/local/bin, installs fzf through your package
manager when it is missing, and creates ~/.noterc. It uses sudo when it
needs root and sudo is available; on a root shell without sudo it just
writes directly.

To install somewhere you own instead of /usr/local, use get.sh:
`curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh -s -- --prefix "$HOME/.local"`


About the build
---------------

The `note` binary (dot_note_rust_*) is statically linked against musl. It
has no shared library dependencies at all, so it runs on any distribution,
including Alpine.


Opening notes on a headless machine
-----------------------------------

`note search`, `note open` and `note create` hand the selected file to
xdg-open. On a server with no desktop session there is no xdg-open, so
note falls back to $VISUAL, then $EDITOR. Set one of them in your shell
profile:
`export EDITOR=vim`


Uninstall
---------

`./uninstall.sh`

It removes /usr/local/bin/note and ~/.note.
