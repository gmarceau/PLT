#;
(
TR opt: unboxed-let-functions5.rkt 20:12 (+ 1.0+2.0i 2.0+4.0i) -- unboxed float complex
TR opt: unboxed-let-functions5.rkt 20:13 + -- unboxed binary float complex
TR opt: unboxed-let-functions5.rkt 20:15 1.0+2.0i -- unboxed literal
TR opt: unboxed-let-functions5.rkt 20:24 2.0+4.0i -- unboxed literal
3.0+6.0i
)

#lang typed/scheme
#:optimize



;; invalid: f "escapes", according to our analysis
(letrec: ((f : (Float-Complex -> Float-Complex)
             (lambda: ((x : Float-Complex))
                      (let: ((y : (Float-Complex -> Float-Complex) f))
                            x))))
         (f (+ 1.0+2.0i 2.0+4.0i)))
