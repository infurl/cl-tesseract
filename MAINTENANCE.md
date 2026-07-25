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

Forked to `infurl/cl-tesseract` (Andrew Smith) and added to this
workspace 2026-07-26 as a git **submodule** of `common-lisp/` (real git
history preserved via `git submodule add`, not a vendor-copy-in like
[galar](/workspace/okf/tooling/galar.md)'s). Andrew had just added the
`tesseract-ocr`/`libtesseract-dev` 5.5.0 packages to this container and
asked for the bindings — frozen at 3.04-era conventions for over a
decade — to be brought up to date against them.

**The 2026-07-26 modernization pass** (commit `03ceed8`) is the bulk of
what this document covers below. Full technical rationale for each
individual binding change also lives in that commit's own message; this
document restates and organizes it for a maintainer who hasn't read the
commit, and adds the parts that don't fit a commit message (the
Reference table, the RSS measurement methodology, open scope).

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

**Two container-portability fixes, the actual reason the library failed
to load at all before this pass** (on this Debian container
specifically, likely on most non-macOS Linux installs generally):
- `*tessdata-directory*`'s probing only ever checked macOS/Homebrew
  paths (`/usr/local/share/tessdata`, `/opt/homebrew/share/tessdata`)
  plus a generic `/usr/local/tessdata` — none of which exist on Debian/
  Ubuntu, whose `tesseract-ocr` apt package installs to
  `/usr/share/tesseract-ocr/<major-version>/tessdata` instead. Since the
  old code's `(namestring (or (probe-file ...) ...))` fell through to
  `(namestring nil)` when nothing matched, this was a hard load-time
  error (`The value NIL is not of type (OR STRING PATHNAME ...)`), not
  a soft misconfiguration — confirmed directly by trying to load the
  original bindings unmodified against this container before making any
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

## Reference: the full C-to-Lisp binding surface

Every function in `capi.lisp` binds 1:1 to the identically-named C
function in `/usr/include/tesseract/capi.h` — see that header directly
for parameter/return semantics beyond what's in this document; there is
no separate binding-by-binding table here beyond what's already spelled
out above; the enum/struct/general-free-function/renderer/base-API/
page-iterator/result-iterator/choice-iterator/progress-monitor grouping
in `capi.lisp` itself (each under its own `;;;` comment header) mirrors
the header's own section structure.

## Known gotchas / open scope

- **No test suite.** Verification for the 2026-07-26 pass was manual:
  a synthetic PIL-generated test image, run through all five
  `image-to-*` functions plus the RSS-measurement scripts described
  above, all in throwaway `sbcl --script` processes rather than this
  workspace's persistent sbcl-bridge (per the standing policy of never
  experimenting against a pinned production core). Nothing here is
  wired into an ASDF `:test-op` or run automatically.
- **CCL untested.** The original project claimed CCL support; that
  claim predates this update, and this container has no CCL installed
  to verify it against Tesseract 5.5 either way.
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
- **Submodule not yet pushed.** This repo is tracked as a git submodule
  of `common-lisp/` pinned to commit `03ceed8`. That commit currently
  only exists in the local checkout — it has not been pushed to
  `github.com/infurl/cl-tesseract` yet, so a fresh clone of `common-lisp`
  elsewhere cannot resolve the submodule reference until that push
  happens (confirmed directly via a fresh-clone test). Not a code issue,
  just a publishing step still pending.

## Dependencies

- `cffi` (Quicklisp), the only ASDF `:depends-on`.
- `libtesseract5`/`libtesseract-dev` (verified against 5.5.0-1+b1) and
  Leptonica (Tesseract's own image-decoding dependency, pulled in
  alongside it), plus at least one `tesseract-ocr-<lang>` language-data
  package — all system/apt packages, not managed by ASDF or Quicklisp.

## Consumers

None yet in this workspace — added and modernized standalone, ahead of
any concrete consumer.
