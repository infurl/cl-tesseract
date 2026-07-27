(in-package :cl-tesseract)

;;; Bindings for Tesseract OCR's capi.h, current as of Tesseract 5.5.0 (verified
;;; against /usr/include/tesseract/capi.h from the libtesseract-dev 5.5.0-1+b1
;;; package on Debian, 2026-07-26). Originally generated via SWIG against
;;; Tesseract 3.04.00; Tesseract has since dropped the Cube OCR engine entirely
;;; in favor of an LSTM-based one, added PDF/TSV/ALTO/PAGE-XML output, and added
;;; a real cancellable progress-monitor API, all reflected below. A handful of
;;; 3.04-era functions (Cube recognition context, TBLOB/OCRRow construction,
;;; thresholder/dict/probability/lattice callback injection, the old
;;; TessBaseAPIInit mega-overload, TessFindRowForBox, TessBaseAPIDumpPGM,
;;; TessDeleteBlockList, TessBaseAPIInitLangMod, TessBaseAPIGetOpenCLDevice,
;;; TessBaseAPIRecognizeForChopTest, TessBaseAPIDetectOS) no longer exist in the
;;; library at all and have been dropped rather than left as dead bindings.

(cffi:defctype tess-size-t :unsigned-long
  "Stands in for C's size_t, which CFFI has no built-in type for. Correct on
the 64-bit platforms cl-tesseract targets (Linux/macOS); would need revisiting
for a 32-bit or Windows port.")

(cffi:defcenum tess-ocr-engine-mode
	:oem-tesseract-only
	:oem-lstm-only
	:oem-tesseract-lstm-combined
	:oem-default)

(cffi:defcenum tess-page-seg-mode
	:psm-osd-only
	:psm-auto-osd
	:psm-auto-only
	:psm-auto
	:psm-single-column
	:psm-single-block-vert-text
	:psm-single-block
	:psm-single-line
	:psm-single-word
	:psm-circle-word
	:psm-single-char
	:psm-sparse-text
	:psm-sparse-text-osd
	:psm-raw-line
	:psm-count)

(cffi:defcenum tess-page-iterator-level
	:ril-block
	:ril-para
	:ril-textline
	:ril-word
	:ril-symbol)

(cffi:defcenum tess-poly-block-type
	:pt-unknown
	:pt-flowing-text
	:pt-heading-text
	:pt-pullout-text
	:pt-equation
	:pt-inline-equation
	:pt-table
	:pt-vertical-text
	:pt-caption-text
	:pt-flowing-image
	:pt-heading-image
	:pt-pullout-image
	:pt-horz-line
	:pt-vert-line
	:pt-noise
	:pt-count)

(cffi:defcenum tess-orientation
	:orientation-page-up
	:orientation-page-right
	:orientation-page-down
	:orientation-page-left)

(cffi:defcenum tess-paragraph-justification
	:justification-unknown
	:justification-left
	:justification-center
	:justification-right)

(cffi:defcenum tess-writing-direction
	:writing-direction-left-to-right
	:writing-direction-right-to-left
	:writing-direction-top-to-bottom)

(cffi:defcenum tess-textline-order
	:textline-order-left-to-right
	:textline-order-right-to-left
	:textline-order-top-to-bottom)

(cl:defconstant +true+ 1)

(cl:defconstant +false+ 0)

;;; General free functions

(cffi:defcfun ("TessVersion" tess-version) :string)

(cffi:defcfun ("TessDeleteText" tess-delete-text) :void
  (text :pointer))

(cffi:defcfun ("TessDeleteTextArray" tess-delete-text-array) :void
  (arr :pointer))

(cffi:defcfun ("TessDeleteIntArray" tess-delete-int-array) :void
  (arr :pointer))

;;; Renderer API

(cffi:defcfun ("TessTextRendererCreate" tess-text-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessHOcrRendererCreate" tess-hocr-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessHOcrRendererCreate2" tess-hocr-renderer-create2) :pointer
  (outputbase :string)
  (font_info :int))

(cffi:defcfun ("TessAltoRendererCreate" tess-alto-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessPAGERendererCreate" tess-page-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessTsvRendererCreate" tess-tsv-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessPDFRendererCreate" tess-pdf-renderer-create) :pointer
  (outputbase :string)
  (datadir :string)
  (textonly :int))

(cffi:defcfun ("TessUnlvRendererCreate" tess-unlv-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessBoxTextRendererCreate" tess-box-text-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessLSTMBoxRendererCreate" tess-lstm-box-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessWordStrBoxRendererCreate" tess-word-str-box-renderer-create) :pointer
  (outputbase :string))

(cffi:defcfun ("TessDeleteResultRenderer" tess-delete-result-renderer) :void
  (renderer :pointer))

(cffi:defcfun ("TessResultRendererInsert" tess-result-renderer-insert) :void
  (renderer :pointer)
  (next :pointer))

(cffi:defcfun ("TessResultRendererNext" tess-result-renderer-next) :pointer
  (renderer :pointer))

(cffi:defcfun ("TessResultRendererBeginDocument" tess-result-renderer-begin-document) :int
  (renderer :pointer)
  (title :string))

(cffi:defcfun ("TessResultRendererAddImage" tess-result-renderer-add-image) :int
  (renderer :pointer)
  (api :pointer))

(cffi:defcfun ("TessResultRendererEndDocument" tess-result-renderer-end-document) :int
  (renderer :pointer))

(cffi:defcfun ("TessResultRendererExtention" tess-result-renderer-extention) :string
  (renderer :pointer))

(cffi:defcfun ("TessResultRendererTitle" tess-result-renderer-title) :string
  (renderer :pointer))

(cffi:defcfun ("TessResultRendererImageNum" tess-result-renderer-image-num) :int
  (renderer :pointer))

;;; Base API

(cffi:defcfun ("TessBaseAPICreate" tess-base-api-create) :pointer)

(cffi:defcfun ("TessBaseAPIDelete" tess-base-api-delete) :void
  (handle :pointer))

(cffi:defcfun ("TessBaseAPISetInputName" tess-base-api-set-input-name) :void
  (handle :pointer)
  (name :string))

(cffi:defcfun ("TessBaseAPIGetInputName" tess-base-api-get-input-name) :string
  (handle :pointer))

(cffi:defcfun ("TessBaseAPISetInputImage" tess-base-api-set-input-image) :void
  (handle :pointer)
  (pix :pointer))

(cffi:defcfun ("TessBaseAPIGetInputImage" tess-base-api-get-input-image) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetSourceYResolution" tess-base-api-get-source-y-resolution) :int
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetDatapath" tess-base-api-get-datapath) :string
  (handle :pointer))

(cffi:defcfun ("TessBaseAPISetOutputName" tess-base-api-set-output-name) :void
  (handle :pointer)
  (name :string))

(cffi:defcfun ("TessBaseAPISetVariable" tess-base-api-set-variable) :int
  (handle :pointer)
  (name :string)
  (value :string))

(cffi:defcfun ("TessBaseAPISetDebugVariable" tess-base-api-set-debug-variable) :int
  (handle :pointer)
  (name :string)
  (value :string))

(cffi:defcfun ("TessBaseAPIGetIntVariable" tess-base-api-get-int-variable) :int
  (handle :pointer)
  (name :string)
  (value :pointer))

(cffi:defcfun ("TessBaseAPIGetBoolVariable" tess-base-api-get-bool-variable) :int
  (handle :pointer)
  (name :string)
  (value :pointer))

(cffi:defcfun ("TessBaseAPIGetDoubleVariable" tess-base-api-get-double-variable) :int
  (handle :pointer)
  (name :string)
  (value :pointer))

(cffi:defcfun ("TessBaseAPIGetStringVariable" tess-base-api-get-string-variable) :string
  (handle :pointer)
  (name :string))

(cffi:defcfun ("TessBaseAPIPrintVariables" tess-base-api-print-variables) :void
  (handle :pointer)
  (fp :pointer))

(cffi:defcfun ("TessBaseAPIPrintVariablesToFile" tess-base-api-print-variables-to-file) :int
  (handle :pointer)
  (filename :string))

(cffi:defcfun ("TessBaseAPIInit1" tess-base-api-init1) :int
  (handle :pointer)
  (datapath :string)
  (language :string)
  (oem tess-ocr-engine-mode)
  (configs :pointer)
  (configs_size :int))

(cffi:defcfun ("TessBaseAPIInit2" tess-base-api-init2) :int
  (handle :pointer)
  (datapath :string)
  (language :string)
  (oem tess-ocr-engine-mode))

(cffi:defcfun ("TessBaseAPIInit3" tess-base-api-init3) :int
  (handle :pointer)
  (datapath :string)
  (language :string))

(cffi:defcfun ("TessBaseAPIInit4" tess-base-api-init4) :int
  (handle :pointer)
  (datapath :string)
  (language :string)
  (mode tess-ocr-engine-mode)
  (configs :pointer)
  (configs_size :int)
  (vars_vec :pointer)
  (vars_values :pointer)
  (vars_vec_size tess-size-t)
  (set_only_non_debug_params :int))

(cffi:defcfun ("TessBaseAPIInit5" tess-base-api-init5) :int
  (handle :pointer)
  (data :pointer)
  (data_size :int)
  (language :string)
  (mode tess-ocr-engine-mode)
  (configs :pointer)
  (configs_size :int)
  (vars_vec :pointer)
  (vars_values :pointer)
  (vars_vec_size tess-size-t)
  (set_only_non_debug_params :int))

(cffi:defcfun ("TessBaseAPIGetInitLanguagesAsString" tess-base-api-get-init-languages-as-string) :string
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetLoadedLanguagesAsVector" tess-base-api-get-loaded-languages-as-vector) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetAvailableLanguagesAsVector" tess-base-api-get-available-languages-as-vector) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIInitForAnalysePage" tess-base-api-init-for-analyse-page) :void
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIReadConfigFile" tess-base-api-read-config-file) :void
  (handle :pointer)
  (filename :string))

(cffi:defcfun ("TessBaseAPIReadDebugConfigFile" tess-base-api-read-debug-config-file) :void
  (handle :pointer)
  (filename :string))

(cffi:defcfun ("TessBaseAPISetPageSegMode" tess-base-api-set-page-seg-mode) :void
  (handle :pointer)
  (mode tess-page-seg-mode))

(cffi:defcfun ("TessBaseAPIGetPageSegMode" tess-base-api-get-page-seg-mode) tess-page-seg-mode
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIRect" tess-base-api-rect) :pointer
  (handle :pointer)
  (imagedata :pointer)
  (bytes_per_pixel :int)
  (bytes_per_line :int)
  (left :int)
  (top :int)
  (width :int)
  (height :int))

(cffi:defcfun ("TessBaseAPIClearAdaptiveClassifier" tess-base-api-clear-adaptive-classifier) :void
  (handle :pointer))

(cffi:defcfun ("TessBaseAPISetImage" tess-base-api-set-image) :void
  (handle :pointer)
  (imagedata :pointer)
  (width :int)
  (height :int)
  (bytes_per_pixel :int)
  (bytes_per_line :int))

(cffi:defcfun ("TessBaseAPISetImage2" tess-base-api-set-image2) :void
  (handle :pointer)
  (pix :pointer))

(cffi:defcfun ("TessBaseAPISetSourceResolution" tess-base-api-set-source-resolution) :void
  (handle :pointer)
  (ppi :int))

(cffi:defcfun ("TessBaseAPISetRectangle" tess-base-api-set-rectangle) :void
  (handle :pointer)
  (left :int)
  (top :int)
  (width :int)
  (height :int))

(cffi:defcfun ("TessBaseAPIGetThresholdedImage" tess-base-api-get-thresholded-image) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetGradient" tess-base-api-get-gradient) :float
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetRegions" tess-base-api-get-regions) :pointer
  (handle :pointer)
  (pixa :pointer))

(cffi:defcfun ("TessBaseAPIGetTextlines" tess-base-api-get-textlines) :pointer
  (handle :pointer)
  (pixa :pointer)
  (blockids :pointer))

(cffi:defcfun ("TessBaseAPIGetTextlines1" tess-base-api-get-textlines1) :pointer
  (handle :pointer)
  (raw_image :int)
  (raw_padding :int)
  (pixa :pointer)
  (blockids :pointer)
  (paraids :pointer))

(cffi:defcfun ("TessBaseAPIGetStrips" tess-base-api-get-strips) :pointer
  (handle :pointer)
  (pixa :pointer)
  (blockids :pointer))

(cffi:defcfun ("TessBaseAPIGetWords" tess-base-api-get-words) :pointer
  (handle :pointer)
  (pixa :pointer))

(cffi:defcfun ("TessBaseAPIGetConnectedComponents" tess-base-api-get-connected-components) :pointer
  (handle :pointer)
  (cc :pointer))

(cffi:defcfun ("TessBaseAPIGetComponentImages" tess-base-api-get-component-images) :pointer
  (handle :pointer)
  (level tess-page-iterator-level)
  (text_only :int)
  (pixa :pointer)
  (blockids :pointer))

(cffi:defcfun ("TessBaseAPIGetComponentImages1" tess-base-api-get-component-images1) :pointer
  (handle :pointer)
  (level tess-page-iterator-level)
  (text_only :int)
  (raw_image :int)
  (raw_padding :int)
  (pixa :pointer)
  (blockids :pointer)
  (paraids :pointer))

(cffi:defcfun ("TessBaseAPIGetThresholdedImageScaleFactor" tess-base-api-get-thresholded-image-scale-factor) :int
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIAnalyseLayout" tess-base-api-analyse-layout) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIRecognize" tess-base-api-recognize) :int
  (handle :pointer)
  (monitor :pointer))

(cffi:defcfun ("TessBaseAPIProcessPages" tess-base-api-process-pages) :int
  (handle :pointer)
  (filename :string)
  (retry_config :string)
  (timeout_millisec :int)
  (renderer :pointer))

(cffi:defcfun ("TessBaseAPIProcessPage" tess-base-api-process-page) :int
  (handle :pointer)
  (pix :pointer)
  (page_index :int)
  (filename :string)
  (retry_config :string)
  (timeout_millisec :int)
  (renderer :pointer))

(cffi:defcfun ("TessBaseAPIGetIterator" tess-base-api-get-iterator) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetMutableIterator" tess-base-api-get-mutable-iterator) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetUTF8Text" tess-base-api-get-utf8-text) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIGetHOCRText" tess-base-api-get-hocr-text) :pointer
  (handle :pointer)
  (page_number :int))

