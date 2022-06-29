# -*- cperl -*-
package Cetmodules::UPS::Setup;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules qw(:DIAG_VARS);
use Cetmodules::CMake
  qw(@PROJECT_KEYWORDS get_CMakeLists_hash process_cmake_file);
use Cetmodules::CMake::CommandInfo qw();
use Cetmodules::CMake::Util qw(can_interpolate interpolated);
use Cetmodules::UPS::ProductDeps
  qw($BTYPE_TABLE $PATHSPEC_INFO get_pathspec get_table_fragment pathkey_is_valid sort_qual var_stem_for_dirkey);
use Cetmodules::Util
  qw(debug error_exit info parse_version_string to_cmake_version to_product_name to_ups_version to_version_string verbose warning);
use Cetmodules::Util::VariableSaver qw();
use Cwd qw(abs_path);
use English qw(-no_match_vars);
use Exporter qw(import);
use File::Spec qw();
use IO::File qw();
use List::MoreUtils qw();
use Readonly qw();

##
use warnings FATAL => qw(Cetmodules);

##
use vars qw($PATH_VAR_TRANSLATION_TABLE);

our (@EXPORT, @EXPORT_OK);

@EXPORT = qw(
  cetpkg_info_file
  classify_deps
  compiler_for_quals
  deps_for_quals
  get_cmake_project_info
  get_derived_parent_data
  match_qual
  output_info
  print_dep_setup
  print_dep_setup_one
  print_dev_setup
  print_dev_setup_var
  table_dep_setup
  ups_to_cmake
  write_table_deps
  write_table_frag
);
@EXPORT_OK = qw($PATH_VAR_TRANSLATION_TABLE);

########################################################################
# Exported variables
########################################################################
$PATH_VAR_TRANSLATION_TABLE = _path_var_translation_table();

########################################################################
# Private variables
########################################################################
my ($_cqual_table, $_cm_state);
Readonly::Scalar my $_EXEC_MODE => oct(755);

########################################################################
# Exported functions
########################################################################
# Output information for buildtool.
sub cetpkg_info_file {
  my (%cetpkg_info) = @_;
  my @expected_keys = qw(source build name version cmake_project_version
    chains qualspec cqual build_type extqual use_time_deps
    build_only_deps cmake_args);
  my @for_export = (
    qw(CETPKG_SOURCE CETPKG_BUILD CETPKG_FLAVOR CETPKG_QUALSPEC CETPKG_FQ_DIR),
    map { "CETPKG_$_"; } grep {
      m&\A[A-Za-z0-9]+_(?:STANDARD|COMPILER(?:_(?:ID|VERSION))?)\z&msx;
    } sort keys %cetpkg_info
  );
  my $cetpkgfile =
    File::Spec->catfile($cetpkg_info{build} || q(.), "cetpkg_info.sh");
  my $fh = IO::File->new("$cetpkgfile", q(>))
    or error_exit("couldn't open $cetpkgfile for write");
  $fh->print(<<'EOD');
#!/bin/bash
########################################################################
# cetpkg_info.sh
#
#   Generated script to define variables required by buildtool to
#   compose the build environment.
#
# If we're being sourced, define the expected shell and environment
# variables; otherwise, print the definitions for user information.
#
##################
# NOTES
#
# * The definitions printed by executing this script are formatted to be
#   human-readable; they may *not* be suitable for feeding to a shell.
#
# * This script is *not* shell-agnostic, as it is not intended to be a 
#   general setup script.
#
# * Most items are not exported to the environment and will therefore
#   not be visible downstream of the shell sourcing this file.
#
########################################################################

( return 0 2>/dev/null ) && eval "__EOF__() { :; }" && \
  _cetpkg_catit=(:) || _cetpkg_catit=(cat '<<' __EOF__ '|' sed -Ee "'"'s&\\([^\\]|$)&\1&g'"'" )
eval "${_cetpkg_catit[@]}"$'\n'\
EOD
  my $var_data;
  my $tmp_fh = IO::File->new(\$var_data, q(>))
    or error_exit("could not open memory stream to variable \$tmp_fh");

  # Output known info in expected order, followed by any remainder in
  # lexical order.
  my @output_items = output_info(
    $tmp_fh,
    \%cetpkg_info,
    \@for_export,
    ( map {
        my $key = $_;
        (grep { $key eq $_ } keys %cetpkg_info) ? ($key) : ()
      } @expected_keys
    ),
    ( map {
        my $key = $_;
        (grep { $key eq $_ } @expected_keys) ? () : ($key)
      } sort keys %cetpkg_info
    ));
  $tmp_fh->close();
  $tmp_fh->open(\$var_data, q(<))
    or error_exit("unable to open memory stream from variable \$tmp_fh");

  while (<$tmp_fh>) {
    chomp;
    $fh->print("\Q$_\E\$'\\n'\\\n");
  }
  $tmp_fh->close();
  $fh->print(<<'EOD');
$'\n'\
__EOF__
( return 0 2>/dev/null ) && unset __EOF__ \
EOD
  $fh->print("  || true\n");
  $fh->close();
  chmod $_EXEC_MODE, $cetpkgfile;
  return $cetpkgfile;
} ## end sub cetpkg_info_file


sub classify_deps {
  my ($pi, $dep_info) = @_;

  foreach my $dep (sort keys %{$dep_info}) {
    $pi->{ ($dep_info->{$dep}->{only_for_build})
      ? 'build_only_deps'
      : 'use_time_deps' }->{$dep} = 1;
  } ## end foreach my $dep (sort keys ...)

  foreach my $key (qw(build_only_deps use_time_deps)) {
    $pi->{$key} = [sort keys %{ $pi->{$key} }];
  }
  return;
} ## end sub classify_deps


