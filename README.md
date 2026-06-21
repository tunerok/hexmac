# ediHex **0.2a**

![CI](https://github.com/tunerok/edihex/actions/workflows/ci.yml/badge.svg)

[GitHub](https://github.com/tunerok/edihex)

![ediHex hex editor](Img/2.png)

Native macOS hex editor for inspecting, editing, and analyzing binary files. Built with SwiftUI on a B+ tree byte array with file-backed slices — large files stay on disk while edits live in memory.

## Features

Hex editor:
- Large files without RAM load.
- Edit, undo/redo, adjustable view (width, encodings).
- Copy, fill, clear, export selection.
- Highlights, inspector, status bar, settings.

Workspace:
- Tabs, split panes, drag-and-drop.
- Side-by-side compare with highlights, sync scroll, diff navigation.

Analysis:
- Search HEX/text with progress, save results.
- Hashes (MD5, SHA, CRC), histogram with export.
- Inspector with offset, length, binary view, integer decoding, search/diff results.

### Built-in terminal
Scriptable command line in the panel below the editor (active document pane). Disabled in comparison panes. Type `help` for the full reference.

| Command | Description |
|---------|-------------|
| `goto` | Jump to a byte offset |
| `hex`, `bin`, `ascii` | Dump bytes in different formats |
| `sum`, `xor`, `avg`, `min`, `max` | Byte math over ranges |
| `len`, `count` | Length and byte frequency |
| `read` | Read typed values at an offset (`--le` / `--be`) |
| `find` | Search hex or ASCII patterns |
| `cmp` | Compare two byte ranges |
| `crc`, `hash` | Checksums and digests |
| `help ranges`, `help filters`, `help crc` | Detailed syntax docs |

Ranges support decimal and hex offsets, multiple segments, and sampling filters (`--every`, `--skip`, etc.).

## Requirements

- macOS 15.6 or later
- Xcode 26 or later (Swift 5)

CI runs on `macos-15` with Xcode 26.

## Build & run

```bash
git clone https://github.com/tunerok/edihex.git
cd edihex
open ediHex.xcodeproj
```

In Xcode: select the **ediHex** scheme → **Run** (⌘R).

Don't want to develop an app? Please check out the [Releases](https://github.com/tunerok/edihex/releases) section.

### Run tests

```bash
xcodebuild test \
  -project ediHex.xcodeproj \
  -scheme ediHex \
  -destination 'platform=macOS'
```

Test coverage includes byte-array I/O, virtual scroll window, row loading and caches, pattern search, hashing, CRC, comparison diff mapping, highlight spans, histogram building, and the terminal command parser/tokenizer.

## Keyboard shortcuts

| Action | Shortcut |
|--------|----------|
| New file | ⌘N |
| Open file | ⌘O |
| Save / Save As | ⌘S / ⇧⌘S |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Copy selection as hex | ⇧⌘C |
| Find | ⌘F |
| Next / previous difference (compare) | F3 / ⇧F3 |
| Split right / down | ⌘\\ / ⇧⌘\\ |
| Next / previous tab | ⇧⌘] / ⇧⌘[ |
| Close tab / group | ⌘W / ⇧⌘W |
| Help | ⌘? |

## Project structure

```
ediHex/
├── ediHexApp.swift          # App entry point, menus, settings
├── ContentView.swift        # Root layout
├── Core/ByteArray/          # B+ tree, file/memory slices, chunked I/O, writer
├── Models/                  # Document, selection, CRC, find, highlight models
├── ViewModels/              # Workspace and pane state
├── Views/                   # SwiftUI views (grid, compare, tools, terminal)
└── Services/                # I/O, search, hash, CRC, scroll, compare, terminal

ediHexTests/                 # Unit tests (13 suites)
```

## Contributing

Issues and pull requests are welcome. Please keep changes focused and match the existing code style.

1. Fork the repository
2. Create a feature branch
3. Add tests when changing behavior in `Services/` or `Core/`
4. Open a pull request with a clear description

## License

[GNU General Public License v3.0](LICENSE) — Copyright © 2026 [tunerok](https://github.com/tunerok).

ediHex is free software: you may redistribute and/or modify it under the terms of the GPL v3 or (at your option) any later version.

## Screenshots

![Screenshot 1](Img/1.png)

![Screenshot 2](Img/2.png)

![Screenshot 3](Img/3.png)

![Screenshot 4](Img/4.png)

![Screenshot 5](Img/5.png)

![Screenshot 6](Img/6.png)

![Screenshot 7](Img/7.png)

![Screenshot 8](Img/8.png)
