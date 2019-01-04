#!/usr/bin/env perl
use strict;
use Test::More;

use SemVer::Ranges qw(major minor patch);

{
    my @versions = (
        [ '1.2.3',       1 ],
        [ ' 1.2.3 ',     1 ],
        [ ' 2.2.3-4 ',   2 ],
        [ ' 3.2.3-pre ', 3 ],
        [ 'v5.2.3',      5 ],
        [ ' v8.2.3 ',    8 ],
        [ "\t13.2.3",    13 ],

        #['=21.2.3', 21, 1],
        #['v=34.2.3', 34, 1]
    );

    for my $pair (@versions) {
        my ( $range, $version, $loose ) = @$pair;
        is major( $range, $loose ), $version, "major($range) = $version";
    }
}

{
    my @versions = (
        [ '1.1.3',       1 ],
        [ ' 1.1.3 ',     1 ],
        [ ' 1.2.3-4 ',   2 ],
        [ ' 1.3.3-pre ', 3 ],
        [ 'v1.5.3',      5 ],
        [ ' v1.8.3 ',    8 ],
        [ "\t1.13.3",    13 ],

        #['=1.21.3', 21, 1],
        #['v=1.34.3', 34, 1]
    );

    for my $pair (@versions) {
        my ( $range, $version, $loose ) = @$pair;
        is minor( $range, $loose ), $version, "minor($range) = $version";
    }
}

{
    my @versions = (
        [ '1.2.1',       1 ],
        [ ' 1.2.1 ',     1 ],
        [ ' 1.2.2-4 ',   2 ],
        [ ' 1.2.3-pre ', 3 ],
        [ 'v1.2.5',      5 ],
        [ ' v1.2.8 ',    8 ],
        [ "\t1.2.13",    13 ],

        #['=1.2.21', 21, 1],
        #['v=1.2.34', 34, 1]
    );

    for my $pair (@versions) {
        my ( $range, $version, $loose ) = @$pair;
        is patch( $range, $loose ), $version, "patch($range) = $version";
    }
}
done_testing();
