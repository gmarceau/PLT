#lang racket/base
(require ffi/unsafe/objc
         ffi/unsafe
         racket/class
          "../../syntax.rkt"
         "item.rkt"
         "utils.rkt"
         "types.rkt"
         "const.rkt"
         "window.rkt"
         "../common/event.rkt"
         "image.rkt")

(provide 
 (protect-out button%
              core-button%
              MyButton))

;; ----------------------------------------

(import-class NSButton NSView NSImageView)

(define MIN-BUTTON-WIDTH 72)
(define BUTTON-EXTRA-WIDTH 12)

(define NSSmallControlSize 1)
(define NSMiniControlSize 2)

(define-objc-class MyButton NSButton
  #:mixins (FocusResponder KeyMouseResponder CursorDisplayer)
  [wxb]
  (-a _void (clicked: [_id sender])
      (queue-window*-event wxb (lambda (wx) (send wx clicked)))))

(defclass core-button% item%
  (init parent cb label x y w h style font
        [button-type #f])
  (init-field [event-type 'button])
  (inherit get-cocoa get-cocoa-window init-font
           register-as-child)

  (define button-cocoa
    (let ([cocoa 
           (as-objc-allocation
            (tell (tell MyButton alloc) 
                  initWithFrame: #:type _NSRect (make-NSRect (make-init-point x y)
                                                             (make-NSSize w h))))])
      (when button-type
        (tellv cocoa setButtonType: #:type _int button-type))
      (unless button-type
        (tellv cocoa setBezelStyle: #:type _int (if (not (string? label))
                                                    NSRegularSquareBezelStyle
                                                    NSRoundedBezelStyle)))
      (cond
       [(string? label)
        (tellv cocoa setTitleWithMnemonic: #:type _NSString label)]
       [(send label ok?)
        (if button-type
            (tellv cocoa setTitle: #:type _NSString "")
            (tellv cocoa setImage: (bitmap->image label)))]
       [else
        (tellv cocoa setTitle: #:type _NSString "<bad>")])
      (init-font cocoa font)
      (tellv cocoa sizeToFit)
      (when (and (eq? event-type 'button)
                 (string? label))
        (when font
          (let ([n (send font get-point-size)])
            (when (n . < . sys-font-size)
              (tellv (tell cocoa cell) 
                     setControlSize: #:type _int 
                     (if (n . < . (- sys-font-size 2))
                         NSMiniControlSize
                         NSSmallControlSize)))))
        (let ([frame (tell #:type _NSRect cocoa frame)])
          (tellv cocoa setFrame: #:type _NSRect 
                 (make-NSRect (NSRect-origin frame)
                              (make-NSSize (+ BUTTON-EXTRA-WIDTH
                                              (max MIN-BUTTON-WIDTH
                                                   (NSSize-width (NSRect-size frame))))
                                           (NSSize-height (NSRect-size frame)))))))
      cocoa))

  (define cocoa (if (and button-type
                         (not (string? label))
                         (send label ok?))
                    ;; Check-box image: need an view to join a button and an image view:
                    ;; (Could we use the NSImageButtonCell from the radio-box implementation
                    ;;  instead?)
                    (let* ([frame (tell #:type _NSRect button-cocoa frame)]
                           [new-width (+ (NSSize-width (NSRect-size frame))
                                         (send label get-width))]
                           [new-height (max (NSSize-height (NSRect-size frame))
                                            (send label get-height))])
                      (let ([cocoa (as-objc-allocation
                                    (tell (tell NSView alloc)
                                          initWithFrame: #:type _NSRect
                                          (make-NSRect (NSRect-origin frame)
                                                       (make-NSSize new-width
                                                                    new-height))))]
                            [image-cocoa (as-objc-allocation
                                          (tell (tell NSImageView alloc) init))])
                        (tellv cocoa addSubview: button-cocoa)
                        (tellv cocoa addSubview: image-cocoa)
                        (tellv image-cocoa setImage: (bitmap->image label))
                        (tellv image-cocoa setFrame: #:type _NSRect 
                               (make-NSRect (make-NSPoint (NSSize-width (NSRect-size frame))
                                                          (quotient (- new-height
                                                                       (send label get-height))
                                                                    2))
                                            (make-NSSize (send label get-width)
                                                         (send label get-height))))
                        (tellv button-cocoa setFrame: #:type _NSRect
                               (make-NSRect (make-NSPoint 0 0)
                                            (make-NSSize new-width new-height)))
                        (set-ivar! button-cocoa wxb (->wxb this))
                        cocoa))
                    button-cocoa))

  (define we (make-will-executor))

  (super-new [parent parent]
             [cocoa cocoa]
             [no-show? (memq 'deleted style)]
             [callback cb])

  (when (memq 'border style)
    (tellv (get-cocoa-window) setDefaultButtonCell: (tell button-cocoa cell)))

  (tellv button-cocoa setTarget: button-cocoa)
  (tellv button-cocoa setAction: #:type _SEL (selector clicked:))

  (define/override (get-cocoa-control) button-cocoa)

  (define/override (maybe-register-as-child parent on?)
    (register-as-child parent on?))
    
  (define/override (set-label label)
    (cond
     [(string? label)
      (tellv cocoa setTitleWithMnemonic: #:type _NSString label)]
     [else
      (tellv cocoa setImage: (bitmap->image label))]))
  
  (define callback cb)
  (define/public (clicked)
    (callback this (new control-event%
                        [event-type event-type]
                        [time-stamp (current-milliseconds)])))
  
  (def/public-unimplemented set-border))

(define button%
  (class core-button% (super-new)))
