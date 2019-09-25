: c!+ ( c a -> a+1 )    swap over  c!  1+ ;

( Format conversion )
: be1@ ( a -> n )    c@ ;
: be2@ ( a -> n )    c@+ swap  c@ 8 lshift or ;

: be4@ ( a -> n )
    c@+ swap
    c@+  8 lshift  swap
    c@+ 16 lshift  swap
    c@  24 lshift
    or or or ;

: be8@ ( a -> n )
    c@+ swap
    c@+  8 lshift  swap
    c@+ 16 lshift  swap
    c@+ 24 lshift  swap
    c@+ 32 lshift  swap
    c@+ 40 lshift  swap
    c@+ 48 lshift  swap
    c@  56 lshift
    or or or or or or or ;

: 9p-s@ ( a -> a u )    dup 2 +  swap be2@ ;

: be1! ( n a -> )    c! ;

: be2! ( n a -> )
    over swap  c!+
    swap 8 rshift
    swap c! ;

: be4! ( n a -> )
    over >r  c!+
    r@ 08 rshift  swap c!+
    r@ 16 rshift  swap c!+
    r> 24 rshift  swap c! ;

: be8! ( n a -> )
    over >r  c!+
    r@ 08 rshift  swap c!+
    r@ 16 rshift  swap c!+
    r@ 24 rshift  swap c!+
    r@ 32 rshift  swap c!+
    r@ 40 rshift  swap c!+
    r@ 48 rshift  swap c!+
    r> 56 rshift  swap c! ;

: 9p-s! ( src n dst -> )    2dup be2!  2 + swap move ;


( Transmission/reception buffers )
8192 constant /buf

create txbuf  /buf allot
create tx# 0 ,

: txcur ( -> a )    txbuf tx# @ + ;
: tx+ ( n -> )      tx# +! ;

: tx1! ( n -> )    txcur be1!  1 tx+ ;
: tx2! ( n -> )    txcur be2!  2 tx+ ;
: tx4! ( n -> )    txcur be4!  4 tx+ ;
: tx8! ( n -> )    txcur be8!  8 tx+ ;

: txs! ( a u -> )    dup >r  txcur 9p-s!  r> 2 +  tx+ ;
: >tx ( a u -> )    tuck  >r txcur r> move  tx+ ;


create rxbuf  /buf allot
create rx# 0 ,

: rxcur ( -> a )    rxbuf rx# @ + ;
: rx+ ( n -> )      rx# +! ;

: rx1@ ( -> n )    rxcur be1@  1 rx+ ;
: rx2@ ( -> n )    rxcur be2@  2 rx+ ;
: rx4@ ( -> n )    rxcur be4@  4 rx+ ;
: rx8@ ( -> n )    rxcur be8@  8 rx+ ;

: rxs@ ( -> a u )    rxcur 9p-s@  dup 2 + rx+ ;

: 9p-rxbuf ( -> a u )    rxbuf /buf ;


( 9P utilities )
create curtag 0 ,
: tag ( -> n )
    curtag @
    dup  1 + 65535 mod
    curtag ! ;

4294967295 constant NOFID
create curfid 0 ,
: newfid ( -> n )
    curfid @
    dup  1 + NOFID mod
    curfid ! ;

: tx[ ( type -> )   4 tx# !  tx1!  tag tx2! ;
: ]tx ( -> a u )    tx# @  txbuf be4!  txbuf tx# @ ;

13 constant /qid
: 9p-qtype ( a -> n )       be1@ ;
: 9p-qversion ( a -> n )    1 +  be4@ ;
: 9p-qpath ( a -> n )       5 +  be8@ ;
: 9p-qnew ( a -> a' )
    /qid allocate throw
    dup >r  /qid move  r> ;

: .qfield ( n -> )      s>d <# #s #> type ;
: .qtype  ( a -> )      9p-qtype .qfield ;
: .qversion ( a -> )    9p-qversion  decimal .qfield ;
: .qpath ( a -> )       9p-qpath  hex .qfield ;
: .qid ( a -> )
    base @ >r
    ." ("  dup .qpath  space  dup .qversion  space .qtype  ." )"
    r> base ! ;

\ Addresses valid for every R-message
: 9p-size@ ( a -> a' )    be4@ ;
: 9p-type@ ( a -> a' )    4 + be1@ ;
: 9p-tag@  ( a -> a' )    5 + be2@ ;
: 9p-body ( a -> a' )     7 + ;

\ Error on short reads or wrong response type
: rxerror? ( msg-size type -> flag )
    rxbuf 9p-type@ <>  swap rxbuf 9p-size@ <>  or ;

( 9P messages )
: Tversion ( -> a u )    100 tx[ 8192 tx4! s" 9P2000" txs! ]tx ;

: Rversion ( msg-size -> a u msize )
    101 rxerror? if  0 0 0 exit  then
    rxbuf 9p-body  dup >r
    4 + 9p-s@
    r> be4@ ;

: Tattach ( 'uname n1 'aname n2 -> rootfid a u )
    104 tx[
        newfid dup >r  tx4!
        NOFID tx4!
        >r >r  txs!
        r> r>  txs!
        r>
    ]tx ;

: Rattach ( msg-size -> 'qid )
    105 rxerror? if  0 exit  then
    rxbuf 9p-body ;

: Twalk ( 'name #name ... #names fid -> newfid a u )
    110 tx[
        tx4!
        newfid  dup >r  tx4!
        dup tx2!
        dup if
            1- for txs! next
        else
            drop
        then
        r>
    ]tx ;

: clonefid ( fid -> newfid a u )    0 swap Twalk ;

: Rwalk ( msg->size -> 'qids #qids )
    111 rxerror? if  0 -1 exit  then
    rxbuf 9p-body  dup 2 +  swap be2@ ;

: Topen ( fid mode -> a u )
    112 tx[
        swap tx4! tx1!
    ]tx ;

: Ropen ( n -> 'qid iounit )
    113 rxerror? if  0 0 exit  then
    rxbuf 9p-body  dup /qid + be4@ ;

: rw ( fid offset count -> )
    >r >r tx4!  r> tx8!  r> tx4! ;

: Tread ( fid offset count -> a u )
    116 tx[ rw ]tx ;

: Rread ( n -> data count )
    117 rxerror? if  0 0 exit  then
    rxbuf 9p-body  dup be4@  swap 4 + swap ;

: Twrite ( fid offset data count -> a u )
    tuck >r >r
    118 tx[
        rw
        r> r> >tx
    ]tx ;

: Rwrite ( n -> count )
    119 rxerror? if  0 exit  then
    rxbuf 9p-body be4@ ;
