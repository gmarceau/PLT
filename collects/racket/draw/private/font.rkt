#lang scheme/base
(require scheme/class
         ffi/unsafe
         ffi/unsafe/atomic
         "syntax.ss"
         "../unsafe/pango.ss"
         "font-syms.ss"
         "font-dir.ss"
         "local.ss")

(provide font%
         font-list% the-font-list
         family-symbol? style-symbol? weight-symbol? smoothing-symbol?
         get-pango-attrs
         get-face-list)

(define-local-member-name 
  get-pango-attrs)

(define underlined-attrs (let ([l (pango_attr_list_new)])
                           (pango_attr_list_insert l (pango_attr_underline_new
                                                      PANGO_UNDERLINE_SINGLE))
                           l))

(define (smoothing-symbol? s)
  (memq s '(default smoothed unsmoothed partly-smoothed)))

(define (size? v) (and (exact-positive-integer? v)
                       (byte? v)))

(define-local-member-name s-set-table-key)

(define font-descs (make-weak-hash))
(define ps-font-descs (make-weak-hash))
(define keys (make-weak-hash))

(define-syntax-rule (atomically e)
  (begin (start-atomic) (begin0 e (end-atomic))))

(defclass font% object%

  (define table-key #f)
  (define/public (s-set-table-key k) (set! table-key k))

  (define cached-desc #f)
  (define ps-cached-desc #f)
  
  (define/public (get-pango)
    (create-desc #f 
                 cached-desc
                 font-descs
                 (lambda (d) (set! cached-desc d))))

  (define/public (get-ps-pango)
    (create-desc #t
                 ps-cached-desc
                 ps-font-descs
                 (lambda (d) (set! ps-cached-desc d))))

  (define/private (create-desc ps? cached-desc font-descs install!)
    (or cached-desc
        (let ([desc (atomically (hash-ref font-descs key #f))])
          (and desc
               (install! desc)
               desc))
        (let* ([desc (pango_font_description_new)])
          (pango_font_description_set_family desc 
                                             (if ps?
                                                 (send the-font-name-directory
                                                       get-post-script-name
                                                       id
                                                       weight
                                                       style)
                                                 (send the-font-name-directory
                                                       get-screen-name
                                                       id
                                                       weight
                                                       style)))
          (pango_font_description_set_style desc (case style
                                                   [(normal) PANGO_STYLE_NORMAL]
                                                   [(italic) PANGO_STYLE_ITALIC]
                                                   [(slant) PANGO_STYLE_OBLIQUE]))
          (pango_font_description_set_weight desc (case weight
                                                    [(normal) PANGO_WEIGHT_MEDIUM]
                                                    [(light) PANGO_WEIGHT_LIGHT]
                                                    [(bold) PANGO_WEIGHT_BOLD]))
          (if size-in-pixels?
              (pango_font_description_set_absolute_size desc (* size PANGO_SCALE))
              (pango_font_description_set_size desc (inexact->exact (floor (* size PANGO_SCALE)))))
          (install! desc)
          (atomically (hash-set! font-descs key desc))
          desc)))

  (define/public (get-pango-attrs)
    (if underlined?
        underlined-attrs
        #f))

  (define face #f)
  (def/public (get-face) face)

  (define family 'default)
  (def/public (get-family) family)

  (define size 12)
  (def/public (get-point-size) size)

  (define size-in-pixels? #f)
  (def/public (get-size-in-pixels) size-in-pixels?)

  (define smoothing 'default)
  (def/public (get-smoothing) smoothing)
  
  (define style 'normal)
  (def/public (get-style) style)

  (define underlined? #f)
  (def/public (get-underlined) underlined?)

  (define weight 'normal)
  (def/public (get-weight) weight)

  (def/public (get-font-id) id)
  (def/public (get-font-key) key)

  (def/public (screen-glyph-exists? [char? c]
                                    [any? [for-label? #f]])
    ;; FIXME:
    #t)

  (init-rest args)
  (super-new)
  (case-args 
   args
   [() (void)]
   [([size? _size]
     [family-symbol? _family]
     [style-symbol? [_style 'normal]]
     [weight-symbol? [_weight 'normal]]
     [any? [_underlined? #f]]
     [smoothing-symbol? [_smoothing 'default]]
     [any? [_size-in-pixels? #f]])
    (set! size _size)
    (set! family _family)
    (set! style _style)
    (set! weight _weight)
    (set! underlined? _underlined?)
    (set! smoothing _smoothing)
    (set! size-in-pixels? _size-in-pixels?)]
   [([size? _size]
     [(make-or-false string?) _face]
     [family-symbol? _family]
     [style-symbol? [_style 'normal]]
     [weight-symbol? [_weight 'normal]]
     [any? [_underlined? #f]]
     [smoothing-symbol? [_smoothing 'default]]
     [any? [_size-in-pixels? #f]])
    (set! size _size)
    (set! face (and _face (string->immutable-string _face)))
    (set! family _family)
    (set! style _style)
    (set! weight _weight)
    (set! underlined? _underlined?)
    (set! smoothing _smoothing)
    (set! size-in-pixels? _size-in-pixels?)]
   (init-name 'font%))

  (define id 
    (if face
        (send the-font-name-directory find-or-create-font-id face family)
        (send the-font-name-directory find-family-default-font-id family)))
  (define key
    (let ([key (vector id size style weight underlined? smoothing size-in-pixels?)])
      (let ([old-key (atomically (hash-ref keys key #f))])
        (if old-key
            (weak-box-value old-key)
            (begin
              (atomically (hash-set! keys key (make-weak-box key)))
              key))))))

;; ----------------------------------------

(defclass font-list% object%
  (define fonts (make-weak-hash))
  (super-new)
  (define/public (find-or-create-font . args)
    (let ([key
           (case-args 
            args
            [([size? size]
              [family-symbol? family]
              [style-symbol? [style 'normal]]
              [weight-symbol? [weight 'normal]]
              [any? [underlined? #f]]
              [smoothing-symbol? [smoothing 'default]]
              [any? [size-in-pixels? #f]])
             (vector size family style weight underlined? smoothing size-in-pixels?)]
            [([size? size]
              [(make-or-false string?) face]
              [family-symbol? family]
              [style-symbol? [style 'normal]]
              [weight-symbol? [weight 'normal]]
              [any? [underlined? #f]]
              [smoothing-symbol? [smoothing 'default]]
              [any? [size-in-pixels? #f]])
             (vector size (and face (string->immutable-string face)) family
                     style weight underlined? smoothing size-in-pixels?)]
            (method-name 'find-or-create-font font-list%))])
      (let ([e (hash-ref fonts key #f)])
        (or (and e
                 (ephemeron-value e))
            (let* ([f (apply make-object font% (vector->list key))]
                   [e (make-ephemeron key f)])
              (send f s-set-table-key key)
              (hash-set! fonts key e)
              f))))))

(define the-font-list (new font-list%))

(define (get-face-list [mode 'all])
  (map pango_font_family_get_name
       (let ([fams (pango_font_map_list_families
                    (pango_cairo_font_map_get_default))])
         (if (eq? mode 'mono)
             (filter pango_font_family_is_monospace fams)
             fams))))
