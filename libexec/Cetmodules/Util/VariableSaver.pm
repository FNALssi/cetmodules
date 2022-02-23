# -*- cperl -*-
package Cetmodules::Util::VariableSaver;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules::Util qw(error_exit);
use Storable qw(dclone);

##
use warnings FATAL => qw(Cetmodules);


sub new {
  my ($class, $saved_var, @args) = @_;
  my $self = { saved_var => $saved_var, saved_val => dclone($saved_var) };
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  given (ref $self->{saved_var}) {
    when ('HASH')   { %{ $self->{saved_var} } = %{@args}; }
    when ('SCALAR') { ${ $self->{saved_var} } = shift @args; }
    when ('ARRAY')  { @{ $self->{saved_var} } = @args; }
    default         { error_exit("unable to save data of unknown type $_"); }
  } ## end given
  return bless $self, $class;
} ## end sub new


sub DESTROY {
  my ($self) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  given (ref $self->{saved_var}) {
    when ('HASH')   { %{ $self->{saved_var} } = %{ $self->{saved_val} }; }
    when ('SCALAR') { ${ $self->{saved_var} } = ${ $self->{saved_val} }; }
    when ('ARRAY')  { @{ $self->{saved_var} } = @{ $self->{saved_val} }; }
  } ## end given
  return;
} ## end sub DESTROY

########################################################################
1;
__END__
