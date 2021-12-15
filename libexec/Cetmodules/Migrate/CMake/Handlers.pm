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
  include
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
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
avoid directory-scope functions: use target_compile_definitions() or target_compile_features() whenever possible
EOF
  return;
} ## end sub add_compile_definitions


sub add_compile_options {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
avoid directory-scope functions: use target_compile_options() or target_compile_features() whenever possible
EOF
  return;
} ## end sub add_compile_options


sub add_definitions {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
avoid directory-scope functions: use target_compile_definitions() or target_compile_features() whenever possible
EOF
  return;
} ## end sub add_definitions


sub add_executable {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
use cet_make_exec() for transitivity
EOF
  return;
} ## end sub add_executable


sub add_library {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_required($cmd_info, <<"EOF");
use cet_make_library() or cet_build_plugin() for automatic transitivity
EOF
  return;
} ## end sub add_library


sub add_link_options {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
avoid directory-scope functions: use target_link_options() whenever possible
EOF
  return;
} ## end sub add_link_options


sub add_subdirectory {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;

  if (interpolated(arg_at($cmd_info, 0)) eq 'ups') {
    report_removed($options->{cmakelists_short} // $cmakelists,
        " (obsolete)", pop @{$cmd_infos});
  }
  return;
} ## end sub add_subdirectory


