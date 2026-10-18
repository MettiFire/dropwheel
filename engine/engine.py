#!/usr/bin/env python3
"""dropwheel conversion engine (offline, wraps open-source CLI tools).

  engine.py convert <file> <ext>
  engine.py tool <name> <file> [<file> ...]

tools: compress | resize-50 | rotate-90 | strip-metadata | split-pdf | merge-pdf
Outputs are written next to the source and never overwrite existing files.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

os.environ["PATH"] = os.pathsep.join([
    "/opt/homebrew/bin", "/usr/local/bin",
    *glob.glob(os.path.expanduser("~/Library/Python/*/bin")),
    os.environ.get("PATH", ""),
])

IMG = {"jpg", "jpeg", "png", "webp", "heic", "tiff", "tif", "avif", "bmp"}
AUD = {"mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"}
VID = {"mp4", "mov", "mkv", "webm", "avi", "wmv", "gif"}
DOC = {"docx", "md", "txt", "epub", "html"}
SLIDE = {"pptx", "ppt"}
SHEET = {"xlsx", "xls", "ods", "csv", "tsv"}
SUB = {"srt", "vtt"}
EBOOK = {"epub", "azw3", "azw", "mobi", "fb2"}
ARC = {"zip", "tar", "tgz", "gz", "rar"}


def sh(*cmd):
    subprocess.run([str(c) for c in cmd], check=True)


def need(tool):
    if not shutil.which(tool):
        sys.exit(f"missing dependency: {tool} (see README)")


def unique(p: Path) -> Path:
    if not p.exists():
        return p
    i = 1
    while True:
        q = p.with_name(f"{p.stem} ({i}){p.suffix}")
        if not q.exists():
            return q
        i += 1


def calibre_bin():
    for c in ("ebook-convert", "/Applications/calibre.app/Contents/MacOS/ebook-convert"):
        p = shutil.which(c) or (c if Path(c).exists() else None)
        if p:
            return p
    sys.exit("missing dependency: calibre (brew install --cask calibre)")


def soffice_bin():
    for c in ("soffice", "/Applications/LibreOffice.app/Contents/MacOS/soffice"):
        p = shutil.which(c) or (c if Path(c).exists() else None)
        if p:
            return p
    sys.exit("missing dependency: LibreOffice (brew install --cask libreoffice)")


def via_soffice(src: Path, fmt: str, out: Path):
    spec, produced = fmt, fmt
    if fmt == "tsv":
        spec, produced = "csv:Text - txt - csv (StarCalc):9,34,76,1", "csv"
    elif fmt == "pdf" and src.suffix.lower() == ".html":
        spec = "pdf:writer_web_pdf_Export"
    with tempfile.TemporaryDirectory() as t:
        sh(soffice_bin(), "--headless", "--convert-to", spec, "--outdir", t, src)
        res = Path(t) / f"{src.stem}.{produced}"
        if not res.exists():
            sys.exit("LibreOffice produced no output")
        shutil.move(str(res), str(out))


def strip_subs(text: str) -> str:
    keep = []
    for line in text.splitlines():
        l = line.strip()
        if not l or l.isdigit() or "-->" in l or l.startswith("WEBVTT"):
            continue
        keep.append(re.sub(r"<[^>]+>", "", l))
    return "\n".join(keep) + "\n"


def pdf_to(src: Path, ext: str, out: Path):
    if ext in {"png", "jpg"}:
        need("pdftoppm")
        sh("pdftoppm", "-r", "300", "-png" if ext == "png" else "-jpeg", src, out.with_suffix(""))
    elif ext == "docx":
        need("pdf2docx")
        sh("pdf2docx", "convert", src, out)
    elif ext == "txt":
        need("pdftotext")
        sh("pdftotext", "-layout", src, out)
    else:
        sys.exit(f"no route: pdf >> {ext}")


def convert_archive(src: Path, ext: str):
    if ext not in {"zip", "tar", "tgz"}:
        sys.exit(f"no route: archive >> {ext}")
    name, low = src.name, src.name.lower()
    for suf in (".tar.gz", ".tgz", ".tar", ".gz", ".zip", ".rar"):
        if low.endswith(suf):
            name = name[: -len(suf)]
            break
    out = unique(src.with_name(f"{name}.{ext}"))
    with tempfile.TemporaryDirectory() as t:
        tp = Path(t)
        if low.endswith(".zip"):
            sh("ditto", "-x", "-k", src, tp)
        elif low.endswith((".tar", ".tar.gz", ".tgz")):
            sh("tar", "-xf", src, "-C", tp)
        elif low.endswith(".gz"):
            with open(tp / name, "wb") as f:
                subprocess.run(["gzip", "-dc", str(src)], stdout=f, check=True)
        elif low.endswith(".rar"):
            need("unar")
            sh("unar", "-q", "-o", tp, src)
        if ext == "zip":
            sh("ditto", "-c", "-k", tp, out)
        elif ext == "tar":
            sh("tar", "-cf", out, "-C", tp, ".")
        else:
            sh("tar", "-czf", out, "-C", tp, ".")


def convert(src: Path, ext: str):
    s = src.suffix.lower().lstrip(".")
    if s == ext:
        sys.exit("source and target formats are the same")
    if s in ARC:
        return convert_archive(src, ext)

    out = unique(src.with_suffix("." + ext))

    if s in SUB and ext in SUB:
        need("ffmpeg")
        sh("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, out)
    elif s in SUB and ext == "txt":
        out.write_text(strip_subs(src.read_text(errors="ignore")))
    elif s in IMG and (ext in IMG or ext == "pdf"):
        need("magick")
        sh("magick", src, out)
    elif s in AUD | VID and ext in AUD | VID:
        need("ffmpeg")
        sh("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, *(["-vn"] if ext in AUD else []), out)
    elif (s in EBOOK
          or (ext in {"azw3", "mobi", "fb2"} and s in DOC | {"rtf"})
          or (s == "pdf" and ext in {"epub", "azw3", "mobi", "fb2"})):
        sh(calibre_bin(), src, out)
    elif s == "pdf":
        pdf_to(src, ext, out)
    elif s in SLIDE and ext in {"pdf", "png", "jpg"}:
        if ext == "pdf":
            via_soffice(src, "pdf", out)
        else:
            with tempfile.TemporaryDirectory() as t:
                tmp_pdf = Path(t) / f"{src.stem}.pdf"
                via_soffice(src, "pdf", tmp_pdf)
                pdf_to(tmp_pdf, ext, out)
    elif s in SHEET and ext in {"xlsx", "ods", "csv", "tsv", "pdf"}:
        via_soffice(src, ext, out)
    elif s in {"rtf", "rtfd"} and ext in {"docx", "txt", "html"}:
        sh("textutil", "-convert", ext, src, "-output", out)
    elif s in {"rtf", "rtfd"} and ext == "pdf":
        via_soffice(src, "pdf", out)
    elif s in DOC and ext == "pdf":
        if s == "md":
            need("pandoc")
            with tempfile.TemporaryDirectory() as t:
                h = Path(t) / f"{src.stem}.html"
                sh("pandoc", src, "-s", "-o", h)
                via_soffice(h, "pdf", out)
        else:
            via_soffice(src, "pdf", out)
    elif s in DOC and ext in DOC:
        need("pandoc")
        sh("pandoc", src, "-o", out)
    else:
        sys.exit(f"no route: {s} >> {ext}")


def tool_single(name: str, f: Path):
    s = f.suffix.lower().lstrip(".")

    def outname(tag):
        return unique(f.with_name(f"{f.stem}-{tag}{f.suffix}"))

    if name == "compress":
        out = outname("compressed")
        if s in IMG:
            need("magick")
            sh("magick", f, "-strip", "-quality", "75", out)
        elif s in VID:
            need("ffmpeg")
            sh("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", f, "-vcodec", "libx264", "-crf", "28",
               "-preset", "medium", "-acodec", "aac", out)
        elif s == "pdf":
            need("gs")
            sh("gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=pdfwrite",
               "-dPDFSETTINGS=/ebook", f"-sOutputFile={out}", f)
        else:
            sys.exit(f"compress: unsupported type {s}")
    elif name in {"resize-50", "rotate-90"} and s in IMG:
        need("magick")
        arg = ["-resize", "50%"] if name == "resize-50" else ["-rotate", "90"]
        sh("magick", f, *arg, outname(name))
    elif name == "strip-metadata":
        out = outname("clean")
        if s in IMG:
            need("magick")
            sh("magick", f, "-strip", out)
        elif s in AUD | VID:
            need("ffmpeg")
            sh("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", f, "-map_metadata", "-1", "-c", "copy", out)
        else:
            sys.exit(f"strip-metadata: unsupported type {s}")
    elif name == "split-pdf" and s == "pdf":
        need("pdfseparate")
        sh("pdfseparate", f, f.with_name(f"{f.stem}-page-%d.pdf"))
    else:
        sys.exit(f"unknown tool or unsupported file: {name} / {s}")


def tool(name: str, files):
    if name == "merge-pdf":
        need("gs")
        out = unique(files[0].with_name("merged.pdf"))
        sh("gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=pdfwrite", f"-sOutputFile={out}", *files)
        return
    for f in files:
        tool_single(name, f)


def doctor():
    for t in ["ffmpeg", "magick", "pandoc", "pdftoppm", "pdftotext", "pdfseparate",
              "gs", "unar", "pdf2docx", "textutil", "ditto"]:
        print(("ok      " if shutil.which(t) else "MISSING ") + t)
    lo = any(shutil.which(c) or Path(c).exists() for c in
             ("soffice", "/Applications/LibreOffice.app/Contents/MacOS/soffice"))
    print(("ok      " if lo else "MISSING ") + "soffice (LibreOffice)")
    cal = any(shutil.which(c) or Path(c).exists() for c in
              ("ebook-convert", "/Applications/calibre.app/Contents/MacOS/ebook-convert"))
    print(("ok      " if cal else "MISSING ") + "ebook-convert (calibre)")


def main(argv):
    try:
        if len(argv) >= 4 and argv[1] == "convert":
            convert(Path(argv[2]).expanduser(), argv[3].lstrip("."))
        elif len(argv) >= 4 and argv[1] == "tool":
            tool(argv[2], [Path(a).expanduser() for a in argv[3:]])
        elif len(argv) == 2 and argv[1] == "doctor":
            doctor()
        else:
            print(__doc__)
            sys.exit(2)
    except subprocess.CalledProcessError as e:
        sys.exit(f"command failed: {e.cmd[0]} (exit {e.returncode})")


if __name__ == "__main__":
    main(sys.argv)
