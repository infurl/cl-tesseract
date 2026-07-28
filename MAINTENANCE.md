# cl-tesseract — Maintenance

See [README.md](README.md) for the user-facing Quickstart/Reference and
[CHANGELOG.md](CHANGELOG.md) for the dated history.

## Provenance

Originally written by Edward Geist
([GOFAI/cl-tesseract](https://github.com/GOFAI/cl-tesseract)), first
committed 2015-10-18: SWIG-generated CFFI bindings against Tesseract
3.04.00's C API, plus five hand-written convenience functions
(`image-to-text`, `image-to-hocr`, and their `with-base-api`/
`init-tess-api`/`process-pages` plumbing). MIT licensed. A Windows
namestring fix and an SBCL float-trap workaround followed the same year
and in 2017; a Homebrew-on-Apple-Silicon path was merged 2025-01-09 (PR
from `lispnik`) — otherwise untouched between 2017-11-12 and that merge.
His original README is preserved, unedited, as
[ORIGINAL_README.txt](ORIGINAL_README.txt).

Forked to `infurl/cl-tesseract`, then modernized 2026-07-26 against a
real Tesseract 5.5.0 + `libtesseract-dev` installation after being
frozen at 3.04-era conventions for over a decade.

**The 2026-07-26 modernization pass** is the bulk of what this document
covers below. **A 2026-07-27 follow-up pass**, prompted by real reviewer
feedback after that release (see "What changed in the 2026-07-27 pass"
below), lispified the binding names and added the regression-check
suite the prior pass's own "Known gotchas" flagged as missing. **A
2026-07-28 pass** fixed a real page-segmentation-mode default mismatch
against the `tesseract` CLI tool, found while wiring up this library's
first real consumer (see "What changed in the 2026-07-28 pass" and
"Consumers" below).

## Architecture

Three files, loaded in this order (`cl-tesseract.asd`):

1. **`library.lisp`** — `cffi:define-foreign-library` (locates
   `libtesseract` across platforms) and `*tessdata-directory*`
   (locates `.traineddata` files). The only file with platform-specific
   logic.
2. **`capi.lisp`** — raw `cffi:defcfun`/`defcenum` bindings, one per
   Tesseract C API entry point, no logic of its own. Rewritten wholesale
   2026-07-26 against `/usr/include/tesseract/capi.h` (libtesseract-dev
   5.5.0-1+b1) rather than patched piecemeal, since the drift between
   3.04 and 5.5 touched enough of the file that a fresh pass against the
   real header was more reliable than diffing.
3. **`cl-tesseract.lisp`** — the five convenience functions and their
   shared plumbing (`with-base-api`, `mask-sigfpe`, `run-ocr`,
   `owned-foreign-string`).

## What changed in the 2026-07-26 modernization

**Enum drift, both silent:**
- `TessOcrEngineMode`: Tesseract dropped its old Cube OCR engine
  entirely between 3.04 and 4.x in favor of an LSTM-based one. The enum
  ordinals didn't move (`OEM_TESSERACT_ONLY`, then Cube's/LSTM's slot,
  then the combined slot, then `OEM_DEFAULT`), but the old binding still
  named the middle two `OEM_CUBE_ONLY`/`OEM_TESSERACT_CUBE_COMBINED` —
  renamed to `OEM_LSTM_ONLY`/`OEM_TESSERACT_LSTM_COMBINED` to match the
  real header. Nothing in this library actually passes an explicit OEM
  value (only `TessBaseAPIInit3`, which has no OEM parameter, is used by
  the convenience functions), so this was a naming-correctness fix, not
  a behavior change.
- `TessPageSegMode`: gained `PSM_RAW_LINE`, inserted before `PSM_COUNT`
  in the real header but entirely missing from the old binding — every
  enum value from that point on (just `PSM_COUNT` itself, in practice)
  was silently off by one relative to the real library.

**Signature drift:**
- `TessPDFRendererCreate` gained a third parameter (`BOOL textonly`)
  between 3.04 and 5.5; the old binding only declared two.
- `TessBaseAPIInit4`'s `vars_vec_size` parameter is a `size_t` **value**
  in the real header, not a pointer as the old binding declared. CFFI
  has no built-in `:size_t` type (confirmed by trying `cffi:defcfun`
  with it directly — signals "Unknown CFFI type"), so a local
  `tess-size-t` type alias to `:unsigned-long` was added instead — correct
  on the 64-bit Linux/macOS platforms this library targets, would need
  revisiting for a 32-bit or Windows port.

**Functions dropped outright** (confirmed absent from
`/usr/include/tesseract/capi.h`, not just unused): Cube recognition
context (`TessBaseAPIGetCubeRecoContext`), TBLOB/OCRRow construction
(`TessMakeTessOCRRow`, `TessMakeTBLOB`, `TessNormalizeTBLOB`),
thresholder/dict/probability/lattice callback injection
(`TessBaseAPISetThresholder`, `TessBaseAPISetDictFunc`,
`TessBaseAPISetProbabilityInContextFunc`, `TessBaseAPISetFillLatticeFunc`),
the old `TessBaseAPIInit` mega-overload (superseded by `Init1`-`Init5`),
`TessFindRowForBox`, `TessBaseAPIDumpPGM`, `TessDeleteBlockList`,
`TessBaseAPIInitLangMod`, `TessBaseAPIGetOpenCLDevice`,
`TessBaseAPIRecognizeForChopTest`, `TessBaseAPIGetFeaturesForBlob`,
`TessBaseAPIRunAdaptiveClassifier`, `TessBaseAPIGetDawg`/`NumDawgs`'s
sibling `TessBaseAPIGetDawg` (`NumDawgs` itself remains, still in the
real header), `TessBaseAPIInitTruthCallback`,
`TessBaseAPIDetectOS` (replaced — see below). None of these were called
by the five convenience functions, so dropping them changed nothing
observable; they were dead, silently-broken bindings (CFFI resolves
foreign symbols lazily, so calling any of these against a real 5.5
library would have failed at call time with an undefined-symbol error,
not at load time).

**New v5.5 API surface added:**
- Renderers/text-getters: `TessAltoRendererCreate`/`GetAltoText`,
  `TessPAGERendererCreate`/`GetPAGEText`, `TessTsvRendererCreate`/
  `GetTsvText`, `TessLSTMBoxRendererCreate`, `TessWordStrBoxRendererCreate`/
  `GetWordStrBoxText`. The first three are exposed as new convenience
  functions (`image-to-alto`, `image-to-page`, `image-to-tsv`); the LSTM/
  word-str-box renderers are bound but not wrapped, since they're niche
  enough (LSTM training-data-format box output) that no convenience
  wrapper seemed worth adding speculatively.
- A real cancellable progress-monitor API: `TessMonitorCreate`/`Delete`/
  `SetCancelFunc`/`SetCancelThis`/`GetCancelThis`/`SetProgressFunc`/
  `GetProgress`/`SetDeadlineMSecs`. Previously unreachable in practice —
  `process-pages`/`TessBaseAPIRecognize` always passed a null monitor
  pointer, so cancellation/progress callbacks were never wired up even
  though the underlying library always accepted a real monitor there.
  Bound but not yet threaded through `process-pages` or exposed as a
  keyword argument — open scope, see below.
- `TessBaseAPIInit5` — like `Init4` but takes an in-memory data buffer
  instead of a datapath string, for loading a `.traineddata` file
  without it existing on disk as a separate file. Bound, not yet wrapped.
- `TessBaseAPIDetectOrientationScript` — replaces the removed
  `TessBaseAPIDetectOS`, different signature (separate `orient_deg`/
  `orient_conf`/`script_name`/`script_conf` out-parameters rather than a
  single results struct). Bound, not yet wrapped.
- `TessBaseAPIGetGradient` — new in 5.5, no 3.04 equivalent. Bound, not
  yet wrapped.

**A real, pre-existing memory leak fixed** (not version-specific — this
bug was present in the original 2015 bindings too): every `Get*Text`
call (`TessBaseAPIGetUTF8Text`, `GetHOCRText`, `GetTsvText`, `GetAltoText`,
`GetPAGEText`, `GetBoxText`, `GetUNLVText`, etc.) returns a heap-allocated
buffer that Tesseract's own C API documents as caller-owned, freed via
`TessDeleteText`. The original bindings declared these functions' return
type as CFFI `:string`, which copies the bytes into a fresh Lisp string
but never frees the original C buffer — every single OCR call leaked
that buffer. Fixed by changing these bindings' return type to `:pointer`
and adding a shared `owned-foreign-string` helper
(`cl-tesseract.lisp`) that copies-then-frees explicitly.

**Measured, not just asserted, and the honest result wasn't what was
expected:** a naive before/after RSS comparison across 500
`image-to-text` calls against the same small test image showed
near-identical growth (~20MB) with and without the fix. Isolated
further by re-running the same measurement calling only
`TessBaseAPICreate`/`TessBaseAPIInit3`/`TessBaseAPIEnd`/`TessBaseAPIDelete`
in a loop, zero OCR calls at all — and got the *same* ~18MB growth. This
confirms the RSS growth is almost entirely repeated `TessBaseAPI`
creation and language-model reload (ordinary glibc malloc-arena
behavior — freed memory not returned to the OS — present in both old and
new code, and inherent to this library's own design: every
`image-to-*` call creates a fresh `TessBaseAPI` and reloads the language
model from scratch via `init-tess-api`), not the leaked text buffer,
whose real per-call footprint is bytes, dwarfed by that background
churn. **The fix is still correct per Tesseract's documented API
contract** — it's a real leak that would matter at larger buffer sizes
or over a long enough run — but this measurement doesn't demonstrate a
dramatic win, and the README says so rather than overclaiming one.

**Two portability fixes, the actual reason the library failed to load
at all on Debian/Ubuntu before this pass:**
- `*tessdata-directory*`'s probing only ever checked macOS/Homebrew
  paths (`/usr/local/share/tessdata`, `/opt/homebrew/share/tessdata`)
  plus a generic `/usr/local/tessdata` — none of which exist on Debian/
  Ubuntu, whose `tesseract-ocr` apt package installs to
  `/usr/share/tesseract-ocr/<major-version>/tessdata` instead. Since the
  old code's `(namestring (or (probe-file ...) ...))` fell through to
  `(namestring nil)` when nothing matched, this was a hard load-time
  error (`The value NIL is not of type (OR STRING PATHNAME ...)`), not
  a soft misconfiguration — confirmed directly by trying to load the
  original bindings unmodified on a Debian install before making any
  changes. Fixed with `find-tessdata-directory`, which globs
  `/usr/share/tesseract-ocr/*/tessdata/` (tolerant of future Tesseract
  major-version bumps) before falling back through the original paths;
  if nothing is found, `*tessdata-directory*` is now `nil` rather than
  erroring, so a caller gets a clear "no tessdata found" signal at
  `init-tess-api` time instead of a load-time crash.
- The `:linux` foreign-library search list only tried `libtesseract.3.so`
  (a 3.x-major-version-specific name) or `libtesseract.so` (the
  unversioned name, which only exists because the `-dev` package happens
  to symlink it). A deployment with only the runtime `libtesseract5`
  package installed, not `-dev`, would have no unversioned symlink to
  find. Fixed by trying `libtesseract.so.5` explicitly first.

**SIGFPE workaround**: `mask-sigfpe` (wraps recognition calls in
`sb-int:with-float-traps-masked` on SBCL) dates from a real 3.04/Cube-
engine numeric quirk. Tested with the trap deliberately left unmasked
against Tesseract 5.5's LSTM engine (a raw, unwrapped
`tessbaseapiprocesspages` call) and it did not reproduce — but only one
simple synthetic test image was tried, not a survey of edge cases, so
the macro is kept in place regardless as cheap defensive insurance
rather than removed on the strength of one negative test.

