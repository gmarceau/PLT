#lang racket/base
(require racket/class
         ffi/unsafe
         racket/draw
         "../../syntax.rkt"
         "../../lock.rkt"
         "../common/canvas-mixin.rkt"
         "../common/backing-dc.rkt"
         "../common/event.rkt"
         "../common/freeze.rkt"
         "../common/queue.rkt"
         "utils.rkt"
         "types.rkt"
         "const.rkt"
         "wndclass.rkt"
         "window.rkt"
         "dc.rkt"
         "item.rkt"
         "hbitmap.rkt"
         "gcwin.rkt"
         "theme.rkt")

(provide 
 (protect-out canvas%))

(define WS_EX_STATICEDGE        #x00020000)
(define WS_EX_CLIENTEDGE        #x00000200)

(define-user32 BeginPaint (_wfun _HWND _pointer -> _HDC))
(define-user32 EndPaint (_wfun _HDC _pointer -> _BOOL))
(define-user32 ShowScrollBar (_wfun _HWND _int _BOOL -> (r : _BOOL)
                                    -> (unless r (failed 'ShowScrollbar))))

(define-gdi32 CreateSolidBrush (_wfun _COLORREF -> _HBRUSH))
(define-user32 FillRect (_wfun _HDC _RECT-pointer _HBRUSH -> (r : _int)
                               -> (when (zero? r) (failed 'FillRect))))

(define _HRGN _pointer)
(define-user32 GetDCEx (_wfun _HWND _HRGN _DWORD -> _HDC))
(define DCX_WINDOW           #x00000001)
(define DCX_CACHE            #x00000002)

(define EP_EDITTEXT 1)
(define ETS_NORMAL 1)
(define ETS_DISABLE 4)

(define HTHSCROLL           6)
(define HTVSCROLL           7)

(define-cstruct _SCROLLINFO
  ([cbSize _UINT]
   [fMask _UINT]
   [nMin  _int]
   [nMax  _int]
   [nPage _UINT]
   [nPos  _int]
   [nTrackPos _int]))

(define-user32 SetScrollInfo (_wfun _HWND _int _SCROLLINFO-pointer _BOOL -> _int))
(define-user32 GetScrollPos (_wfun _HWND _int -> _int))
(define-user32 SetScrollPos (_wfun _HWND _int _int _BOOL -> _int))
(define-user32 GetScrollInfo (_wfun _HWND _int (i : _SCROLLINFO-pointer
                                                  = (make-SCROLLINFO (ctype-sizeof _SCROLLINFO)
                                                                     (bitwise-ior SIF_RANGE SIF_POS 
                                                                                  SIF_PAGE SIF_TRACKPOS)
                                                                     0 0 0 0 0))
                                    -> (r : _BOOL)
                                    -> (if r i (error 'GetScrollInfo "failed"))))

(define COMBO-WIDTH 18)

(define canvas% 
  (canvas-mixin
   (class (canvas-autoscroll-mixin (item-mixin window%))
     (init parent
           x y w h
           style
           [ignored-name #f]
           [gl-conf #f])

     (inherit get-hwnd
              get-client-size
              get-eventspace
              set-control-font
              is-auto-scroll? get-virtual-width get-virtual-height
              reset-auto-scroll
              refresh-for-autoscroll
              on-size)

     (define hscroll? (memq 'hscroll style))
     (define vscroll? (memq 'vscroll style))
     (define for-gl? (memq 'gl style))

     (define panel-hwnd
       (and (memq 'combo style)
            (CreateWindowExW 0
                             "PLTTabPanel"
                             #f
                             (bitwise-ior WS_CHILD)
                             0 0 w h
                             (send parent get-client-hwnd)
                             #f
                             hInstance
                             #f)))

     (define canvas-hwnd
       (CreateWindowExW (cond
                         [(memq 'border style) WS_EX_STATICEDGE]
                         [(memq 'control-border style) WS_EX_CLIENTEDGE]
                         [else 0])
                        "PLTCanvas"
                        #f
                        (bitwise-ior WS_CHILD 
                                     (if panel-hwnd WS_VISIBLE 0)
                                     (if hscroll? WS_HSCROLL 0)
                                     (if vscroll? WS_VSCROLL 0))
                        0 0 w h
                        (or panel-hwnd (send parent get-hwnd))
                        #f
                        hInstance
                        #f))
     (define combo-hwnd
       (and panel-hwnd
            (CreateWindowExW/control 0
                                     "PLTCOMBOBOX"
                                     ""
                                     (bitwise-ior WS_CHILD WS_VISIBLE
                                                  CBS_DROPDOWNLIST 
                                                  WS_HSCROLL WS_VSCROLL
                                                  WS_BORDER WS_CLIPSIBLINGS)
                                     0 0 w h
                                     panel-hwnd
                                     #f
                                     hInstance
                                     #f)))

     (define hwnd (or panel-hwnd canvas-hwnd))

     (super-new [parent parent]
                [hwnd hwnd]
                [extra-hwnds (if panel-hwnd
                                 (list canvas-hwnd combo-hwnd)
                                 null)]
                [style style])

     (when combo-hwnd
       (set-control-font #f combo-hwnd))

     (define control-border-theme
       (and (memq 'control-border style)
            (OpenThemeData canvas-hwnd "Edit")))

     (define/override (wndproc w msg wParam lParam default)
       (cond
        [(= msg WM_PAINT)
         (let* ([ps (malloc 128)]
                [hdc (BeginPaint w ps)])
           (if for-gl?
               (queue-paint)
               (unless (positive? paint-suspended)
                 (let* ([hbrush (if no-autoclear?
                                    #f
                                    (if transparent?
                                        background-hbrush
                                        (CreateSolidBrush bg-colorref)))])
                   (when hbrush
                     (let ([r (GetClientRect canvas-hwnd)])
                       (FillRect hdc r hbrush))
                     (unless transparent?
                       (DeleteObject hbrush)))
                   (unless (do-canvas-backing-flush hdc)
                     (queue-paint)))))
           (EndPaint hdc ps))
         0]
        [(= msg WM_NCPAINT)
         (if control-border-theme
             (let* ([r (GetWindowRect canvas-hwnd)]
                    [res (default w msg wParam lParam)]
                    [hdc (GetDCEx canvas-hwnd #f (bitwise-ior DCX_CACHE DCX_WINDOW))]
                    [wr (make-RECT 0 0
                                   (- (RECT-right r) (RECT-left r))
                                   (- (RECT-bottom r) (RECT-top r)))])
               (DrawThemeBackground control-border-theme
                                    hdc
                                    EP_EDITTEXT
                                    ETS_NORMAL ;; or ETS_DISABLED?
                                    wr
                                    #f)
               (ReleaseDC canvas-hwnd hdc)
               1)
             (default w msg wParam lParam))]
        [(= msg WM_HSCROLL)
         (on-scroll-change SB_HORZ (LOWORD wParam))
         0]
        [(= msg WM_VSCROLL)
         (on-scroll-change SB_VERT (LOWORD wParam))
         0]
        [else (super wndproc w msg wParam lParam default)]))
     
     (define/override (wndproc-for-ctlproc w msg wParam lParam default)
       (default w msg wParam lParam))
     
     (define dc (new dc% [canvas this]))
     (send dc start-backing-retained)

     (define/public (get-dc) dc)

     (define gl-config gl-conf)
     (define/public (get-gl-config) gl-config)

     (define/override (on-resized)
       (reset-dc))

     (define/private (reset-dc)
       (send dc reset-backing-retained)
       (send dc set-auto-scroll
             (if (get-virtual-width)
                 (get-virtual-h-pos)
                 0)
             (if (get-virtual-height)
                 (get-virtual-v-pos)
                 0)))

     (define/override (get-client-hwnd)
       canvas-hwnd)

     (define/override (set-size x y w h)
       (super set-size x y w h)
       (when panel-hwnd
         (let* ([r (and (or (= w -1) (= h -1))
                        (GetWindowRect hwnd))]
                [w (if (= w -1) (- (RECT-right r) (RECT-left r)) w)]
                [h (if (= h -1) (- (RECT-bottom r) (RECT-top r)) h)])
           (MoveWindow canvas-hwnd 0 0 (max 1 (- w COMBO-WIDTH)) h #t)
           (MoveWindow combo-hwnd 0 0 (max 1 w) (- h 2) #t)))
       (on-size 0 0))

     ;; The `queue-paint' and `paint-children' methods
     ;; are defined by `canvas-mixin' from ../common/canvas-mixin
     (define/public (queue-paint) (void))
     (define/public (request-canvas-flush-delay)
       (request-flush-delay this))
     (define/public (cancel-canvas-flush-delay req)
       (cancel-flush-delay req))
     (define/public (queue-canvas-refresh-event thunk)
       (queue-window-refresh-event this thunk))

     (define/public (get-flush-window) canvas-hwnd)

     (define/public (begin-refresh-sequence)
       (send dc suspend-flush))
     (define/public (end-refresh-sequence)
       (send dc resume-flush))

     ;; Improve this method to flush locally
     ;; instead of globally:
     (define/public (flush)
       (flush-display))

     (define/public (on-paint) (void))
     (define/override (refresh) (queue-paint))

     (define/public (queue-backing-flush)
       (unless for-gl?
         (InvalidateRect canvas-hwnd #f #f)
         (schedule-periodic-backing-flush)))

     ;; overridden to extend for scheduled periodic flushes:
     (define/public (schedule-periodic-backing-flush)
       (void))
     (define/public (do-canvas-backing-flush hdc)
       (if hdc
           (do-backing-flush this dc hdc)
           (let ([hdc (GetDC canvas-hwnd)])
             (do-backing-flush this dc hdc)
             (ReleaseDC canvas-hwnd hdc)
             (ValidateRect canvas-hwnd #f))))

     (define/public (make-compatible-bitmap w h)
       (send dc make-backing-bitmap w h))

     (define paint-suspended 0)
     (define/public (suspend-paint-handling)
       (atomically
        (set! paint-suspended (add1 paint-suspended))))
     (define/public (resume-paint-handling)
       (atomically
        (unless (zero? paint-suspended)
          (set! paint-suspended (sub1 paint-suspended)))))

     (define no-autoclear? (memq 'no-autoclear style))
     (define transparent? (memq 'transparent style))
     (define bg-col (make-object color% "white"))
     (define bg-colorref #xFFFFFF)
     (define/public (get-canvas-background) (if transparent?
                                                #f
                                                bg-col))
     (define/public (get-canvas-background-for-backing) (and (not transparent?)
                                                             (not no-autoclear?)
                                                             bg-col))
     (define/public (set-canvas-background col)
       (atomically
        (set! bg-col col)
        (set! bg-colorref (make-COLORREF (send col red)
                                         (send col green)
                                         (send col blue)))))

     (define wants-focus? (not (memq 'no-focus style)))
     (define/override (can-accept-focus?)
       wants-focus?)

     (define h-scroll-visible? hscroll?)
     (define v-scroll-visible? vscroll?)
     (define/public (show-scrollbars h? v?)
       (when hscroll?
         (atomically
          (set! h-scroll-visible? (and h? #t))
          (ShowScrollBar canvas-hwnd SB_HORZ h?)))
       (when vscroll?
         (atomically
          (set! v-scroll-visible? (and v? #t))
          (ShowScrollBar canvas-hwnd SB_VERT v?))))

     (define/override (do-set-scrollbars h-step v-step
                                         h-len v-len
                                         h-page v-page
                                         h-pos v-pos)
       (define (make-info len page pos vis?)
         (make-SCROLLINFO (ctype-sizeof _SCROLLINFO)
                          (bitwise-ior (if vis? SIF_DISABLENOSCROLL 0)
                                       SIF_RANGE
                                       SIF_POS
                                       SIF_PAGE)
                          0 (+ len page -1) page pos 0))
       (when hscroll?
         (SetScrollInfo canvas-hwnd SB_HORZ (make-info h-len h-page h-pos h-scroll-visible?) #t))
       (when vscroll?
         (SetScrollInfo canvas-hwnd SB_VERT (make-info v-len v-page v-pos v-scroll-visible?) #t))
       (void))

    (define/override (reset-dc-for-autoscroll)
      (reset-dc)
      (refresh))

    (define/override (get-virtual-h-pos)
      (GetScrollPos canvas-hwnd SB_HORZ))
    (define/override (get-virtual-v-pos)
      (GetScrollPos canvas-hwnd SB_VERT))

     (define/public (get-scroll-pos which)
       (if (is-auto-scroll?)
           0
           (GetScrollPos canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ))))
     (define/public (get-scroll-range which)
       (if (is-auto-scroll?)
           0
           (get-real-scroll-range which)))
     (define/public (get-real-scroll-range which)
       (let ([i (GetScrollInfo canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ))])
         (+ (- (SCROLLINFO-nMax i)
               (SCROLLINFO-nPage i))
            1)))
     (define/public (get-scroll-page which)
       (if (is-auto-scroll?)
           0
           (let ([i (GetScrollInfo canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ))])
             (SCROLLINFO-nPage i))))

     (define/public (set-scroll-pos which v)
       (void (SetScrollPos canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ) v #t)))
     (define/public (set-scroll-range which v)
       (let ([i (GetScrollInfo canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ))])
         (set-SCROLLINFO-fMask! i (bitwise-ior SIF_RANGE 
                                               (if (if (eq? which 'vertical)
                                                       v-scroll-visible?
                                                       h-scroll-visible?)
                                                   SIF_DISABLENOSCROLL
                                                   0)))
         (set-SCROLLINFO-nMax! i (+ v (SCROLLINFO-nPage i) -1))
         (SetScrollInfo canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ) i #t)
         (void)))
     (define/public (set-scroll-page which v)
       (let ([i (GetScrollInfo canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ))])
         (set-SCROLLINFO-fMask! i (bitwise-ior SIF_RANGE SIF_PAGE
                                               (if (if (eq? which 'vertical)
                                                       v-scroll-visible?
                                                       h-scroll-visible?)
                                                   SIF_DISABLENOSCROLL
                                                   0)))
         (set-SCROLLINFO-nMax! i (+ (- (SCROLLINFO-nMax i) (SCROLLINFO-nPage i))
                                    v))
         (set-SCROLLINFO-nPage! i v)
         (SetScrollInfo canvas-hwnd (if (eq? which 'vertical) SB_VERT SB_HORZ) i #t)
         (void)))

     (define/public (on-scroll e) (void))
     (define/private (on-scroll-change dir part)
       (let ([i (GetScrollInfo canvas-hwnd dir)])
         (let ([new-pos
                (cond
                 [(= part SB_TOP) 0]
                 [(= part SB_BOTTOM) (SCROLLINFO-nMax i)]
                 [(= part SB_LINEUP) (max 0 (sub1 (SCROLLINFO-nPos i)))]
                 [(= part SB_LINEDOWN) (min (SCROLLINFO-nMax i) (add1 (SCROLLINFO-nPos i)))]
                 [(= part SB_PAGEUP) (max 0 (- (SCROLLINFO-nPos i) (SCROLLINFO-nPage i)))]
                 [(= part SB_PAGEDOWN) (min (SCROLLINFO-nMax i) (+ (SCROLLINFO-nPos i) (SCROLLINFO-nPage i)))]
                 [(= part SB_THUMBTRACK) (SCROLLINFO-nTrackPos i)]
                 [else (SCROLLINFO-nPos i)])])
           (unless (= new-pos (SCROLLINFO-nPos i))
             (set-SCROLLINFO-nPos! i new-pos)
             (set-SCROLLINFO-fMask! i SIF_POS)
             (SetScrollInfo canvas-hwnd dir i #t)
             (if (is-auto-scroll?)
                 (refresh-for-autoscroll)
                 (queue-window-event
                  this
                  (lambda ()
                    (on-scroll (new scroll-event%
                                    [event-type 'thumb]
                                    [direction (if (= dir SB_HORZ) 'horizontal 'vertical)]
                                    [position new-pos])))))
             (constrained-reply (get-eventspace)
                                (lambda ()
                                  (let loop () (pre-event-sync #t) (when (yield) (loop))))
                                (void))))))

     (define/override (wants-mouse-capture? control-hwnd)
       (ptr-equal? canvas-hwnd control-hwnd))

     (define/override (definitely-wants-event? w msg wParam e) 
       (cond
        [(e . is-a? . key-event%)
         ;; All key events to canvas, event for combo:
         #t]
        [(and (or (= wParam HTVSCROLL)
                  (= wParam HTHSCROLL))
              (or (= msg WM_NCLBUTTONDOWN)
                  (= msg WM_NCRBUTTONDOWN)
                  (= msg WM_NCMBUTTONDOWN)
                  (= msg WM_NCLBUTTONDBLCLK)
                  (= msg WM_NCRBUTTONDBLCLK)
                  (= msg WM_NCMBUTTONDBLCLK)
                  (= msg WM_NCLBUTTONUP)
                  (= msg WM_NCRBUTTONUP)
                  (= msg WM_NCMBUTTONUP)))
         ;; let scrollbar handle event:
         #f]
        [else
         ;; otherwise, just handle events to canvas:
         (ptr-equal? w canvas-hwnd)]))

     (define/public (on-combo-select i) (void))
     (define/public (set-combo-text s) (void))
     (define/public (append-combo-item s)
       (SendMessageW/str combo-hwnd CB_ADDSTRING 0 s))
     (define/public (clear-combo-items)
       (SendMessageW combo-hwnd CB_RESETCONTENT 0 0))

     (define/public (on-popup) (void))

     (define/override (is-command? cmd)
       (or (= cmd CBN_SELENDOK)
           (= cmd CBN_DROPDOWN)))

     (define/public (do-command cmd control-hwnd)
       (cond
        [(= cmd CBN_SELENDOK)
         (let ([i (SendMessageW combo-hwnd CB_GETCURSEL 0 0)])
           (queue-window-event this (lambda () (on-combo-select i))))]
        [(= cmd CBN_DROPDOWN)
         (constrained-reply (get-eventspace) (lambda () (on-popup)) (void))]))

     (define/override (is-hwnd? a-hwnd)
       (or (ptr-equal? panel-hwnd a-hwnd)
           (ptr-equal? canvas-hwnd a-hwnd)
           (ptr-equal? combo-hwnd a-hwnd)))

     (define/public (scroll x y)
       (when (is-auto-scroll?) 
         (when (x . >= . 0)
           (set-scroll-pos 'horizontal 
                           (->long (* x (get-real-scroll-range 'horizontal)))))
         (when (y . >= . 0)
           (set-scroll-pos 'vertical 
                           (->long (* y (get-real-scroll-range 'vertical)))))
         (refresh-for-autoscroll)))

     (define/public (warp-pointer x y) (void))

     (define/public (set-resize-corner on?)
       (void))

     (define reg-blits null)
     
     (define/private (register-one-blit x y w h on-hbitmap off-hbitmap)
       (atomically
        (let ([hdc (create-gc-dc canvas-hwnd)])
          (let ([r (scheme_add_gc_callback
                    (make-gc-show-desc hdc on-hbitmap x y w h)
                    (make-gc-hide-desc hdc off-hbitmap x y w h))])
            (cons hdc r)))))
     
     (define/public (register-collecting-blit x y w h on off on-x on-y off-x off-y)
       (let ([on (fix-bitmap-size on w h on-x on-y)]
             [off (fix-bitmap-size off w h off-x off-y)])
         (let ([on-hbitmap (bitmap->hbitmap on)]
               [off-hbitmap (bitmap->hbitmap off)])
           (atomically
            (set! reg-blits (cons (register-one-blit x y w h on-hbitmap off-hbitmap) reg-blits))))))
     
     (define/public (unregister-collecting-blits)
       (atomically
        (for ([r (in-list reg-blits)])
          (ReleaseDC canvas-hwnd (car r))
          (scheme_remove_gc_callback (cdr r)))
        (set! reg-blits null))))))

