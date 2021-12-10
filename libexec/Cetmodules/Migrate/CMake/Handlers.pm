# -*- cperl -*-
package Cetmodules::Migrate::CMake::Handlers;

use 5.016;
use Cwd qw(abs_path chdir getcwd);
use English qw(-no_match_vars);
use File::Basename qw(dirname);
use File::Spec;
use Readonly;
use Storable qw(dclone);
use Cetmodules::Util;
use Cetmodules::CMake;
use Cetmodules::UPS::Setup;
use Cetmodules::Migrate::Tagging;
use strict;
use warnings FATAL => qw(
  Cetmodules
  io
  regexp
  severe
  syntax
  uninitialized
  void
);

use vars qw(@CALL_HANDLERS @EVENT_HANDLERS);

our (@EXPORT_OK, %EXPORT_TAGS);

########################################################################
# Exported variables
########################################################################
Readonly::Array @CALL_HANDLERS => qw(
  add_compile_definitions
  add_compile_options
  add_definitions
  add_dependencies
  add_link_options
  add_subdirectory
  add_test
  art_dictionary
  art_make
  art_make_library
  basic_plugin
  build_dictionary
  build_plugin
  cet_cmake_config
  cet_cmake_env
  cet_find_library
  cet_make
  cet_make_library
  cet_make_executable
  cet_report_compiler_flags
  cmake_minimum_required
  cmake_policy
  endfunction
  endmacro
  find_library
  find_package
  find_ups_product
  function
  include_directories
  link_directories
  link_libraries
  link_options
  macro
  project
  remove_definitions
  set
  simple_plugin
  subdirs
);
Readonly::Array @EVENT_HANDLERS => qw(comment_handler eof_handler);
@EXPORT_OK =
  (@CALL_HANDLERS, @EVENT_HANDLERS, qw(@CALL_HANDLERS @EVENT_HANDLERS));
%EXPORT_TAGS = (
    CALL_HANDLERS  => ['@CALL_HANDLERS',  @CALL_HANDLERS],
    EVENT_HANDLERS => ['@EVENT_HANDLERS', @EVENT_HANDLERS]);
