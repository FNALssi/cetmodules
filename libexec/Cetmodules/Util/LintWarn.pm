# -*- cperl -*-
package Cetmodules::Util::LintWarn;

use 5.016;
use strict;
use warnings;
use English qw(-no_match_vars);

my $_n_warnings;


BEGIN {
  $SIG{__WARN__} = ## no critic qw(Variables::RequireLocalizedPunctuationVars)
    sub { $COMPILING and ++$_n_warnings; warn @_; };
}
CHECK {
  delete $SIG{__WARN__}; $_n_warnings
    and die "FAIL: counted $_n_warnings warnings during compilation\n";
}
1;
