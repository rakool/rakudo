#!/usr/bin/env raku

# This script reads the native_array.pm6 file, and generates the
# shaped1intarray, shaped1numarray and shaped1strarray postcircumfix
# candidates and writes it back to the file.

# always use highest version of Raku
use v6.*;

my $generator = $*PROGRAM-NAME;
my $generated = DateTime.now.gist.subst(/\.\d+/,'');
my $start     = '#- start of postcircumfix candidates of shaped1';
my $idpos     = $start.chars;
my $idchars   = 3;
my $end       = '#- end of postcircumfix candidates of shaped1';

# slurp the whole file and set up writing to it
my $filename = "src/core.c/native_array.pm6";
my @lines = $filename.IO.lines;
$*OUT = $filename.IO.open(:w);

# for all the lines in the source that don't need special handling
while @lines {
    my $line := @lines.shift;

    # nothing to do yet
    unless $line.starts-with($start) {
        say $line;
        next;
    }

    # found header
    my $type = $line.substr($idpos,$idchars);
    die "Don't know how to handle $type" unless $type eq "int" | "num" | "str";
    say $start ~ $type ~ "array ------------------------";
    say "#- Generated on $generated by $generator";
    say "#- PLEASE DON'T CHANGE ANYTHING BELOW THIS LINE";

    # skip the old version of the code
    while @lines {
        last if @lines.shift.starts-with($end);
    }

    # set up template values
    my %mapper =
      postfix => $type.substr(0,1),
      type    => $type,
      Type    => $type.tclc,
    ;

    # spurt the candidates
    say Q:to/SOURCE/.subst(/ '#' (\w+) '#' /, -> $/ { %mapper{$0} }, :g).chomp;

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos
) is raw {
    nqp::atposref_#postfix#(nqp::decont(SELF),$pos)
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos, #Type#:D \assignee
) is raw {
    nqp::bindpos_#postfix#(nqp::decont(SELF),$pos,assignee)
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array, Any:D, :$BIND!
) {
    X::Bind.new(target => 'a shaped native #type# array').throw
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos, :$exists!, *%_
) {
    my int $state =
      nqp::isge_i($pos,0) && nqp::islt_i($pos,nqp::elems(nqp::decont(SELF)));
    my $value := nqp::hllbool($exists ?? $state !! nqp::not_i($state));

    $state
      ?? nqp::elems(my $adverbs := nqp::getattr(%_,Map,'$!storage'))
        ?? nqp::atkey($adverbs,'kv')
          ?? ($pos,$value)
          !! nqp::atkey($adverbs,'p')
            ?? Pair.new($pos,$value)
            !! Failure.new(
                 X::Adverb.new(
                   what   => "slice",
                   source => "native shaped1 #type# array",
                   nogo   => ('exists', |%_.keys).sort
                 )
               )
        !! $value
      !! $value
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos, :$delete!, *%_
) {
    $delete
      ?? X::Delete.new(target => 'a shaped native #type# array').throw
      !! nqp::elems(nqp::getattr(%_,Map,'$!storage'))
        ?? postcircumfix:<[ ]>(SELF, $pos, |%_)
        !! nqp::atposref_#postfix#(nqp::decont(SELF),$pos)
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos, :$kv!
) is raw {
    $kv
      ?? nqp::list($pos,nqp::atpos_#postfix#(nqp::decont(SELF),$pos))
      !! nqp::atposref_#postfix#(nqp::decont(SELF),$pos)
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos, :$p!
) is raw {
    $p
      ?? Pair.new($pos,nqp::atpos_#postfix#(nqp::decont(SELF),$pos))
      !! nqp::atposref_#postfix#(nqp::decont(SELF),$pos)
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos, :$k!
) is raw {
    $k ?? $pos !! nqp::atposref_#postfix#(nqp::decont(SELF),$pos)
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Int:D $pos, :$v!
) is raw {
    $v
      ?? nqp::isge_i($pos,0) && nqp::islt_i($pos,nqp::elems(nqp::decont(SELF)))
        ?? nqp::list(nqp::atpos_#postfix#(nqp::decont(SELF),$pos))
        !! ()
      !! nqp::atpos_#postfix#(nqp::decont(SELF),$pos)
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Iterable:D $pos
) is raw {
    my $self     := nqp::decont(SELF);
    my $buffer   := IterationBuffer.new;
    my $iterator := $pos.iterator;

    nqp::until(
      nqp::eqaddr((my $pulled := $iterator.pull-one),IterationEnd),
      nqp::push(
        $buffer,
        nqp::atpos_#postfix#(
          $self,
          nqp::if(
            nqp::istype($pulled,Callable),
            $pulled(nqp::elems($self)),
            $pulled.Int
          )
        )
      )
    );

    $buffer.List
}

multi sub postcircumfix:<[ ]>(
  array::shaped1#type#array \SELF, Whatever
) {
    nqp::decont(SELF)
}

SOURCE

    # we're done for this role
    say "#- PLEASE DON'T CHANGE ANYTHING ABOVE THIS LINE";
    say $end ~ $type ~ "array --------------------------";
}

# close the file properly
$*OUT.close;

# vim: expandtab sw=4
