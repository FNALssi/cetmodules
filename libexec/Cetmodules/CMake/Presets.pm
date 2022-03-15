# -*- cperl -*-
package Cetmodules::CMake::Presets;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules qw(:DIAG_VARS);
use Cetmodules::CMake::Presets::BadPerlRef qw();
use Cetmodules::CMake::Presets::ProjectVariable qw();
use Cetmodules::CMake::Presets::Util qw(is_bad_reference is_project_variable);
use Cetmodules::Util
  qw(debug error_exit info parse_version_string to_cmake_version to_product_name to_string to_ups_version to_version_string verbose warning);
use Cetmodules::Util::VariableSaver qw();
use Cwd qw(abs_path);
use English qw(-no_match_vars);
use Exporter qw(import);
use File::Basename qw(dirname fileparse);
use File::Spec qw();
use IO::File qw();
use JSON qw();
use List::Util qw();
use List::MoreUtils qw();
use Path::Tiny qw();
use Readonly qw();
use Scalar::Util qw(blessed);

##
use warnings FATAL => qw(Cetmodules);

##
use vars qw();

our (@EXPORT, @EXPORT_OK);

@EXPORT = qw(
  project_preset_data
  resolve_reference
  write_preset_data
);
@EXPORT_OK = qw();

########################################################################
# Exported functions
########################################################################
sub project_preset_data {
  my ($source_dir, $cmake_args, $pv_seed, $options) = @_;
  my $preset_data =
    _read_preset_template($source_dir,
      $options->{json} // JSON->new->relaxed([]))
    or return;
  my ($filtered_defs, $ups_defs) =
    _process_cmake_args($cmake_args, $pv_seed, $options);
  my $from_pd = { name        => "from_product_deps",
                  hidden      => JSON::true,
                  displayName => "Configuration from product_deps",
                  description =>
                  "Configuration settings translated from ups/product_deps",
                  cacheVariables => { %{$filtered_defs} } };
  my $for_UPS = {
              name        => "extra_for_UPS",
              hidden      => JSON::true,
              displayName => "UPS extra configuration",
              description => "Extra configuration for UPS package generation",
              cacheVariables => { %{$ups_defs} } };
  unshift @{ $preset_data->{configurePresets} }, $from_pd, $for_UPS;
  return _resolve_special($preset_data, $pv_seed);
} ## end sub project_preset_data


sub resolve_reference {
  my ($preset_data, @args) = @_;
  my $result = _resolve_ref(\@args, $preset_data);
  return is_bad_reference($result) ? undef : $result;
} ## end sub resolve_reference


sub write_preset_data {
  my ($preset_data, $preset_out_path) = @_;
  my $json = JSON->new;

  # Generated JSON should be:
  $json->pretty       # indented on multiple lines,
    ->convert_blessed # handle (some) Perl classes,
    ->canonical([]);  # and map keys should be sorted.
  Path::Tiny::path($preset_out_path)->spew_utf8($json->encode($preset_data))
    or error_exit(<<"EOF");
unable to write CMake presets to $preset_out_path
EOF
  return;
} ## end sub write_preset_data

########################################################################
# Private functions
########################################################################
sub _expand_cmake_list {
  my @args = @_;
  return map { ## no critic qw(BuiltinFunctions::ProhibitComplexMappings)
    if (is_bad_reference($_)) {
      ();
    } elsif ((ref) eq 'ARRAY') {
      _expand_cmake_list(@{$_});
    } elsif (
      (ref) eq 'HASH'
      and exists $_->{value}
      and ((scalar keys %{$_}) == 1
        or ((scalar keys %{$_}) == 2 and exists $_->{type}))
      ) {
      $_->{value};
    } else {
      $_;
    }
  } @args;
} ## end sub _expand_cmake_list


sub _extract_definitions {
  my ($cmake_args, $pv_seed) = @_;
  my $definitions = {};

  foreach my $cmake_arg (@{ $cmake_args // [] }) {
    ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
    $cmake_arg =~
      m&\A-D(?P<name>[^:=]+?)(?::(?P<type>[^=]+))?=(?P<value>.+)?$&msx
      or next;
    my $def_details = {%LAST_PAREN_MATCH};
    my $def_val =
      { $def_details->{type} ? (type => $def_details->{type}) : (),
        value => $def_details->{value} // q()
      };

    if (
      $def_details->{name} =~
      m&\ACET_PV_(?P<prefix>\L[0-9A-Fa-f]+\E)_(?P<name>[A-Za-z0-9_-]+)\z&msx
      or (  $pv_seed->{project_name}
        and $def_details->{name} =~
m&\A(?P<project_name>\Q$pv_seed->{project_name}\E)_(?P<name>[A-Za-z0-9_-]+?)_INIT\z&msx
      )
      ) {
      my $pv = Cetmodules::CMake::Presets::ProjectVariable->new(%{$pv_seed},
        %{$def_val}, %LAST_PAREN_MATCH);
      $definitions->{ $pv->init_var } = $pv;
    } else {
      $definitions->{ $def_details->{name} } = $def_val;
    }
  } ## end foreach my $cmake_arg (@{ $cmake_args...})
  return $definitions;
} ## end sub _extract_definitions


sub _maybe_tweak_defs {
  my ($definitions, $pv_seed, $options) = @_;

  if ($options->{sanitize_defs}) {
    my $exec_prefix = delete $definitions->{saved}->{'EXEC_PREFIX'};

    if ($exec_prefix) {
      if (is_project_variable($exec_prefix)) {
        $exec_prefix->set_value(q($env{CETPKG_FQ_DIR}));
      } else {
        $exec_prefix = Cetmodules::CMake::Presets::ProjectVariable->new(
          %{$pv_seed},
          name  => 'EXEC_PREFIX',
          value => q($env{CETPKG_FQ_DIR}));
      } ## end else [ if (is_project_variable...)]
      $definitions->{ups}->{ $exec_prefix->init_var } = $exec_prefix;
    } ## end if ($exec_prefix)
    my $ups_product_flavor = Cetmodules::CMake::Presets::ProjectVariable->new(
      %{$pv_seed},
      name  => 'UPS_PRODUCT_FLAVOR',
      value => $exec_prefix ? q($env{CETPKG_FLAVOR}) : 'NULL');
    $definitions->{ups}->{ $ups_product_flavor->init_var } =
      $ups_product_flavor;

    foreach my $name (sort keys %{ $definitions->{compiler} }) {
      if ($name =~
m&\A(?:CMAKE|UPS)_([A-Za-z0-9]+_(?:STANDARD|COMPILER(?:_(?:ID|VERSION))?))\z&msx
        ) {
        my $val = delete $definitions->{compiler}->{$name};
        $definitions->{ups}->{$name} = { type  => $val->{'type'} // 'STRING',
                                         value => "\$env{CETPKG_$1}"
                                       };
      } ## end if ($name =~ ...)
    } ## end foreach my $name (sort keys...)

    if (delete $definitions->{saved}->{'UPS_QUALIFIER_STRING'}) {
      my $ups_qualifier_string =
        Cetmodules::CMake::Presets::ProjectVariable->new(
          %{$pv_seed},
          name  => 'UPS_QUALIFIER_STRING',
          value => q($env{CETPKG_QUALSPEC}));
      $definitions->{ups}->{ $ups_qualifier_string->init_var } =
        $ups_qualifier_string;
    } ## end if (delete $definitions...)
  } else {

    # Put CET_PV_PREFIX back in $definitions.
    exists $definitions->{saved}->{'CET_PV_PREFIX'}
      and $definitions->{misc}->{'CET_PV_PREFIX'} =
      delete $definitions->{saved}->{'CET_PV_PREFIX'};

    # Put everything else in $definitions->{ups}.
    foreach my $key_type qw(saved compiler) {
      foreach my $name (sort keys %{ $definitions->{$key_type} }) {
        my $val = delete $definitions->{$key_type}->{$name};
        my $key = is_project_variable($val) ? $val->init_var : $name;
        $definitions->{ups}->{$key} = $val;
      } ## end foreach my $name (sort keys...)
    } ## end foreach my $key_type qw(saved compiler)
  } ## end else [ if ($options->{sanitize_defs...})]
  return $definitions->{misc}, $definitions->{ups};
} ## end sub _maybe_tweak_defs


sub _process_cmake_args {
  my ($cmake_args, $pv_seed, $options) = @_;
  my $definitions = _extract_definitions($cmake_args, $pv_seed);
  my $ups_definitions =
    { WANT_UPS => { type => 'BOOL', value => JSON::true } };
  my @save_definitions = qw(
    CET_PV_PREFIX
    EXEC_PREFIX
    UPS_PRODUCT_FLAVOR
    UPS_PRODUCT_VERSION
    UPS_QUALIFIER_STRING
    WANT_UPS
  );
  my $saved_definitions    = {};
  my $compiler_definitions = {};

  foreach my $def (keys %{$definitions}) {
    my $name =
      (is_project_variable($definitions->{$def}))
      ? $definitions->{$def}->name
      : $def;

    if (List::Util::any { $name eq $_; } @save_definitions) {
      $saved_definitions->{$name} = delete $definitions->{$def};
    } elsif ($name =~
m&\A(?:CMAKE|UPS)_[A-Za-z0-9]+_(?:STANDARD|COMPILER(?:_(?:ID|VERSION))?)\z&msx
      ) {
      $compiler_definitions->{$name} = delete $definitions->{$def};
    } elsif ($name =~ m&\AUPS_&msx) {
      $ups_definitions->{$def} = delete $definitions->{$def};
    }
  } ## end foreach my $def (keys %{$definitions...})
  return _maybe_tweak_defs(
    {   misc     => $definitions,
        ups      => $ups_definitions,
        saved    => $saved_definitions,
        compiler => $compiler_definitions
    },
    $pv_seed, $options);
} ## end sub _process_cmake_args


sub _read_preset_template {
  my ($source_dir, $json) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $preset_template = List::Util::first { -r; }
  Path::Tiny::path($source_dir, qw(config CMakePresets.json.in)),
    Path::Tiny::path(__FILE__)
    ->parent->child(qw(.. .. .. config ups CMakePresets.json.in))
    or return;
  return $json->decode($preset_template->absolute->slurp_utf8);
} ## end sub _read_preset_template


sub _resolve_cmake_list {
  return join(q(;), _expand_cmake_list(shift));
}


sub _resolve_ref {
  my ($ref_arg, $preset_data, $options) = @_;
  my @refbits   = (ref($ref_arg) eq 'ARRAY') ? @{$ref_arg} : ($ref_arg);
  my $refstring = q({});
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
RESOLVE: while (my $key = shift @refbits) {
    given (ref $preset_data) {
      when ('HASH') {
        if (exists $preset_data->{$key}) {
          $refstring   = join(q(->), $refstring // (), "{$key}");
          $preset_data = $preset_data->{$key};
        } else {
          $preset_data = [values %{$preset_data}];
          redo RESOLVE;
        }
      } ## end when ('HASH')
      when ('ARRAY') {
        if ($key =~ m&\A[[:digit:]+-]+\z&msx) {
          $refstring   = join(q(->), $refstring // (), "[$key]");
          $preset_data = $preset_data->[$key]
            // Cetmodules::CMake::Presets::BadPerlRef->new($refstring);
        } else {
          foreach my $element (@{$preset_data}) {
            if (ref($element) eq 'HASH' and ($element->{name} // q()) eq $key)
            {
              $refstring   = join(q(->), $refstring // (), "[\"$key\"]");
              $preset_data = $element;
              next RESOLVE;
            } elsif (is_project_variable($element) and $element->name eq $key)
            {
              $refstring   = join(q(->), $refstring // (), "<$key>");
              $preset_data = $element;
              next RESOLVE;
            } ## end elsif (is_project_variable... [ if (ref($element) eq 'HASH'...)])
          } ## end foreach my $element (@{$preset_data...})
          $refstring = join(q(->), $refstring // (), "[\"$key\"]");
          $preset_data =
            Cetmodules::CMake::Presets::BadPerlRef->new($refstring);
        } ## end else [ if ($key =~ m&\A[[:digit:]+-]+\z&msx)]
      } ## end when ('ARRAY')
      default {
        $preset_data =
          Cetmodules::CMake::Presets::BadPerlRef->new($refstring);
      }
    } ## end given
    is_bad_reference($preset_data) and last;
  } ## end RESOLVE: while (my $key = shift @refbits)
  return (is_project_variable($preset_data)
      and $options->{resolve_project_variables})
    ? $preset_data = $preset_data->value
    : $preset_data;
} ## end sub _resolve_ref


sub _resolve_special {
  my ($preset_data, $pv_seed) = @_;
  my $json = JSON->new->convert_blessed;
  Cetmodules::CMake::Presets::ProjectVariable->PERL_JSON_ENCODING;
  my $json_data = $json->encode($preset_data);
  Cetmodules::CMake::Presets::ProjectVariable->CMAKE_JSON_ENCODING;
  $json->filter_json_single_key_object(
    "__ref__",
    sub {
      return _resolve_ref(shift, $preset_data,
        { resolve_project_variables => 1 });
    });
  $json->filter_json_single_key_object("__cmake_list__",
    \&_resolve_cmake_list);
  $json->filter_json_single_key_object(
    "__project_variable__",
    sub {
      my $ref = shift;
      return Cetmodules::CMake::Presets::ProjectVariable->new(%{$pv_seed},
        %{$ref});
    });
  $json->filter_json_single_key_object(
    "__variable_list__",
    sub {
      my $list_in = shift;
      return { map { is_project_variable($_) ? ($_->init_var => $_) : $_; }
                 @{$list_in} };
    });
  my $resolved = $json->decode($json_data);
  return $resolved;
} ## end sub _resolve_special

########################################################################
1;
__END__
