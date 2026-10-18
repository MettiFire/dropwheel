# dropwheel

A small, fully offline "drag a file, tap a key, drop on an option" file converter for macOS.
Independent implementation inspired by the interaction model of radial-menu file tools. Not affiliated with them, and it contains no code from any third-party app.

```
drag file >> tap modifier >> wheel appears at cursor >> drop on an option >> engine/engine.py >> output next to source
```

| Key while dragging | Wheel | Examples |
|---|---|---|
| ⇧ Shift | Convert | HEIC → PNG, MOV → MP3, DOCX → PDF |
| ⌘ Command | Tools | Compress, Resize 50%, Rotate, Strip metadata, Split / Merge PDF |
| ⌃ Control | Actions | AirDrop, Copy, Copy Path, Reveal, Terminal |

## Architecture

| Piece | File | Notes |
|---|---|---|
| Menu-bar agent | `main.swift`, `AppDelegate.swift` | `.accessory` activation policy, no Dock icon |
| Drag detection | `DragWatcher.swift` | Polls `NSPasteboard(name: .drag)` + `NSEvent.pressedMouseButtons`; modifiers via `NSEvent.modifierFlags` (no Accessibility permission needed) |
| Wheel UI | `Wheel.swift` | Non-activating floating `NSPanel` hosting SwiftUI; each option is an `.onDrop` target |
| Options per mode | `Options.swift` | Category → targets/tools routing |
| Formats + process runner | `Engine.swift` | Spawns `python3 engine/engine.py` with Homebrew on `PATH` |
| Conversion engine | `engine/engine.py` | Thin router onto ffmpeg, ImageMagick, pandoc, LibreOffice, poppler, ghostscript, `textutil`, `ditto`, `tar` |

The engine also works standalone:

```bash
python3 engine/engine.py convert ~/Desktop/photo.heic png
python3 engine/engine.py tool compress ~/Desktop/clip.mov
python3 engine/engine.py tool merge-pdf a.pdf b.pdf
```

## Requirements

- macOS 13+, Xcode command line tools (Swift 5.9+)
- Homebrew packages:

```bash
brew install ffmpeg imagemagick libheif pandoc poppler ghostscript unar
brew install --cask libreoffice
pip3 install pdf2docx
```

## Run

```bash
git clone <your-repo-url> && cd dropwheel
swift run            # run from the repo root so engine/engine.py is found
# or: DROPWHEEL_ENGINE=/abs/path/to/engine/engine.py swift run
```

A menu-bar icon appears. Start dragging a file from Finder, tap ⇧ / ⌘ / ⌃, then drop on an option. Results are written next to the original and never overwrite existing files. Errors are printed to the terminal.

## Supported conversions

| Category | Targets |
|---|---|
| Images | JPG PNG WebP HEIC TIFF AVIF BMP PDF |
| Audio | MP3 M4A WAV FLAC OGG Opus AIFF |
| Video | MP4 MOV MKV WebM AVI GIF, MP3 (audio extract) |
| PDF | DOCX PNG JPG TXT |
| Documents | DOCX MD TXT EPUB HTML PDF (RTF/RTFD input via `textutil`) |
| Slides | PPT/PPTX → PDF PNG JPG |
| Spreadsheets | XLSX ODS CSV TSV PDF |
| Subtitles | SRT VTT TXT |
| Archives | ZIP TAR TGZ (RAR input via `unar`) |

## Known limitations

- The Swift sources were written without access to a Mac toolchain and have not been compiled yet. Expect to fix a few compile errors on first build.
- No `.pages` support, no PDF → PPTX/XLSX, no Enter/arrow-key navigation, no Move/Float actions.
- Video compress uses H.264 (`mp4`/`mov`/`mkv`); `webm`/`gif` will fail.
- Mixed-category selections only get the Actions wheel.
- Markdown → PDF goes through pandoc → HTML → LibreOffice (untested).

## License

MIT
