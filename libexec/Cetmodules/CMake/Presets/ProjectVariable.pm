# -*- cperl -*-
package Cetmodules::CMake::Presets::ProjectVariable;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules qw();
use Cetmodules::CMake::Presets::BadPerlRef qw();
use Cetmodules::CMake::Util qw(is_cmake_true);
use Cetmodules::Util qw(error_exit);
use English qw(-no_match_vars);
use JSON qw();
use Scalar::Util qw(blessed);

##
use warnings FATAL => qw(Cetmodules);

my @_incoming_keywords = qw(name project_name prefix type value);
my $_ENCODE_PERL;

########################################################################
# Public methods
########################################################################
sub new {
  my ($class, %args) = @_;
  my $self = { map { (exists $args{$_}) ? ($_ => $args{$_}) : (); }
               @_incoming_keywords };
  defined $self->{'project_name'} or delete $self->{'project_name'};
  JSON::is_bool($self->{'value'}) and $self->{'type'} = 'BOOL';
  return bless $self, $class;
} ## end sub new


sub PERL_JSON_ENCODING {
  my ($class) = @_;
  $_ENCODE_PERL = 1;
  return;
} ## end sub PERL_JSON_ENCODING


sub CMAKE_JSON_ENCODING {
  my ($class) = @_;
  undef $_ENCODE_PERL;
  return;
} ## end sub CMAKE_JSON_ENCODING


sub TO_JSON {
  my ($self) = @_;
  my $basic = { 'type'  => ($self->{'type'} // 'STRING'),
                'value' => $self->value // JSON::null
              };
  return $_ENCODE_PERL
    ? { __project_variable__ => { %{$self}, %{$basic} } }
    : $basic;
} ## end sub TO_JSON


sub definition {
  my ($self) = @_;
  return sprintf("-D%s%s=%s",
    $self->init_var,
    $self->{'type'} ? ":$self->{'type'}" : q(),
    (($self->{'type'} // q()) eq 'BOOL')
    ? $self->value
        ? 'ON'
        : 'OFF'
    : $self->value // q());
} ## end sub definition


sub init_var {
  my ($self) = @_;
  return $self->{'project_name'}
    ? "$self->{'project_name'}_$self->{'name'}_INIT"
    : $self->{'prefix'} ? "CET_PV_$self->{'prefix'}_$self->{'name'}"
    :                     $self->{'name'};
} ## end sub init_var


sub name {
  my ($self) = @_;
  return $self->{'name'};
}


sub project_name {
  my ($self) = @_;
  return $self->{'project_name'} // ();
}


sub set_project_name {
  my ($self, $pn) = @_;
  $self->{'project_name'} = $pn;
  return;
} ## end sub set_project_name


sub set_type {
  my ($self, $type) = @_;
  $self->{'type'} = $type;
  return;
} ## end sub set_type


sub set_value {
  my ($self, $val) = @_;
  $self->{'value'} = $val;
  JSON::is_bool($val) and $self->{'type'} = 'BOOL';
  return;
} ## end sub set_value


sub type {
  my ($self) = @_;
  return $self->{'type'};
}


sub value {
  my ($self) = @_;
  my $result;

  if (($self->{'type'} // q()) eq 'BOOL'
    and not JSON::is_bool(($self->{'value'} // q()))) {
    $result = is_cmake_true($self->{'value'}) ? JSON::true : JSON::false;
  } else {
    $result = $self->{'value'};
  }
  return $result;
} ## end sub value

########################################################################
1;
__END__
