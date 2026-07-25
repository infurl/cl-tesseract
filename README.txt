CL-TESSERACT is a set of CFFI bindings for the Tesseract OCR library, updated 2026-07-26
against v. 5.5.0: https://github.com/tesseract-ocr/tesseract

On OS X, Tesseract can be conveniently installed using Homebrew:
brew install tesseract

On Debian/Ubuntu:
apt install tesseract-ocr libtesseract-dev

Tesseract OCR's capi last changed incompatibly in the update to v. 3.04 (earlier versions
such as 3.02 will not work with these bindings) and has evolved compatibly since -- most
notably, Tesseract dropped the old Cube OCR engine for an LSTM-based one between 3.04 and
4.x, and added TSV/ALTO/PAGE-XML output and a real progress-monitor/cancellation API since.
These bindings were re-verified end-to-end against a real 5.5.0 install as part of the
2026-07-26 update; see cl-tesseract.lisp and capi.lisp for the details of what changed.

CL-TESSERACT also provides convenient lisp functions to retrieve text from images:
IMAGE-TO-TEXT, IMAGE-TO-HOCR, IMAGE-TO-TSV, IMAGE-TO-ALTO, and IMAGE-TO-PAGE.

IMAGE-TO-TEXT accepts a lisp pathname and an optional language parameter and returns a 
unicode string:

* (image-to-text #P"~/eurotext.tif")
"The (quick) [brown] {fox} jumps!
Over the $43,456.78 <lazy> #90 dog
& duck/goose, as 12.5% of E-mail
from aspammer@website.com is spam.
Der ,,schnelle” braune Fuchs springt
ﬁber den faulen Hund. Le renard brun
«rapide» saute par-dessus le chien
paresseux. La volpe marrone rapida
salta sopra i] cane pigro. El zorro
marrén répido salta sobre el perro
perezoso. A raposa marrom répida
salta sobre 0 C50 preguieoso.

"

* (image-to-text #P"~/eurotext.tif" :lang "rus")
"ТЬе (чиісК) [Ьгошп] {Гох} ]итрз!
Очег [пе $43‚456.78 <1а2у> #90 603
& ‹1исК/3005е, аз 12.5% ог Е-таіі
Ггот азраттег@шеЬ5і[е.сош із зрат.
Бег ‚,5с11пе11е” Ьгаипе Риспз зргіпві
ііЬег ‹!еп Тапіеп Нипа. Ье гепага Ьгип
«гарісіе» заше раг-сіеззиз 1е сЬіеп
рагеззеих. Ьа уоіре тапопе гаріаа
зама зорга і] сапе рівго. Е1 гогго
таггбп гёріао зама воЬге е1 репо
регегозо. А гароза шапот гйріаа
зака воЬге о еде ргевиісозо.

"

Available languages are dependent on the Tesseract OCR .traineddata files located in the directory denoted by *TESSDATA-DIRECTORY*. CL-TESSERACT attempts to set this variable to
a reasonable default for your platform, including Debian/Ubuntu's apt layout (which nests
it under a Tesseract-major-version directory, e.g. /usr/share/tesseract-ocr/5/tessdata) as
well as the macOS Homebrew locations. If none of the known locations exist, *TESSDATA-
DIRECTORY* is NIL and must be set explicitly before use.

IMAGE-TO-HOCR accepts a lisp pathname, the optional language parameter, and a optional 
page number (default 0) and return HOCR XML describing not just the recognized text, but 
its location in the page:

* (image-to-hocr #P"~/python-tesseract/eurotext.jpg”)
"  <div class='ocr_page' id='page_2' title='image \"/Users/Walrus/python-tesseract/eurotext.jpg\"; bbox 0 0 1024 800; ppageno 1'>
   <div class='ocr_carea' id='block_2_1' title=\"bbox 98 66 918 661\">
. . .
word_2_65' title='bbox 391 621 456 651; x_wconf 72' lang='eng' dir='ltr'>C50</span> <span class='ocrx_word' id='word_2_66' title='bbox 481 621 710 661; x_wconf 74' lang='eng' dir='ltr'>preguieoso.</span> 
     </span>
    </p>
   </div>
  </div>
"

This can be parsed using Common Lisp libraries such as Closure-XML and plump.

IMAGE-TO-TSV, IMAGE-TO-ALTO, and IMAGE-TO-PAGE take the same arguments as IMAGE-TO-HOCR and
return, respectively: tab-separated-value text (one recognized element per row, more compact
than HOCR for programmatic consumption), ALTO XML (a layout-analysis format used by
libraries/archives), and PAGE XML (PRImA Page Analysis and Ground-truth Elements, another
layout-analysis format) -- all new as of the 2026-07-26 update, none available in Tesseract
3.04.

Every one of these functions returns a Lisp string built by copying and then explicitly
freeing (via TessDeleteText) a heap-allocated buffer Tesseract hands back -- the C API's
documented ownership convention, which earlier versions of these bindings did not follow
(they leaked that buffer on every call). In practice this leak was too small to be the
dominant cost of repeated OCR calls in this API's design: creating a fresh TessBaseAPI and
reloading its language model per call, as every IMAGE-TO-* function does, dominates memory
churn far more than the text buffer ever did; a caller doing high-volume repeated OCR would
get more benefit from keeping one TessBaseAPI alive across calls (via WITH-BASE-API,
INIT-TESS-API, and PROCESS-PAGES directly) than from this fix alone.

Tested on SBCL. The CCL claim from the original 3.04-era bindings is untested against this
update -- verify before relying on it.

License: 

MIT

Author:
Edward Geist (egeist@stanford.edu)
