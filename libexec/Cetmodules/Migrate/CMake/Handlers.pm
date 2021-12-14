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
use Cetmodules::UPS::Setup qw(:DEFAULT $PATH_VAR_TRANSLATION_TABLE);
use Cetmodules::Migrate::CMake::Tagging;
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

use vars qw(@COMMAND_HANDLERS @EVENT_HANDLERS);

our (@EXPORT_OK, %EXPORT_TAGS);

my @_CMAKE_SCRIPTING_COMMAND_HANDLERS = qw(
  -break
  -cmake_host_system_information
  -cmake_language
  cmake_minimum_required
  -cmake_parse_arguments
  -cmake_path
  -cmake_policy
  -configure_file
  -continue
  -else
  -elseif
  -endforeach
  endfunction
  -endif
  endmacro
  -endwhile
  -execute_process
  -file
  -find_file
  find_library
  find_package
  -find_path
  -find_program
  -foreach
  function
  -get_cmake_property
  -get_directory_property
  -get_filename_component
  -get_property
  -if
  -include
  -include_guard
  -list
  macro
  -mark_as_advanced
  -math
  -message
  -option
  -return
  -separate_arguments
  set
  -set_directory_properties
  -set_property
  -site_name
  -string
  -unset
  -variable_watch
  -while
);
my @_CMAKE_PROJECT_COMMAND_HANDLERS = qw(
  add_compile_definitions
  add_compile_options
  -add_custom_command
  -add_custom_target
  add_definitions
  -add_dependencies
  add_executable
  add_library
  add_link_options
  add_subdirectory
  add_test
  -aux_source_directory
  -build_command
  -create_test_sourcelist
  -define_property
  -enable_language
  -enable_testing
  -export
  -fltk_wrap_ui
  -get_source_file_property
  -get_target_property
  -get_test_property
  include_directories
  -include_external_msproject
  -include_regular_expression
  -install
  link_directories
  link_libraries
  -load_cache
  project
  remove_definitions
  -set_source_files_properties
  -set_target_properties
  -set_tests_properties
  -source_group
  -target_compile_definitions
  -target_compile_features
  -target_compile_options
  -target_include_directories
  -target_link_directories
  -target_link_libraries
  -target_link_options
  -target_precompile_headers
  -target_sources
  -try_compile
  -try_run
);
my @_CMAKE_CTEST_COMMAND_HANDLERS = qw(
  -ctest_build
  -ctest_configure
  -ctest_coverage
  -ctest_empty_binary_directory
  -ctest_memcheck
  -ctest_read_custom_files
  -ctest_run_script
  -ctest_sleep
  -ctest_start
  -ctest_submit
  -ctest_test
  -ctest_update
  -ctest_upload
);
my @_CMAKE_DEPRECATED_COMMAND_HANDLERS = qw(
  -build_name
  -exec_program
  -export_library_dependencies
  -install_files
  -install_programs
  -install_targets
  -load_command
  -make_directory
  -output_required_files
  -qt_wrap_cpp
  -qt_wrap_ui
  -remove
  -subdir_depends
  subdirs
  -use_mangled_mesa
  -utility_source
  -variable_requires
  -write_file
);