(cffi:defcfun ("TessBaseAPIGetAltoText" tess-base-api-get-alto-text) :pointer
  (handle :pointer)
  (page_number :int))

(cffi:defcfun ("TessBaseAPIGetPAGEText" tess-base-api-get-page-text) :pointer
  (handle :pointer)
  (page_number :int))

(cffi:defcfun ("TessBaseAPIGetTsvText" tess-base-api-get-tsv-text) :pointer
  (handle :pointer)
  (page_number :int))

(cffi:defcfun ("TessBaseAPIGetBoxText" tess-base-api-get-box-text) :pointer
  (handle :pointer)
  (page_number :int))

(cffi:defcfun ("TessBaseAPIGetLSTMBoxText" tess-base-api-get-lstm-box-text) :pointer
  (handle :pointer)
  (page_number :int))

(cffi:defcfun ("TessBaseAPIGetWordStrBoxText" tess-base-api-get-word-str-box-text) :pointer
  (handle :pointer)
  (page_number :int))

(cffi:defcfun ("TessBaseAPIGetUNLVText" tess-base-api-get-unlv-text) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIMeanTextConf" tess-base-api-mean-text-conf) :int
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIAllWordConfidences" tess-base-api-all-word-confidences) :pointer
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIAdaptToWordStr" tess-base-api-adapt-to-word-str) :int
  (handle :pointer)
  (mode tess-page-seg-mode)
  (wordstr :string))

