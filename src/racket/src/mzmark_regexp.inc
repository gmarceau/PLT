/* >>>> Generated by mkmark.rkt from mzmarksrc.c <<<< */

static int mark_regexp_SIZE(void *p, struct NewGC *gc) {
  regexp *r = (regexp *)p;
  return
  gcBYTES_TO_WORDS((sizeof(regexp) + r->regsize));
}

static int mark_regexp_MARK(void *p, struct NewGC *gc) {
  regexp *r = (regexp *)p;
  gcMARK2(r->source, gc);
  gcMARK2(r->regstart, gc);
  return
  gcBYTES_TO_WORDS((sizeof(regexp) + r->regsize));
}

static int mark_regexp_FIXUP(void *p, struct NewGC *gc) {
  regexp *r = (regexp *)p;
  gcFIXUP2(r->source, gc);
  gcFIXUP2(r->regstart, gc);
  return
  gcBYTES_TO_WORDS((sizeof(regexp) + r->regsize));
}

#define mark_regexp_IS_ATOMIC 0
#define mark_regexp_IS_CONST_SIZE 0


static int mark_regwork_SIZE(void *p, struct NewGC *gc) {
  return
  gcBYTES_TO_WORDS(sizeof(Regwork));
}

static int mark_regwork_MARK(void *p, struct NewGC *gc) {
  Regwork *r = (Regwork *)p;
  gcMARK2(r->str, gc);
  gcMARK2(r->instr, gc);
  gcMARK2(r->port, gc);
  gcMARK2(r->unless_evt, gc);
  gcMARK2(r->startp, gc);
  gcMARK2(r->maybep, gc);
  gcMARK2(r->endp, gc);
  gcMARK2(r->counters, gc);
  gcMARK2(r->peekskip, gc);
  gcMARK2(r->prefix, gc);
  gcMARK2(r->rewind_stack, gc);
  return
  gcBYTES_TO_WORDS(sizeof(Regwork));
}

static int mark_regwork_FIXUP(void *p, struct NewGC *gc) {
  Regwork *r = (Regwork *)p;
  gcFIXUP2(r->str, gc);
  gcFIXUP2(r->instr, gc);
  gcFIXUP2(r->port, gc);
  gcFIXUP2(r->unless_evt, gc);
  gcFIXUP2(r->startp, gc);
  gcFIXUP2(r->maybep, gc);
  gcFIXUP2(r->endp, gc);
  gcFIXUP2(r->counters, gc);
  gcFIXUP2(r->peekskip, gc);
  gcFIXUP2(r->prefix, gc);
  gcFIXUP2(r->rewind_stack, gc);
  return
  gcBYTES_TO_WORDS(sizeof(Regwork));
}

#define mark_regwork_IS_ATOMIC 0
#define mark_regwork_IS_CONST_SIZE 1