# This list made with:
#
#   ack --cmake -h -i '^\s*(?:function|macro)\(\s*+[^_$]' | \
#     sed -Ene 's&^[[:space:]]*(function|macro)\(([^[:space:])]+).*$&\2&ip' | \
#     sort -u
my @_CET_COMMAND_HANDLERS = qw(
  -ParseAndAddCatchTests
  -ParseFile
  -PrintDebugMessage
  -RemoveComments
  -art::module
  -art::plugin
  -art::service
  -art::source
  -art::tool
  -art_dictionary
  art_make
  art_make_exec
  -art_make_library
  basic_plugin
  -build_dictionary
  build_plugin
  -cet_add_compiler_flags
  -cet_add_to_library_list
  -cet_armor_string
  -cet_build_plugin
  -cet_checkpoint_cmp
  -cet_checkpoint_did
  cet_cmake_config
  -cet_cmake_env
  -cet_cmake_module_directories
  -cet_collect_plugin_builders
  -cet_compare_versions
  -cet_convert_target_args
  -cet_disable_asserts
  -cet_enable_asserts
  -cet_exclude_files_from
  -cet_export_alias
  cet_find_library
  cet_find_package
  cet_find_pkg_config_package
  cet_find_simple_package
  -cet_generate_sphinxdocs
  -cet_get_pv_property
  -cet_have_qual
  -cet_installed_path
  -cet_lib_alias
  -cet_localize_pv
  -cet_localize_pv_all
  cet_make
  -cet_make_completions
  -cet_make_exec
  -cet_make_library
  -cet_make_plugin_builder
  -cet_maybe_disable_asserts
  -cet_package_path
  cet_parse_args
  -cet_passthrough
  -cet_process_cmp
  -cet_process_did
  -cet_process_liblist
  -cet_query_system
  -cet_regex_escape
  -cet_register_export_set
  cet_remove_compiler_flags
  cet_report_compiler_flags
  -cet_rootcint
  -cet_script
  -cet_set_compiler_flags
  -cet_set_pv_property
  -cet_source_file_extensions
  -cet_test
  -cet_test_assertion
  -cet_test_env
  -cet_timestamp
  -cet_version_cmp
  -cet_without_deprecation_warnings
  -cet_write_plugin_builder
  -check_class_version
  -check_prod_version
  -check_ups_version
  -filter_and_compare
  -find_package
  find_tbb_offloads
  find_ups_boost
  find_ups_geant4
  find_ups_product
  find_ups_root
  -generate_from_fragments
  -include
  -install_fhicl
  -install_fw
  -install_gdml
  -install_headers
  -install_license
  -install_perllib
  -install_pkgmeta
  -install_python
  -install_scripts
  -install_source
  -install_wp
  -make_simple_builder
  -parse_ups_version
  -process_smc
  -process_ups_files
  -product_to_project
  -project_variable
  -pvs_test
  -set_dot_version
  -set_install_root
  -set_version_from_ups
  simple_plugin
  tbb_offload
  -to_cmake_version
  -to_dot_version
  -to_ups_version
  -to_version_string
  -warn_deprecated
);

########################################################################
# Exported variables
########################################################################
Readonly::Array
  @COMMAND_HANDLERS => grep { not m&\A-&msx; }
  @_CMAKE_SCRIPTING_COMMAND_HANDLERS,
  @_CMAKE_PROJECT_COMMAND_HANDLERS,    @_CMAKE_CTEST_COMMAND_HANDLERS,
  @_CMAKE_DEPRECATED_COMMAND_HANDLERS, @_CET_COMMAND_HANDLERS;
Readonly::Array @EVENT_HANDLERS =>
  qw(comment_handler eof_handler arg_handler);
@EXPORT_OK = (@COMMAND_HANDLERS, @EVENT_HANDLERS,
              qw(@COMMAND_HANDLERS @EVENT_HANDLERS));
%EXPORT_TAGS = (
    COMMAND_HANDLERS => ['@COMMAND_HANDLERS', @COMMAND_HANDLERS],
    EVENT_HANDLERS   => ['@EVENT_HANDLERS',   @EVENT_HANDLERS]);

########################################################################
# Private variables
########################################################################
my $_cml_state              = {};
my $_cmake_required_version = _get_cmake_required_version();
my @_cmake_languages = qw(NONE CXX C Fortran CUDA ISPC OBJC OBJCXX ASM);
my $_default_crv     = "3.19";
Readonly::Scalar my $_LAST_ELEM_IDX => -1;

########################################################################
# Exported functions
########################################################################
sub add_compile_definitions {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions: use target_compile_definitions() or target_compile_features() whenever possible
EOF
  return;
} ## end sub add_compile_definitions


sub add_compile_options {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions: use target_compile_options() or target_compile_features() whenever possible
EOF
  return;
} ## end sub add_compile_options