(cffi:defcfun ("TessBaseAPIClear" tess-base-api-clear) :void
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIEnd" tess-base-api-end) :void
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIIsValidWord" tess-base-api-is-valid-word) :int
  (handle :pointer)
  (word :string))

(cffi:defcfun ("TessBaseAPIGetTextDirection" tess-base-api-get-text-direction) :int
  (handle :pointer)
  (out_offset :pointer)
  (out_slope :pointer))

(cffi:defcfun ("TessBaseAPIClearPersistentCache" tess-base-api-clear-persistent-cache) :void
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIDetectOrientationScript" tess-base-api-detect-orientation-script) :int
  (handle :pointer)
  (orient_deg :pointer)
  (orient_conf :pointer)
  (script_name :pointer)
  (script_conf :pointer))

(cffi:defcfun ("TessBaseAPISetMinOrientationMargin" tess-base-api-set-min-orientation-margin) :void
  (handle :pointer)
  (margin :double))

(cffi:defcfun ("TessBaseAPINumDawgs" tess-base-api-num-dawgs) :int
  (handle :pointer))

(cffi:defcfun ("TessBaseAPIOem" tess-base-api-oem) tess-ocr-engine-mode
  (handle :pointer))

(cffi:defcfun ("TessBaseGetBlockTextOrientations" tess-base-get-block-text-orientations) :void
  (handle :pointer)
  (block_orientation :pointer)
  (vertical_writing :pointer))

