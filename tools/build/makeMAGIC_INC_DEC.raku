#!/usr/bin/env raku

# This script reads the Rakudo/Internals.pm6 file from STDIN, and generates
# the necessary lookup hashes for making magic Str .succ / .pred work, and
# writes it to STDOUT.

use v6;
use nqp;

# general initializations
my $generator = $*PROGRAM-NAME;
my $generated = DateTime.now.gist.subst(/\.\d+/,'');
my $start     = '#- start of generated part of succ/pred';
my $end       = '#- end of generated part of succ/pred';

# the ranges we consider magic wrt to .succ / .pred
my @ranges =
  "0".ord .. "9".ord,  # arabic digits
  "A".ord .. "Z".ord,  # latin uppercase
  "a".ord .. "z".ord,  # lating lowercase
  0x00391 .. 0x003A9,  # greek uppercase
  0x003B1 .. 0x003C9,  # greek lowercase
  0x005D0 .. 0x005EA,  # hebrew
  0x00410 .. 0x0042F,  # cyrillic uppercase
  0x00430 .. 0x0044F,  # cyrillic lowercase
  0x00660 .. 0x00669,  # arabic-indic digits
  0x006F0 .. 0x006F9,  # extended arabic-indic digits
  0x007C0 .. 0x007C9,  # nko digits
  0x00966 .. 0x0096F,  # devanagari digits
  0x009E6 .. 0x009EF,  # bengali digits
  0x00A66 .. 0x00A6F,  # gurmukhi digits
  0x00AE6 .. 0x00AEF,  # gujarati digits
  0x00B66 .. 0x00B6F,  # oriya digits
  0x00BE6 .. 0x00BEF,  # tamil digits
  0x00C66 .. 0x00C6F,  # telugu digits
  0x00CE6 .. 0x00CEF,  # kannada digits
  0x00D66 .. 0x00D6F,  # malayalam digits
  0x00DE6 .. 0x00DEF,  # sinhala lith digits
  0x00E50 .. 0x00E59,  # thai digits
  0x00ED0 .. 0x00ED9,  # lao digits
  0x00F20 .. 0x00F29,  # tibetan digits
  0x01040 .. 0x01049,  # myanmar digits
  0x01090 .. 0x01099,  # myanmar shan digits
  0x017E0 .. 0x017E9,  # khmer digits
  0x01810 .. 0x01819,  # mongolian digits
  0x01946 .. 0x0194F,  # limbu digits
  0x019D0 .. 0x019D9,  # new tai lue digits
  0x01A80 .. 0x01A89,  # tai tham hora digits
  0x01A90 .. 0x01A99,  # tai tham tham digits
  0x01B50 .. 0x01B59,  # balinese digits
  0x01BB0 .. 0x01BB9,  # sundanese digits
  0x01C40 .. 0x01C49,  # lepcha digits
  0x01C50 .. 0x01C59,  # ol chiki digits
  0x02070 .. 0x02079,  # superscripts
  0x02080 .. 0x02089,  # subscripts
  0x02160 .. 0x0216b,  # clock roman uc
  0x02170 .. 0x0217b,  # clock roman lc
  0x02460 .. 0x02473,  # circled digits 1..20
  0x02474 .. 0x02487,  # parenthesized digits 1..20
  0x0249C .. 0x024B5,  # parenthesized latin lc
  0x02581 .. 0x02588,  # lower blocks
  0x02680 .. 0x02685,  # die faces
  0x02776 .. 0x0277F,  # dingbat negative circled 1..10
  0x0A620 .. 0x0A629,  # vai digits
  0x0A8D0 .. 0x0A8D9,  # saurashtra digits
  0x0A8E0 .. 0x0A8E9,  # combining devanagari digits
  0x0A900 .. 0x0A909,  # kayah li digits
  0x0A9D0 .. 0x0A9D9,  # javanese digits
  0x0A9F0 .. 0x0A9F9,  # myanmar tai laing digits
  0x0AA50 .. 0x0AA59,  # cham digits
  0x0ABF0 .. 0x0ABF9,  # meetei mayek digits
  0x0FF10 .. 0x0FF19,  # fullwidth digits
  0x1D400 .. 0x1D419,  # mathematical bold uppercase
  0x1D41A .. 0x1D433,  # mathematical bold lowercase
  0x1D434 .. 0x1D44D,  # mathematical italic uppercase
  0x1D44E .. 0x1D467,  # mathematical italic lowercase
  0x1D468 .. 0x1D481,  # mathematical bold italic uppercase
  0x1D482 .. 0x1D49B,  # mathematical bold italic lowercase
  0x1D49C .. 0x1D4B5,  # mathematical script uppercase
  0x1D4B6 .. 0x1D4CF,  # mathematical script lowercase
  0x1D4D0 .. 0x1D4E9,  # mathematical bold script uppercase
  0x1D4EA .. 0x1D503,  # mathematical bold script lowercase
  0x1D504 .. 0x1D51D,  # mathematical fraktur uppercase
  0x1D51E .. 0x1D537,  # mathematical fraktur lowercase
  0x1D538 .. 0x1D551,  # mathematical double-struck uppercase
  0x1D552 .. 0x1D56B,  # mathematical double-struck lowercase
  0x1D56C .. 0x1D585,  # mathematical bold fraktur uppercase
  0x1D586 .. 0x1D59F,  # mathematical bold fraktur lowercase
  0x1D5A0 .. 0x1D5B9,  # mathematical sans-serif uppercase
  0x1D5BA .. 0x1D5D3,  # mathematical sans-serif lowercase
  0x1D5D4 .. 0x1D5ED,  # mathematical sans-serif bold uppercase
  0x1D5EE .. 0x1D607,  # mathematical sans-serif bold lowercase
  0x1D608 .. 0x1D621,  # mathematical sans-serif italic uppercase
  0x1D622 .. 0x1D63B,  # mathematical sans-serif italic lowercase
  0x1D63C .. 0x1D655,  # mathematical sans-serif bold italic uppercase
  0x1D656 .. 0x1D66F,  # mathematical sans-serif bold italic lowercase
  0x1D670 .. 0x1D689,  # mathematical monospace uppercase
  0x1D68A .. 0x1D6A3,  # mathematical monospace lowercase
  0x1D6A8 .. 0x1D6C0,  # mathematical greek bold uppercase
  0x1D6C2 .. 0x1D6DA,  # mathematical greek bold lowercase
  0x1D6E2 .. 0x1D6FA,  # mathematical greek italic uppercase
  0x1D6FC .. 0x1D714,  # mathematical greek italic lowercase
  0x1D71C .. 0x1D734,  # mathematical greek bold italic uppercase
  0x1D736 .. 0x1D74E,  # mathematical greek bold italic lowercase
  0x1D756 .. 0x1D76E,  # mathematical greek sans-serif bold uppercase
  0x1D770 .. 0x1D788,  # mathematical greek sans-serif bold lowercase
  0x1D790 .. 0x1D7A8,  # mathematical greek sans-serif bold italic uppercase
  0x1D7AA .. 0x1D7C2,  # mathematical greek sans-serif bold italic lowercase
  0x1D7CE .. 0x1D7D7,  # mathematical bold digit
  0x1D7D8 .. 0x1D7E1,  # mathematical double-struck digit
  0x1D7E2 .. 0x1D7EB,  # mathematical sans-serif digit
  0x1D7ED .. 0x1D7F5,  # mathematical sans-serif bold digit
  0x1D7F6 .. 0x1D7FF,  # mathematical monospace digit
  0x1F37A .. 0x1F37B,  # beer mugs
  0x1F42A .. 0x1F42B,  # camels