sub add_definitions {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions: use target_compile_definitions() or target_compile_features() whenever possible
EOF
  return;
} ## end sub add_definitions


sub add_executable {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
use cet_make_exec() for compactness and flexibility
EOF
  return;
} ## end sub add_executable


sub add_library {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
use cet_make_library() or cet_build_plugin() for compactness and flexibility
EOF
  return;
} ## end sub add_library


sub add_link_options {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions: use target_link_options() whenever possible
EOF
  return;
} ## end sub add_link_options


sub add_subdirectory {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;

  if (interpolated(arg_at($call_info, 0)) eq 'ups') {
    report_removed($options->{cmakelists_short} // $cmakelists,
        " (obsolete)", pop @{$call_infos});
  }
  return;
} ## end sub add_subdirectory


sub add_test {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
use cet_test() for flexibility and default test labels
EOF
  return;
} ## end sub add_test

# Lookup table used by arg_handler().
my $_UPS_var_translation_table =
  { version =>
      { new => 'UPS_PRODUCT_VERSION', 'flag' => \&_flag_remove_UPS_vars },
    UPSFLAVOR =>
      { new => 'UPS_PRODUCT_FLAVOR', 'flag' => \&_flag_remove_UPS_vars },
    flavorqual     => { new => 'EXEC_PREFIX' },
    full_qualifier =>
      { new => 'UPS_QUALIFIER_STRING', 'flag' => \&_flag_remove_UPS_vars },
    %{$PATH_VAR_TRANSLATION_TABLE} };
