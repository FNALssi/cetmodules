# -*- cperl -*-
package Cetmodules::Util::PosResetter;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules::Util qw(error_exit);

##
use warnings FATAL => qw(Cetmodules);


sub new {
  my ($class, $saved_var) = @_;
  ref $saved_var eq 'SCALAR'
    or error_exit("unable to store ", ref $saved_var);
  my $self = { saved_var => $saved_var };
  return bless $self, $class;
} ## end sub new


sub DESTROY {
  my ($self) = @_;
  pos(${ $self->{saved_var} }) = undef;
  return;
} ## end sub DESTROY

########################################################################
1;
__END__
