;;;; test-cl-tesseract.lisp -- regression checks for cl-tesseract.
;;;;
;;;; These are integration checks against a real, locally installed Tesseract +
;;;; eng.traineddata, run against a small synthetic fixture image
;;;; (fixtures/hello-tesseract.png, rendering "Hello Tesseract 5" in DejaVu Sans
;;;; Mono) rather than mocks -- the whole point of this library is the FFI
;;;; boundary to the real C library, so a mock would test nothing that could
;;;; actually regress (a CFFI signature drift, an enum-ordinal mismatch, a
;;;; renamed C symbol). No CI is wired up for this project (a deliberate
;;;; choice, not an oversight -- see MAINTENANCE.md); these checks are meant to
;;;; be run by hand via (asdf:test-op :cl-tesseract) after any change here.

(in-package #:cl-tesseract)

;;; a tiny, dependency-free check harness, mirroring glr-parser's own
;;; tests/test-grammar.lisp convention ------------------------------------

(defvar *checks-run* 0)
(defvar *checks-failed* 0)

(defmacro check (description form)
  `(progn
     (incf *checks-run*)
     (if ,form
         (format t "  ok   ~a~%" ,description)
         (progn
           (incf *checks-failed*)
           (format t "  FAIL ~a~%" ,description)))))

(defun fixture-path (name)
  (asdf:system-relative-pathname :cl-tesseract (merge-pathnames name "tests/fixtures/")))

(defparameter *hello-fixture* (fixture-path "hello-tesseract.png"))

;;; version / environment ---------------------------------------------------

(defun test-tesseract-version ()
  (let ((version (tesseract-version)))
    (check "tesseract-version returns a non-empty string"
      (and (stringp version) (plusp (length version))))
    (check "tesseract-version starts with a digit (e.g. \"5.5.0\")"
      (digit-char-p (char version 0)))))

(defun test-tessdata-directory ()
  (check "*tessdata-directory* was auto-detected (install tesseract-ocr-eng if this fails)"
    (and *tessdata-directory* (probe-file *tessdata-directory*)))
  (when *tessdata-directory*
    (check "*tessdata-directory* contains eng.traineddata"
      (probe-file (merge-pathnames "eng.traineddata" *tessdata-directory*)))))

;;; enum lispification -- guards against the kebab-case rename silently
;;; breaking CFFI's enum-name-to-ordinal lookup ------------------------------

(defun test-enum-values ()
  (check "tess-ocr-engine-mode's :oem-default resolves (enum lispified correctly)"
    (= 3 (cffi:foreign-enum-value 'tess-ocr-engine-mode :oem-default)))
  (check "tess-page-seg-mode's :psm-auto resolves (enum lispified correctly)"
    (= 3 (cffi:foreign-enum-value 'tess-page-seg-mode :psm-auto)))
  (check "tess-page-iterator-level's :ril-word resolves (enum lispified correctly)"
    (= 3 (cffi:foreign-enum-value 'tess-page-iterator-level :ril-word))))

;;; the five convenience functions, each against the real fixture image -----

(defun test-image-to-text ()
  (check "image-to-text recognizes the fixture's exact text"
    (string= "Hello Tesseract 5" (string-trim '(#\Newline #\Return #\Space)
                                                (image-to-text *hello-fixture*)))))

(defun test-image-to-hocr ()
  (let ((hocr (image-to-hocr *hello-fixture*)))
    (check "image-to-hocr produces an ocr_page div"
      (search "ocr_page" hocr))
    (check "image-to-hocr's output contains the recognized word \"Hello\""
      (search "Hello" hocr))))

(defun test-image-to-tsv ()
  (let ((tsv (image-to-tsv *hello-fixture*)))
    (check "image-to-tsv is tab-separated"
      (find #\Tab tsv))
    (check "image-to-tsv's output contains the recognized word \"Hello\""
      (search "Hello" tsv))))

(defun test-image-to-alto ()
  (let ((alto (image-to-alto *hello-fixture*)))
    (check "image-to-alto produces an ALTO <Page> element"
      (search "<Page " alto))
    (check "image-to-alto's output contains the recognized word \"Hello\""
      (search "CONTENT=\"Hello\"" alto))))

(defun test-image-to-page ()
  (let ((page (image-to-page *hello-fixture*)))
    (check "image-to-page produces a PAGE <Page> element"
      (search "<Page " page))
    (check "image-to-page's output contains the recognized text"
      (search "Hello Tesseract 5" page))))

;;; error paths and resource cleanup -----------------------------------------

(defun test-init-tess-api-bad-language ()
  (check "init-tess-api signals an error for an unavailable language"
    (with-base-api api
      (handler-case (progn (init-tess-api api "not-a-real-language-xyz") nil)
        (error () t)))))

(defun test-with-base-api-cleanup ()
  (check "with-base-api's UNWIND-PROTECT still tears down the handle when body errors"
    (handler-case
        (progn (with-base-api api
                 (declare (ignore api))
                 (error "deliberate test error"))
               nil)
      (error () t))))

(defun test-owned-foreign-string-null ()
  (check "owned-foreign-string returns NIL for a null pointer"
    (null (owned-foreign-string (cffi:null-pointer)))))

;;; entry point ---------------------------------------------------------------

(defun run-checks ()
  (let ((*checks-run* 0) (*checks-failed* 0))
    (test-tesseract-version)
    (test-tessdata-directory)
    (test-enum-values)
    (test-image-to-text)
    (test-image-to-hocr)
    (test-image-to-tsv)
    (test-image-to-alto)
    (test-image-to-page)
    (test-init-tess-api-bad-language)
    (test-with-base-api-cleanup)
    (test-owned-foreign-string-null)
    (format t "~%~a/~a checks passed~%" (- *checks-run* *checks-failed*) *checks-run*)
    (zerop *checks-failed*)))
