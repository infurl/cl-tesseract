;;;; cl-tesseract.asd

(asdf:defsystem #:cl-tesseract
  :description "CFFI bindings to the Tesseract OCR library."
  :author "Edward Geist"
  :license "MIT"
  :depends-on (#:cffi)
  :serial t
  :components ((:file "package")
	       (:file "library")
	       (:file "capi")
               (:file "cl-tesseract"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-tesseract/tests))))

(asdf:defsystem #:cl-tesseract/tests
  :description "Regression checks for cl-tesseract, run against a real local
Tesseract install and a small synthetic fixture image -- see
tests/test-cl-tesseract.lisp's own header for why these are integration
checks rather than mocked unit tests, and MAINTENANCE.md for why no CI is
wired up around them."
  :depends-on (#:cl-tesseract)
  :components ((:module "tests"
                :components ((:file "test-cl-tesseract"))))
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-tesseract :run-checks)
               (error "cl-tesseract regression checks failed"))))