;;; Page iterator

(cffi:defcfun ("TessPageIteratorDelete" tess-page-iterator-delete) :void
  (handle :pointer))

(cffi:defcfun ("TessPageIteratorCopy" tess-page-iterator-copy) :pointer
  (handle :pointer))

(cffi:defcfun ("TessPageIteratorBegin" tess-page-iterator-begin) :void
  (handle :pointer))

(cffi:defcfun ("TessPageIteratorNext" tess-page-iterator-next) :int
  (handle :pointer)
  (level tess-page-iterator-level))

(cffi:defcfun ("TessPageIteratorIsAtBeginningOf" tess-page-iterator-is-at-beginning-of) :int
  (handle :pointer)
  (level tess-page-iterator-level))

(cffi:defcfun ("TessPageIteratorIsAtFinalElement" tess-page-iterator-is-at-final-element) :int
  (handle :pointer)
  (level tess-page-iterator-level)
  (element tess-page-iterator-level))

(cffi:defcfun ("TessPageIteratorBoundingBox" tess-page-iterator-bounding-box) :int
  (handle :pointer)
  (level tess-page-iterator-level)
  (left :pointer)
  (top :pointer)
  (right :pointer)
  (bottom :pointer))

(cffi:defcfun ("TessPageIteratorBlockType" tess-page-iterator-block-type) tess-poly-block-type
  (handle :pointer))