## What changed in the 2026-07-27 pass

Prompted by real reviewer feedback after the 2026-07-26 release went
public — someone asked, reasonably, why the bindings still read as raw
C names (`TessBaseAPICreate` etc.) instead of ordinary Lisp identifiers,
and separately, why there was no test suite.

**Lispification.** Every `defcfun`'s Lisp-side name, every `defcenum`
type name, and every enum value keyword in `capi.lisp` is now
kebab-case: `TessBaseAPICreate` → `tess-base-api-create`,
`TessOcrEngineMode` → `tess-ocr-engine-mode`, `:OEM_TESSERACT_ONLY` →
`:oem-tesseract-only`. Only the Lisp-side symbol changed — the first
argument to each `defcfun`, the actual string CFFI resolves against
`libtesseract`, is untouched, so this is a pure renaming with no
behavior change. Generated mechanically (a standard CamelCase-to-
kebab-case regex pass: insert a hyphen between a lowercase/digit and a
following uppercase letter, and between the last letter of an uppercase
run and a following capitalized word), then reviewed by hand for
acronym runs the generic rule gets wrong:
- `TessHOcrRendererCreate`/`TessHOcrRendererCreate2` → `tess-hocr-
  renderer-create`/`-create2`, not `tess-h-ocr-...` (the mechanical rule
  would split `HOcr` into `H`+`Ocr`, since it's mixed-case in the real
  header rather than a clean `HOCR` or `Hocr`).
