# -*- cperl -*-
package Cetmodules::CMake::Presets::BadPerlRef;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules qw();
use Cetmodules::Util qw(error_exit);
use English qw(-no_match_vars);
use Scalar::Util qw(refaddr);

##
use warnings FATAL => qw(Cetmodules);


sub new {
  my ($class, $refstring) = @_;
  return bless { refstring => $refstring }, $class;
}

########################################################################
# Public methods
########################################################################
sub TO_JSON {
  my ($self) = @_;
  return sprintf("<bad-perl-ref \"%s\">", $self->{refstring} // "<UNDEF>");
}

########################################################################
1;
__END__