sub add_test {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
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
  my ($cmd_info, $cmakelists, $options) = @_;
  my @arg_idx_idx = all_idx_idx($cmd_info) or return;

  # Flag uses of CMAKE_INSTALL_PREFIX.
  List::MoreUtils::any {
    arg_at($cmd_info, $_) =~ m&\$\{CMAKE_INSTALL_PREFIX\}&msx;
  }
  @arg_idx_idx and flag_required($cmd_info, <<"EOF");
avoid CMAKE_INSTALL_PREFIX: not necesssary for install()-like commands
EOF

  # Flag uses of CMAKE_MODULE_PATH.
  my $found_CMP = List::Util::first {
    interpolated(arg_at($cmd_info, $_)) eq 'CMAKE_MODULE_PATH';
  }
  @arg_idx_idx;

  if (defined $found_CMP) {
    if (List::MoreUtils::any {
          arg_at($cmd_info, $_) =~ m&\$\{.*?_(SOURCE|BINARY)_DIR\}&smx;
        }
        @arg_idx_idx[$found_CMP .. $_LAST_ELEM_IDX]
      ) {
      flag_required($cmd_info, <<"EOF");
declare CMake private and exportable module dirs with cet_cmake_module_directories()
EOF
    } else {
      flag_recommended($cmd_info, <<"EOF");
use find_package() to find external CMake modules
EOF
    } ## end else [ if (List::MoreUtils::any...)]
  } ## end if (defined $found_CMP)

  # Remove problematic and unnecessary install path fragments.
  grep {
      if (my @separated = arg_at($cmd_info, $_)) {
        $separated[(scalar @separated > 1) ? 1 : 0] =~
        s&\$\{product\}/+\$\{version\}/*&&gmsx
        and replace_arg_at($cmd_info, $_, join(q(), @separated));
    } else {
        0;
      }
  } @arg_idx_idx and tag_changed($cmd_info, <<'EOF');
${product}/+${version}/* -> ""
EOF

  # Migrate old UPS-style variables.
  foreach my $arg_idx (@arg_idx_idx) {
    my $flagged;
    my @separated = arg_at($cmd_info, $arg_idx) or next;
    my $argref    = \$separated[(scalar @separated > 1) ? 1 : 0];

    foreach my $var (keys %{$_UPS_var_translation_table}) {
      if (${$argref} =~ m&(?<translate>\$\{\Q$var\E\})&msx) {
        my $old = $LAST_PAREN_MATCH{translate};

        if (defined(my $new = $_UPS_var_translation_table->{$var}->{new})) {
          ${$argref} =~
            s&\Q$old\E&\${\${CETMODULES_CURRENT_PROJECT_NAME}_$new}&gmsx
            and replace_arg_at($cmd_info, $arg_idx, join(q(), @separated))
            and tag_changed($cmd_info,
              "$old -> \${CETMODULES_CURRENT_PROJECT_NAME}_$new");
        } ## end if (defined(my $new = ...))

        if (exists $_UPS_var_translation_table->{$var}->{'flag'}) {
          &{ $_UPS_var_translation_table->{$var}->{'flag'} }($cmd_info);
          $flagged = 1;
        }
      } ## end if (${$argref} =~ m&(?<translate>\$\{\Q$var\E\})&msx)
    } ## end foreach my $var (keys %{$_UPS_var_translation_table...})
  } ## end foreach my $arg_idx (@arg_idx_idx)
  return;
} ## end sub arg_handler


sub art_make {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
deprecated: use art_make_library(), art_dictonary(), and cet_build_plugin() with explicit source lists and plugin base types
EOF
  return;
} ## end sub art_make


sub art_make_exec {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  replace_cmd_with($cmd_info, 'cet_make_exec');
  tag_changed($cmd_info, <<"EOF");
art_make_exec() -> cet_make_exec()
EOF
  return;
} ## end sub art_make_exec


sub basic_plugin {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
use cet_build_plugin() with explicit plugin base types whenever possible
EOF
  return;
} ## end sub basic_plugin


sub build_plugin {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
deprecated: use cet_build_plugin() with explicit plugin base types
EOF
  return;
} ## end sub build_plugin


sub cet_cmake_config {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  report_removed($options->{cmakelists_short} // $cmakelists,
      " (called automatically)",
      pop @{$cmd_infos});
  return;
} ## end sub cet_cmake_config


sub cet_find_library {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_required($cmd_info, <<'EOF');
use find_package() with custom Find<pkg>.cmake for Spack compatibility
EOF
  return;
} ## end sub cet_find_library


sub cet_make {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
deprecated: use cet_make_library(), build_dictonary(), cet_plugin() with explicit source lists and plugin base types
EOF
  return;
} ## end sub cet_make


sub cet_parse_args {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  replace_cmd_with($cmd_info, 'cmake_parse_arguments');
  my $flags = arg_at($cmd_info, 2);
  insert_args_at($cmd_info, 1, $flags);
  remove_args_at($cmd_info, 3); ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
  tag_changed($cmd_info, <<"EOF");
cet_parse_args(<prefix> <args> <opts> ...) -> cmake_parse_arguments(<prefix> <flags> <single-value-opts> <opts> ...)
EOF
  flag_recommended($cmd_info, <<"EOF");
separate <opts> into <single-value-opts> <opts>
EOF
  return;
} ## end sub cet_parse_args


sub cet_remove_compiler_flags {
  goto &_handler_placeholder; # Delegate to placeholder.
}


sub cet_report_compiler_flags {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  scalar @{ $cmd_info->{arg_indexes} }
    or flag_recommended($cmd_info, "add args: REPORT_THRESHOLD VERBOSE");
  return;
} ## end sub cet_report_compiler_flags


sub cmake_minimum_required {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  my $edit;

  if ($_cml_state->{seen_cmds}->{ $cmd_info->{name} }) {
    debug(<<"EOF");
ignoring duplicate $cmd_info->{name}() at line $cmd_info->{start_line} \
previously seen at $_cml_state->{seen_cmds}->{$cmd_info->{name}}->{start_line}
EOF
    return;
  } elsif ($_cml_state->{current_definition}) {
    debug(<<"EOF");
ignoring $cmd_info->{name} at line $cmd_info->{start_line} in \
definition of $_cml_state->{current_definition}->{name}()
EOF
    return;
  } ## end elsif ($_cml_state->{current_definition... [ if ($_cml_state->{seen_cmds...})]})
  $_cml_state->{seen_cmds}->{ $cmd_info->{name} } = $cmd_info;
  debug(<<"EOF");
found top level $cmd_info->{name}() at line $cmd_info->{start_line}
EOF

  if (not has_keyword($cmd_info, 'VERSION')) {
    warning(<<"EOF");
ill-formed $cmd_info->{name}() at line $cmd_info->{start_line} (no VERSION) will be corrected
EOF
    append_args($cmd_info, 'VERSION', $_cmake_required_version);
    $edit = "added missing keyword VERSION";
  } else {
    my ($req_version_idx) =
      find_single_value_for($cmd_info, qw(VERSION FATAL_ERROR));

    if (not $req_version_idx) {
      warning(<<"EOF");
ill-formed $cmd_info->{name}() at line $cmd_info->{start_line} (VERSION keyword missing value) will be corrected
EOF
      insert_args_at(
          $cmd_info,
          keyword_arg_append_position(
            $cmd_info, 'VERSION', 'FATAL_ERROR'
          ),
          $_cmake_required_version);
      $edit = "VERSION keyword missing value";
    } else {
      my $req_version = arg_at($cmd_info, $req_version_idx);
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
$cmd_info->{pre_cmd_ws}\Ecmake_policy(VERSION $policy)
EOF
          push @{$cmd_infos}, ${$lineref};
        } ## end if ($policy)
        my $new_req_version =
          join(q(...), $_cmake_required_version, $vmax // ());
        $edit = sprintf("VERSION %s -> $new_req_version",
            arg_at($cmd_info, $req_version_idx));
        replace_arg_at($cmd_info, $req_version_idx, $new_req_version);
      } ## end if (version_cmp($vmin,...))
    } ## end else [ if (not $req_version_idx)]
  } ## end else [ if (not has_keyword($cmd_info...))]
  defined $edit and tag_changed($cmd_info, $edit || ());

  if (not has_keyword($cmd_info, 'FATAL_ERROR')) {
    append_args($cmd_info, 'FATAL_ERROR');
    tag_changed($cmd_info, "added FATAL_ERROR");
  }
  return;
} ## end sub cmake_minimum_required


sub comment_handler {
  my ($pi, $comments, $cmakelists, $options) = @_;
  return;
}


sub endfunction {
  goto &_end_cmd_definition; # Delegate.
}


sub endmacro {
  goto &_end_cmd_definition; # Delegate.
}


sub eof_handler {
  my ($cml_data, $line_no, $options) = @_;
  verbose("[SUCCESS] processed $cml_data->{cmakelists} ($line_no lines)");
  undef $_cml_state;
  return;
} ## end sub eof_handler


sub function {
  goto &_cmd_definition; # Delegate.
}


sub find_library {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  if (has_keyword($cmd_info, 'ENV')
      or List::MoreUtils::any { arg_at($cmd_info, $_) =~ m&\$ENV\{&msx; }
      all_idx_idx($cmd_info)
    ) {
    flag_recommended($cmd_info, <<'EOF');
use find_package() with custom Find<pkg>.cmake or cet_find_library() with ENV <x> for transitivity, relocatability
EOF
  } else {
    flag_recommended($cmd_info, <<'EOF');
use find_package() with custom Find<pkg>.cmake for transitivity, relocatability
EOF
  } ## end else [ if (has_keyword($cmd_info...))]
  return;
} ## end sub find_library


sub find_package {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  my $package_to_find = interpolated(arg_at($cmd_info, 0));

  if ($package_to_find =~ m&\A(cet(?:modules|buildtools))\z&msx
      and (
        exists $_cml_state->{project_info}
        or (  exists $_cml_state->{seen_cmds}
          and exists $_cml_state->{seen_cmds}->{ $cmd_info->{name} }
          and scalar keys $_cml_state->{seen_cmds}->{ $cmd_info->{name} }
          ->{cetmodules}))
    ) {
    info(<<"EOF");
removing late, redundant $cmd_info->{name}($1) at line $cmd_info->{start_line}
EOF
    pop(@{$cmd_infos});
    return;
  } ## end if ($package_to_find =~...)

  if ($package_to_find eq 'cetbuildtools') {
    tag_changed($cmd_info, "$package_to_find -> cetmodules");
    $package_to_find = 'cetmodules';
    replace_arg_at($cmd_info, 0, $package_to_find);
  } ## end if ($package_to_find eq...)
  $_cml_state->{seen_cmds}->{ $cmd_info->{name} }->{$package_to_find}
    ->{ $cmd_info->{start_line} } = $cmd_info;
  my @removed_keywords = map {
      remove_keyword($cmd_info, $_, _find_package_keywords()) // ();
  } qw(BUILD_ONLY PRIVATE);

  if (my @obsolete_keywords = map {
        remove_keyword($cmd_info, $_, _find_package_keywords()) // ();
      } qw(INTERFACE PUBLIC)
    ) {

    if (defined find_keyword($cmd_info, 'EXPORT')) {
      push @removed_keywords, @obsolete_keywords;
    } else {
      append_args($cmd_info, 'EXPORT');
      tag_changed(
          $cmd_info,
          sprintf(
            "replaced obsolete keyword%s with EXPORT: %s",
            ($#obsolete_keywords) ? 's' : q(),
            join(q( ), @obsolete_keywords)));
    } ## end else [ if (defined find_keyword...)]
  } ## end if (my @obsolete_keywords...)
  scalar @removed_keywords
    and tag_changed(
      $cmd_info,
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
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $old_cmd = $cmd_info->{name};
  my ($product_to_find, $package_to_find, $had_project_kw);

  # Handle OPTIONAL keyword.
  my $add_required = not remove_keyword($cmd_info, "OPTIONAL");

  # Rename the function.
  replace_cmd_with($cmd_info, 'find_package');

  # Behavior specific to the function we're replacing.
  given ($old_cmd) {
    when ('find_ups_product') {
      $product_to_find = interpolated(arg_at($cmd_info, 0));

      # Determine package name for product and replace args.
      $had_project_kw =
        remove_keyword($cmd_info, "PROJECT", _find_package_keywords());
      $package_to_find = single_value_for($cmd_info, 'PROJECT', 1)
        // _product_to_package($product_to_find);

      if ($package_to_find ne $product_to_find) {
        replace_arg_at($cmd_info, 0, $package_to_find);
      }
    } ## end when ('find_ups_product')
    when (m&\Afind_ups_(?P<product>boost|geant4|root)\z&msx) {
      $package_to_find = _product_to_package($LAST_PAREN_MATCH{product});
      prepend_args($cmd_info, $package_to_find);
    }
    default { # Unknown command delegated to us.
      error_exit(<<"EOF");
[INTERNAL] unrecognized command $old_cmd at $cmakelists:$cmd_info->{start_line}
EOF
    } ## end default
  } ## end given

  # Translate minimum version requirement if necessary.
  my $minv = interpolated(arg_at($cmd_info, 1));
  is_ups_version($minv) or undef $minv;

  # Remove arguments to find_ups_boost() not already handled.
  if (not defined $product_to_find and $package_to_find eq 'Boost') {
    remove_args_at($cmd_info,
        ((defined $minv) ? 2 : 1) .. $#{ $cmd_info->{arg_indexes} });
  }
  $add_required
    and not has_keyword($cmd_info, 'REQUIRED')
    and append_args($cmd_info, "REQUIRED");

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
    replace_arg_at($cmd_info, 1, $minv);
    unshift @new_bits, $minv;
  } ## end if (defined $minv)
  scalar @old_bits and unshift @new_bits, $package_to_find;
  push @old_bits, q(...);
  push @new_bits, q(...);
  tag_changed(
      $cmd_info,
      sprintf(
        "find_ups_product(%s) -> find_package(%s)",
        join(q( ), @old_bits),
        join(q( ), @new_bits)));
  ##
  ####################################
  return find_package($pi, $cmd_infos, $cmd_info, $cmakelists,
      $options);
} ## end sub find_ups_product


sub find_ups_root {
  goto &find_ups_product; # Delegate.
}


sub include {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  given (interpolated(arg_at($cmd_info, 0))) {
    when ('CetParseArgs') {
      report_removed($options->{cmakelists_short} // $cmakelists,
          " (obsolete)", pop @{$cmd_infos});
    }
    default { } # NOP.
  } ## end given
  return;
} ## end sub include


sub include_directories {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
avoid directory-scope functions: use target_link_libraries() with target semantics or target_include_directories() whenever possible
EOF
  return;
} ## end sub include_directories


sub link_directories {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
avoid directory-scope functions: use target_link_libraries() with target semantics or target_link_directories() whenever possible
EOF
  return;
} ## end sub link_directories


sub link_libraries {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
avoid directory-scope functions: use target_link_libraries() whenever possible
EOF
  return;
} ## end sub link_libraries


sub macro {
  goto &_cmd_definition; # Delegate.
}


sub project { ## no critic qw(Subroutines::ProhibitExcessComplexity)
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ($_cml_state->{seen_cmds}->{ $cmd_info->{name} }) {
    info(<<"EOF");
ignoring subsequent $cmd_info->{name}() at line $cmd_info->{start_line} \
previously seen at $_cml_state->{seen_cmds}->{$cmd_info->{name}}->{start_line}
EOF
    return;
  } elsif (not(
      exists $_cml_state->{seen_cmds}->{'find_package'}
      and $_cml_state->{seen_cmds}->{'find_package'}->{cetmodules})) {
    unshift @{$cmd_infos},
      ${tag_added(
          sprintf("%sfind_package(cetmodules REQUIRED)\n",
            $cmd_info->{pre_cmd_ws} // q()),
          "find_package(cetmodules) must precede project()") };
  } ## end elsif (not(exists $_cml_state... [ if ($_cml_state->{seen_cmds...})]))
  $_cml_state->{seen_cmds}->{ $cmd_info->{name} } = $cmd_info;
  $_cml_state->{project_info}                         = my $project_info = {};
  $project_info->{first_pass}                         = my $cpi =
    get_cmake_project_info(dirname($cmakelists, $options),
      quiet_warnings => 1);
  $project_info->{name} = $cpi->{cmake_project_name};
  my $n_args = scalar @{ $cmd_info->{arg_indexes} };
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ( # Identify old-style project().
      $n_args > 1 and List::MoreUtils::all {
        my $arg = interpolated($cmd_info, $_);
        List::MoreUtils::any { $arg eq $_; } @_cmake_languages;
      }
      1 .. ($n_args - 1)
    ) {
    # Old-style command with only name and languages (no keywords).
    add_args_after($cmd_info, 0, 'LANGUAGES');
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
      remove_keyword($cmd_info, 'VERSION', @PROJECT_KEYWORDS);
      $project_info->{cmake_project_version} =
        $cpi->{CMAKE_PROJECT_VERSION_STRING};
      $project_info->{cmake_project_version_info} = $vsinfo;
      tag_changed($cmd_info,
          "VERSION -> set(CMAKE_PROJECT_VERSION_STRING ...)");

      if (my $vs_cmd_info =
          $_cml_state->{seen_cmds}->{'set'}->{CMAKE_PROJECT_VERSION_STRING}) {

        # This was seen too early and removed: reinstate it here with
        # the correct indentation.
        $vs_cmd_info = dclone($vs_cmd_info->[0]);

        if ($cmd_info->{pre_cmd_ws}) {
          $vs_cmd_info->{pre_cmd_ws} = $cmd_info->{pre_cmd_ws};
        } else {
          delete $vs_cmd_info->{pre_cmd_ws};
        }
        tag_changed($vs_cmd_info,
            "moved from line $vs_cmd_info->{start_line}");
        push @{$cmd_infos}, $vs_cmd_info;
      } ## end if (my $vs_cmd_info...)
    } else {
      $project_info->{redundant_version_string} = 1;

      if (defined $cpi->{cmake_project_version}
          and version_cmp($cpi->{cmake_project_version_info}, $vsinfo) != 0) {
        info(<<"EOF");
project($project_info->{name} VERSION $cpi->{cmake_project_version} ...) overridden by \${$project_info->{name}_CMAKE_PROJECT_VERSION_STRING} ($cpi->{CMAKE_PROJECT_VERSION_STRING}: updating project($project_info->{name} VERSION ...)
EOF

        # Delete any VERSIONs from project() to avoid confusion.
        remove_keyword($cmd_info, 'VERSION', @PROJECT_KEYWORDS);
        add_args_after($cmd_info, 0, 'VERSION',
            $cpi->{CMAKE_PROJECT_VERSION_STRING});
        tag_changed($cmd_info,
            "VERSION -> set(CMAKE_PROJECT_VERSION_STRING ...)");
      } ## end if (defined $cpi->{cmake_project_version...})
    } ## end else [ if ($vsinfo->{extra}) ]
  } elsif (defined $cpi->{cmake_project_version} and defined $pi->{version})
  { # we override product_deps
    warning(<<"EOF");
UPS product version $pi->{version} overridden by project($project_info->{name} ... VERSION $cpi->{cmake_project_version} ...) at $cmakelists:$cmd_info->{start_line}
EOF
  } elsif (not defined $cpi->{cmake_project_version}
      and defined $pi->{version}) { # Take version from product_deps
    $project_info->{cmake_project_version_info} = my $vinfo =
      parse_version_string($pi->{version});
    $project_info->{cmake_project_version} =
      to_cmake_version($project_info->{cmake_project_version_info});

    if ($vinfo->{extra}) {          # need to use version string
      my $lineref = tag_added(<<"EOF", "extended version semantics");
$cmd_info->{pre_cmd_ws}\Eset($project_info->{cmake_project_name} $project_info->{cmake_project_version})
EOF
      push @{$cmd_infos}, ${$lineref};

      # Remove any empty VERSION keywords.
      remove_keyword($cmd_info, 'VERSION', @PROJECT_KEYWORDS);
    } else {
      remove_keyword($cmd_info, 'VERSION', @PROJECT_KEYWORDS);
      add_args_after($cmd_info, 0, 'VERSION',
          $cpi->{CMAKE_PROJECT_VERSION_STRING});
      tag_changed($cmd_info,
          "set(CMAKE_PROJECT_VERSION_STRING) -> VERSION");
    } ## end else [ if ($vinfo->{extra}) ]
  } ## end elsif (not defined $cpi->... [ if ($cpi->{CMAKE_PROJECT_VERSION_STRING...})])
  return;
} ## end sub project


sub remove_definitions {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
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
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  debug("in handler for $cmd_info->{name}()");
  my ($set_var_name, $is_literal) = interpolated($cmd_info, 0) // return;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ($set_var_name = List::MoreUtils::first_value {
        $set_var_name =~ m&(?:\A|_)\Q$_\E\z&msx;
      }
      @_HANDLED_SET_VARS
    ) {
    # We have a match and (hopefully) a handler therefor.
    push @{ $_cml_state->{seen_cmds}->{'set'}->{$set_var_name} },
      $cmd_info;
    local $EVAL_ERROR; ## no critic qw(RequireInitializationForLocalVars)
    my $func_name = "Cetmodules::Migrate::CMake::Handlers\::_$set_var_name";
    my $func_ref  = \&{$func_name};
    eval {
        &{$func_ref}
        ($pi, $cmd_infos, $cmd_info, $cmakelists, $options);
    } or 1;
    $EVAL_ERROR and error_exit(<<"EOF");
error calling SET handler for matched variable $set_var_name at $cmakelists:$cmd_info->{start_line}:
$EVAL_ERROR
EOF
  } ## end if ($set_var_name = List::MoreUtils::first_value...)
  return;
} ## end sub set


sub simple_plugin {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_recommended($cmd_info, <<"EOF");
deprecated: use cet_build_plugin() with explicit source lists and plugin base types
EOF
  return;
} ## end sub simple_plugin


sub subdirs {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  report_removed($options->{cmakelists_short} // $cmakelists,
      " (obsolete)", pop @{$cmd_infos});
  scalar @{ $cmd_info->{arg_indexes} } or return;
  my $mode               = q();
  my @preordered_subdirs = ();
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
arg: foreach my $arg_idx (all_idx_idx($cmd_info)) {
    my $arg = arg_at($cmd_info, $arg_idx);
    given (interpolated($arg)) {
      when ('ups') { # Drop.
        info(sprintf(<<"EOF", arg_location($cmd_info, $arg_idx)));
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
    my $new_cmd =
      sprintf("$cmd_info->{pre_cmd_ws}add_subdirectory($arg%s)\n",
        ($mode eq 'EXCLUDE_FROM_ALL') ? " $mode" : q());
    tag_changed(\$new_cmd, "subdirs(...) -> add_subdirectory(...)");

    if ($mode eq 'PREORDER') {
      push @preordered_subdirs, $new_cmd;
    } else {
      push @{$cmd_infos}, $new_cmd;
    }
  } ## end arg: foreach my $arg_idx (all_idx_idx...)

  if (scalar @preordered_subdirs) {
    unshift @{$cmd_infos}, @preordered_subdirs;
  }
  return;
} ## end sub subdirs


sub tbb_offload {
  goto &_handler_placeholder; # Delegate to placeholder.
}

########################################################################
# Private functions
########################################################################
sub _cmd_definition {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  my $name = interpolated($cmd_info, 0);
  my $type = $cmd_info->{name};

  if ($_cml_state->{current_definition}) {
    my $cd_info = $_cml_state->{current_definition};
    error(<<"EOF");
found nested definition of $type $name at line $cmd_info->{start_line}:
already in definition of $cd_info->{type} $cd_info->{name} since line $cd_info->{start_line}
EOF
  } else {
    debug(
        "found definition of $type $name at line $cmd_info->{start_line}"
    );
    $_cml_state->{current_definition} =
      { %{$cmd_info}, name => $name, type => $type };
  } ## end else [ if ($_cml_state->{current_definition...})]
  return;
} ## end sub _cmd_definition


sub _end_cmd_definition {
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  my ($type) = ($cmd_info->{name} =~ m&\Aend(.*)\z&msx);
  my $cd_info = $_cml_state->{current_definition};

  if (not defined $cd_info) {
    error(<<"EOF");
found $cmd_info->{name}\(\) while not in $type definition
EOF
  } elsif ($type ne $cd_info->{type}) {
    error(<<"EOF");
found $cmd_info->{name}() at line $cmd_info->{start_line} in definition of $cd_info->{type} $cd_info->{name}\(\) definition
EOF
  } else {
    debug(<<"EOF");
found $cmd_info->{name}() at line $cmd_info->{start_line} matching $cd_info->{type}($cd_info->{name}) at line $cd_info->{start_line}
EOF
  } ## end else [ if (not defined $cd_info) [elsif ($type ne $cd_info->...)]]
  delete $_cml_state->{current_definition};
  return;
} ## end sub _end_cmd_definition

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

      while (my $line = <$kw_pipe>) {
        chomp $line;
        my @kw = split qq( ), $line;
        @kw and @{$kw_in}{@kw} = (1) x scalar @kw;
      } ## end while (my $line = <$kw_pipe>)
      $kw_pipe->close();
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
  my ($cmd_info) = @_;
  return flag_required($cmd_info, <<"EOF");
remove/replace UPS variables for Spack compatibility
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
  my ($dummy, $dummy, $cmd_info) = @_;
  debug("in handler for $cmd_info->{name}()");
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
# Private handlers invoked by set()
#
########################################################################
sub _set_CMAKE_PROJECT_VERSION_STRING { ## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;

  if (not $_cml_state->{seen_cmds}->{'project'}) { # Too early.
    warning(<<"EOF");
project variable CMAKE_PROJECT_VERSION_STRING set at $cmakelists:$cmd_info->{start_line} must follow project() and precede cet_cmake_env() - relocating
EOF
  } elsif (not $_cml_state->{project_info}->{redundant_version_string}) {
    return;
  }

  # Don't need this command.
  report_removed($options->{cmakelists_short} // $cmakelists,
      " (obsolete)", pop @{$cmd_infos});
  return;
} ## end sub _set_CMAKE_PROJECT_VERSION_STRING


sub _set_CMAKE_INSTALL_PREFIX { ## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($pi, $cmd_infos, $cmd_info, $cmakelists, $options) = @_;
  flag_required($cmd_info, <<"EOF");
REMOVE: avoid setting CMAKE_INSTALL_PREFIX in CMake code
EOF
  return;
} ## end sub _set_CMAKE_INSTALL_PREFIX

########################################################################
1;
__END__
