package SemVer::Ranges;
use 5.10.0;
use warnings;

use Exporter qw(import);
use List::Util qw(max all);

use DDP;

our @EXPORT_OK = qw(
  major minor patch
  gt lt eq gte lte neq cmp
  compare satisfies
);

my $nr        = qr/(?:0|[1-9]\d*)/a;
my $part      = qr/(?:$nr|\d*[\w-][\w-]*)/a;
my $parts     = qr/(?:$part(?:\.$part)*)/;
my $pre       = qr/\-(?<pre>$parts)/;
my $build     = qr/\+(?<build>$parts)/;
my $qualifier = qr/(?:(?:\-$pre)?(?:\+$build)?)/;
my $xr        = qr/(?:[xX*]|$nr)/;

my $main_version =
  qr/(?:(?<major>$nr)\.(?<minor>$nr)\.(?<patch>$nr))/;

my $fullplain = qr/v?${main_version}${pre}?${build}?/;
my $full      = qr/(?<full>^$fullplain$)/;

my $gtlt = qr/(?<gtlt>(<|>)?=?)/;

my $xrange =
  qr/(?:(?:(?<major>$xr)\.)?(?:(?<minor>$xr)\.)?(?<patch>$xr)?)/;

my $xrangeplain = qr/[v=\s]?${xrange}${pre}?${build}?/;

my $hyphen = qr/\s*(?<hyphen_range>(?<from>$xrange)\s*-\s*(?<to>$xrange))/;
my $caret  = qr/\s*\^(?<caret>$xrange)/;
my $tilde  = qr/\s*\~(?<tilde>$xrange)/;

my $range     = qr/(?:$hyphen|$caret|$tilde)/;
my $range_set = qr/^(?<range_set>$range(?:\s*||\s*$range)*)/;

sub is_valid {
    my $range = shift;
    return $range =~ $range_set;
}

use Carp qw(confess);

sub parse_version {
    confess unless defined $_[0];
    return $_[0] if ref $_[0] eq ref {};
    # TODO this should maybe be %- but I don't know what that'll break yet
    return {%+} if $_[0] =~ $full;
    return {};
}

sub major {
    my $v = ref $_[0] eq ref {} ? shift : parse_version(shift);
    return $v->{major};
}

sub minor {
    my $v = ref $_[0] eq ref {} ? shift : parse_version(shift);
    return $v->{minor};
}

sub patch {
    my $v = ref $_[0] eq ref {} ? shift : parse_version(shift);
    return $v->{patch};
}

sub compare { compare_main(@_) || compare_pre(@_) }

sub gt  { compare(@_) > 0 }
sub lt  { compare(@_) < 0 }
sub eq  { compare(@_) == 0 }
sub lte { compare(@_) <= 0 }
sub gte { compare(@_) >= 0 }
sub neq { compare(@_) != 0 }

sub cmp {
    my ( $v1, $op, $v2 ) = @_;
    for ($op) {
        if ( $_ eq '>' ) { return &gt( $v1, $v2 ) }
        if ( $_ eq '<' ) { return &lt( $v1, $v2 ) }
        if ( $_ eq '==' ) { return &eq( $v1, $v2 ) }
        if ( $_ eq '!=' ) { return neq( $v1, $v2 ) }
        if ( $_ eq '>=' ) { return gte( $v1, $v2 ) }
        if ( $_ eq '<=' ) { return lte( $v1, $v2 ) }
        die "Invalid operator: $_";
    }
}

sub compare_main {
    my ( $v1, $v2 ) = map { parse_version $_ } @_;
    compare_identifiers( major($v1), major($v2) )
      || compare_identifiers( minor($v1), minor($v2) )
      || compare_identifiers( patch($v1), patch($v2) );
}

sub compare_identifiers {

    # if both sides are numbers return the comparison
    return $_[0] <=> $_[1] if all { m/^\d+$/a } @_;

    # if only the left side is a number, pick it
    return -1 if $_[0] =~ m/^\d+$/a;

    # if only the right side is a number, pick it
    return 1 if $_[1] =~ m/^\d+$/a;

    # otherwise compare strings
    return $_[0] cmp $_[1];
}

sub compare_pre {
    my ( $v1, $v2 ) = map { parse_version $_ } @_;

    unless ( all { defined $_->{pre} } $v1, $v2 ) {
        return exists( $v2->{pre} ) <=> exists( $v1->{pre} );
    }

    my $v1_pre = [ split /\./, $v1->{pre} ];
    my $v2_pre = [ split /\./, $v2->{pre} ];

    my $max = max map { scalar @$_ } $v1_pre, $v2_pre;
    for my $i ( 0 .. $max - 1 ) {
        my $p1 = $v1_pre->[$i] // '';
        my $p2 = $v2_pre->[$i] // '';
        next if "$p1" eq "$p2";
        return compare_identifiers( $p1, $p2 );
    }
}

sub parse_range {
    confess unless defined $_[0];
    return $_[0] if ref $_[0] eq ref {};
    warn "parsing range: $_[0]";
    return {%+} if $_[0] =~ $range_set;
    return {};
}

use DDP;
sub satisfies {
    my ( $range, $version ) = @_;
    $range = parse_range($range);
    warn p $range;
}

__END__
range-set  ::= range ( logical-or range ) *
logical-or ::= ( ' ' ) * '||' ( ' ' ) *
range      ::= hyphen | simple ( ' ' simple ) * | ''
hyphen     ::= partial ' - ' partial
simple     ::= primitive | partial | tilde | caret
primitive  ::= ( '<' | '>' | '>=' | '<=' | '=' ) partial
partial    ::= xr ( '.' xr ( '.' xr qualifier ? )? )?
xr         ::= 'x' | 'X' | '*' | nr
nr         ::= '0' | [1-9] ( [0-9] ) *
tilde      ::= '~' partial
caret      ::= '^' partial
qualifier  ::= ( '-' pre )? ( '+' build )?
pre        ::= parts
build      ::= parts
parts      ::= part ( '.' part ) *
part       ::= nr | [-0-9A-Za-z]+

