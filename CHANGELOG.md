# Changelog

All notable changes to cl-tesseract, in reverse-chronological order.
There's no version-number scheme for this project, so entries are dated
instead.

## 2026-07-26

Full modernization to Tesseract 5.5.0, after over a decade frozen at
3.04-era conventions. See [MAINTENANCE.md](MAINTENANCE.md) for the full
technical account; summary:

* `capi.lisp` rewritten wholesale against the real installed header
  (`/usr/include/tesseract/capi.h`, libtesseract-dev 5.5.0-1+b1):
  `TessOcrEngineMode`'s Cube-era names corrected to the real LSTM-era
  ones (Tesseract dropped the Cube engine entirely between 3.04 and
  4.x); `TessPageSegMode` gained `PSM_RAW_LINE`, missing before and
  silently shifting the enum's last value; `TessPDFRendererCreate`'s
  3rd parameter and `TessBaseAPIInit4`'s `vars_vec_size` type corrected;
  ~15 functions no longer in the library dropped rather than left as
  dead bindings.
* New v5.5 API surface added: TSV/ALTO/PAGE-XML output exposed as new
  convenience functions (`image-to-tsv`, `image-to-alto`,
  `image-to-page`, alongside the original `image-to-text`/
  `image-to-hocr`); a real cancellable progress-monitor API, `Init5`
  (load models from memory), `DetectOrientationScript`, and
  `GetGradient` bound at the C level (not yet wrapped).
* Fixed a real, pre-existing memory leak (not version-specific): every
  `Get*Text` call leaked its heap-allocated return buffer since the
  original 2015 bindings declared it CFFI `:string` instead of freeing
  it via `TessDeleteText`. Fixed and honestly measured — found to be
  dwarfed by unrelated per-call `TessBaseAPI`-recreation overhead
  inherent to this library's design, not overclaimed as a dramatic win.
* Fixed the actual reason the library failed to load at all on this
  container: `*tessdata-directory*` never probed Debian/Ubuntu's apt
  layout, and the foreign-library search list relied on an unversioned
  `.so` symlink only the `-dev` package provides.
* Restructured as a git submodule of the containing `common-lisp/`
  workspace repo, rather than an untracked nested checkout.
* Added this CHANGELOG.md, plus a MAINTENANCE.md split out from
  README.md per this workspace's documentation policy (agent/developer/
  maintainer-oriented content in MAINTENANCE.md, strictly user-facing
  content in README.md).

## Prior history (2015–2025)

* **2025-01-09** — merged a Homebrew-on-Apple-Silicon tessdata path
  (`/opt/homebrew/share/tessdata`).
* **2017-11-12** — updated the SBCL float-trap workaround to ignore
  `:invalid` in addition to `:divide-by-zero`.
* **2015-10-26** — fixed a Windows namestring bug; removed a stray
  `library.lisp~` backup file.
* **2015-10-18** — initial release by Edward Geist
  ([GOFAI/cl-tesseract](https://github.com/GOFAI/cl-tesseract)): SWIG-
  generated CFFI bindings against Tesseract 3.04.00, plus
  `image-to-text`/`image-to-hocr` and their supporting plumbing.

See `git log` in this repository for the complete commit-level history.