##
sub arg_handler {
  my ($call_info, $cmakelists, $options) = @_;
  my @arg_idx_idx = all_idx_idx($call_info) or return;

  # Flag uses of CMAKE_INSTALL_PREFIX.
  List::MoreUtils::any {
    arg_at($call_info, $_) =~ m&\$\{CMAKE_INSTALL_PREFIX\}&msx;
  }
  @arg_idx_idx and flag_recommended($call_info, <<"EOF");
avoid CMAKE_INSTALL_PREFIX: not necesssary for install()-like commands
EOF

  # Flag uses of CMAKE_MODULE_PATH.
  my $found_CMP = List::Util::first {
    interpolated(arg_at($call_info, $_)) eq 'CMAKE_MODULE_PATH';
  }
  @arg_idx_idx;

  if (defined $found_CMP) {
    if (List::MoreUtils::any {
          arg_at($call_info, $_) =~ m&\$\{.*?_(SOURCE|BINARY)_DIR\}&smx;
        }
        @arg_idx_idx[$found_CMP .. $_LAST_ELEM_IDX]
      ) {
      flag_required($call_info, <<"EOF");
declare exportable CMake module directories with cet_cmake_module_directories()
EOF
    } else {
      flag_recommended($call_info, <<"EOF");
use find_package() to find external CMake modules
EOF
    } ## end else [ if (List::MoreUtils::any...)]
  } ## end if (defined $found_CMP)

  # Remove problematic and unnecessary install path fragments.
  grep {
      if (my @separated = arg_at($call_info, $_)) {
        $separated[(scalar @separated > 1) ? 1 : 0] =~
        s&\$\{product\}/+\$\{version\}/*&&gmsx
        and replace_arg_at($call_info, $_, join(q(), @separated));
    } else {
        0;
      }
  } @arg_idx_idx and tag_changed($call_info, <<'EOF');
${product}/+${version}/* -> ""
EOF

  # Migrate old UPS-style variables.
  foreach my $arg_idx (@arg_idx_idx) {
    my $flagged;
    my @separated = arg_at($call_info, $arg_idx) or next;
    my $argref    = \$separated[(scalar @separated > 1) ? 1 : 0];

    foreach my $var (keys %{$_UPS_var_translation_table}) {
      if (${$argref} =~ m&(?<translate>\$\{\Q$var\E\})&msx) {
        my $old = $LAST_PAREN_MATCH{translate};

        if (defined(my $new = $_UPS_var_translation_table->{$var}->{new})) {
          ${$argref} =~
            s&\Q$old\E&\${\${CETMODULES_CURRENT_PROJECT_NAME}_$new}&gmsx
            and replace_arg_at($call_info, $arg_idx, join(q(), @separated))
            and tag_changed($call_info,
              "$old -> \${CETMODULES_CURRENT_PROJECT_NAME}_$new");
        } ## end if (defined(my $new = ...))

        if (exists $_UPS_var_translation_table->{$var}->{'flag'}) {
          &{ $_UPS_var_translation_table->{$var}->{'flag'} }($call_info);
          $flagged = 1;
        }
      } ## end if (${$argref} =~ m&(?<translate>\$\{\Q$var\E\})&msx)
    } ## end foreach my $var (keys %{$_UPS_var_translation_table...})
  } ## end foreach my $arg_idx (@arg_idx_idx)
  return;
} ## end sub arg_handler


sub art_make {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
deprecated: use art_make_library(), art_dictonary(), and cet_build_plugin() with explicit source lists and plugin base types
EOF
  return;
} ## end sub art_make


sub art_make_exec {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  replace_call_with($call_info, 'cet_make_exec');
  tag_changed($call_info, <<"EOF");
art_make_exec() -> cet_make_exec()
EOF
  return;
} ## end sub art_make_exec


sub basic_plugin {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
use cet_build_plugin() with explicit plugin base types whenever possible
EOF
  return;
} ## end sub basic_plugin


sub build_plugin {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
deprecated: use cet_build_plugin() with explicit plugin base types
EOF
  return;
} ## end sub build_plugin


sub cet_cmake_config {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  report_removed($options->{cmakelists_short} // $cmakelists,
      " (called automatically)",
      pop @{$call_infos});
  return;
} ## end sub cet_cmake_config


sub cet_find_library {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<'EOF');
use find_package() with custom Find<pkg>.cmake
EOF
  return;
} ## end sub cet_find_library


sub cet_make {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
deprecated: use cet_make_library(), build_dictonary(), cet_plugin() with explicit source lists and plugin base types
EOF
  return;
} ## end sub cet_make


sub cet_parse_args {
  goto &_handler_placeholder; # Delegate to placeholder.
}


sub cet_remove_compiler_flags {
  goto &_handler_placeholder; # Delegate to placeholder.
}


sub cet_report_compiler_flags {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  scalar @{ $call_info->{arg_indexes} }
    or flag_recommended($call_info, "report on VERBOSE only");
  return;
} ## end sub cet_report_compiler_flags


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
  } ## end elsif ($_cml_state->{current_definition... [ if ($_cml_state->{seen_calls...})]})
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
      } ## end if (not $is_literal)
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
          } ## end given
        } ## end else [ if (not $vmax) ]

        if ($policy) {
          my $lineref = tag_added(<<"EOF", "CMake compatibility");
$call_info->{pre_call_ws}\Ecmake_policy(VERSION $policy)
EOF
          push @{$call_infos}, ${$lineref};
        } ## end if ($policy)
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


sub comment_handler {
  my ($pi, $comments, $cmakelists, $options) = @_;
  return;
}


sub endfunction {
  goto &_end_call_definition; # Delegate.
}


sub endmacro {
  goto &_end_call_definition; # Delegate.
}


sub eof_handler {
  my ($cml_data, $line_no, $options) = @_;
  verbose("[SUCCESS] processed $cml_data->{cmakelists} ($line_no lines)");
  undef $_cml_state;
  return;
} ## end sub eof_handler


sub function {
  goto &_call_definition; # Delegate.
}


sub find_library {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  if (has_keyword($call_info, 'ENV')
      or List::MoreUtils::any { arg_at($call_info, $_) =~ m&\$ENV\{&msx; }
      all_idx_idx($call_info)
    ) {
    flag_recommended($call_info, <<'EOF');
use find_package() with custom Find<pkg>.cmake or cet_find_library() with ENV <x> instead of $ENV{<x>}
EOF
  } else {
    flag_recommended($call_info, <<'EOF');
use find_package() with custom Find<pkg>.cmake
EOF
  } ## end else [ if (has_keyword($call_info...))]
  return;
} ## end sub find_library


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
  } ## end if ($package_to_find =~...)

  if ($package_to_find eq 'cetbuildtools') {
    tag_changed($call_info, "$package_to_find -> cetmodules");
    $package_to_find = 'cetmodules';
    replace_arg_at($call_info, 0, $package_to_find);
  } ## end if ($package_to_find eq...)
  $_cml_state->{seen_calls}->{ $call_info->{name} }->{$package_to_find}
    ->{ $call_info->{start_line} } = $call_info;
  my @removed_keywords = map {
      remove_keyword($call_info, $_, _find_package_keywords()) // ();
  } qw(BUILD_ONLY PRIVATE);

  if (my @obsolete_keywords = map {
        remove_keyword($call_info, $_, _find_package_keywords()) // ();
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
    } ## end else [ if (defined find_keyword...)]
  } ## end if (my @obsolete_keywords...)
  scalar @removed_keywords
    and tag_changed(
      $call_info,
      sprintf(
        "removed obsolete keyword%s: %s",
        ($#removed_keywords) ? 's' : q(),
        join(q( ), @removed_keywords)));
  return;
} ## end sub find_package


sub find_tbb_offloads {
  goto &_handler_placeholder; # Delegate to placeholder.
}


sub find_ups_boost {
  goto &find_ups_product;     # Delegate.
}


sub find_ups_geant4 { ## no critic qw(Bangs::ProhibitNumberedNames)
  goto &find_ups_product; # Delegate.
}


sub find_ups_product {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $old_call = $call_info->{name};
  my ($product_to_find, $package_to_find, $had_project_kw);

  # Handle OPTIONAL keyword.
  my $add_required = not remove_keyword($call_info, "OPTIONAL");

  # Rename the function.
  replace_call_with($call_info, 'find_package');

  # Behavior specific to the function we're replacing.
  given ($old_call) {
    when ('find_ups_product') {
      $product_to_find = interpolated(arg_at($call_info, 0));

      # Determine package name for product and replace args.
      $had_project_kw =
        remove_keyword($call_info, "PROJECT", _find_package_keywords());
      $package_to_find = single_value_for($call_info, 'PROJECT', 1)
        // _product_to_package($product_to_find);

      if ($package_to_find ne $product_to_find) {
        replace_arg_at($call_info, 0, $package_to_find);
      }
    } ## end when ('find_ups_product')
    when (m&\Afind_ups_(?P<product>boost|geant4|root)\z&msx) {
      $package_to_find = _product_to_package($LAST_PAREN_MATCH{product});
      prepend_args($call_info, $package_to_find);
    }
    default { # Unknown call delegated to us.
      error_exit(<<"EOF");
unrecognized find_ups_X() call $old_call at $cmakelists:$call_info->{start_line}
EOF
    } ## end default
  } ## end given

  # Translate minimum version requirement if necessary.
  my $minv = interpolated(arg_at($call_info, 1));
  is_ups_version($minv) or undef $minv;

  # Remove arguments to find_ups_boost() not already handled.
  if (not defined $product_to_find and $package_to_find eq 'Boost') {
    remove_args_at($call_info,
        ((defined $minv) ? 2 : 1) .. $#{ $call_info->{arg_indexes} });
  }
  $add_required
    and not has_keyword($call_info, 'REQUIRED')
    and append_args($call_info, "REQUIRED");

  ####################################
  # Compose and add the annotation.
  my @old_bits = (
      (defined $minv) ? $minv                         : (),
      $had_project_kw ? ('PROJECT', $package_to_find) : (),
      $add_required   ? ()                            : qw(OPTIONAL)
  );
  defined $product_to_find
    and (scalar @old_bits
      or $add_required
      or $package_to_find ne $product_to_find)
    and unshift @old_bits, $product_to_find;
  my @new_bits = ($add_required) ? qw(REQUIRED) : ();

  # Handling of $minv delayed to when we no longer need the UPS version.
  if (defined $minv) {
    $minv = to_dot_version($minv);
    replace_arg_at($call_info, 1, $minv);
    unshift @new_bits, $minv;
  } ## end if (defined $minv)
  scalar @old_bits and unshift @new_bits, $package_to_find;
  push @old_bits, q(...);
  push @new_bits, q(...);
  tag_changed(
      $call_info,
      sprintf(
        "find_ups_product(%s) -> find_package(%s)",
        join(q( ), @old_bits),
        join(q( ), @new_bits)));
  ##
  ####################################
  return find_package($pi, $call_infos, $call_info, $cmakelists, $options);
} ## end sub find_ups_product


sub find_ups_root {
  goto &find_ups_product; # Delegate.
}


sub include_directories {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions: use target_link_libraries() with target semantics or target_include_directories() whenever possible
EOF
  return;
} ## end sub include_directories


sub link_directories {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions: use target_link_libraries() with target semantics or target_link_directories() whenever possible
EOF
  return;
} ## end sub link_directories


sub link_libraries {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions: use target_link_libraries() whenever possible
EOF
  return;
} ## end sub link_libraries


sub macro {
  goto &_call_definition; # Delegate.
}


sub project { ## no critic qw(Subroutines::ProhibitExcessComplexity)
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ($_cml_state->{seen_calls}->{ $call_info->{name} }) {
    info(<<"EOF");
ignoring subsequent $call_info->{name}() at line $call_info->{start_line} \
previously seen at $_cml_state->{seen_calls}->{$call_info->{name}}->{start_line}
EOF
    return;
  } elsif (not(
      exists $_cml_state->{seen_calls}->{'find_package'}
      and $_cml_state->{seen_calls}->{'find_package'}->{cetmodules})) {
    unshift @{$call_infos},
      ${tag_added(
          sprintf("%sfind_package(cetmodules REQUIRED)\n",
            $call_info->{pre_call_ws} // q()),
          "find_package(cetmodules) must precede project()") };
  } ## end elsif (not(exists $_cml_state... [ if ($_cml_state->{seen_calls...})]))
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
    } ## end else [ if ($vinfo->{extra}) ]
  } ## end elsif (not defined $cpi->... [ if ($cpi->{CMAKE_PROJECT_VERSION_STRING...})])
  return;
} ## end sub project


sub remove_definitions {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_recommended($call_info, <<"EOF");
avoid directory-scope functions whenever possible
EOF
  return;
} ## end sub remove_definitions

####################################
# Private constants used by set()
####################################
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
  flag_recommended($call_info, <<"EOF");
deprecated: use cet_build_plugin() with explicit source lists and plugin base types
EOF
  return;
} ## end sub simple_plugin


sub subdirs {
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  report_removed($options->{cmakelists_short} // $cmakelists,
      " (obsolete)", pop @{$call_infos});
  scalar @{ $call_info->{arg_indexes} } or return;
  my $mode               = q();
  my @preordered_subdirs = ();
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
arg: foreach my $arg_idx (all_idx_idx($call_info)) {
    my $arg = arg_at($call_info, $arg_idx);
    given (interpolated($arg)) {
      when ('ups') { # Drop.
        info(sprintf(<<"EOF", arg_location($call_info, $arg_idx)));
subdirs(...) -> add_subdirectory(ups) omitted (no longer required)
at $cmakelists:%s
EOF
        next arg;
      } ## end when ('ups')
      when ($_ eq 'EXCLUDE_FROM_ALL' or $_ eq 'PREORDER') {

        # Keywords.
        $mode = $_;
        next arg;
      } ## end when ($_ eq 'EXCLUDE_FROM_ALL'...)
      default { } # Treat as normal.
    } ## end given
    my $new_call =
      sprintf("$call_info->{pre_call_ws}add_subdirectory($arg%s)\n",
        ($mode eq 'EXCLUDE_FROM_ALL') ? " $mode" : q());
    tag_changed(\$new_call, "subdirs(...) -> add_subdirectory(...)");

    if ($mode eq 'PREORDER') {
      push @preordered_subdirs, $new_call;
    } else {
      push @{$call_infos}, $new_call;
    }
  } ## end arg: foreach my $arg_idx (all_idx_idx...)

  if (scalar @preordered_subdirs) {
    unshift @{$call_infos}, @preordered_subdirs;
  }
  return;
} ## end sub subdirs


sub tbb_offload {
  goto &_handler_placeholder; # Delegate to placeholder.
}

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
  } ## end else [ if (exists $_cml_state...)]
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
  } ## end else [ if (not defined $cd_info) [elsif ($type ne $cd_info->...)]]
  return;
} ## end sub _end_call_definition

####################################
# Private constants used by _find_package_keywords()
####################################
my @_cmake_fp_kw;
my @_cet_fp_kw =
  qw(BUILD_ONLY EXPORT INTERFACE NOP OPTIONAL PROJECT PUBLIC PRIVATE REQUIRED_BY);


sub _find_package_keywords {
  my @args = @_;
  @args or @args = qw(all);
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
      } ## end while (<$kw_pipe>)
      @_cmake_fp_kw = sort keys %{$kw_in};
    } ## end if (not defined @_cmake_fp_kw)
    @{$result}{@_cmake_fp_kw} = (1) x scalar @_cmake_fp_kw;
  } ## end if ($types->{cmake} or...)

  if ($types->{cet} or $types->{all}) {
    @{$result}{@_cet_fp_kw} = (1) x scalar @_cet_fp_kw;
  }
  my @result = sort keys %{$result};
  return @result;
} ## end sub _find_package_keywords


sub _flag_remove_UPS_vars {
  my ($call_info) = @_;
  return flag_required($call_info, <<"EOF");
remove UPS variables for Spack compatibility
EOF
} ## end sub _flag_remove_UPS_vars


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
    } ## end while (<$crv_fh>)
  } ## end if (my $crv_fh = IO::File...)
  return $result;
} ## end sub _get_cmake_required_version


sub _handler_placeholder {
  my ($dummy, $dummy, $call_info) = @_;
  debug("in handler for $call_info->{name}()");
  return;
} ## end sub _handler_placeholder

# Lookup table used by _product_to_package()
my $_product_to_package_table = { boost    => 'Boost',
                                  cppunit  => 'CppUnit',
                                  geant4   => 'Geant4',
                                  range    => 'Range-v3',
                                  root     => 'ROOT',
                                  smc      => 'Smc',
                                  sqlite   => 'SQLite3',
                                  tbb      => 'TBB',
                                  xerces_c => 'XercesC',
                                };
##
sub _product_to_package {
  my ($product) = @_;
  return $_product_to_package_table->{$product} // $product;
}

########################################################################
# _set_X
#
# Private callback routines invoked by set()
#
########################################################################
sub _set_CMAKE_PROJECT_VERSION_STRING { ## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;

  if (not $_cml_state->{seen_calls}->{'project'}) { # Too early.
    warning(<<"EOF");
project variable CMAKE_PROJECT_VERSION_STRING set at $cmakelists:$call_info->{start_line} must follow project() and precede cet_cmake_env() - relocating
EOF
  } elsif (not $_cml_state->{project_info}->{redundant_version_string}) {
    return;
  }

  # Don't need this call.
  report_removed($options->{cmakelists_short} // $cmakelists,
      " (obsolete)", pop @{$call_infos});
  return;
} ## end sub _set_CMAKE_PROJECT_VERSION_STRING


sub _set_CMAKE_INSTALL_PREFIX { ## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($pi, $call_infos, $call_info, $cmakelists, $options) = @_;
  flag_required($call_info, <<"EOF");
avoid setting CMAKE_INSTALL_PREFIX in CMake code
EOF
  return;
} ## end sub _set_CMAKE_INSTALL_PREFIX

########################################################################
1;
__END__
