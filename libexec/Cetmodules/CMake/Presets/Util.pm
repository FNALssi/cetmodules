# -*- cperl -*-
package Cetmodules::CMake::Presets::Util;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules qw(:DIAG_VARS);
use Exporter qw(import);
use Scalar::Util qw(blessed);

##
use warnings FATAL => qw(Cetmodules);

##
use vars qw();

our (@EXPORT_OK);

@EXPORT_OK = qw(
  is_bad_reference
  is_project_variable
);

########################################################################
# Exported functions
########################################################################
sub is_bad_reference {
  my ($ref) = @_;
  return blessed($ref) && $ref->isa("Cetmodules::CMake::Presets::BadPerlRef");
}


sub is_project_variable {
  my ($ref) = @_;
  return blessed($ref)
    && $ref->isa("Cetmodules::CMake::Presets::ProjectVariable");
} ## end sub is_project_variable

########################################################################
1;
__END__
