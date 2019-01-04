package SemVer::Ranges;
use 5.14.0;
use warnings;

use Exporter qw(import);
use List::Util qw(max any all);

#use DDP use_prototypes => 0; # TODO Remove me

our @EXPORT_OK = qw(
  major minor patch prerelease
  gt lt eq gte lte neq cmp
  compare satisfies
  parse_version
);

my $nr        = qr/(?:0|[1-9]\d*)/a;
my $part      = qr/(?:$nr|\d*[\w-][\w-]*)/a;
my $parts     = qr/(?:$part(?:\.$part)*)/;
my $pre       = qr/\-(?<pre>$parts)/;
my $build     = qr/\+(?<build>$parts)/;
my $qualifier = qr/(?:(?:\-$pre)?(?:\+$build)?)/;
my $xr        = qr/(?:[xX*]|$nr)/;

my $main_version = qr/(?<major>$nr)(?:\.(?<minor>$nr))?(?:\.(?<patch>$nr))?/;

my $fullplain = qr/v?${main_version}${pre}?${build}?/;
my $full      = qr/(?<full>^$fullplain$)/;

my $gtlt = qr/(?<gtlt>[<>]?=?)/;

my $xrange_short = qr/(?:(?<major>$xr)?(?:\.(?<minor>$xr))?(?:\.(?<patch>$xr))?)/;

my $xrangeplain = qr/[v=\s]?${xrange_short}${pre}?${build}?/;

my $hyphen = qr/\s*(?<hyphen_range>(?<from>$xrangeplain)\s*-\s*(?<to>$xrangeplain))/;
my $caret = qr/\s*\^(?<caret>$xrangeplain)/;
my $tilde = qr/\s*\~\>?(?<tilde>$xrangeplain)/;
my $xrange = qr/\s*$gtlt\s*(?<xrange>$xrangeplain)/;

my $range     = qr/(?:$hyphen|$caret|$tilde|$xrange)/;
my $range_set = qr/^(?<range_set>$range(?:\s*||\s*$range)*)/;

sub is_valid { $_[0] =~ $range_set }

sub parse_version {
    die "Invalid Version" unless defined $_[0];
    return $_[0] if ref $_[0] eq ref {};
    my $v_string = $_[0] || 0;
       $v_string =~ s/^\s+//;
       $v_string =~ s/\s+$//;

    # TODO this should maybe be %- but I don't know what that'll break yet
    return {%+} if 0 + $v_string =~ $full;
    die "Invalid Version";
}

sub parse_range_part {
    die "Invalid Range" unless defined $_[0];
    return $_[0] if ref $_[0] eq ref {};
    my $r_string = $_[0];
    $r_string =~ s/^\s+//;
    $r_string =~ s/\s+$//;
    $r_string =~ s/\*/x/g;    # stars are also x's and we can parse those

    return {%+} if $r_string =~ $xrangeplain;
    die "Invalid Range";
}

sub parse_range {
    die unless defined $_[0];
    return $_[0] if ref $_[0] eq ref {};
    my $r_string = $_[0];
    $r_string =~ s/^\s+//;
    $r_string =~ s/\s+$//;
    $r_string =~ s/\*/x/g;    # stars are also x's and we can parse those

    return {%+} if $r_string =~ $range_set;
    die "Invalid range";
}

sub major {
    my $v = ref $_[0] eq ref {} ? shift : parse_version(shift);
    return $v->{major} // 0;
}

sub minor {
    my $v = ref $_[0] eq ref {} ? shift : parse_version(shift);
    return $v->{minor} // 0;
}

sub patch {
    my $v = ref $_[0] eq ref {} ? shift : parse_version(shift);
    return $v->{patch} // 0;
}

sub prerelease {
    my $v = ref $_[0] eq ref {} ? shift : parse_version(shift);
    return unless $v->{pre};
    return [split /\./, $v->{pre} ];
}

sub compare {compare_main(@_) || compare_pre(@_) }

