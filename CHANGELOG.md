# Changelog

All notable changes to cl-tesseract, in reverse-chronological order.
There's no version-number scheme for this project, so entries are dated
instead.

## 2026-07-28

Found while wiring up the first real consumer (`cl-ocr`, an OCR pipeline
for full-length book PDFs — see MAINTENANCE.md's "Consumers"):

* **Fixed a real, silent segmentation-mode mismatch against the
  `tesseract` CLI tool.** `TessBaseAPIInit3` defaults `page_seg_mode` to
  `PSM_SINGLE_BLOCK` (confirmed via `TessBaseAPIGetPageSegMode`
  immediately after init, no other calls in between) — but the
  `tesseract` CLI tool explicitly sets `PSM_AUTO` before OCR unless its
  own `--psm` flag overrides it. None of the five `image-to-*`
  convenience functions ever called `TessBaseAPISetPageSegMode`, so they
  silently inherited single-block mode: not a crash, geometrically wrong
  output — confirmed directly against a real book's title page, whose
  CLI-tool TSV output correctly separates title/author into distinct
  blocks while the unset-PSM API output merged the entire page into one
  oversized block. All five `image-to-*` functions gained a `:psm`
  keyword, defaulting to `:psm-auto` (CLI parity), threaded through the
  shared `run-ocr` helper. Additive, not breaking — existing call sites
  need no changes. 3 new regression checks (22 total): the raw
  `TessBaseAPIInit3` default really is `:psm-single-block` (a guard in
  case libtesseract itself changes that default in a future version,
  which would make the explicit `:psm-auto` call redundant rather than
  load-bearing), that setting `:psm-auto` explicitly actually moves it
  away from that default, and that the `:psm` keyword genuinely reaches
  the C call through `image-to-tsv`.
* **Added `image-to-word-styles`**, a sixth convenience function: real
  per-word bold/italic/underlined/monospace/serif/smallcaps/font-name/
  pointsize data, for `cl-ocr`'s planned use of this signal to recover
  typographic emphasis a plain OCR pass throws away. Returns structured
  Lisp data (a list of plists) rather than a string, unlike every other
  `image-to-*` function — there's no standard textual format carrying
  font attributes the way TSV/HOCR/ALTO/PAGE do for text/layout. Uses
  Tesseract's legacy engine internally (`TessBaseAPIInit2` with
  `:oem-tesseract-only`, via a new `init-tess-api-with-oem` helper;
  every other function is untouched, still using `init-tess-api`/
  `TessBaseAPIInit3`) — confirmed empirically that the LSTM engine
  (what every other function effectively uses) returns a null font-name
  and every boolean attribute hardcoded false rather than erroring, so
  this isn't a style preference, real font data genuinely requires the
  legacy engine. That engine in turn needs a tessdata file with real
  legacy-engine components — Debian/Ubuntu's `tesseract-ocr-<lang>` apt
  package (LSTM-only "fast" data) fails outright; verified against the
  real upstream [tesseract-ocr/tessdata](https://github.com/tesseract-ocr/tessdata)
  mirror instead, including a genuine bold-vs-plain discrimination test
  (new fixture `tests/fixtures/word-styles.png`) — see README's Cookbook
  for the real verified output. 1 new regression check (23 total): a
  portable robustness check (real data or a clean error, never an
  uncontrolled crash) rather than a hard-coded legacy-tessdata
  dependency in the automated suite, since that's a workspace-local
  resource, not something a fresh clone can assume.

## 2026-07-27

Prompted by real reviewer feedback after the 2026-07-26 release (see
MAINTENANCE.md's "Known gotchas" for the full account):

* **`capi.lisp`'s Lisp-side bindings lispified to kebab-case.** All 139
  `defcfun` names, all 8 `defcenum` type names, and every enum value
  keyword (`_` → `-`) now read as ordinary Lisp identifiers
  (`tess-base-api-create`, `tess-ocr-engine-mode`, `:oem-tesseract-only`,
  etc.) instead of the raw CamelCase C names the bindings previously
  reused verbatim (`TessBaseAPICreate` read as-is). The actual CFFI
  foreign-symbol strings — what really gets linked against
  `libtesseract` — are untouched; only the Lisp-side name changed. Two
  acronym runs needed a manual override rather than the generic
  CamelCase-to-kebab-case rule (`TessHOcrRendererCreate` → `tess-hocr-
  renderer-create`, not `tess-h-ocr-...`; `TessMonitorSetDeadlineMSecs`
  → `...-deadline-msecs`, not `...-deadline-m-secs`).
  `TessResultRendererExtention` keeps the header's own real misspelling
  (`tess-result-renderer-extention`) rather than silently correcting it.
  `TRUE`/`FALSE` renamed to `+true+`/`+false+` per ordinary CL constant
  convention. All call sites in `cl-tesseract.lisp` updated to match.
* **Added a regression-check suite** (`tests/test-cl-tesseract.lisp`,
  new `cl-tesseract/tests` ASDF system, run via
  `(asdf:test-op :cl-tesseract)`), closing the "No test suite" item from
  the prior pass's known gotchas. 19 checks, run as real integration
  tests against a genuine local Tesseract install and a small committed
  fixture image (`tests/fixtures/hello-tesseract.png`) rather than
  mocks — mocking the FFI boundary itself would test nothing that could
  actually regress here (a signature drift, an enum-ordinal shift, a
  renamed C symbol). No CI wired up — a deliberate choice, see
  MAINTENANCE.md.
* Documented `tessdata`/`tesseract` GitHub mirrors added under
  `resources/github/` for provenance cross-referencing.

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
* Fixed the actual reason the library failed to load at all on Debian/
  Ubuntu: `*tessdata-directory*` never probed its apt layout, and the
  foreign-library search list relied on an unversioned `.so` symlink
  only the `-dev` package provides.
* Added this CHANGELOG.md, plus a MAINTENANCE.md split out from
  README.md: agent/developer/maintainer-oriented content in
  MAINTENANCE.md, strictly user-facing content in README.md.
* The original 2015 README, superseded in content by the new
  README.md, is preserved unedited as
  [ORIGINAL_README.txt](ORIGINAL_README.txt) rather than deleted.

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