sub compiler_for_quals {
  my ($compilers, $qualspec) = @_;
  $compilers->{$qualspec}
    and $compilers->{$qualspec} ne q(-)
    and return $compilers->{$qualspec};
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $compiler     = 'cc'; # Default to native.
  my @sorted_quals = ();
  sort_qual(\@sorted_quals, $qualspec);
  given ($sorted_quals[0] // q()) {
    when (m&\A(?:e13|c(?:lang)?\d+)\z&msx) {
      $compiler = "clang";
    }
    when (m&\A(?:e|gcc)\d+\z&msx) {
      $compiler = "gcc";
    }
    when (m&\A(?:i|icc)\d+\z&msx) {
      $compiler = "icc";
    }
  } ## end given
  return $compiler;
} ## end sub compiler_for_quals


sub deps_for_quals {
  my ($pfile, $phash, $qhash, $qualspec) = @_;
  my $results = {};

  foreach my $prod (sort keys %{$phash}) {

    # Find matching version hashes for this product, including default
    # and empty. $phash is the product list hash as produced by
    # get_product_list().
    my $matches = {
        map {
          match_qual($_, $qualspec) ? ($_ => $phash->{ ${prod} }->{$_}) : ();
        } sort keys %{ $phash->{$prod} } };

    # Remove the default entry from the set of matches (if it exists)
    # and save it.
    my $default = delete $matches->{"-default-"}; # undef if missing.
    scalar keys %{$matches} > 1 and error_exit(<<"EOF");
ambiguous result matching version for dependency $prod against parent qualifiers $qualspec in $pfile
EOF

    # Use $default if we need to.
    my $result = (values %{$matches})[0] || $default || next;
    $result = { %{$result} };                     # Copy contents for amendment.

    if (exists $qhash->{$prod} and exists $qhash->{$prod}->{$qualspec}) {
      if ($qhash->{$prod}->{$qualspec} eq '-b-') {

        # Old syntax for unqualified build-only deps.
        $result->{only_for_build} = 1;
        $result->{qualspec}       = q();
      } elsif ($qhash->{$prod}->{$qualspec} eq q(-)) {

        # Not needed here.
        next;
      } else {

        # Normal case.
        $result->{qualspec} = $qhash->{$prod}->{$qualspec} || q();
      } ## end else [ if ($qhash->{$prod}->{... [elsif ($qhash->{$prod}->{...})]})]
    } elsif (not $result->{only_for_build}) {
      if (not exists $qhash->{$prod}) {
        error_exit(<<"EOF");
dependency $prod has no column in the qualifier table in $pfile
EOF
      } else {
        my $qualspec_msg =
          $qualspec ? "parent qualifier $qualspec" : "unqualified parent";
        error_exit(sprintf(<<"EOF", $prod, $qualspec_msg));
dependency %s has no entry in the qualifier table for %s in $pfile
EOF
      } ## end else [ if (not exists $qhash->...)]
    } else {
      $result->{qualspec} = $qhash->{$prod}->{$qualspec} || q();
    }
    $results->{$prod} = $result;
  } # foreach $prod.
  return $results;
} ## end sub deps_for_quals


