# HexMac **0.1**

![CI](https://github.com/tunerok/hexmac/actions/workflows/ci.yml/badge.svg)

[GitHub](https://github.com/tunerok/hexmac)

![HexMac hex editor](Img/2.png)

Native macOS hex editor for inspecting, editing, and analyzing binary files. Built with SwiftUI on a B+ tree byte array with file-backed slices — large files stay on disk while edits live in memory.

## Features

### Hex editor
- Memory slices — open large files without loading them entirely into RAM
- Virtual viewport scrolling with row cache, overscan, and background prefetch
- In-place save without temporary files; Save As streams through a bounded buffer
- New empty document and in-place byte editing with undo/redo
- Configurable bytes per row: 8, 16, 24, or 32
- Text column with multiple encodings: ASCII, UTF-8, UTF-16 LE/BE, Latin-1, Windows-1252, Mac Roman
- Copy selection as hex, fill/clear selected bytes, show selection as binary
- Save selection as raw binary (`.bin`) or hex text (`.hex`)
- Color highlights with navigation in the Inspector panel
- Status bar with offset, file size, bytes-per-row, and encoding controls
- Default text encoding in **Settings** (⌘,)

### Workspace
- Tabbed editor groups (VS Code–style layout)
- Split panes horizontally or vertically
- Drag-and-drop to open files
- Side-by-side binary comparison with color-coded diff, minimap, and linked scrolling
- **Compare with…** from a tab context menu to diff against another open file

### Analysis tools
- **Find** — search by hex pattern or ASCII text across the file or selection
- **Hash** — MD5, SHA-1, SHA-224/256/384/512 (file or selection)
- **CRC** — CRC-8/16/32 with 60+ industry presets (Modbus, USB, AUTOSAR, ISO-HDLC, …) and custom parameters
- **Histogram** — byte frequency distribution for the file or selection; export as PNG or JPEG
- **Inspector** — offset, length, binary view, integer interpretations (LE/BE, `int8_t` … `uint64_t`)

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
git clone https://github.com/tunerok/hexmac.git
cd hexmac
open HexMac.xcodeproj
```

In Xcode: select the **HexMac** scheme → **Run** (⌘R).

Don't want to develop an app? Please check out the [Releases](https://github.com/tunerok/hexmac/releases) section.

### Run tests

```bash
xcodebuild test \
  -project HexMac.xcodeproj \
  -scheme HexMac \
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
| Split right / down | ⌘\\ / ⇧⌘\\ |
| Next / previous tab | ⇧⌘] / ⇧⌘[ |
| Close tab / group | ⌘W / ⇧⌘W |
| Help | ⌘? |

## Project structure

```
HexMac/
├── HexMacApp.swift          # App entry point, menus, settings
├── ContentView.swift        # Root layout
├── Core/ByteArray/          # B+ tree, file/memory slices, chunked I/O, writer
├── Models/                  # Document, selection, CRC, find, highlight models
├── ViewModels/              # Workspace and pane state
├── Views/                   # SwiftUI views (grid, compare, tools, terminal)
└── Services/                # I/O, search, hash, CRC, scroll, compare, terminal

HexMacTests/                 # Unit tests (13 suites)
```

## Contributing

Issues and pull requests are welcome. Please keep changes focused and match the existing code style.

1. Fork the repository
2. Create a feature branch
3. Add tests when changing behavior in `Services/` or `Core/`
4. Open a pull request with a clear description

## License

[GNU General Public License v3.0](LICENSE) — Copyright © 2026 [tunerok](https://github.com/tunerok).

HexMac is free software: you may redistribute and/or modify it under the terms of the GPL v3 or (at your option) any later version.

## Screenshots

![Screenshot 1](Img/1.png)

![Screenshot 2](Img/2.png)

![Screenshot 3](Img/3.png)

![Screenshot 4](Img/4.png)

![Screenshot 5](Img/5.png)

![Screenshot 6](Img/6.png)

![Screenshot 7](Img/7.png)

![Screenshot 8](Img/8.png)
