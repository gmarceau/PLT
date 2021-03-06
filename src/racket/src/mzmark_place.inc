/* >>>> Generated by mkmark.rkt from mzmarksrc.c <<<< */

static int place_bi_channel_val_SIZE(void *p, struct NewGC *gc) {
  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place_Bi_Channel));
}

static int place_bi_channel_val_MARK(void *p, struct NewGC *gc) {
  Scheme_Place_Bi_Channel *pbc = (Scheme_Place_Bi_Channel *)p;
  gcMARK2(pbc->sendch, gc);
  gcMARK2(pbc->recvch, gc);

  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place_Bi_Channel));
}

static int place_bi_channel_val_FIXUP(void *p, struct NewGC *gc) {
  Scheme_Place_Bi_Channel *pbc = (Scheme_Place_Bi_Channel *)p;
  gcFIXUP2(pbc->sendch, gc);
  gcFIXUP2(pbc->recvch, gc);

  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place_Bi_Channel));
}

#define place_bi_channel_val_IS_ATOMIC 0
#define place_bi_channel_val_IS_CONST_SIZE 1


static int place_val_SIZE(void *p, struct NewGC *gc) {
  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place));
}

static int place_val_MARK(void *p, struct NewGC *gc) {
  Scheme_Place *pr = (Scheme_Place *)p;
  gcMARK2(pr->channel, gc);
  gcMARK2(pr->mref, gc);

  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place));
}

static int place_val_FIXUP(void *p, struct NewGC *gc) {
  Scheme_Place *pr = (Scheme_Place *)p;
  gcFIXUP2(pr->channel, gc);
  gcFIXUP2(pr->mref, gc);

  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place));
}

#define place_val_IS_ATOMIC 0
#define place_val_IS_CONST_SIZE 1


static int place_async_channel_val_SIZE(void *p, struct NewGC *gc) {
  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place_Async_Channel));
}

static int place_async_channel_val_MARK(void *p, struct NewGC *gc) {
  Scheme_Place_Async_Channel *pac = (Scheme_Place_Async_Channel *)p;
  gcMARK2(pac->msgs, gc);
  gcMARK2(pac->msg_memory, gc);

  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place_Async_Channel));
}

static int place_async_channel_val_FIXUP(void *p, struct NewGC *gc) {
  Scheme_Place_Async_Channel *pac = (Scheme_Place_Async_Channel *)p;
  gcFIXUP2(pac->msgs, gc);
  gcFIXUP2(pac->msg_memory, gc);

  return
  gcBYTES_TO_WORDS(sizeof(Scheme_Place_Async_Channel));
}

#define place_async_channel_val_IS_ATOMIC 0
#define place_async_channel_val_IS_CONST_SIZE 1