sub get_cmake_project_info {
  my ($pkgtop, %options) = @_;
  undef $_cm_state;
  my $cmake_file = File::Spec->catfile($pkgtop, "CMakeLists.txt");
  process_cmake_file(
    $cmake_file,
    {   %options,
        cet_cmake_env_cmd             => \&_set_seen_cet_cmake_env,
        cet_set_version_from_file_cmd => \&_get_info_from_csvf_cmd,
        project_cmd                   => \&_get_info_from_project_cmd,
        file_cmd                      => \&_get_info_from_file_cmd,
        set_cmd                       => \&_get_info_from_set_cmds
    });
  return { %{ $_cm_state->{cmake_info} // {} } };
} ## end sub get_cmake_project_info


sub get_derived_parent_data {
  my ($pi, $sourcedir, @qualstrings) = @_;

  # Checksum the absolute filename of the CMakeLists.txt file to
  # identify initial values for project variables when we're not
  # guaranteed to know the CMake project name by reading CMakeLists.txt
  # (conditionals, variables, etc.):
  $pi->{project_variable_prefix} = get_CMakeLists_hash($sourcedir);

  # CMake info.
  my $cpi =
    get_cmake_project_info($sourcedir,
      ($pi->{version}) ? (quiet_warnings => 1) : ());

  if (not $cpi or not scalar keys %{$cpi}) {
    error_exit(
      "unable to obtain useful information from $sourcedir/CMakeLists.txt");
  }

  if (not defined $pi->{name}) {
    $cpi->{cmake_project_name}
      and not $cpi->{cmake_project_name} =~ m&\$&msx
      and $pi->{name} = to_product_name($cpi->{cmake_project_name})
      or error_exit(<<"EOF");
UPS product name not specified in product_deps and could not identify an
unambiguous project name in $sourcedir/CMakeLists.txt
EOF
  } ## end if (not defined $pi->{...})
  exists $cpi->{cmake_project_version_info}
    and $cpi->{cmake_project_version_info}->{extra}
    and error_exit(<<"EOF");
VERSION as specified in $sourcedir/CMakeLists.txt:project() ($cpi->{cmake_project_version}) has an
impermissible non-numeric component "$cpi->{cmake_project_version_info}->{extra}": remove from project()
and set \${PROJECT_NAME}_CMAKE_PROJECT_VERSION_STRING to $cpi->{cmake_project_version}
before calling cet_cmake_env()
EOF
  _set_version($pi, $cpi, $sourcedir);
  my @sorted;
  $pi->{qualspec} = sort_qual(\@sorted, @qualstrings);
  @{$pi}{qw(cqual extqual build_type)} = @sorted;
  $pi->{build_type}
    and $pi->{cmake_build_type} = $BTYPE_TABLE->{ $pi->{build_type} };

  # Derivatives of the product's UPS flavor.
  if ($pi->{no_fq_dir}) {
    $pi->{flavor} = "NULL";
  } else {
    my $flavor = qx(ups flavor -4) ## no critic qw(InputOutput::ProhibitBacktickOperator)
      or error_exit("failure executing ups flavor: UPS not set up?",
        $OS_ERROR // ());
    chomp $flavor;

    # We only care about OS major version no. for Darwin.
    $flavor =~ s&\A(Darwin.*?\+\d+).*\z&${1}&msx;
    $pi->{flavor} = $flavor;
    my $fq_dir = ($pi->{noarch}) ? 'noarch' : $ENV{CET_SUBDIR}
      or error_exit("CET_SUBDIR not set: missing cetpkgsupport?");
    $pi->{fq_dir} = join(q(.), $fq_dir, split(/:/msx, $pi->{qualspec}));
  } ## end else [ if ($pi->{no_fq_dir}) ]

  # Compiler info.
  _add_compiler_info($pi);
  return $cpi;
} ## end sub get_derived_parent_data


sub match_qual {
  my ($match_spec, $qualstring) = @_;
  my @quals = split(/:/msx, $qualstring);
  my ($neg, $qual_spec) = ($match_spec =~ m&\A(!)?(.*)\z&msx);
  return (
         $qual_spec eq q(-)
      or $qual_spec eq '-default-'
      or ($neg xor grep { $qual_spec eq $_ } @quals));
} ## end sub match_qual


sub output_info {
  my ($fh, $cetpkg_info, $for_export, @keys) = @_;
  my @defined_vars = ();

  foreach my $key (@keys) {
    my $current_var =
      sprintf('CETPKG_%s', ($key eq "\L$key") ? "\U$key" : $key);
    local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
    List::MoreUtils::any { $current_var eq $_; } @{$for_export}
      and $current_var = "export $current_var";
    my $val = $cetpkg_info->{$key} || q();

    if (not ref $val) {
      $fh->print("$current_var=\Q$val\E\n");
    } elsif (ref $val eq "SCALAR") {
      $fh->print("$current_var=\Q$$val\E\n");
    } elsif (ref $val eq "ARRAY") {
      $fh->printf("$current_var=(%s)\n", join(q( ), map {"\Q$_\E"} @{$val}));
    } else {
      verbose(sprintf("ignoring unexpected info $key of type %s", ref $val));
      next;
    }
    push @defined_vars, $current_var;
  } ## end foreach my $key (@keys)
  return @defined_vars;
} ## end sub output_info


sub print_dep_setup {
  my ($deps, $out) = @_;
  my ($setup_cmds, $only_for_build_cmds);

  # Temporary variable connected as a filehandle.
  my $setup_cmds_fh = IO::File->new(\$setup_cmds, q(>))
    or error_exit("could not open memory stream to variable \$setup_cmds");

  # Second temporary variable connected as a filehandle.
  my $only_cmds_fh = IO::File->new(\$only_for_build_cmds, q(>))
    or error_exit(
      "could not open memory stream to variable \$only_for_build_cmds");
  my $onlyForBuild = q();

  for (keys %{$deps}) {
    my $dep_info = $deps->{$_};
    my $fh;

    if ($dep_info->{only_for_build}) {
      m&\Acet(?:buildtools|modules)\z&msx and next; # Dealt with elsewhere.
      $fh = $only_cmds_fh;
    } else {
      $fh = $setup_cmds_fh;
    }
    print_dep_setup_one($_, $dep_info, $fh);
  } ## end for (keys %{$deps})
  $setup_cmds_fh->close();
  $only_cmds_fh->close();
  $out->print(<<'EOF');
# Add '-B' to UPS_OVERRIDE for safety.
tnotnull UPS_OVERRIDE || setenv UPS_OVERRIDE ''
expr "x $UPS_OVERRIDE" : '.* -[^- 	]*B' >/dev/null || setenv UPS_OVERRIDE "$UPS_OVERRIDE -B"
EOF

  # Build-time dependencies first.
  $only_for_build_cmds and $out->print(<<'EOF', $only_for_build_cmds);

####################################
# Build-time dependencies.
####################################
EOF

  # Now use-time dependencies.
  $setup_cmds and $out->print(<<'EOF', $setup_cmds);

####################################
# Use-time dependencies.
####################################
EOF
  return;
} ## end sub print_dep_setup


sub print_dep_setup_one {
  my ($dep, $dep_info, $out) = @_;
  my $thisver =
    (not $dep_info->{version} or $dep_info->{version} eq q(-))
    ? q()
    : $dep_info->{version};
  my @setup_options =
    (exists $dep_info->{setup_options} and $dep_info->{setup_options})
    ? @{ $dep_info->{setup_options} }
    : ();
  my @prodspec   = ("$dep", "$thisver");
  my $qualstring = join(q(:+), split(/:/msx, $dep_info->{qualspec} || q()));
  $qualstring and push @prodspec, '-q', $qualstring;
  $out->print("# > $dep <\n");

  if ($dep_info->{optional}) {
    my $prodspec_string = join(q( ), @prodspec);
    $out->print(<<"EOF");
# Setup of $dep is optional.
ups exist $prodspec_string
test "\$?" != 0 && \\
  echo \QINFO: skipping missing optional product $prodspec_string\E || \\
EOF
    $out->print(q(  ));
  } ## end if ($dep_info->{optional...})
  my $setup_cmd = join(q( ), qw(setup -B), @prodspec, @setup_options);

  if (scalar @setup_options) {

    # Work around bug in ups active -> unsetup_all for UPS<=6.0.8.
    $setup_cmd = sprintf(
      '%s && setenv %s "`echo \"$%s\" | sed -Ee \'s&[[:space:]]+-j$&&\'`"',
      "$setup_cmd", ("SETUP_\U$dep\E") x 2);
  } ## end if (scalar @setup_options)
  $out->print("$setup_cmd; ");
  _setup_err($out, "$setup_cmd failed");
  return;
} ## end sub print_dep_setup_one


sub print_dev_setup {
  my ($pi, $out) = @_;
  my $fqdir;
  $out->print(<<"EOF");

####################################
# Development environment.
####################################
EOF
  my $libdir = _fq_path_for($pi, 'libdir', 'lib');
  $libdir and _setup_from_libdir($pi, $out, $libdir);

  # ROOT_INCLUDE_PATH.
  $out->print(print_dev_setup_var(
    "ROOT_INCLUDE_PATH", [qw(${CETPKG_SOURCE} ${CETPKG_BUILD})]));

  # CMAKE_PREFIX_PATH.
  $out->print(print_dev_setup_var("CMAKE_PREFIX_PATH", '${CETPKG_BUILD}', 1));

  # FHICL_FILE_PATH.
  $fqdir = _fq_path_for($pi, 'fcldir', 'fcl')
    and $out->print(print_dev_setup_var(
      "FHICL_FILE_PATH", File::Spec->catfile('${CETPKG_BUILD}', $fqdir)));

  # FW_SEARCH_PATH.
  my $fw_pathspec = get_pathspec($pi, 'set_fwdir');
  $fw_pathspec->{path}
    and not $fw_pathspec->{fq_path}
    and error_exit(<<"EOF");
INTERNAL ERROR in print_dev_setup(): ups_to_cmake() should have been called first
EOF
  my @fqdirs =
    map { m&\A/&msx ? $_ : File::Spec->catfile('${CETPKG_BUILD}', $_); } (
      _fq_path_for($pi, 'gdmldir', 'gdml') || (),
      _fq_path_for($pi, 'fwdir') || ());
  push @fqdirs,
    map { m&\A/&msx ? $_ : File::Spec->catfile('${CETPKG_SOURCE}', $_); }
    @{ $fw_pathspec->{fq_path} || [] };
  $out->print(print_dev_setup_var("FW_SEARCH_PATH", \@fqdirs));

  # WIRECELL_PATH.
  my $wp_pathspec = get_pathspec($pi, 'set_wpdir') || {};
  $wp_pathspec->{path}
    and not $wp_pathspec->{fq_path}
    and error_exit(<<"EOF");
INTERNAL ERROR in print_dev_setup(): ups_to_cmake() should have been called first
EOF
  @fqdirs =
    map { m&\A/&msx ? $_ : File::Spec->catfile('${CETPKG_SOURCE}', $_); }
    @{ $wp_pathspec->{fq_path} || [] };
  $out->print(print_dev_setup_var("WIRECELL_PATH", \@fqdirs));

  # PYTHONPATH.
  $pi->{define_pythonpath} and $out->print(print_dev_setup_var(
    "PYTHONPATH",
    File::Spec->catfile(
      '${CETPKG_BUILD}', $libdir || ($pi->{fq_dir} || (), 'lib'))));

  # PATH.
  $fqdir = _fq_path_for($pi, 'bindir', 'bin')
    and $out->print(print_dev_setup_var(
      "PATH",
      [File::Spec->catfile('${CETPKG_BUILD}',  $fqdir),
       File::Spec->catfile('${CETPKG_SOURCE}', $fqdir)]));
  return;
} ## end sub print_dev_setup


sub print_dev_setup_var {
  my ($setup_var, $setup_val, $no_errclause) = @_;
  my @vals = (ref $setup_val eq 'ARRAY') ? @{$setup_val} : ($setup_val // ());
  my $result;
  my $out = IO::File->new(\$result, q(>))
    or error_exit("could not open memory stream to variable \$out");

  if (scalar @vals) {
    $out->print(
      "# $setup_var\n",
      "setenv $setup_var ",
      '"`dropit -p \\"${',
      "$setup_var",
      '}\\" -sfe ');
    $out->print(join(q( ), map { sprintf('\\"%s\\"', $_); } @vals), q(`"));

    if ($no_errclause) {
      $out->print("\n");
    } else {
      $out->print("; ");
      _setup_err($out, "failure to prepend to $setup_var");
    }
  } ## end if (scalar @vals)
  $out->close();
  return $result // q();
} ## end sub print_dev_setup_var


sub table_dep_setup {
  my ($dep, $dep_info, $fh) = @_;
  my @setup_cmd_args = (
    $dep,
    ($dep_info->{version} ne '-c') ? $dep_info->{version} : (),
    $dep_info->{qualspec}
    ? (
      '-q',
      sprintf("+%s",
        join(q(:+), split(/:/msx, $dep_info->{qualspec} || q()))))
    : ());
  $fh->printf(
    "setup%s(%s)\n",
    ($dep_info->{optional}) ? "Optional" : "Required",
    join(q( ), @setup_cmd_args));
  return;
} ## end sub table_dep_setup


sub ups_to_cmake {
  my ($pi)       = @_;
  my $pv_prefix  = "CET_PV_$pi->{project_variable_prefix}";
  my @cmake_args = ();

  # Compiler-related.
  foreach my $lang qw(C CXX Fortran) {
    exists $pi->{"${lang}_COMPILER"}
      and push @cmake_args,
      "-DCMAKE_${lang}_COMPILER:STRING=$pi->{\"${lang}_COMPILER\"}";

    foreach my $item qw(ID VERSION) {
      exists $pi->{"${lang}_COMPILER_$item"}
        and push @cmake_args,
"-DUPS_${lang}_COMPILER_$item:STRING=$pi->{\"${lang}_COMPILER_$item\"}";
    } ## end foreach my $item qw(ID VERSION)
  } ## end foreach my $lang qw(C CXX Fortran)
  exists $pi->{CXX_STANDARD}
    and push @cmake_args, "-DCMAKE_CXX_STANDARD:STRING=$pi->{CXX_STANDARD}",
    "-DCMAKE_CXX_STANDARD_REQUIRED:BOOL=ON",
    "-DCMAKE_CXX_EXTENSIONS:BOOL=OFF";

  # Pathspec-related.
  push @cmake_args, _pathspecs_to_cmake($pi, $pv_prefix);

  # UPS-specific.
  push @cmake_args, '-DWANT_UPS:BOOL=ON';
  push @cmake_args, _cmake_defs_for_ups_config($pi, $pv_prefix);

  # Other.
  push @cmake_args, "-DCET_PV_PREFIX:STRING=$pi->{project_variable_prefix}";
  $pi->{cmake_build_type}
    and push @cmake_args, "-DCMAKE_BUILD_TYPE:STRING=$pi->{cmake_build_type}";
  $pi->{fq_dir}
    and push @cmake_args, "-D${pv_prefix}_EXEC_PREFIX:STRING=$pi->{fq_dir}";
  $pi->{noarch} and push @cmake_args, "-D${pv_prefix}_NOARCH:BOOL=ON";
  $pi->{define_pythonpath}
    and push @cmake_args, "-D${pv_prefix}_DEFINE_PYTHONPATH:BOOL=ON";
  $pi->{old_style_config_vars}
    and push @cmake_args, "-D${pv_prefix}_OLD_STYLE_CONFIG_VARS:BOOL=ON";

  ##################
  # Done.
  return \@cmake_args;
} ## end sub ups_to_cmake


sub write_table_deps {
  my ($parent, $deps) = @_;
  my $fh = IO::File->new("table_deps_$parent", q(>))
    or error_exit("Unable to open table_deps_$parent for write");

  foreach my $dep (sort keys %{$deps}) {
    my $dep_info = $deps->{$dep};
    $dep_info->{only_for_build} or table_dep_setup($dep, $dep_info, $fh);
  }
  $fh->close();
  return;
} ## end sub write_table_deps


sub write_table_frag {
  my ($parent, $pfile) = @_;
  my $fraglines = get_table_fragment($pfile);

  if ($fraglines and scalar @{$fraglines}) {
    my $fh = IO::File->new("table_frag_$parent", q(>))
      or error_exit("Unable to open table_frag_$parent for write");
    $fh->print(join("\n", @{$fraglines}), "\n");
    $fh->close();
  } else {
    unlink("table_frag_$parent");
  }
  return;
} ## end sub write_table_frag

########################################################################
# Private variables
########################################################################
$_cqual_table =
  { e15 => ['gcc', 'g++', 'GNU', '6.4.0',  '14', 'gfortran', 'GNU', '6.4.0'],
    e17 => ['gcc', 'g++', 'GNU', '7.3.0',  '17', 'gfortran', 'GNU', '7.3.0'],
    e19 => ['gcc', 'g++', 'GNU', '8.2.0',  '17', 'gfortran', 'GNU', '8.2.0'],
    e20 => ['gcc', 'g++', 'GNU', '9.3.0',  '17', 'gfortran', 'GNU', '9.3.0'],
    e22 => ['gcc', 'g++', 'GNU', '10.3.0', '17', 'gfortran', 'GNU', '10.3.0'],
    e24 => ['gcc', 'g++', 'GNU', '10.3.0', '17', 'gfortran', 'GNU', '10.3.0'],
    e25 => ['gcc', 'g++', 'GNU', '11.3.0', '17', 'gfortran', 'GNU', '11.3.0'],
    e26 => ['gcc', 'g++', 'GNU', '12.1.0', '17', 'gfortran', 'GNU', '12.1.0'],
    c2 => [
      'clang',    'clang++', 'Clang', '5.0.1', '17', #
      'gfortran', 'GNU',     '6.4.0'
          ],
    c5 => [
      'clang',    'clang++', 'Clang', '6.0.1', '17', #
      'gfortran', 'GNU',     '8.2.0'
          ],
    c7 => [
      'clang',    'clang++', 'Clang', '7.0.0', '17',     #
      'gfortran', 'GNU',     '8.2.0'
          ],
    c13 => [
      'clang',    'clang++', 'Clang', '14.0.6', '17',    #
      'gfortran', 'GNU',     '12.1.0'
           ],
  };

########################################################################
# Private functions
########################################################################
sub _add_compiler_info {
  my ($pi) = @_;
  $pi->{cqual} or return;
  exists $_cqual_table->{ $pi->{cqual} }
    and my ($cc, $cxx, $compiler_id, $compiler_version, $cxx_standard, $fc,
      $fc_id, $fc_version)
    = @{ $_cqual_table->{ $pi->{cqual} } }
    or error_exit(<<"EOF");
unrecognized compiler qualifier $pi->{cqual} in $pi->{pfile}"
EOF

  foreach my $lang qw(C CXX) {
    $pi->{"${lang}_COMPILER_ID"}      = $compiler_id;
    $pi->{"${lang}_COMPILER_VERSION"} = $compiler_version;
  }
  $pi->{C_COMPILER}               = $cc;
  $pi->{CXX_COMPILER}             = $cxx;
  $pi->{Fortran_COMPILER}         = $fc;
  $pi->{Fortran_COMPILER_ID}      = $fc_id;
  $pi->{Fortran_COMPILER_VERSION} = $fc_version;
  $pi->{CXX_STANDARD}             = $cxx_standard;
  return;
} ## end sub _add_compiler_info


sub _cmake_cetb_compat_defs {
  return [map { "-DCETB_COMPAT_$_:STRING=$PATH_VAR_TRANSLATION_TABLE->{$_}"; }
          sort keys $PATH_VAR_TRANSLATION_TABLE];
}


sub _cmake_defs_for_ups_config {
  my ($pi, $pv_prefix) = @_;
  my @cmake_args = ();
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  $pi->{name}
    and push @cmake_args,
    "-D${pv_prefix}_UPS_PRODUCT_NAME:STRING=$pi->{name}";
  $pi->{version}
    and push @cmake_args,
    "-D${pv_prefix}_UPS_PRODUCT_VERSION:STRING=$pi->{version}";
  $pi->{qualspec}
    and push @cmake_args,
    "-D${pv_prefix}_UPS_QUALIFIER_STRING:STRING=$pi->{qualspec}";
  push @cmake_args, "-D${pv_prefix}_UPS_PRODUCT_FLAVOR:STRING=$pi->{flavor}";
  $pi->{build_only_deps} and push @cmake_args,
    sprintf("-D${pv_prefix}_UPS_BUILD_ONLY_DEPENDENCIES=%s",
      join(q(;), @{ $pi->{build_only_deps} }));
  $pi->{chains} and push @cmake_args,
    sprintf("-D${pv_prefix}_UPS_PRODUCT_CHAINS=%s",
      join(q(;), (sort @{ $pi->{chains} })));
  $pi->{build_only_deps} and List::MoreUtils::any { $_ eq 'cetbuildtools' }
  @{ $pi->{build_only_deps} }
    and push @cmake_args, @{ _cmake_cetb_compat_defs() };
  return @cmake_args;
} ## end sub _cmake_defs_for_ups_config


sub _cmake_project_var_for_pathspec {
  my ($pi, $dirkey) = @_;
  my $pathspec = get_pathspec($pi, $dirkey);
  $pathspec and $pathspec->{key} or return;
  my $var_stem = $pathspec->{var_stem} || var_stem_for_dirkey($dirkey);
  $pathspec->{var_stem} = $var_stem;
  my $pv_prefix = "CET_PV_$pi->{project_variable_prefix}";
  exists $pathspec->{path} or return "-D${pv_prefix}_${var_stem}=";
  my @result_elements = ();

  if (ref $pathspec->{key}) { # PATH-like.
    foreach my $pskey (@{ $pathspec->{key} }) {
      pathkey_is_valid($pskey)
        or error_exit("unrecognized pathkey $pskey for $dirkey");
      my $path = shift @{ $pathspec->{path} };

      if ($pskey eq q(-)) {
        $path or last;
        $path =~ m&\A/&msx
          or error_exit("non-empty path $path must be absolute",
            "with pathkey \`$pskey' for directory key $dirkey");
      } elsif ($pskey eq 'fq_dir'
        and $pi->{fq_dir}
        and not $path =~ m&\A/&msx) {

        # Prepend EXEC_PREFIX here to avoid confusion with defaults in CMake.
        $path = File::Spec->catfile($pi->{fq_dir}, $path);
      } elsif ($path =~ m&\A/&msx) {
        warning(
          "redundant pathkey $pskey ignored for absolute path $path",
          "specified for directory key $dirkey: use '-' as a placeholder.");
      } ## end elsif ($path =~ m&\A/&msx) [ if ($pskey eq q(-)) ]
      push @result_elements, $path;
    } ## end foreach my $pskey (@{ $pathspec...})
    $pathspec->{fq_path} = [@result_elements];
  } else {

    # Single non-elided value.
    push @result_elements, $pathspec->{path};
  } ## end else [ if (ref $pathspec->{key...})]
  (scalar @result_elements != 1 or $result_elements[0])
    and return
    sprintf("-D${pv_prefix}_${var_stem}=%s", join(q(;), @result_elements));
  return;
} ## end sub _cmake_project_var_for_pathspec


sub _fq_path_for {
  my ($pi, $dirkey, $default) = @_;
  my $pathspec =
    get_pathspec($pi, $dirkey) || { key => q(-), path => $default };
  my $fq_path = $pathspec->{fq_path} // q();

  if (not($fq_path or ($pathspec->{key} eq q(-) and not $pathspec->{path}))) {
    local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
    my $want_fq = $pi->{fq_dir}
      && (
        $pathspec->{key} eq 'fq_dir'
        or ($pathspec->{key} eq q(-)
          and List::MoreUtils::any { $_ eq $dirkey } qw(bindir libdir)));
    $fq_path = File::Spec->catfile($want_fq ? $pi->{fq_dir} : (),
      $pathspec->{path} || $default || ());
  } ## end if (not($fq_path or ($pathspec...)))
  return $fq_path;
} ## end sub _fq_path_for


sub _get_info_from_csvf_cmd {
  my ($cmd_infos, $cmd_info, $cmake_file, $options) = @_;
  $_cm_state->{seen_cmds}->{project}
    and not $_cm_state->{seen_cmds}->{cet_cmake_env}
    or return;
  my $cmake_project_name =
    $cmd_info->has_keyword('PROJECT')
    ? interpolated($cmd_info->single_value_for('PROJECT'))
    : $_cm_state->{cmake_info}->{cmake_project_name};
  my $version_file =
    interpolated($cmd_info->single_value_for('VERSION_FILE'))
    // "\${${cmake_project_name}_SOURCE_DIR}/VERSION";
  $cmd_info->has_keyword('EXTENDED_VERSION_SEMANTICS')
    and $_cm_state->{cmake_info}->{EXTENDED_VERSION_SEMANTICS} = 1;
  return _set_version_from_file($cmd_info, $cmake_file, $cmake_project_name,
    $version_file);
} ## end sub _get_info_from_csvf_cmd


sub _get_info_from_file_cmd {
  my ($cmd_infos, $cmd_info, $cmake_file, $options) = @_;
  $_cm_state->{seen_cmds}->{project}
    and not $_cm_state->{seen_cmds}->{cet_cmake_env}
    or return;
  my $cmake_project_name = $_cm_state->{cmake_info}->{cmake_project_name};
  my $cmd                = $cmd_info->interpolated_arg_at(0);
  $cmd eq 'READ' or return;
  my $result_var = $cmd_info->interpolated_arg_at($cmd_info->last_arg_idx);
  $result_var eq "${cmake_project_name}_CMAKE_PROJECT_VERSION_STRING"
    or $result_var eq '${PROJECT_NAME}_CMAKE_PROJECT_VERSION_STRING'
    or return;
  my $version_file = $cmd_info->interpolated_arg_at(1);
  return _set_version_from_file($cmd_info, $cmake_file, $cmake_project_name,
    $version_file);
} ## end sub _get_info_from_file_cmd


sub _get_info_from_project_cmd {
  my ($cmd_infos, $cmd_info, $cmake_file, $options) = @_;
  my $qw_saver = # RAII for Perl.
    Cetmodules::Util::VariableSaver->new(\$Cetmodules::QUIET_WARNINGS,
      $options->{quiet_warnings} ? 1 : 0);

  if ($_cm_state->{seen_cmds}->{project}) {
    info(\*STDERR, <<"EOF");
ignoring superfluous project() at $cmake_file:$cmd_info->{start_line}: previously seen at line $_cm_state->{seen_cmds}->{project}
EOF
    return;
  } elsif ($_cm_state->{seen_cmds}->{cet_cmake_env}) {
    warning(<<"EOF");
ignoring project() at $cmake_file:$cmd_info->{start_line} following previous cet_cmake_env() at line $_cm_state->{seen_cmds}->{cet_cmake_env}
EOF
    return;
  } ## end elsif ($_cm_state->{seen_cmds... [ if ($_cm_state->{seen_cmds...})]})
  $_cm_state->{seen_cmds}->{project} = $cmd_info->{start_line};
  my ($project_name, $is_literal) = $cmd_info->interpolated_arg_at(0);
  $project_name or error_exit(<<"EOF");
unable to find name in project() at $cmake_file:$cmd_info->{start_line}
EOF

  if (not $is_literal) { # Simple variable substitution.
    while ($project_name =~ m&\G\$\{([A-Za-z_-][A-Za-z0-9_-]*)\}&msxg) {
      my $found_var = $1;
      my $found_val = ($_cm_state->{cmake_info}->{$found_var}) // q();
      $project_name =~ s&\$\{\Q$found_var\E\}&$found_val&msxg;
    } ## end while ($project_name =~ ...)

    if (not can_interpolate($project_name)) {
      warning(<<"EOF");
unable to interpret $project_name as a literal CMake project name in $cmd_info->{name}() at $cmake_file:$cmd_info->{chunk_locations}->{$cmd_info->{arg_indexes}->[0]}
EOF
      return;
    } ## end if (not can_interpolate...)
  } ## end if (not $is_literal)
  $_cm_state->{cmake_info}->{cmake_project_name} = $project_name;
  my $version_idx =
    $cmd_info->find_single_value_for('VERSION', @PROJECT_KEYWORDS) // return;

  # We have a VERSION keyword and value.
  my $version;
  ($version, $is_literal) = $cmd_info->interpolated_arg_at($version_idx);
  $is_literal or do {
    my $version_arg_location = $cmd_info->arg_location($version_idx);
    warning(<<"EOF");
nonliteral version "$version" found at $cmake_file:$version_arg_location
EOF
    return;
  };
  @{ $_cm_state->{cmake_info} }
    {qw(cmake_project_version cmake_project_version_info)} =
    ($version, parse_version_string($version));
  return;
} ## end sub _get_info_from_project_cmd


sub _get_info_from_set_cmds {
  my ($cmd_infos, $cmd_info, $cmake_file, $options) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $qw_saver = # RAII for Perl.
    Cetmodules::Util::VariableSaver->new(\$Cetmodules::QUIET_WARNINGS,
      $options->{quiet_warnings} ? 1 : 0);
  my ($found_pvar) =
    (($cmd_info->interpolated_arg_at(0) // return) =~
      m&(?:\A|_)(EXTENDED_VERSION_SEMANTCS|CMAKE_PROJECT_VERSION_STRING)\z&msx
    );
  $found_pvar
    or (($cmd_info->{post} // q()) =~ m&(?:\A|\s+)\#\#\s+CET-VAR\b&msx
      and $found_pvar = $cmd_info->interpolated_arg_at(0))
    or return;

  if ($_cm_state->{seen_cmds}->{cet_cmake_env}) {
    warning(<<"EOF");
$cmd_info->{name}($found_pvar ...) ignored at $cmake_file:$cmd_info->{start_line} due to previous cet_cmake_env() at line $_cm_state->{seen_cmds}->{cet_cmake_env}
EOF
    return;
  } ## end if ($_cm_state->{seen_cmds...})
  $_cm_state->{cmake_info}->{$found_pvar} =
    $cmd_info->interpolated_arg_at(1);
  return;
} ## end sub _get_info_from_set_cmds


sub _pathspecs_to_cmake {
  my ($pi, $pv_prefix) = @_;
  my @results =
    (map { _cmake_project_var_for_pathspec($pi, $_) // (); }
      keys %{$PATHSPEC_INFO});
  my @arch_pathspecs   = ();
  my @noarch_pathspecs = ();

  foreach my $pathspec (values %{ $pi->{pathspec_cache} }) {
    if (  $pathspec->{var_stem}
      and not ref $pathspec->{path}
      and $pathspec->{key} ne q(-)) {
      push @{ $pathspec->{key} eq 'fq_dir'
        ? \@arch_pathspecs
        : \@noarch_pathspecs }, $pathspec->{var_stem};
    } ## end if ($pathspec->{var_stem...})
  } ## end foreach my $pathspec (values...)
  scalar @arch_pathspecs and push @results,
    sprintf("-D${pv_prefix}_ADD_ARCH_DIRS:INTERNAL=%s",
      join(q(;), @arch_pathspecs));
  scalar @noarch_pathspecs and push @results,
    sprintf("-D${pv_prefix}_ADD_NOARCH_DIRS:INTERNAL=%s",
      join(q(;), @noarch_pathspecs));
  return @results;
} ## end sub _pathspecs_to_cmake


sub _path_var_translation_table {
  return {
      map {
        my $dirkey_ish = $_;
        $dirkey_ish =~ s&([^_])dir\z&${1}_dir&msx;
        ($dirkey_ish => var_stem_for_dirkey($_));
      } sort keys %{$PATHSPEC_INFO} };
} ## end sub _path_var_translation_table


sub _set_seen_cet_cmake_env {
  my ($cmd_infos, $cmd_info, $cmake_file, $options) = @_;
  my $cmd_line = $cmd_info->{start_line};
  my $qw_saver = # RAII for Perl.
    Cetmodules::Util::VariableSaver->new(\$Cetmodules::QUIET_WARNINGS,
      $options->{quiet_warnings} ? 1 : 0);
  $_cm_state->{seen_cmds}->{project} or error_exit(<<"EOF");
$cmd_info->{name}() at $cmake_file:$cmd_line MUST follow project()"
EOF
  $_cm_state->{seen_cmds}->{cet_cmake_env} and error_exit(<<"EOF");
prohibited duplicate $cmd_info->{name}() at $cmake_file:$cmd_line: already seen at line $_cm_state->{seen_cmds}->{cet_cmake_env}
EOF
  $_cm_state->{seen_cmds}->{cet_cmake_env} = $cmd_line;
  return;
} ## end sub _set_seen_cet_cmake_env


sub _set_version {
  my ($pi, $cpi, $sourcedir) = @_;

  if ($cpi->{CMAKE_PROJECT_VERSION_STRING}) {
    my $cmake_version_info =
      parse_version_string($cpi->{CMAKE_PROJECT_VERSION_STRING});
    ($pi->{version} // q()) ne q()
      and $pi->{version} ne to_ups_version($cmake_version_info)
      and warning(<<"EOF");
UPS product $pi->{name} version $pi->{version} from product_deps overridden by project variable $cpi->{CMAKE_PROJECT_VERSION_STRING} from $sourcedir/CMakeLists.txt
EOF
    $pi->{version}               = to_ups_version($cmake_version_info);
    $pi->{cmake_project_version} = to_version_string($cmake_version_info);
  } elsif ($cpi->{cmake_project_version_info}) {
    ($pi->{version} // q()) ne q()
      and to_cmake_version($pi->{version}) ne $cpi->{cmake_project_version}
      and warning(<<"EOF");
UPS product $pi->{name} version $pi->{version} from product_deps overridden by VERSION $cpi->{cmake_project_version} from project() in $sourcedir/CMakeLists.txt
EOF
    $pi->{version} = to_ups_version($cpi->{cmake_project_version_info});
  } elsif ($pi->{version}) {
    my $version_info = parse_version_string($pi->{version});

    if ($version_info->{extra}) {
      $pi->{cmake_project_version} = to_version_string($version_info);
    }
  } else {
    warning(<<"EOF");
could not identify a product/project version from product_deps or $sourcedir/CMakeLists.txt.
Ensure version is set in product_deps or with project() or CMAKE_PROJECT_VERSION_STRING project variable in CMakeLists.txt
EOF
  } ## end else [ if ($cpi->{CMAKE_PROJECT_VERSION_STRING... [... [elsif ($pi->{version}) ]]})]
  return;
} ## end sub _set_version


sub _setup_err {
  my ($out, @msg_lines) = @_;
  $out->print('test "$?" != 0 && \\', "\n");

  for (@msg_lines) {
    chomp;
    $out->print("  echo \QERROR: $_\E && \\\n");
  }
  $out->print("  return 1 || true\n");
  return;
} ## end sub _setup_err


sub _set_version_from_file {
  my ($cmd_info, $cmake_file, $cmake_project_name, $version_file) = @_;
  my ($project_source_dir, $project_binary_dir) = (
    defined $ENV{MRB_SOURCE}
      and (not defined $ENV{CETPKG_SOURCE}
        or abs_path($ENV{CETPKG_SOURCE}) eq abs_path($ENV{MRB_SOURCE})))
    ? (
      File::Spec->catfile($ENV{MRB_SOURCE},   $cmake_project_name),
      File::Spec->catfile($ENV{MRB_BUILDDIR}, $cmake_project_name))
    : ($ENV{CETPKG_SOURCE}, $ENV{CETPKG_BUILD});
  my $dirvar_start =
qr&\A\$\{(?:(?:CMAKE_)?PROJECT|\$\{PROJECT_NAME\}|\Q$cmake_project_name\E)&msx;
  my $dirvar_end = qr&DIR\}&msx;
  $version_file =~
    s&${dirvar_start}_SOURCE_${dirvar_end}&$project_source_dir&msx;
  $version_file =~
    s&${dirvar_start}_BINARY_${dirvar_end}&$project_binary_dir&msx;
  debug(<<"EOF");
attempting to read $cmake_project_name version from $version_file
EOF
  my $fh = IO::File->new($version_file, q(<)) or warning(<<"EOF")
unable to read $cmake_project_name version from $version_file per $cmake_file:$cmd_info->{start_line}
EOF
    or return;
  my $version = $fh->getline();
  chomp $version;
  $fh->close();
  $_cm_state->{cmake_info}->{VERSION_FILE}                 = $version_file;
  $_cm_state->{cmake_info}->{CMAKE_PROJECT_VERSION_STRING} = $version;
  return;
} ## end sub _set_version_from_file


sub _setup_from_libdir {
  my ($pi, $out, $libdir) = @_;

  # (DY)LD_LIBRARY_PATH.
  $out->print(print_dev_setup_var(
    sprintf("%sLD_LIBRARY_PATH",
      ($pi->{flavor} =~ m&\bDarwin\b&msx) ? "DY" : q()),
    File::Spec->catfile('${CETPKG_BUILD}', $libdir)));

  # CET_PLUGIN_PATH. We only want to add to this if it's already set
  # or we're cetlib, which is the package that makes use of it.
  my ($head, @output) = split(
    /\n/msx,
    print_dev_setup_var(
      "CET_PLUGIN_PATH", File::Spec->catfile('${CETPKG_BUILD}', $libdir)));
  $out->print(
    "$head\n",
    ($pi->{name} ne 'cetlib')
    ? "test -z \"\${CET_PLUGIN_PATH}\" || \\\n  "
    : q(),
    join("\n", @output),
    "\n");
  return;
} ## end sub _setup_from_libdir

########################################################################
1;
__END__
