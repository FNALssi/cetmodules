# -*- cperl -*-
package Cetmodules::Util::LintWarn;

use 5.016;

use strict;
use warnings;

use English qw(-no_match_vars);

my $_n_warnings;

BEGIN { $SIG{__WARN__} = sub { $COMPILING and ++$_n_warnings; warn @_; }; } ## no critic qw(Variables::RequireLocalizedPunctuationVars)

CHECK { delete $SIG{__WARN__}; $_n_warnings and die "FAIL: counted $_n_warnings warnings during compilation\n"; }

1;
