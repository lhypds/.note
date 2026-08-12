
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


Which build to take
-------------------

* Rust build (dot_note_rust_*)
Statically linked against musl. It has no shared library dependencies at
all, so it runs on any distribution, including Alpine.

* Python build (dot_note_python_*)
A PyInstaller bundle, linked against glibc 2.31. It needs Debian 11,
Ubuntu 20.04, RHEL 9 or newer. The `note` executable and its `_internal`
directory must stay side by side, which is why install.sh copies the whole
bundle to /usr/local/lib/note and symlinks it.

The rust build is faster and more portable. Prefer it unless you have a
reason not to.


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

It removes /usr/local/bin/note, the /usr/local/lib/note bundle if the
python build was installed, and ~/.note.
