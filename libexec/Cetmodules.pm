# -*- cperl -*-
package Cetmodules;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Exporter qw(import);
use warnings::register;

our (@EXPORT_OK, %EXPORT_TAGS);

@EXPORT_OK   = qw($DEBUG $QUIET $QUIET_WARNINGS $VERBOSE);
%EXPORT_TAGS = (DIAG_VARS => [@EXPORT_OK]);

our ($DEBUG, $QUIET, $QUIET_WARNINGS, $VERBOSE);

########################################################################
# Exported variables
########################################################################
$DEBUG   = $ENV{DEBUG};
$QUIET   = $ENV{QUIET};
$VERBOSE = $ENV{VERBOSE};

########################################################################
1;
__END__