(cffi:defcfun ("TessPageIteratorGetBinaryImage" tess-page-iterator-get-binary-image) :pointer
  (handle :pointer)
  (level tess-page-iterator-level))

(cffi:defcfun ("TessPageIteratorGetImage" tess-page-iterator-get-image) :pointer
  (handle :pointer)
  (level tess-page-iterator-level)
  (padding :int)
  (original_image :pointer)
  (left :pointer)
  (top :pointer))

(cffi:defcfun ("TessPageIteratorBaseline" tess-page-iterator-baseline) :int
  (handle :pointer)
  (level tess-page-iterator-level)
  (x1 :pointer)
  (y1 :pointer)
  (x2 :pointer)
  (y2 :pointer))

(cffi:defcfun ("TessPageIteratorOrientation" tess-page-iterator-orientation) :void
  (handle :pointer)
  (orientation :pointer)
  (writing_direction :pointer)
  (textline_order :pointer)
  (deskew_angle :pointer))

(cffi:defcfun ("TessPageIteratorParagraphInfo" tess-page-iterator-paragraph-info) :void
  (handle :pointer)
  (justification :pointer)
  (is_list_item :pointer)
  (is_crown :pointer)
  (first_line_indent :pointer))

;;; Result iterator

(cffi:defcfun ("TessResultIteratorDelete" tess-result-iterator-delete) :void
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorCopy" tess-result-iterator-copy) :pointer
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorGetPageIterator" tess-result-iterator-get-page-iterator) :pointer
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorGetPageIteratorConst" tess-result-iterator-get-page-iterator-const) :pointer
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorGetChoiceIterator" tess-result-iterator-get-choice-iterator) :pointer
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorNext" tess-result-iterator-next) :int
  (handle :pointer)
  (level tess-page-iterator-level))

