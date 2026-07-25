# cl-tesseract

CFFI (Common Foreign Function Interface) bindings for
[Tesseract OCR](https://github.com/tesseract-ocr/tesseract), giving
Common Lisp callers direct access to Tesseract's C API instead of
shelling out to the `tesseract` command-line tool. Five convenience
functions cover the common case — pull recognized text or layout
information out of an image file in one call — plus the full underlying
C API for anything more involved.

See [CHANGELOG.md](CHANGELOG.md) for the dated history of what's changed
and [MAINTENANCE.md](MAINTENANCE.md) for design rationale, the full
binding-by-binding provenance of the 2026-07-26 update, and known open
scope.

> **Provenance and AI Disclosure**
>
> This is a fork of an existing open-source project, originally written
> by Edward Geist ([GOFAI/cl-tesseract](https://github.com/GOFAI/cl-tesseract),
> 2015).
>
> The 2026-07-26 update — bringing the bindings up to date against
> Tesseract 5.5.0 — was carried out through close collaboration between
> an experienced human programmer and Claude Sonnet 5 (Anthropic).
>
> It is published openly for community scrutiny and iteration.

## What it is

* `image-to-text` / `image-to-hocr` / `image-to-tsv` / `image-to-alto` /
  `image-to-page` — run OCR on an image file and get back plain text,
  HOCR XML, TSV, ALTO XML, or PAGE XML respectively, each with layout/
  confidence information beyond plain text (except `image-to-text`
  itself).
* `with-base-api`, `init-tess-api`, `process-pages`, and the full
  `capi.lisp` binding set for direct access to Tesseract's C API, if the
  five convenience functions above aren't enough.
* No image-decoding code of its own — Tesseract's own Leptonica
  dependency (installed alongside it) handles that; supported image
  formats depend entirely on your Leptonica build.

## Quickstart

Install Tesseract and its development headers first:

```bash
# Debian/Ubuntu
apt install tesseract-ocr libtesseract-dev tesseract-ocr-eng

# macOS (Homebrew)
brew install tesseract
```

Then, from Lisp:

```lisp
(push #p"/path/to/cl-tesseract/" asdf:*central-registry*)
(ql:quickload :cffi :silent t)
(asdf:load-system :cl-tesseract)

(cl-tesseract:tesseract-version)
;=> "5.5.0"
```

**Verify OCR itself works**, against any real image containing text
(the exact output below is from a real synthetic test image used to
verify the 2026-07-26 update — substitute your own image and you'll get
its actual recognized text instead):

```lisp
(cl-tesseract:image-to-text #p"/path/to/an/image.png")
;=> "Hello Tesseract 5
"
```

If this signals an error instead, see MAINTENANCE.md's Known gotchas —
most likely `*tessdata-directory*` didn't find your `.traineddata`
files (see Reference below).

## Reference

* **Exported symbols** (package `cl-tesseract`, nicknames `tesseract`/
  `tess`): `image-to-text`, `image-to-hocr`, `image-to-tsv`,
  `image-to-alto`, `image-to-page` — each `(filepath &key (lang "eng")
  (page 0))` (`image-to-text` has no `page` argument, since plain text
  has no per-page layout to select). `tesseract-version`,
  `*tessdata-directory*`, plus the lower-level `with-base-api`,
  `init-tess-api`, `process-pages` if you need to drive a `TessBaseAPI`
  yourself (see Cookbook). Everything in `capi.lisp` (the raw C
  bindings) is unexported but usable via `cl-tesseract::` if you need
  something the five convenience functions don't expose — progress-
  monitor/cancellation, loading a model from memory instead of a
  datapath, orientation/script detection, and more; see
  MAINTENANCE.md's Reference for the full C-to-Lisp binding table.
* **`*tessdata-directory*`** must point at the directory holding your
  `.traineddata` language-data files. Auto-detected at load time, in
  order: Debian/Ubuntu's apt layout
  (`/usr/share/tesseract-ocr/<major>/tessdata`), `/usr/share/tessdata`,
  Homebrew's Intel and Apple Silicon paths, `/usr/local/tessdata`, and
  (Windows) `C:\Program Files\Tesseract OCR\tessdata`. If none of these
  match your system, it's `nil` and you must set it yourself before
  calling any `image-to-*` function.
* **Requirements**: SBCL (this is what the 2026-07-26 update was
  verified against), `cffi` (Quicklisp), and a working Tesseract 5.x +
  Leptonica install with at least one language's `.traineddata` file
  available. The original project also claimed CCL support; that claim
  predates this update and hasn't been re-verified — check for yourself
  before relying on it.

## Cookbook

**Get layout information, not just text** — `image-to-hocr` (or `-tsv`/
`-alto`/`-page`) instead of `image-to-text`, same first argument:

```lisp
(cl-tesseract:image-to-hocr #p"/path/to/an/image.png")
;=> "  <div class='ocr_page' id='page_1' title='image \"...\"; bbox 0 0 600 100; ppageno 0; scan_res 70 70'>
   <div class='ocr_carea' id='block_1_1' title=\"bbox 13 27 354 54\">
..."
```

`image-to-tsv` is the most compact of the four layout formats if you
just need bounding boxes and per-word confidence for programmatic
consumption; `image-to-hocr` is the most widely supported by existing
tooling (parseable with Closure-XML or plump); `image-to-alto`/
`image-to-page` are for interoperating with library/archive systems that
specifically expect those XML dialects.

**Point at a different language-data directory**, without touching the
auto-detected default — shadow the special variable dynamically around
the call:

```lisp
(let ((cl-tesseract:*tessdata-directory* "/path/to/your/tessdata/"))
  (cl-tesseract:image-to-text #p"/path/to/an/image.png"))
```

## License

[MIT](LICENSE)
