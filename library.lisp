(in-package :cl-tesseract)

(cffi:define-foreign-library tesseract
  (:darwin (:or "libtesseract.5.dylib" "libtesseract.3.dylib" "libtesseract.dylib"))
  (:linux (:or "libtesseract.so.5" "libtesseract.so.3" "libtesseract.so"))
  (t (:default "libtesseract"))) ; Will this work on Windows?

(cffi:use-foreign-library tesseract)

(defun find-tessdata-directory ()
  "Searches common default tessdata locations across platforms and package managers,
returning the first one found as a namestring, or NIL if none exist.

Debian/Ubuntu's tesseract-ocr package installs under a Tesseract-major-version-numbered
directory (e.g. /usr/share/tesseract-ocr/5/tessdata), so that pattern is globbed rather
than hardcoded to one version."
  #+unix
  (or (loop for dir in (directory "/usr/share/tesseract-ocr/*/tessdata/")
            do (return (namestring dir))) ; Debian/Ubuntu apt
      (probe-file "/usr/share/tessdata/") ; some other Linux distros
      (probe-file "/usr/local/share/tessdata/") ; Homebrew
      (probe-file "/opt/homebrew/share/tessdata/")
      (probe-file "/usr/local/tessdata/"))
  #+windows
  (probe-file "C:\\Program Files\\Tesseract OCR\\tessdata"))

(defparameter *tessdata-directory*
  (let ((dir (find-tessdata-directory)))
    (if dir (namestring dir) nil))
  "*tessdata-directory* should point to the location of the directory containing
.traineddata files for use by Tesseract. The value must be a string representing the full
path to the directory.

This searches in common default locations for each platform and package manager and will
follow symlinks to find the true location of the tessdata directory if one exists. If none
of them exist, this is NIL, and must be set explicitly before use.

If your .traineddata files are in a non-standard location, it can be shadowed; i.e.
(let ((*tessdata-directory* \"/path/to/tessdata\"))
     (image-to-text #P\"~/eurotext.jpg\"))")