sub gt  { compare(@_) > 0 }
sub lt  { compare(@_) < 0 }
sub eq  { compare(@_) == 0 }
sub lte { compare(@_) <= 0 }
sub gte { compare(@_) >= 0 }
sub neq { compare(@_) != 0 }

sub cmp {
    my ( $v1, $op, $v2 ) = @_;
    die "Missing Operator" unless $op;
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
    my ( $v1, $v2 ) = map { parse_version $_ } @_[0,1];
    compare_identifiers( major($v1), major($v2) )
      || compare_identifiers( minor($v1), minor($v2) )
      || compare_identifiers( patch($v1), patch($v2) );
}


sub compare_identifiers {
    # if both sides are numbers return the comparison
    return ($_[0] || 0) <=> ($_[1] || 0) if all { m/^\d*$/a }  @_;

    # if only the left side is a number, pick it
    return -1 if $_[0] =~ m/^\d*$/a;

    # if only the right side is a number, pick it
    return 1 if $_[1] =~ m/^\d*$/a;

    # otherwise compare strings
    return $_[0] cmp $_[1];
}

sub compare_pre {
    my ( $v1, $v2 ) = map { parse_version $_ } @_[0,1];

    unless ( all { defined $_->{pre} } $v1, $v2 ) {
        return defined( $v2->{pre} ) <=> defined( $v1->{pre} );
    }
    my $v1_pre = prerelease($v1);
    my $v2_pre = prerelease($v2);

    my $max = max map { scalar @{ $_ // [] } } $v1_pre, $v2_pre;
    for my $i ( 0 .. $max - 1 ) {
        my $p1 = $v1_pre->[$i] // '';
        my $p2 = $v2_pre->[$i] // '';
        next if "$p1" eq "$p2";
        return compare_identifiers( $p1, $p2 );
    }
}



sub is_x {
    my $x = shift;
    return !$x || lc($x) eq 'x' || $x eq '*';
}

sub format_version {
    my $v = shift;
    my $s = sprintf '%s.%s.%s.', $v->{qw(major minor patch)};
    if ($v->{pre}) { $s .= "-$v->{pre}" }
    if ($v->{build}) { $s .= "+$v->{build}" }
    return $s;
}

sub clean { format_version parse_version shift }

sub new_version {
    {
        major => shift,
        minor => shift,
        patch => shift,
        pre   => shift,
        build => shift
    }
}

sub get_hyphen_range_comparators {
    my $r = shift;

    my $fr = parse_range_part( $r->{from} );
    my $tr = parse_range_part( $r->{to} );
    my $fv = new_version map { is_x($_) ? 0 : $_ } @$fr{qw(major minor patch pre)};
    my $tv = new_version map { is_x($_) ? 0 : $_ } @$tr{qw(major minor patch pre)};

    my $from =
        is_x( $fv->{major} ) ? [ '>=', new_version( 0,            0, 0 ) ]
      : is_x( $fv->{minor} ) ? [ '>=', new_version( $fv->{major}, 0, 0 ) ]
      : is_x( $fv->{patch} )
      ? [ '>=', new_version( $fv->{major}, $fv->{minor}, 0 ) ]
      : [ '>=', $fv ];

    # the "to" is actually less than one higher
    my $to =
        is_x( $tv->{major} ) ? [ '<', new_version( $fv->{major} + 1, 0, 0 ) ]
      : is_x( $tv->{minor} ) ? [ '<', new_version( $tv->{major}, 0, 0 ) ]
      : is_x( $tv->{patch} )
      ? [ '<', new_version( $tv->{major}, $tv->{minor} + 1, 0 ) ]
      : [ '<', $tv ];

    return ( $from, $to );
}

sub get_caret_comparators {
    my $r = shift;
    my $v = new_version map { is_x($_) ? 0 : $_ } @$r{qw(major minor patch pre)};

    my $from = [ '>=', $v];

    return $from if all { is_x $_ } @$r{qw(major minor patch pre)};

    # the "to" is actually less than one higher
    my $to =
        !is_x( $v->{major} ) ? [ '<', new_version($v->{major} + 1, 0, 0, $v->{pre}) ]
      : !is_x( $v->{minor} ) ? [ '<', new_version( $v->{major}, $v->{minor}+ 1, 0, $v->{pre}) ]
      : [ '<', new_version( $v->{major}, $v->{minor}, $v->{patch} + 1, $v->{pre}) ];

    return ( $from, $to );
}

sub get_tilde_comparators {
    my $r = shift;
    my $v = new_version map { is_x($_) ? 0 : $_ } @$r{qw(major minor patch)};

    my $from =
        is_x( $v->{major} ) ? [ '>=', {} ]
      : is_x( $v->{minor} ) ? [ '>=', new_version( $v->{major}, 0, 0 ) ]
      : is_x( $v->{patch} ) ? [ '>=', new_version( $v->{major}, $v->{minor}, 0 ) ]
      : [ '>=', $v ];

    # the "to" is actually less than one higher
    my $to =
        is_x( $v->{major} ) ? [ '<', new_version( 1, 0, 0 ) ]
      : is_x( $v->{minor} ) ? [ '<', new_version( $v->{major} + 1, 0, 0 ) ]
      : is_x( $v->{patch} ) ? [ '<', new_version( $v->{major}, $v->{minor} + 1, 0 ) ]
      : [ '<', new_version( $v->{major}, $v->{minor} + 1, 0 ) ];

    return ( $from, $to );

}

sub get_xrange_comparators {
    my $r = shift;
    $r->{gtlt} = $r->{gtlt} eq '=' ? '==' : $r->{gtlt} || '>=';

    my ( $major, $minor, $patch ) = map { is_x($_) ? 0 : $_ } @$r{qw(major minor patch)};

    if (is_x ($r->{patch})) {
        if ($r->{gtlt} eq '==') {
            return  (
				['>=', new_version($major, $minor, 0) ],
				['<', new_version($major, $minor + 1, 0) ]
			);
        }
        if ($r->{gtlt} eq '<=') {
			if (is_x $r->{minor}) {
            	return  ['<', new_version($major + 1, 0, 0) ];
			}
            return  ['<', new_version($major, $minor+1, 0) ];
        }
    }

    return  [ $r->{gtlt}, new_version( $major, $minor, $patch ) ];
}

sub get_comparators {
    my $r = ref $_[0] eq ref {} ? shift : parse_range(shift);
    if ( exists $r->{hyphen_range} ) {
        return get_hyphen_range_comparators($r);
    }
    if ( exists $r->{caret} ) {
        return get_caret_comparators($r);
    }
    if ( exists $r->{xrange} ) {
        return get_xrange_comparators($r);
    }
    if ( exists $r->{tilde} ) {
        return get_tilde_comparators($r);
    }
    die "couldn't find comparators";
}

sub test_set {
    my ( $set, $version ) = @_;
    my @comps = get_comparators($set);
    return 0 unless all { &cmp( $version, @$_ ) } @comps;

    my $v = parse_version($version);
    if ( $v->{pre} ) {
        for my $c (@comps) {

            # Find the set of versions that are allowed to have prereleases
            # For example, ^1.2.3-pr.1 desugars to >=1.2.3-pr.1 <2.0.0
            # That should allow `1.2.3-pr.2` to pass.
            # However, `1.2.4-alpha.notready` should NOT be allowed,
            # even though it's within the range set by the comparators.
            my $allowed = $c->[-1];    # always the last entry in the comparator
            next unless $allowed->{pre};
            return 1
              if $allowed->{major} == $v->{major}
              && $allowed->{minor} == $v->{minor}
              && $allowed->{patch} == $v->{patch};
        }

        # version has a -pre but not one we like
        return 0;
    }
    return 1;
}

sub satisfies {
    my ( $range_string, $version ) = @_;
    my @sets = split /\|\|/, $range_string;
    return 1 unless @sets;
    return any { test_set($_, $version) } @sets;
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

