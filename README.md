[![XERJ Corpus Hub contributor](https://hub.xerj.org/contributors/MettiFire/badge.svg)](https://hub.xerj.org/contributors/MettiFire)
<p align="center">
  <img src="docs/icon.png" width="128" alt="Dropwheel">
</p>

<h1 align="center">Dropwheel</h1>

<p align="center">
  Offline drag-and-drop file converter that lives in your menu bar.<br>
  Drag a file, tap a key, drop it on a slice of the wheel.
</p>

---

Dropwheel is a menu-bar-only app: no Dock icon, no windows. It stays invisible until you need it. Start dragging a file from Finder, tap one of the trigger keys, and a compact wheel opens under your cursor. Drop the file on a slice and the result lands right next to the original. Everything runs locally: nothing is ever uploaded. drag file >> tap a key >> wheel opens at the cursor >> drop on a slice >> result next to the original 
## Usage

| Key while dragging | Wheel | Examples |
|---|---|---|
| ⇧ Shift | Convert | HEIC to PNG, MOV to MP3, DOCX to PDF, EPUB to AZW3 |
| ⌘ Command | Tools | Compress, resize (50%, 25%, max 1080px), rotate, strip metadata, split or merge PDF |
| ⌃ Control | Actions | AirDrop, Copy, Copy Path, Reveal in Finder, open in Terminal |

Nothing shows up if you drag without tapping a key. While the wheel is open you can tap another trigger key to switch wheel. The slice under the cursor lights up as you move around the ring; drop to run it. Results never overwrite existing files: a clash becomes `name (1).ext`.

## Settings

Click the Dropwheel icon in the menu bar to open the settings popover.

| Setting | What it does |
|---|---|
| Trigger keys | Pick which of Shift, Command, Control or Option opens each wheel (picking a key already in use swaps the two) |
| Accent color | Lilac, Sky blue, Mint, Rose, Orange or Graphite; tints the wheel and the settings |
| Launch at login | Starts Dropwheel when you log in (works from the installed app) |
| Check installed tools | Lists which conversion tools are available |
| Open log | Opens `~/Library/Logs/Dropwheel.log` |
| Quit Dropwheel | The only way to quit, since there is no Dock icon |

## Install

Requirements: macOS 13+, Xcode command line tools.

```bash
brew install ffmpeg imagemagick libheif pandoc poppler ghostscript unar
brew install --cask libreoffice calibre
pip3 install pdf2docx

git clone <your-repo-url> && cd dropwheel
scripts/build_app.sh --install
```

This builds `build/Dropwheel.app`, generates the app icon, ad-hoc signs the app, copies it to `/Applications` and launches it. Then open the settings popover and enable *Launch at login*.

The app icon is lilac by default; build a sky-blue one with `ICON_THEME=sky scripts/build_app.sh --install`.

Handy while developing:

```bash
swift run                         # run from the repo root
python3 engine/engine.py doctor   # which tools are installed
```

You only need the tools for the conversions you use.

## Supported conversions

| Category | Input | Output |
|---|---|---|
| Images | JPG PNG WebP HEIC TIFF AVIF BMP | the same set + PDF |
| Audio | MP3 M4A WAV FLAC OGG Opus AIFF WMA | MP3 M4A WAV FLAC OGG Opus AIFF |
| Video | MP4 MOV MKV WebM AVI WMV GIF | MP4 MOV MKV WebM AVI GIF, MP3 (audio extract) |
| PDF | PDF | DOCX PNG JPG TXT EPUB AZW3 |
| Documents | DOCX MD TXT HTML RTF RTFD | DOCX MD TXT EPUB HTML PDF AZW3 MOBI |
| Ebooks | EPUB AZW3 AZW MOBI FB2 | EPUB AZW3 MOBI FB2 PDF TXT DOCX |
| Slides | PPT PPTX | PDF PNG JPG |
| Spreadsheets | XLSX XLS ODS CSV TSV | XLSX ODS CSV TSV PDF |
| Subtitles | SRT VTT | SRT VTT TXT |
| Archives | ZIP TAR TGZ GZ RAR | ZIP TAR TGZ |

Ebook conversion goes through Calibre and only works on DRM-free files.

## How it works

| Piece | File | Notes |
|---|---|---|
| Menu-bar agent | `App.swift`, `AppDelegate.swift` | Accessory app (no Dock icon); status item toggles the settings popover |
| Drag detection | `DragWatcher.swift` | Watches the drag pasteboard and polls modifier keys, so no Accessibility permission is needed |
| Wheel | `Wheel.swift` | Non-activating floating panel; one drop area for the whole wheel, the slice is computed from the cursor angle |
| What each wheel offers | `Options.swift` | Category to conversions, tools and actions |
| Formats and process runner | `Engine.swift` | Maps extensions to categories and runs the Python engine |
| Settings and login item | `Preferences.swift`, `SettingsView.swift` | Trigger keys and accent in `UserDefaults`, login item via `SMAppService` |
| Icons | `MenuIcon.swift`, `scripts/make_icon.swift` | Menu bar template icon drawn in code; app icon generated at build time |
| Conversion engine | `engine/engine.py` | A thin router over ffmpeg, ImageMagick, pandoc, LibreOffice, Calibre, poppler, Ghostscript, `textutil`, `ditto`, `tar` |

The engine also works on its own:

```bash
python3 engine/engine.py convert ~/Desktop/photo.heic png
python3 engine/engine.py tool resize-25 ~/Desktop/photo.jpg
python3 engine/engine.py tool merge-pdf a.pdf b.pdf
```

### Adding a conversion

1. Add the target extension to the category in `targets` (`Sources/Dropwheel/Engine.swift`).
2. Add the route in `convert()` in `engine/engine.py`.
3. Rebuild with `scripts/build_app.sh --install`.

## Troubleshooting

| Problem | What to do |
|---|---|
| A slice shows "Failed, see log" | Open the log from the settings popover, or read `~/Library/Logs/Dropwheel.log` |
| "missing dependency" in the log | Install the tool (see Install) and re-run *Check installed tools* |
| macOS asks to access Desktop, Documents or Downloads | Allow it: the engine needs to read and write next to your files |
| *Launch at login* does nothing | It only works from the installed app in `/Applications`; if it says approval is needed, enable Dropwheel in System Settings, General, Login Items |
| The wheel never appears | Tap the key while the mouse button is still held during the drag |
| No icon in the menu bar | The menu bar may be full; quit some other menu bar apps or check the Dropwheel process is running |

## Known limitations

- No `.pages` support, no PDF to PPTX or XLSX, no keyboard navigation of the wheel, no Move or Float actions.
- Video compression uses H.264, so it works for `mp4`, `mov` and `mkv` but not `webm` or `gif`.
- Mixed-category selections only get the Actions wheel.
- Markdown to PDF goes through pandoc, HTML and LibreOffice and is lightly tested.

## License

MIT
