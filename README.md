Playlist view and [contact sheet](https://en.wikipedia.org/wiki/Contact_print) scripts for [mpv](https://github.com/mpv-player/mpv).

[![demo](https://i.vimeocdn.com/video/811681643.jpg)](https://vimeo.com/358137972)

# Important

* **Make sure that the thumbnail directory exists for thumbnail generation to work.**
* **The default thumbnail directory is probably not appropriate for your system.** `~/.mpv_thumbs_dir/` on Unix, `%APPDATA%\mpv\gallery-thumbs-dir` on Windows. See Configuration for instructions on how to change it.

# Installation

Copy everything in `scripts/` to your mpv scripts directory.

If you are not interested in the playlist view or contact sheet, respectively remove the [`playlist-view.lua`](scripts/playlist-view.lua) or [`contact-sheet.lua`](scripts/contact-sheet.lua) files.

You can make multiple copies (or symlinks) of [`gallery-thumbgen.lua`](scripts/gallery-thumbgen.lua) to speed up thumbnail generation, they will register themselves automatically.

# Usage

By default, the playlist-view can be opened with `g` and the contact-sheet with `c`.

In both you can navigate around using arrow keys or the mouse.

When you activate an item in the playlist-view, it will switch to that file. In the contact sheet, it will seek to that timestamp.

# Configuration

Both scripts can be configured through the usual `script-opts` mechanism of mpv (see its [manual](https://mpv.io/manual/master/#files)). The files [`contact_sheet.conf`](script-opts/contact_sheet.conf) and [`playlist_view.conf`](script-opts/playlist_view.conf) in this repository contain a detailed list of options.

Note that both scripts cannot be used at the same time, as they compete for the same resources. If you want to use both, I recommend using the following input.conf bindings:
```
g script-message contact-sheet-close; script-message playlist-view-toggle
c script-message playlist-view-close; script-message contact-sheet-toggle
```
To ensure that only one of the scripts is active at a time.

# Playlist-view flagging

When the playlist-view is open, you can flag playlist entries (using `SPACE` by default). Flagged entries are indicated with a small frame. Then, when exiting mpv a text file will be created (default `./mpv_gallery_flagged`) containing the filenames of the flagged entries, one per line.

# Limitations

Yet another ad-hoc thumbnail library, which is not shared with any other program.

Management of the thumbnails is left to the user. In particular, stale thumbnails (whose file has been (re)moved) are not deleted by the script. This can be fixed by deleting thumbnails which have not been accessed since N days with such a snippet
```
days=7
min=$((days * 60 * 24))
# run first without -delete to be sure
find ~/.mpv_thumbs_dir/ -maxdepth 1 -type f -amin +$min -delete
```

Thumbnails are raw bgra, which is somewhat wasteful. With the default settings, a thumbnail uses 81KB (around 13k thumbnails in a GB).
