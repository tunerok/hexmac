# HexMac

![HexMac hex editor](Img/2.png)

Native macOS hex editor for inspecting, editing, and analyzing binary files. Built with SwiftUI and a HexFiend-style slice for fast work with large files.

## Features

### Hex editor
- Slice-based file access — open large files without loading them entirely into RAM
- In-place save without temporary files; Save As streams through a bounded buffer
- In-place byte editing with undo/redo
- Configurable bytes per row: 8, 16, 24, or 32
- Text column with multiple encodings: ASCII, UTF-8, UTF-16 LE/BE, Latin-1, Windows-1252, Mac Roman
- Copy selection as hex, fill/clear selected bytes
- Color highlights with navigation in the Inspector panel

### Workspace
- Tabbed editor groups (VS Code–style layout)
- Split panes horizontally or vertically
- Side-by-side binary comparison with diff minimap

### Analysis tools
- **Find** — search by hex pattern or ASCII text across the file or selection
- **Hash** — MD5, SHA-1, SHA-224/256/384/512, SHA3-256/384/512 (file or selection)
- **CRC** — CRC-8/16/32 with 60+ industry presets (Modbus, USB, AUTOSAR, ISO-HDLC, …) and custom parameters
- **Histogram** — byte frequency distribution for the file or selection
- **Inspector** — offset, length, binary view, integer interpretations (LE/BE)

### Built-in terminal
Scriptable command line inside each document pane. Type `help` for the full reference.

| Command | Description |
|---------|-------------|
| `goto` | Jump to a byte offset |
| `hex`, `bin`, `ascii` | Dump bytes in different formats |
| `sum`, `xor`, `avg`, `min`, `max` | Byte math over ranges |
| `len`, `count` | Length and byte frequency |
| `read` | Read typed values at an offset |
| `find` | Search hex or ASCII patterns |
| `cmp` | Compare two byte ranges |
| `crc`, `hash` | Checksums and digests |
| `help ranges`, `help filters`, `help crc` | Detailed syntax docs |

Ranges support decimal and hex offsets, multiple segments, and sampling filters (`--every`, `--skip`, etc.).

## Requirements

- macOS 26.5 or later
- Xcode 26 or later (Swift 5)

## Build & run

```bash
git clone https://github.com/tunerok/hexmac.git
cd hexmac
open HexMac.xcodeproj
```

In Xcode: select the **HexMac** scheme → **Run** (⌘R).

### Run tests

```bash
xcodebuild test \
  -project HexMac.xcodeproj \
  -scheme HexMac \
  -destination 'platform=macOS'
```

## Keyboard shortcuts

| Action | Shortcut |
|--------|----------|
| Open file | ⌘O |
| Save / Save As | ⌘S / ⇧⌘S |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Copy selection (hex) | ⌘C |
| Find | ⌘F |
| Split right / down | ⌘\\ / ⇧⌘\\ |
| Next / previous tab | ⇧⌘] / ⇧⌘[ |
| Close tab / group | ⌘W / ⇧⌘W |

## Project structure

```
HexMac/
├── HexMacApp.swift          # App entry point, menus
├── Models/                  # Document, selection, CRC, find models
├── ViewModels/              # Workspace and pane state
├── Views/                   # SwiftUI views (grid, compare, tools)
└── Services/                # I/O, search, hash, CRC, terminal parser

HexMacTests/                 # Unit tests
```

## Contributing

Issues and pull requests are welcome. Please keep changes focused and match the existing code style.

1. Fork the repository
2. Create a feature branch
3. Add tests when changing behavior in `Services/`
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