(cffi:defcfun ("TessResultIteratorGetUTF8Text" tess-result-iterator-get-utf8-text) :pointer
  (handle :pointer)
  (level tess-page-iterator-level))

(cffi:defcfun ("TessResultIteratorConfidence" tess-result-iterator-confidence) :float
  (handle :pointer)
  (level tess-page-iterator-level))

(cffi:defcfun ("TessResultIteratorWordRecognitionLanguage" tess-result-iterator-word-recognition-language) :string
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorWordFontAttributes" tess-result-iterator-word-font-attributes) :string
  (handle :pointer)
  (is_bold :pointer)
  (is_italic :pointer)
  (is_underlined :pointer)
  (is_monospace :pointer)
  (is_serif :pointer)
  (is_smallcaps :pointer)
  (pointsize :pointer)
  (font_id :pointer))

(cffi:defcfun ("TessResultIteratorWordIsFromDictionary" tess-result-iterator-word-is-from-dictionary) :int
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorWordIsNumeric" tess-result-iterator-word-is-numeric) :int
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorSymbolIsSuperscript" tess-result-iterator-symbol-is-superscript) :int
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorSymbolIsSubscript" tess-result-iterator-symbol-is-subscript) :int
  (handle :pointer))

(cffi:defcfun ("TessResultIteratorSymbolIsDropcap" tess-result-iterator-symbol-is-dropcap) :int
  (handle :pointer))

;;; Choice iterator

(cffi:defcfun ("TessChoiceIteratorDelete" tess-choice-iterator-delete) :void
  (handle :pointer))

(cffi:defcfun ("TessChoiceIteratorNext" tess-choice-iterator-next) :int
  (handle :pointer))

(cffi:defcfun ("TessChoiceIteratorGetUTF8Text" tess-choice-iterator-get-utf8-text) :string
  (handle :pointer))

(cffi:defcfun ("TessChoiceIteratorConfidence" tess-choice-iterator-confidence) :float
  (handle :pointer))

;;; Progress monitor (ETEXT_DESC), new in this pass -- previously cl-tesseract
;;; only ever passed a null monitor pointer to TessBaseAPIRecognize/ProcessPages,
;;; so cancellation/progress-callback support was unreachable even though the
;;; underlying library has always accepted a real monitor there.

(cffi:defcfun ("TessMonitorCreate" tess-monitor-create) :pointer)

(cffi:defcfun ("TessMonitorDelete" tess-monitor-delete) :void
  (monitor :pointer))

(cffi:defcfun ("TessMonitorSetCancelFunc" tess-monitor-set-cancel-func) :void
  (monitor :pointer)
  (cancel-func :pointer))

(cffi:defcfun ("TessMonitorSetCancelThis" tess-monitor-set-cancel-this) :void
  (monitor :pointer)
  (cancel-this :pointer))

(cffi:defcfun ("TessMonitorGetCancelThis" tess-monitor-get-cancel-this) :pointer
  (monitor :pointer))

(cffi:defcfun ("TessMonitorSetProgressFunc" tess-monitor-set-progress-func) :void
  (monitor :pointer)
  (progress-func :pointer))

(cffi:defcfun ("TessMonitorGetProgress" tess-monitor-get-progress) :int
  (monitor :pointer))

(cffi:defcfun ("TessMonitorSetDeadlineMSecs" tess-monitor-set-deadline-msecs) :void
  (monitor :pointer)
  (deadline :int))
