#lang scribble/doc
@(require "common.rkt" "std-grammar.rkt" "prim-ops.rkt"
          (for-label lang/htdp-intermediate-lambda))

@title[#:style 'toc #:tag "intermediate-lam"]{Intermediate Student with Lambda}

@declare-exporting[lang/htdp-intermediate-lambda]

@racketgrammar*+qq[
#:literals (define define-struct lambda λ cond else if and or require lib planet
            local let let* letrec time check-expect check-within check-member-of check-range check-error)
(check-expect check-within check-member-of check-range check-error require)
[program (code:line def-or-expr ...)]
[def-or-expr definition
             expression
             test-case
             library-require]
[definition (define (name variable variable ...) expression)
            (define name expression)
            (define-struct name (name ...))]
[expression (lambda (variable variable ...) expression)
      (λ (variable variable ...) expression)
      (local [definition ...] expression)
      (letrec ([name expression] ...) expression)
      (let ([name expression] ...) expression)
      (let* ([name expression] ...) expression)
      (code:line (expression expression expression ...))
      (cond [expression expression] ... [expression expression])
      (cond [expression expression] ... [else expression])
      (if expression expression expression)
      (and expression expression expression ...)
      (or expression expression expression ...)
      (time expression)
      (code:line name)
      (code:line prim-op)
      (code:line @#,elem{@racketvalfont{'}@racket[_quoted]})
      (code:line @#,elem{@racketvalfont{`}@racket[_quasiquoted]})
      number
      string
      character]
]

@prim-nonterms[("intm-w-lambda") define define-struct]

@prim-variables[("intm-w-lambda") empty true false]


@; ----------------------------------------------------------------------

@section[#:tag "intm-w-lambda-syntax"]{Syntax for Intermediate with Lambda}


@defform[(lambda (variable variable ...) expression)]{

Creates a function that takes as many arguments as given @racket[variables]s,
and whose body is @racket[expression].}

@defform[(λ (variable variable ...) expression)]{

The Greek letter @racket[λ] is a synonym for @racket[lambda].}



@defform/none[(expression expression expression ...)]{

Calls the function that results from evaluating the first
@racket[expression]. The value of the call is the value of function's body when
every instance of @racket[name]'s variables are replaced by the values of the
corresponding @racket[expression]s.

The function being called must come from either a definition appearing before the
function call, or from a @racket[lambda] expression. The number of argument
@racket[expression]s must be the same as the number of arguments expected by
the function.}



@(intermediate-forms lambda
                     quote
                     quasiquote
                     unquote
                     unquote-splicing
                     local
                     letrec
                     let*
                     let
                     time)



@; ----------------------------------------------------------------------

@section[#:tag "intm-w-lambda-common-syntax"]{Common Syntax}

@(define-forms/normal define)

@(prim-forms ("beginner")
             define 
             lambda
             define-struct
             define-wish
             cond
             else
             if
             and 
             or
             check-expect
             check-within
             check-error
             check-member-of
             check-range
             require)

@section[#:tag "intm-w-lambda-pre-defined"]{Pre-defined Functions}

@prim-op-defns['(lib "htdp-intermediate-lambda.rkt" "lang") #'here '()]
