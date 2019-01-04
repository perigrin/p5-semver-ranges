#!/usr/bin/env perl
use strict;
use Test::More;

use SemVer::Ranges qw(prerelease);
use Test::Deep qw(cmp_deeply);

{
    my @versions = (
        [ [ 'alpha', 1 ], '1.2.2-alpha.1' ],
        [ [1], '0.6.1-1' ],
        [ [ 'beta', 2 ], '1.0.0-beta.2' ],
        [ ['pre'], 'v0.5.4-pre' ],
        [ [ 'alpha', 1 ], '1.2.2-alpha.1', 0 ],
        #[ ['beta'], '0.6.1beta', 1 ],
        #[ undef, '1.0.0',          1 ],
        [ undef, '~2.0.0-alpha.1', 0 ],
        [ undef, 'invalid version' ]
    );

	for my $pair (@versions) {
		my ($expected, $version, $loose) = @$pair;
		cmp_deeply scalar prerelease($version, $loose), $expected, "prerelease( $version )";
	}
}


done_testing();