- `TessMonitorSetDeadlineMSecs` → `tess-monitor-set-deadline-msecs`,
  not `...-deadline-m-secs` (`MSecs` is one abbreviation, milliseconds,
  not the letter M followed by a word "Secs").
- `TessResultRendererExtention` → `tess-result-renderer-extention`,
  keeping the real header's own misspelling (it really is "Extention",
  not "Extension", in `capi.h`) rather than silently correcting a typo
  that would then no longer match the C name it's bound to.
- `TRUE`/`FALSE` → `+true+`/`+false+`, the ordinary CL earmuff
  convention for constants (neither is referenced anywhere in this
  library's own code; both exist only for a caller reaching into
  `capi.lisp` directly).

All call sites in `cl-tesseract.lisp` (the five convenience functions
and their shared plumbing) updated to match. Docstrings still name the
underlying C function being called (e.g. "calls `TessBaseAPIRecognize`
on api") deliberately — that's the identifier a reader needs to cross-
reference `capi.h` itself, not the Lisp binding name.

**Regression-check suite.** `tests/test-cl-tesseract.lisp` (new
`cl-tesseract/tests` ASDF system, `(asdf:test-op :cl-tesseract)`), 19
checks, using the same dependency-free `check`/`run-checks` harness
convention as `/workspace/common-lisp/glr-parser`'s own test suite
rather than pulling in an external test framework. Deliberately real
integration checks, not mocks: a committed fixture image
(`tests/fixtures/hello-tesseract.png`, "Hello Tesseract 5" rendered in
DejaVu Sans Mono) is run through all five `image-to-*` functions
against a genuine local Tesseract + `eng.traineddata` install, plus
checks that the three renamed enums still resolve to their correct
ordinals via `cffi:foreign-enum-value` (a direct regression guard for
the lispification above), an error-path check
(`init-tess-api` on a nonexistent language), and an `UNWIND-PROTECT`
cleanup check for `with-base-api`. Mocking the FFI boundary itself
would defeat the purpose — a CFFI signature drift, an enum-ordinal
shift, or a renamed C symbol are exactly the bugs a mock would hide.
**No CI wired up around this suite, on purpose**: this project's
`git`/OKF conventions don't currently run anything on a push hook or a
hosted CI service, and adding one felt like more infrastructure than a
small, personal CFFI-bindings project warrants right now — revisit if
that calculus changes (more contributors, a package-manager release,
etc.), but it isn't default scope for a project this size.

## What changed in the 2026-07-28 pass

Found while wiring up `cl-ocr` (a full-book OCR pipeline, this
library's first real consumer — see "Consumers" below) against a real
320-page book PDF: page reconstruction failed on essentially every page
tried, not just unusual ones.

Root-caused by diffing `image-to-tsv`'s output against the `tesseract`
CLI tool's output for the exact same rasterized PNG (the book's title
page). Two discrepancies, both confirmed rather than assumed:

- **The real bug**: `TessBaseAPIInit3` defaults `page_seg_mode` to
  `PSM_SINGLE_BLOCK` — confirmed directly by calling
  `TessBaseAPIGetPageSegMode` immediately after `init-tess-api` with no
  other calls in between. The `tesseract` CLI tool, by contrast, sets
  `PSM_AUTO` explicitly before OCR unless overridden by its own `--psm`
  flag — a default that lives in the CLI program itself, invisible to
  anyone calling the C API directly the way this library does. Since
  none of the five `image-to-*` functions ever called
  `TessBaseAPISetPageSegMode`, they silently inherited single-block
  mode: on the title page, the CLI's TSV output correctly separates
  "A Student's Introduction to English Grammar" (title) from "Rodney
  Huddleston and Geoffrey K. Pullum" (authors) into two blocks with
  accurate bounding boxes; the un-set-PSM API output merged the entire
  page (title, authors, and the blank space around them) into one
  oversized `block_1` spanning nearly the full page height. Not a crash
  — geometrically wrong output, which is worse, since nothing signals
  that anything went wrong at the OCR-call site itself. (It surfaced
  downstream as `OCR-PARENT-ERROR` in `cl-ocr`'s own page-reconstruction
  code, once that code's assumptions about block/paragraph nesting broke
  against the malformed geometry — a different, separate project's bug
  report, not evidence of a bug in that project's own logic.)
- **A second, smaller discrepancy**: the CLI's TSV output has a
  `level\tpage_num\t...` header row; `TessBaseAPIGetTsvText` (what
  `image-to-tsv` calls) does not include one. Not fixed here — this is
  a real difference between the CLI's own `TsvRenderer` and the raw
  `GetTsvText` API call, not a bug in either; documented so a future
  caller comparing the two doesn't waste time on it the way this pass
  did initially. (`cl-ocr` works around it on its own side, by
  prepending the header line itself before writing the cached `.tsv`
  file — see that project's own docs.)

**Fix**: all five `image-to-*` functions gained a `:psm` keyword
argument, defaulting to `:psm-auto` (CLI parity), threaded through the
shared `run-ocr` helper via a new required parameter — `run-ocr` now
calls `TessBaseAPISetPageSegMode` between `init-tess-api` and
`process-pages`. Purely additive at the call sites: every existing
`image-to-*` call with no `:psm` argument now behaves like the CLI tool
by default instead of like raw `TessBaseAPIInit3`, which is a *behavior*
change (recognized text/layout can differ on multi-block images) even
though it required no *signature* change for existing callers.

**Verified against real data, not just the regression suite**: reran
`image-to-tsv` on the book's title page after the fix and diffed against
the CLI tool's own TSV output for the same PNG — byte-identical except
for the header row (the second discrepancy above, deliberately not
patched around at this layer). 3 new checks added to
`tests/test-cl-tesseract.lisp` (22 total, up from 19): the raw
`TessBaseAPIInit3` default really is `:psm-single-block` right now (a
guard against libtesseract silently changing that default in some
future version, which would make the explicit `:psm-auto` call
redundant rather than load-bearing and this whole fix worth
re-examining), that explicitly setting `:psm-auto` actually moves it
away from that default, and that the `:psm` keyword genuinely reaches
the C call through `image-to-tsv` — the last of these had to be checked
via `TessBaseAPIGetPageSegMode` from inside a custom `run-ocr` extractor
rather than by comparing recognized output, since the committed
`hello-tesseract.png` fixture (one short line of text) turned out not to
produce visibly different output between segmentation modes, unlike the
real book page that surfaced this bug in the first place.

## Reference: the full C-to-Lisp binding surface

Every function in `capi.lisp` binds 1:1 to the correspondingly-named C
function in `/usr/include/tesseract/capi.h` — see that header directly
for parameter/return semantics beyond what's in this document. Since
the 2026-07-27 lispification pass, the Lisp-side name is no longer
identical to the C name (`tess-base-api-create` vs. `TessBaseAPICreate`)
but is mechanically derivable from it (kebab-case the C name); the
first argument to each `defcfun` — the actual foreign-symbol string CFFI
links against — is still the exact, unmodified C name. There is no
separate binding-by-binding table here beyond what's already spelled
out above; the enum/struct/general-free-function/renderer/base-API/
page-iterator/result-iterator/choice-iterator/progress-monitor grouping
in `capi.lisp` itself (each under its own `;;;` comment header) mirrors
the header's own section structure.

## Known gotchas / open scope

- **CCL untested.** The original project claimed CCL support; that
  claim predates this update and has not been re-verified against
  Tesseract 5.5.
- **Progress-monitor, `Init5`, `DetectOrientationScript`, `GetGradient`,
  and the LSTM/word-str-box renderers are bound in `capi.lisp` but have
  no convenience wrapper** — a caller needs `cl-tesseract::` package
  access and to call them directly. Worth adding wrappers if a real use
  case for any of them comes up; speculative wrappers weren't added
  without one.
- **`run-ocr`'s design re-creates and re-initializes a `TessBaseAPI` on
  every single call** (`with-base-api` + `init-tess-api` +
  `process-pages`, all inside each `image-to-*` call) — inherited
  unchanged from the original 3.04-era design. Fine for occasional/one-
  off OCR; a caller doing high-volume repeated OCR would get more benefit
  from keeping one `TessBaseAPI` alive across calls (via `with-base-api`/
  `init-tess-api`/`process-pages` directly, bypassing `image-to-*`) than
  from the memory-leak fix above, per the RSS measurement above.

## Dependencies

- `cffi` (Quicklisp), the only ASDF `:depends-on`.
- `libtesseract5`/`libtesseract-dev` (verified against 5.5.0-1+b1) and
  Leptonica (Tesseract's own image-decoding dependency, pulled in
  alongside it), plus at least one `tesseract-ocr-<lang>` language-data
  package — all system/apt packages, not managed by ASDF or Quicklisp.

## Consumers

**`cl-ocr`** (in the sibling `asiteg/` checkout) — a full-book OCR
pipeline that runs Tesseract over every page of a source PDF and
caches the results under `$XDG_CACHE_HOME/cl-ocr/`. Uses `image-to-tsv`/
`image-to-text` (and, as new output formats are added, potentially
`image-to-hocr`/`-alto`/`-page` for font-styling information beyond
what TSV carries) from multiple threads at once — each call creates and
tears down its own `TessBaseAPI` (see "`run-ocr`'s design" in Known
gotchas below), which is Tesseract's own recommended pattern for
multi-threaded use, so no changes were needed here to support that.
Surfaced the 2026-07-28 `:psm` fix above.