;

# ranges that start with these, carry (aka "9".succ -> "10" instead of "00")
my str $carrydigits =
           '0'  # arabic
   ~ "\x00660"  # arabic-indic
   ~ "\x006F0"  # extended arabic-indic
   ~ "\x007C0"  # nko
   ~ "\x00966"  # devanagari
   ~ "\x009E6"  # bengali
   ~ "\x00A66"  # gurmukhi
   ~ "\x00AE6"  # gujarati
   ~ "\x00B66"  # oriya
   ~ "\x00BE6"  # tamil
   ~ "\x00C66"  # telugu
   ~ "\x00CE6"  # kannada
   ~ "\x00D66"  # malayalam
   ~ "\x00DE6"  # sinhala lith
   ~ "\x00E50"  # thai
   ~ "\x00ED0"  # lao
   ~ "\x00F20"  # tibetan
   ~ "\x01040"  # myanmar
   ~ "\x01090"  # myanmar shan
   ~ "\x017E0"  # khmer
   ~ "\x01810"  # mongolian
   ~ "\x01946"  # limbu
   ~ "\x019D0"  # new tai lue
   ~ "\x01A80"  # tai tham hora
   ~ "\x01A90"  # tai tham tham
   ~ "\x01B50"  # balinese
   ~ "\x01BB0"  # sundanese
   ~ "\x01C40"  # lepcha
   ~ "\x02070"  # superscripts XXX: should be treated as digit?
   ~ "\x02080"  # subscripts XXX: should be treated as digit?
   ~ "\x0A620"  # vai
   ~ "\x0A8D0"  # saurashtra
   ~ "\x0A8E0"  # combining devanagari
   ~ "\x0A900"  # kayah li
   ~ "\x0A9D0"  # javanese
   ~ "\x0A9F0"  # myanmar tai laing
   ~ "\x0ABF0"  # meetei mayek
   ~ "\x0AA50"  # cham
   ~ "\x0FF10"  # fullwidth XXX: should be treated as digit?
   ~ "\x1D7CE"  # mathematical bold digit
   ~ "\x1D7D8"  # mathematical double-struck digit
   ~ "\x1D7E2"  # mathematical sans-serif digit
   ~ "\x1D7ED"  # mathematical sans-serif bold digit
   ~ "\x1D7F6"  # mathematical monospace digit
   ~ "\x1F37A"  # beer mugs
   ~ "\x1F42A"  # camels