########################################################################
# Private variables
########################################################################
my $_cml_state              = {};
my $_cmake_required_version = _get_cmake_required_version();
my @_cmake_languages = qw(NONE CXX C Fortran CUDA ISPC OBJC OBJCXX ASM);
my $_default_crv     = "3.19";
########################################################################
# Exported functions
########################################################################
sub add_compile_definitions {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub add_compile_definitions


sub add_compile_options {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub add_compile_options


sub add_definitions {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub add_definitions


sub add_dependencies {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub add_dependencies


sub add_link_options {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub add_link_options


sub add_subdirectory {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub add_subdirectory


sub add_test {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub add_test


sub art_dictionary {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub art_dictionary


sub art_make {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub art_make


sub art_make_library {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub art_make_library


sub basic_plugin {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub basic_plugin


sub build_dictionary {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub build_dictionary


sub build_plugin {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub build_plugin


sub cet_cmake_config {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cet_cmake_config


sub cet_cmake_env {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cet_cmake_env


sub cet_find_library {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cet_find_library


sub cet_make {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cet_make


sub cet_make_library {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cet_make_library


sub cet_make_executable {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cet_make_executable


sub cet_report_compiler_flags {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cet_report_compiler_flags


sub cmake_minimum_required {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  my $edit;

  if ($_cml_state->{seen_calls}->{ $call_info->{name} }) {
    debug(<<"EOF");
ignoring duplicate $call_info->{name}() at line $call_info->{start_line} \
previously seen at $_cml_state->{seen_calls}->{$call_info->{name}}->{start_line}
EOF
    return;
  } elsif ($_cml_state->{current_definition}) {
    debug(<<"EOF");
ignoring $call_info->{name} at line $call_info->{start_line} in \
definition of $_cml_state->{current_definition}->{name}()
EOF
    return;
  } #-# End elsif ($_cml_state->{current_definition... [ if ($_cml_state->{seen_calls...})]})
  $_cml_state->{seen_calls}->{ $call_info->{name} } = $call_info;
  debug(<<"EOF");
found top level $call_info->{name}() at line $call_info->{start_line}
EOF

  if (not has_keyword($call_info, 'VERSION')) {
    warning(<<"EOF");
ill-formed $call_info->{name}() at line $call_info->{start_line} (no VERSION) will be corrected
EOF
    append_args($call_info, 'VERSION', $_cmake_required_version);
    $edit = "added missing keyword VERSION";
  } else {
    my ($req_version_idx) =
      find_single_value_for($call_info, qw(VERSION FATAL_ERROR));

    if (not $req_version_idx) {
      warning(<<"EOF");
ill-formed $call_info->{name}() at line $call_info->{start_line} (VERSION keyword missing value) will be corrected
EOF
      insert_args_at($call_info,
          keyword_arg_append_position($call_info, 'VERSION', 'FATAL_ERROR'),
          $_cmake_required_version);
      $edit = "VERSION keyword missing value";
    } else {
      my $req_version = arg_at($call_info, $req_version_idx);
      my ($req_version_int, $is_literal) = interpolated($req_version);

      if (not $is_literal) {
        warning(<<"EOF");
non-literal VERSION argument $req_version_int will not be modified
EOF
        return;
      } #-# End if (not $is_literal)
      my $policy;
      my ($vmin, $vmax) =
        ($req_version_int =~ m&\A(.*?)(?:[.]{3}(.*))?\z&msx);

      if (version_cmp($vmin, $_cmake_required_version) < 0) {
        if (not $vmax) {
          $policy = $vmin;
        } else {
          given (version_cmp($_cmake_required_version, $vmax)) {
            when ($_ == 1) {
              $policy = $vmax; # Preserve behavior of code.
              continue;
            }
            when (not($_ < 0)) {
              undef $vmax;
            }
          } #-# End given
        } ## end else [ if (not $vmax) ]

        if ($policy) {
          my $lineref = tag_added(<<"EOF", "CMake compatibility");
$call_info->{pre_call_ws}\Ecmake_policy(VERSION $policy)
EOF
          push @{$call_infos}, ${$lineref};
        } #-# End if ($policy)
        my $new_req_version =
          join(q(...), $_cmake_required_version, $vmax // ());
        $edit = sprintf("VERSION %s -> $new_req_version",
            arg_at($call_info, $req_version_idx));
        replace_arg_at($call_info, $req_version_idx, $new_req_version);
      } ## end if (version_cmp($vmin,...))
    } ## end else [ if (not $req_version_idx)]
  } ## end else [ if (not has_keyword($call_info...))]
  defined $edit and tag_changed($call_info, $edit || ());

  if (not has_keyword($call_info, 'FATAL_ERROR')) {
    append_args($call_info, 'FATAL_ERROR');
    tag_changed($call_info, "added FATAL_ERROR");
  }
  return;
} ## end sub cmake_minimum_required


sub cmake_policy {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub cmake_policy


sub comment_handler {
  my ($pi, $comments, $cmakelists, $options) = @_;
  return {};
}


sub endfunction {
  my @args = @_;
  _end_call_definition(@args);
  return;
} #-# End sub endfunction


sub endmacro {
  my @args = @_;
  _end_call_definition(@args);
  return;
} #-# End sub endmacro


sub eof_handler {
  my ($cml_data, $line_no, $options) = @_;
  verbose("[SUCCESS] processed $cml_data->{cmakelists} ($line_no lines)");
  undef $_cml_state;
  return;
} #-# End sub eof_handler


sub function {
  my @args = @_;
  _call_definition(@args);
  return;
} #-# End sub function


sub find_library {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub find_library


sub find_package {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  my $package_to_find = interpolated(arg_at($call_info, 0));

  if ($package_to_find =~ m&\A(cet(?:modules|buildtools))\z&msx
      and (
        exists $_cml_state->{project_info}
        or (  exists $_cml_state->{seen_calls}
          and exists $_cml_state->{seen_calls}->{ $call_info->{name} }
          and scalar
          keys $_cml_state->{seen_calls}->{ $call_info->{name} }->{cetmodules}
        ))
    ) {
    info(<<"EOF");
removing late, redundant $call_info->{name}($1) at line $call_info->{start_line}
EOF
    pop(@{$call_infos});
    return;
  } #-# End if ($package_to_find =~...)

  if ($package_to_find eq 'cetbuildtools') {
    tag_changed($call_info, "$package_to_find -> cetmodules");
    $package_to_find = 'cetmodules';
    replace_arg_at($call_info, 0, $package_to_find);
  } #-# End if ($package_to_find eq...)
  $_cml_state->{seen_calls}->{ $call_info->{name} }->{$package_to_find}
    ->{ $call_info->{start_line} } = $call_info;
  my @removed_keywords = map {
      remove_keyword($call_info, $_, _find_package_keywords(qw(all))) // ();
  } qw(BUILD_ONLY PRIVATE);

  if (my @obsolete_keywords = map {
        remove_keyword($call_info, $_, _find_package_keywords(qw(all))) // ();
      } qw(INTERFACE PUBLIC)
    ) {

    if (defined find_keyword($call_info, 'EXPORT')) {
      push @removed_keywords, @obsolete_keywords;
    } else {
      append_args($call_info, 'EXPORT');
      tag_changed(
          $call_info,
          sprintf(
            "replaced obsolete keyword%s with EXPORT: %s",
            ($#obsolete_keywords) ? 's' : q(),
            join(q( ), @obsolete_keywords)));
    } #-# End else [ if (defined find_keyword...)]
  } #-# End if (my @obsolete_keywords...)
  scalar @removed_keywords
    and tag_changed(
      $call_info,
      sprintf(
        "removed obsolete keyword%s: %s",
        ($#removed_keywords) ? 's' : q(),
        join(q( ), @removed_keywords)));
  return;
} #-# End sub find_package


sub find_ups_product {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub find_ups_product


sub include_directories {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub include_directories


sub link_directories {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub link_directories


sub link_libraries {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub link_libraries


sub link_options {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub link_options


sub macro {
  my @args = @_;
  _call_definition(@args);
  return;
} #-# End sub macro


sub project {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ($_cml_state->{seen_calls}->{ $call_info->{name} }) {
    info(<<"EOF");
ignoring subsequent $call_info->{name}() at line $call_info->{start_line} \
previously seen at $_cml_state->{seen_calls}->{$call_info->{name}}->{start_line}
EOF
    return;
  } #-# End if ($_cml_state->{seen_calls...})
  $_cml_state->{seen_calls}->{ $call_info->{name} } = $call_info;
  $_cml_state->{project_info}                       = my $project_info = {};
  $project_info->{first_pass}                       = my $cpi =
    get_cmake_project_info(dirname($cmakelists, $options),
      quiet_warnings => 1);
  $project_info->{name} = $cpi->{cmake_project_name};
  my $n_args = scalar @{ $call_info->{arg_indexes} };
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ( # Identify old-style project() call.
      $n_args > 1 and List::MoreUtils::all {
        my $arg = interpolated($call_info, $_);
        List::MoreUtils::any { $arg eq $_; } @_cmake_languages;
      }
      1 .. ($n_args - 1)
    ) {
    # Old-style call with only name and languages (no keywords).
    add_args_after($call_info, 0, 'LANGUAGES');
  } ## end if (  $n_args > 1 and ...)

  if ($cpi->{CMAKE_PROJECT_VERSION_STRING}) {

    # VERSION defined by
    # set($project_info->{cmake_project_name}_CMAKE_PROJECT_VERSION_STRING
    # ...)
    my $vsinfo = parse_version_string($cpi->{CMAKE_PROJECT_VERSION_STRING});

    if ($vsinfo->{extra}) { # non-alphanumeric component(s)
      defined $cpi->{cmake_project_version} and info(<<"EOF");
project($project_info->{name} VERSION $cpi->{cmake_project_version} ...) overridden by \${$project_info->{name}_CMAKE_PROJECT_VERSION_STRING} ($cpi->{CMAKE_PROJECT_VERSION_STRING}: removing VERSION in project()
EOF

      # Delete any VERSIONs from project() to avoid confusion.
      remove_keyword($call_info, 'VERSION', @PROJECT_KEYWORDS);
      $project_info->{cmake_project_version} =
        $cpi->{CMAKE_PROJECT_VERSION_STRING};
      $project_info->{cmake_project_version_info} = $vsinfo;
      tag_changed($call_info,
          "VERSION -> set(CMAKE_PROJECT_VERSION_STRING ...)");

      if (my $vs_call_info =
          $_cml_state->{seen_calls}->{'set'}->{CMAKE_PROJECT_VERSION_STRING})
      {
        # This was seen too early and removed: reinstate it here with
        # the correct indentation.
        $vs_call_info = dclone($vs_call_info->[0]);

        if ($call_info->{pre_call_ws}) {
          $vs_call_info->{pre_call_ws} = $call_info->{pre_call_ws};
        } else {
          delete $vs_call_info->{pre_call_ws};
        }
        tag_changed($vs_call_info,
            "moved from line $vs_call_info->{start_line}");
        push @{$call_infos}, $vs_call_info;
      } ## end if (my $vs_call_info =...)
    } else {
      $project_info->{redundant_version_string} = 1;

      if (defined $cpi->{cmake_project_version}
          and version_cmp($cpi->{cmake_project_version_info}, $vsinfo) != 0) {
        info(<<"EOF");
project($project_info->{name} VERSION $cpi->{cmake_project_version} ...) overridden by \${$project_info->{name}_CMAKE_PROJECT_VERSION_STRING} ($cpi->{CMAKE_PROJECT_VERSION_STRING}: updating project($project_info->{name} VERSION ...)
EOF

        # Delete any VERSIONs from project() to avoid confusion.
        remove_keyword($call_info, 'VERSION', @PROJECT_KEYWORDS);
        add_args_after($call_info, 0, 'VERSION',
            $cpi->{CMAKE_PROJECT_VERSION_STRING});
        tag_changed($call_info,
            "VERSION -> set(CMAKE_PROJECT_VERSION_STRING ...)");
      } ## end if (defined $cpi->{cmake_project_version...})
    } ## end else [ if ($vsinfo->{extra}) ]
  } elsif (defined $cpi->{cmake_project_version} and defined $pi->{version})
  { # we override product_deps
    warning(<<"EOF");
UPS product version $pi->{version} overridden by project($project_info->{name} ... VERSION $cpi->{cmake_project_version} ...) at $cmakelists:$call_info->{start_line}
EOF
  } elsif (not defined $cpi->{cmake_project_version}
      and defined $pi->{version}) { # Take version from product_deps
    $project_info->{cmake_project_version_info} = my $vinfo =
      parse_version_string($pi->{version});
    $project_info->{cmake_project_version} =
      to_cmake_version($project_info->{cmake_project_version_info});

    if ($vinfo->{extra}) {          # need to use version string
      my $lineref = tag_added(<<"EOF", "extended version semantics");
$call_info->{pre_call_ws}\Eset($project_info->{cmake_project_name} $project_info->{cmake_project_version})
EOF
      push @{$call_infos}, ${$lineref};

      # Remove any empty VERSION keywords.
      remove_keyword($call_info, 'VERSION', @PROJECT_KEYWORDS);
    } else {
      remove_keyword($call_info, 'VERSION', @PROJECT_KEYWORDS);
      add_args_after($call_info, 0, 'VERSION',
          $cpi->{CMAKE_PROJECT_VERSION_STRING});
      tag_changed($call_info, "set(CMAKE_PROJECT_VERSION_STRING) -> VERSION");
    } #-# End else [ if ($vinfo->{extra}) ]
  } ## end elsif (not defined $cpi->...)
  return;
} ## end sub project


sub remove_definitions {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub remove_definitions
my @_HANDLED_SET_VARS = qw(CMAKE_PROJECT_VERSION_STRING
);


sub set { ## no critic qw(NamingConventions::ProhibitAmbiguousNames)
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  my ($set_var_name, $is_literal) = interpolated($call_info, 0) // return;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ($set_var_name = List::MoreUtils::first_value {
        $set_var_name =~ m&(?:\A|_)\Q$_\E\z&msx;
      }
      @_HANDLED_SET_VARS
    ) {
    # We have a match and (hopefully) a handler therefor.
    push @{ $_cml_state->{seen_calls}->{'set'}->{$set_var_name} }, $call_info;
    local $EVAL_ERROR; ## no critic qw(RequireInitializationForLocalVars)
    my $func_name = "Cetmodules::Migrate::CMake::Handlers\::_$set_var_name";
    my $func_ref  = \&{$func_name};
    eval {
        &{$func_ref}($pi, $call_infos, $call_info, $cmakelists, $options);
    } or 1;
    $EVAL_ERROR and error_exit(<<"EOF");
error calling SET handler for matched variable $set_var_name at $cmakelists:$call_info->{start_line}:
$EVAL_ERROR
EOF
  } ## end if ($set_var_name = List::MoreUtils::first_value...)
  return;
} ## end sub set


sub simple_plugin {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub simple_plugin


sub subdirs {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} #-# End sub subdirs
########################################################################
# Private functions
########################################################################
sub _call_definition {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  my $name = interpolated($call_info, 0);
  my $type = $call_info->{name};

  if (exists $_cml_state->{current_definition}) {
    my $cd_info = $_cml_state->{current_definition};
    error(<<"EOF");
found nested definition of $type $name at line $call_info->{start_line}:
already in definition of $cd_info->{type} $cd_info->{name} since line $cd_info->{start_line}
EOF
  } else {
    debug("found definition of $type $name at line $call_info->{start_line}");
    $_cml_state->{current_definition} =
      { %{$call_info}, name => $name, type => $type };
  } #-# End else [ if (exists $_cml_state...)]
  return;
} ## end sub _call_definition


sub _end_call_definition {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  my ($type) = ($call_info->{name} =~ m&\Aend(.*)\z&msx);
  my $cd_info = $_cml_state->{current_definition} // undef;

  if (not defined $cd_info) {
    error(<<"EOF");
found $call_info->{name}\(\) while not in $type definition
EOF
  } elsif ($type ne $cd_info->{type}) {
    error(<<"EOF");
found $call_info->{name}() at line $call_info->{start_line} in definition of $cd_info->{type} $cd_info->{name}\(\) definition
EOF
  } else {
    debug(<<"EOF");
found $call_info->{name}() at line $call_info->{start_line} matching $cd_info->{type}($cd_info->{name}) at line $call_info->{start_line}
EOF
  } #-# End else [ if (not defined $cd_info) [elsif ($type ne $cd_info->...)]]
  return;
} ## end sub _end_call_definition
my @_cmake_fp_kw;
my @_cet_fp_kw =
  qw(BUILD_ONLY EXPORT INTERFACE NOP OPTIONAL PROJECT PUBLIC PRIVATE REQUIRED_BY);


sub _find_package_keywords {
  my @args = @_;
  @args or @args = qw(cmake);
  my $types = { map { lc $_ => 1; } @args };
  my $result;

  if ($types->{cmake} or $types->{all}) {
    if (not defined @_cmake_fp_kw) {
      my $kw_in   = {};
      my $kw_pipe = IO::File->new(<<'EOF')
cmake --help-command find_package | sed -E -n -e '/((Basic|Full) Signature( and Module Mode)?|signature is)$/,/\)$/ { s&^[[:space:]]+&&g; s&[[:space:]|]+&\n&g; s&[^A-Z_\n]&\n&g; /^[A-Z_]{2,}(\n|$)/ ! D; P; D }' |
EOF
        or error_exit(
"unable to obtain current list of accepted keywords to find_package() from CMake, \"$OS_ERROR\""
        );

      while (<$kw_pipe>) {
        chomp;
        my @kw = split;
        @kw and @{$kw_in}{@kw} = (1) x scalar @kw;
      } #-# End while (<$kw_pipe>)
      @_cmake_fp_kw = sort keys %{$kw_in};
    } #-# End if (not defined @_cmake_fp_kw)
    @{$result}{@_cmake_fp_kw} = (1) x scalar @_cmake_fp_kw;
  } #-# End if ($types->{cmake} or...)

  if ($types->{cet} or $types->{all}) {
    @{$result}{@_cet_fp_kw} = (1) x scalar @_cet_fp_kw;
  }
  my @result = sort keys %{$result};
  return @result;
} #-# End sub _find_package_keywords


sub _get_cmake_required_version {
  ## no critic qw(InputOutput::ProhibitBacktickOperators)
  my $result = $_default_crv;
  my $crv_file =
    abs_path(File::Spec->catfile(
      dirname(__FILE__), qw(.. .. .. .. etc),
      'cmake_required_version.txt'));

  if (my $crv_fh = IO::File->new("$crv_file", "<")) {
    while (<$crv_fh>) {
      m&\A\s*([0-9.]+)[\s#]*&msx or next;
      $result = $1;
      last;
    } #-# End while (<$crv_fh>)
  } #-# End if (my $crv_fh = IO::File...)
  return $result;
} ## end sub _read_cmake_required_version
########################################################################
# _set_X
#
# Private callback routines invoked by set()
#
########################################################################
## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
sub _set_CMAKE_PROJECT_VERSION_STRING {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;

  if (not $_cml_state->{seen_calls}->{'project'}) { # Too early.
    warning(<<"EOF");
Project variable CMAKE_PROJECT_VERSION_STRING set at $cmakelists:$call_info->{start_line} must follow project() and precede cet_cmake_env() - relocating.
EOF
  } elsif (not $_cml_state->{project_info}->{redundant_version_string}) {
    return;
  }

  # Don't need this call.
  pop @{$call_infos};
  return;
} ## end sub _set_CMAKE_PROJECT_VERSION_STRING
## use critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
########################################################################
1;