;

# holes in otherwise contiguous ranges
my str $holes =
     "\x003A2"  # <reserved>
   ~ "\x003C2"  # GREEK SMALL LETTER FINAL SIGMA
;

# for all the lines in the source that don't need special handling
for $*IN.lines -> $line {

    # nothing to do yet
    unless $line.starts-with($start) {
        say $line;
        next;
    }

    # found header
    say $start ~ " ---------------------------------------";
    say "#- Generated on $generated by $generator";
    say "#- PLEASE DON'T CHANGE ANYTHING BELOW THIS LINE";

    # skip the old version of the code
    for $*IN.lines -> $line {
        last if $line.starts-with($end);
    }

    # initialize .succ data structures
    my $nlook := nqp::list_s;
    my $nchrs := nqp::list_s;
    my $blook := nqp::list_s;
    my $bchrs := nqp::list_s;
    for @ranges -> $range {
        my int $first = $range.AT-POS(0);
        my int $carry = nqp::index($carrydigits,nqp::chr($first)) > -1;
        my int $end   = $range.end;
        my str $char;

        for $range.kv -> int $i, int $ord {
            if $i < $end {
                $char = nqp::chr($ord);
                nqp::push_s($nlook,$char)
                  if nqp::iseq_i(nqp::index($holes,$char),-1);
                $char = nqp::chr($ord + 1);
                nqp::push_s($nchrs,$char)
                  if nqp::iseq_i(nqp::index($holes,$char),-1);
            }
            else {
                nqp::push_s($blook,nqp::chr($ord));
                nqp::push_s($bchrs,nqp::chr($first+$carry) ~ nqp::chr($first));
            }
        }
    }

    # generate the SUCC initialization
    print Q:c:to/SOURCE/;

    # normal increment magic chars & incremented char at same index
    my $succ-nlook = '{nqp::join('',$nlook)}';
    my $succ-nchrs = '{nqp::join('',$nchrs)}'; 

    # magic increment chars at boundary & incremented char at same index
    my $succ-blook = '{nqp::join('',$blook)}';
    my $succ-bchrs = '{nqp::join('',$bchrs)}';

SOURCE

    # initialize .pred data structures
    $nlook := nqp::list_s;
    $nchrs := nqp::list_s;
    $blook := nqp::list_s;
    $bchrs := nqp::list_s;
    for @ranges -> $range {
        my str $char;
        for $range.kv -> int $i, int $ord {
            if $i {
                $char = nqp::chr($ord);
                nqp::push_s($nlook,$char)
                  if nqp::iseq_i(nqp::index($holes,$char),-1);
                $char = nqp::chr($ord - 1);
                nqp::push_s($nchrs,$char)
                  if nqp::iseq_i(nqp::index($holes,$char),-1);
            }
            else {
                nqp::push_s($blook,nqp::chr($ord));
                nqp::push_s($bchrs,nqp::chr($range.AT-POS($range.end)));
            }
        }
    }

    # generate the PRED initialization
    print Q:c:to/SOURCE/;
    # normal decrement magic chars & incremented char at same index
    my $pred-nlook = '{nqp::join('',$nlook)}';
    my $pred-nchrs = '{nqp::join('',$nchrs)}'; 

    # magic decrement chars at boundary & incremented char at same index
    my $pred-blook = '{nqp::join('',$blook)}';
    my $pred-bchrs = '{nqp::join('',$bchrs)}';

SOURCE

    # we're done for this role
    say "#- PLEASE DON'T CHANGE ANYTHING ABOVE THIS LINE";
    say $end ~ " -----------------------------------------";
}

# vim: expandtab sw=4
