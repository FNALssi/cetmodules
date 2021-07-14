########################################################################
# parse_deps.pm
#
#   Parse the information to be found in a package's ups/product_deps
#   file.
#
# For a full description of the product_deps file format, see comments
# to cetmodules/ups-templates/product_deps.template.in.
########################################################################

package parse_deps;

use strict;
use warnings;
use warnings::register;

use Cwd qw(abs_path);
use Digest::SHA;
use File::Basename qw(basename dirname);
use File::Spec; # For catfile;
use FindBin;

use Exporter 'import';
our (@EXPORT, @EXPORT_OK);

use vars qw($btype_table $pathspec_info $VERBOSE $QUIET);

FindBin::again();

$pathspec_info =
  {
   bindir => { },
   cmakemoduledir => { project_var => 'CMAKE_MODULES_DIR' },
   fcldir => { project_var => 'FHICL_DIR' },
   fwdir => { },
   gdmldir => { },
   incdir => { project_var => 'INCLUDE_DIR' },
   libdir => { project_var => 'LIBRARY_DIR' },
   perllib => { },
   set_fwdir => { multiple_ok => 1, project_var => "FW_SEARCH_PATH" },
   set_wpdir => { multiple_ok => 1, project_var => "WIRECELL_PATH" },
   testdir => { },
   wpdir =>  { }
  };

my @known_keywords =
  qw(chain
     chains
     defaultqual
     define_pythonpath
     end_product_list
     end_qualifier_list
     no_fq_dir
     noarch
     parent
     old_style_config_vars
     product
     qualifier
     table_fragment_begin
     table_fragment_end
   );
push @known_keywords, sort keys %$pathspec_info;

my $chain_option_table =
  {
   -c => 'current',
   -d => 'development',
   -n => 'new',
   -o => 'old',
   -t => 'test'
  };

$btype_table = { debug => 'Debug',
                 prof => 'RelWithDebInfo',
                 opt => 'Release' };

@EXPORT =
  qw(
      cetpkg_info_file
      classify_deps
      cmake_cetb_compat_defs
      compiler_for_quals
      deps_for_quals
      error_exit
      get_CMakeLists_hash
      get_cmake_project_info
      get_derived_parent_data
      get_parent_info
      get_pathspec
      get_product_list
      get_qualifier_matrix
      get_table_fragment
      info
      notify
      print_dep_setup
      print_dep_setup_one
      print_dev_setup
      shortest_unique_prefix
      sort_qual
      table_dep_setup
      to_cmake_version
      to_dot_version
      to_string
      to_ups_version
      to_version_string
      ups_to_cmake
      var_stem_for_dirkey
      verbose
      version_sort
      version_cmp
      warning
      write_table_deps
      write_table_frag
   );

@EXPORT_OK = qw($btype_table $pathspec_info parse_version_string setup_err);

sub error_exit {
  my (@msg) = @_;
  chomp @msg;
  print STDERR map { "ERROR: $_\n"; } ("", (map { split("\n") } @msg), "");
  exit 1;
}

sub warning {
  my (@msg) = @_;
  chomp @msg;
  print STDERR map { "WARNING: $_\n"; } ("", (map { split("\n") } @msg), "");
}

sub notify {
  my (@msg) = @_;
  chomp @msg;
  print map { "INFO: $_\n"; } map { split("\n") } @msg;
}

sub info {
  notify(@_) unless $parse_deps::QUIET;
}

sub verbose {
  return unless $parse_deps::VERBOSE;
  my (@msg) = @_;
  chomp @msg;
  print map { "VERBOSE: $_\n"; } map { split("\n") } @msg;
}

sub get_parent_info {
  my ($pfile, %options) = @_;
  open(my $fh, "<", "$pfile") or error_exit("couldn't open $pfile");
  my $result = { pfile => $pfile };
  my $chains;
  while (<$fh>) {
    chomp;
    s&\s*\#.*$&&;
    m&\w+& or next;
    my ($keyword, @pars) = split;
    if ($keyword eq "parent") {
      warning("multi-argument version of \"parent\" in $pfile",
              "is deprecated: VERSION defined via project() or",
              "via <project>_CMAKE_PROJECT_VERSION_STRING in",
              "CMakeLists.txt governs.",
              "Use \"chain[s] [current|test|new|old|<chain>] ...\" in",
              "$pfile to specify chains.")
        if ($pars[1] and not $options{quiet_warnings});
      $result->{name} = shift @pars;
      $result->{version} = shift @pars if $pars[0];
      @$chains{@pars} = (1) x scalar @pars if scalar @pars;
    } elsif ($keyword =~ m&^chains?$&) {
      @$chains{@pars} = (1) x scalar @pars if scalar @pars;
    } elsif ($keyword eq "defaultqual") {
      $result->{default_qual} = sort_qual(@pars);
      $result->{default_qual} =~ m&^-nq-?$& and $result->{default_qual} = "";
    } elsif (grep { $_ eq $keyword; }
             qw(define_pythonpath
                no_fq_dir
                noarch
                old_style_config_vars)) {
      scalar @pars and
        warning(sprintf("unexpected garbage following $keyword: %s",
                        join(" ", @pars)));
      $result->{$keyword} = 1;
    } else {
    }
  }
  close($fh);
  # Make the chain list, translating -c... ups declare options to their
  # corresponding chain names.
  $result->{chains} = [ sort map { exists $chain_option_table->{$_} ?
                                     $chain_option_table->{$_} : $_; }
                        keys %$chains ]
    if scalar keys %$chains;
  return $result;
}

sub get_CMakeLists_hash {
  return Digest::SHA::sha256_hex(abs_path(File::Spec->catfile(shift, 'CMakeLists.txt')));
}

sub get_derived_parent_data {
  my ($pi, $sourcedir, @qualstrings) = @_;

  # CMake info.
  my $cpi = get_cmake_project_info($sourcedir,
                                   ($pi->{version}) ?
                                   (quiet_warnings => 1) : ());

  unless (defined $pi->{name}) {
    if ($cpi->{cmake_project_name} and not
        $cpi->{cmake_project_name} =~ m&\$&) {
      $pi->{name} = to_product_name($cpi->{cmake_project_name});
    } else {
      error_exit(<<EOF);
UPS product name not specified in product_deps and could not identify an
unambiguous project name in CMakeLists.txt
EOF
    }
  }

  if (exists $cpi->{version_info} and $cpi->{version_info}->{extra}) {
    error_exit(sprintf(<<EOF, $cpi->{cmake_project_version}, $cpi->{version_info}->{extra}, $cpi->{cmake_project_version}));
VERSION as specified in CMakeLists.txt:project() (%s) has an
impermissible non-numeric component "%s": remove from project()
and set \${PROJECT_NAME}_CMAKE_PROJECT_VERSION_STRING to %s
before calling cet_cmake_env()
EOF
  }

  if ($cpi->{CMAKE_PROJECT_VERSION_STRING}) {
    my $cmake_version_info = parse_version_string($cpi->{CMAKE_PROJECT_VERSION_STRING});
    if ($pi->{version} and $pi->{version} ne to_ups_version($cmake_version_info)) {
      warning("UPS product version $pi->{version} from product_deps overridden by project variable $cpi->{CMAKE_PROJECT_VERSION_STRING} from CMakeLists.txt");
    }
    $pi->{version} = to_ups_version($cmake_version_info);
    $pi->{cmake_project_version} = to_version_string($cmake_version_info);
  } elsif ($cpi->{version_info}) {
    if ($pi->{version} and to_cmake_version($pi->{version}) ne $cpi->{cmake_project_version}) {
      warning("UPS product version $pi->{version} from product_deps overridden by VERSION $cpi->{cmake_project_version} from project() in CMakeLists.txt");
    }
    $pi->{version} = to_ups_version($cpi->{version_info});
  } elsif ($pi->{version}) {
    my $version_info = parse_version_string($pi->{version});
    if ($version_info->{extra}) {
      $pi->{cmake_project_version} = to_version_string($version_info);
    }
  } else {
    warning("could not identify a product/project version from product_deps or CMakeLists.txt. Ensure version is set in product_deps or with project() or CMAKE_PROJECT_VERSION_STRING project variable in CMakeLists.txt.");
  }

  my @sorted;
  $pi->{qualspec} = sort_qual(\@sorted, @qualstrings);
  @{$pi}{qw(cqual extqual build_type)} = @sorted;
  $pi->{cmake_build_type} = $btype_table->{$pi->{build_type}}
    if $pi->{build_type};

  # Derivatives of the product's UPS flavor.
  if ($pi->{no_fq_dir}) {
    $pi->{flavor} = "NULL";
  } else {
    my $fq_dir;
    my $flavor = `ups flavor -4`;
    error_exit("failure executing ups flavor: UPS not set up?") if $!;
    chomp $flavor;
    # We only care about OS major version no. for Darwin.
    $flavor =~ s&^(Darwin.*?\+\d+).*$&${1}&;
    $pi->{flavor} = $flavor;
    if ($pi->{noarch}) {
      $fq_dir = 'noarch';
    } else {
      $fq_dir = $ENV{CET_SUBDIR} or
        error_exit("CET_SUBDIR not set: missing cetpkgsupport?");
    }
    $pi->{fq_dir} = join('.', $fq_dir, split(':', $pi->{qualspec}));
  }
}

sub get_table_fragment {
  my $pfile = shift;
  my $reading_frag;
  my @fraglines = ();
  open(my $fh, "<", "$pfile") or error_exit("couldn't open $pfile");
  while (<$fh>) {
    chomp;
    next if (m&^\s*#& and not $reading_frag);
    m&^\s*table_fragment_end& and undef $reading_frag;
    push @fraglines, $_ if $reading_frag;
    m&^\s*table_fragment_begin& and $reading_frag = 1;
  }
  close($fh);
  return (scalar @fraglines) ? \@fraglines : undef;
}

sub dirkey_is_valid {
  my $dirkey = shift;
  return $dirkey && grep { $_ eq $dirkey } keys %{$pathspec_info};
}

my $valid_pathkeys = [ "product_dir", "fq_dir", "-" ];

sub pathkey_is_valid {
  my $pathkey = shift;
  return $pathkey && grep { $_ eq $pathkey } @$valid_pathkeys;
}

sub get_pathspec {
  my ($pi, $dirkey) = @_;
  error_exit("unrecognized directory key $dirkey")
    if not dirkey_is_valid($dirkey);
  $pi->{pathspec_cache} = {} unless exists $pi->{pathspec_cache};
  my $pathspec_cache = $pi->{pathspec_cache};
  unless ($pathspec_cache->{$dirkey}) {
    my $multiple_ok = $pathspec_info->{$dirkey}->{multiple_ok} || 0;
    open(PD, "<", "$pi->{pfile}") or error_exit("couldn't open $pi->{pfile}");
    my ($seen_dirkey, $pathkeys, $dirnames) = (undef, [], []);
    while (<PD>) {
      chomp;
      # Skip full-line comments and whitespace-only lines.
      next if m&^\s*#&o or !m&\S&o;
      my ($found_dirkey, $pathkey, $dirname) = (m&^\s*(\Q$dirkey\E)\b(?:\s+(\S+)\s*(\S*?))?(?:\s*#.*)?$&);
      next unless $found_dirkey;
      error_exit("dangling directory key $dirkey seen in $pi->{pfile} at line $.:",
                 "path key is required") unless $pathkey;
      error_exit("unrecognized path key $pathkey for directory key $dirkey in $pi->{pfile}",
                 " at line $.") unless pathkey_is_valid($pathkey);

      if ($seen_dirkey) {
        error_exit("illegal duplicate directory key $dirkey seen in $pi->{pfile} ",
                   "at line $. (first seen at line $seen_dirkey)")
          unless $multiple_ok;
        error_exit("elision request (pathkey '-' with no path) at line $.",
                   "is only valid for the first mention of a directory key",
                   "($dirkey first seen at line $seen_dirkey)")
          if ($pathkey eq "-" and not $dirname);
      } else {
        $seen_dirkey = $.;
      }
      push @$pathkeys, $pathkey;
      if ($pathkey eq "-" and not $dirname) {
        undef $dirnames;
        last;
      }
      push @$dirnames, $dirname;
    }
    close(PD);
    $pathspec_cache->{$dirkey} =
      { key => (scalar @$pathkeys > 1) ? $pathkeys : $pathkeys->[0],
        (defined $dirnames) ?
        (path => (scalar @$dirnames > 1) ? $dirnames : $dirnames->[0]) : () }
        if $seen_dirkey;
  }
  return $pathspec_cache->{$dirkey};
}

sub get_product_list {
  my ($pfile) = @_;
  open(my $fh, "<", "$pfile") or error_exit("couldn't open $pfile");
  my $get_phash;
  my $pv="";
  my $dqiter=-1;
  my $piter=-1;
  my $phash = {};
  my $pl_format = 1; # Default format.
  while (<$fh>) {
    chomp;
    s&\s*\#.*$&&;
    m&\w+& or next;
    my (@words) = split;
    my $keyword = $words[0];
    if ($keyword eq "end_product_list") {
      last; # Done.
    } elsif ($keyword eq "product") {
      $get_phash="true";
      if ($words[$#words] =~ /^<\s*(?:table_)?format\s*=\s*(\d+)\s*>/o) {
        $pl_format = ${1};
      }
    } elsif ($get_phash) {
      unwanted_keyword($keyword) and
        error_exit(sprintf("unexpected keyword $keyword at $pfile:%d - missing end_product_list?",
                           $fh->input_line_number));

      # Also covers archaic "only_for_build" lines: do *not* put a
      # special case above.
      ++$piter;
      my ($prod, $version, $qualspec, @modifiers) = @words;
      $qualspec = '-' unless $qualspec;
      @modifiers = () unless scalar @modifiers;

      if ($prod eq "only_for_build") {
        # Archaic form.
        ($prod, $version, $qualspec, @modifiers) =
          ($version, $qualspec, '-', $prod);
        warning("Deprecated only_for_build entry found in $pfile: please replace:\n",
                "  \"$_\"\n",
                "with\n",
                "  \"$prod\t$version\t$qualspec\t$modifiers[0]\"\n",
                "This accommodation will be removed in future.");
      }

      if ($qualspec and $qualspec eq "-nq-") {
        # Under format version 1, "-nq-" meant, "always." Since format
        # version 2, it means, "when we have no qualifiers," and "-"
        # means, "always."
        $qualspec = ($pl_format == 1) ? "-" : "";
      }

      $phash->{$prod}->{$qualspec} =
        {version => (($version eq "-") ? "-c" : $version),
         map { ($_ => 1) } @modifiers };
    } else {
    }
  }
  close($fh);
  return $phash;
}

sub deps_for_quals {
  my ($pfile, $phash, $qhash, $qualspec) = @_;
  my $results = {};
  foreach my $prod (sort keys %{$phash}) {
    # Find matching version hashes for this product, including default
    # and empty. $phash is the product list hash as produced by
    # get_product_list().
    my $matches =
      { map { match_qual($_, $qualspec) ?
                ( $_ => $phash->{${prod}}->{$_} ) : ();
            } sort keys %{$phash->{$prod}}
      };
    # Remove the default entry from the set of matches (if it exists)
    # and save it.
    my $default = delete $matches->{"-default-"}; # undef if missing.
    error_exit("ambiguous result matching version for dependency $prod against parent qualifiers $qualspec")
      if (scalar keys %{$matches} > 1);
    # Use $default if we need to.
    my $result = (values %{$matches})[0] || $default || next;
    $result = { %{$result} }; # Copy contents for amendment.
    if (exists $qhash->{$prod} and
        exists $qhash->{$prod}->{$qualspec}) {
      if ($qhash->{$prod}->{$qualspec} eq '-b-') {
        # Old syntax for unqualified build-only deps.
        $result->{only_for_build} = 1;
        $result->{qualspec} = '';
      } elsif ($qhash->{$prod}->{$qualspec} eq '-') {
        # Not needed here.
        next;
      } else {
        # Normal case.
        $result->{qualspec} = $qhash->{$prod}->{$qualspec} || '';
      }
    } elsif (not $result->{only_for_build}) {
      if (not exists $qhash->{$prod}) {
        error_exit("dependency $prod has no column in the qualifier table.",
                   "Please check $pfile");
      } else {
        error_exit(sprintf("dependency %s has no entry in the qualifier table for %s.",
                           $prod,
                           ($qualspec ? "parent qualifier $qualspec" :
                            "unqualified parent")),
                   "Please check $pfile");
      }
    } else {
      $result->{qualspec} = $qhash->{$prod}->{$qualspec} || '';
    }
    $results->{$prod} = $result;
  } # foreach $prod.
  return $results;
}

sub wanted_keyword {
  my ($keyword, @whitelist) = @_;
  return grep { $keyword eq $_ } @whitelist;
}

sub unwanted_keyword {
  my ($keyword, @whitelist) = @_;
  return (not grep { $keyword eq $_ } @whitelist and
          grep { $keyword eq $_ } @known_keywords);
}

sub get_qualifier_list {
  my ($pfile) = @_;
  my $get_quals;
  my $qlen = 0;
  my @qlist = ();
  my @notes = ();
  open(my $fh, "<", "$pfile") or error_exit("couldn't open $pfile");
  while (<$fh>) {
    chomp;
    s&\s*\#.*$&&;
    m&\w+& or next;
    my (@words) = split;
    my $keyword = $words[0];
    if ($keyword eq "end_qualifier_list") {
      last; # Done.
    } elsif ($keyword eq "qualifier") {
      $get_quals = 1;
      for (; $qlen < $#words and $words[$qlen + 1] ne "notes"; ++$qlen) { }
      push @notes, $words[$qlen + 1] || '';
      push @qlist, [@words[0..$qlen]];
    } elsif ($get_quals) {
      unwanted_keyword($keyword) and
        error_exit(sprintf("unexpected keyword $keyword at $pfile:%d - missing end_qualifier_list?",
                           $fh->input_line_number));
      scalar @words < $qlen and
        error_exit("require $qlen qualifier_list entries for $keyword: found only $#words");
      push @notes, $words[$qlen + 1] || '';
      push @qlist, [ map { (not $_ or $_ eq "-nq-") ? "" : sort_qual($_); }
                     @words[0..$qlen] ];
    } else {
    }
  }
  close($fh);
  return ($qlen, \@qlist, \@notes);
}

sub get_qualifier_matrix {
  my ($qlen, $qlist, $notes) = get_qualifier_list(shift);
  my ($qhash, $qqhash, $nhash, $headers); # (by-column, by-row, notes, headers)
  if ($qlist and scalar @$qlist) {
    my @prods = @{shift @$qlist}; # Drop header row from @$qlist.
    $qhash = { map { my $idx = $_; ( $prods[$idx] => { map { (@$_[0] => @$_[$idx]); } @$qlist } ); } 1..$qlen };
    $qqhash = { map { my @dq = @$_; ( $dq[0] => { map { ( $prods[$_] => $dq[$_] ); } 1..$qlen } ); } @$qlist };
    $headers = [@prods, shift @$notes || ()];
    $nhash = { map { ( $_->[0] => (shift @$notes or '')); } @$qlist };
  }
  return ($qlen, $qhash, $qqhash, $nhash, $headers);
}

sub match_qual {
  my ($match_spec, $qualstring) = @_;
  my @quals = split(/:/, $qualstring);
  my ($neg, $qual_spec) = ($match_spec =~ m&^(!)?(.*)$&);
  return ($qual_spec eq '-' or
          $qual_spec eq '-default-' or
          ($neg xor grep { $qual_spec eq $_ } @quals));
}

sub sort_qual {
  my ($cqual, $btype);
  # If the first argument is a reference to ARRAY, then it is an output
  # array reference for the result.
  my $sorted =
    ( $_[0] and (ref $_[0] || '') eq 'ARRAY') ? shift : [];
  my @extquals=();
  foreach my $q (map { s&^\+&&o; $_; } split(':', join(':', @_))) {
    if ($q =~ m&^[ce]\d+$&o) {
      error_exit("multiple primary qualifiers encountered: $cqual, $q")
        if $cqual;
      $cqual = $q;
    } elsif (exists $btype_table->{$q}) {
      error_exit("multiple build type qualifiers encountered: $btype, $q")
        if $btype;
      $btype = $q;
    } elsif ($q ne '-nq-') {
      push @extquals, $q;
    }
  }
  # Re-order.
  my $eq = join(':', sort @extquals);
  @$sorted = ($cqual, $eq, $btype);
  return join(':', map { $_ || (); } @$sorted);
}

sub output_info {
  my ($fh, $info, $for_export, @keys) = @_;
  my @defined_vars = ();
  foreach my $key (@keys) {
    my $var = "CETPKG_\U$key";
    $var="export $var" if grep { $var eq $_; } @$for_export;
    my $val = $info->{$key} || "";
    print $fh "$var=";
    if (not ref $val) {
      print $fh "\Q$val\E\n";
    } elsif (ref $val eq "SCALAR") {
      print $fh "\Q$$val\E\n";
    } elsif (ref $val eq "ARRAY") {
      printf $fh "(%s)\n", join(" ", map { "\Q$_\E" } @$val);
    } else {
      verbose(sprintf("ignoring unexpected info $key of type %s", ref $val));
    }
    push @defined_vars, $var;
  }
  return @defined_vars;
}

# Output information for buildtool.
sub cetpkg_info_file {
  my (%info) = @_;

  my @expected_keys =
    qw(source build name version cmake_project_version
       chains qualspec cqual build_type extqual use_time_deps
       build_only_deps cmake_args);
  my @for_export = (qw(CETPKG_SOURCE CETPKG_BUILD));
  my $cetpkgfile = File::Spec->catfile($info{build} || ".", "cetpkg_info.sh");
  open(my $fh, ">", "$cetpkgfile") or
    error_exit("couldn't open $cetpkgfile for write");
  print $fh <<'EOD';
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
  open(my $tmp_fh, ">", \$var_data);
  # Output known info in expected order, followed by any remainder in
  # lexical order.
  my @output_items =
    output_info($tmp_fh, \%info, \@for_export,
                (map { my $key = $_;
                       (grep { $key eq $_ } keys %info) ? ($key) : () }
                 @expected_keys),
              (map { my $key = $_;
                     (grep { $key eq $_ } @expected_keys) ? () : ($key) }
               sort keys %info));
  close($tmp_fh);
  open($tmp_fh, "<", \$var_data);
  while (<$tmp_fh>) {
    chomp;
    print $fh "\Q$_\E\$'\\n'\\\n";
  }
  close($tmp_fh);
  print $fh <<'EOD';
$'\n'\
__EOF__
( return 0 2>/dev/null ) && unset __EOF__ \
EOD
  print $fh "  || true\n";
  close($fh);
  chmod 0755, $cetpkgfile;
  return $cetpkgfile;
}

sub classify_deps {
  my ($pi, $dep_info) = @_;
  foreach my $dep (sort keys %{$dep_info}) {
    $pi->{($dep_info->{$dep}->{only_for_build}) ?
          'build_only_deps' : 'use_time_deps'}->{$dep} = 1;
  }
  foreach my $key (qw(build_only_deps use_time_deps)) {
    $pi->{$key} = [ sort keys %{$pi->{$key}} ];
  }
}

sub compiler_for_quals {
  my ($compilers, $qualspec) = @_;
  my $compiler;
  my @quals = split /:/o, $qualspec;
  if ($compilers->{$qualspec} and $compilers->{$qualspec} ne '-') {
    #print $dfile "product_setup_loop debug info: compiler entry for $qualspec is $compilers->{$qualspec}\n";
    $compiler = $compilers->{$qualspec};
  } elsif (grep /^(?:e13|c(?:lang)?\d+)$/o, @quals) {
    $compiler = "clang";
  } elsif (grep /^(?:e|gcc)\d+$/o, @quals) {
    $compiler = "gcc";
  } elsif (grep /^(?:i|icc)\d+$/o, @quals) {
    $compiler = "icc";
  } else {
    $compiler = "cc";           # Native.
  }
  return $compiler;
}

sub offset_annotated_items;

sub to_string {
  my $incremental_indent = 2;
  my $hash_indent = length('{ ');
  my $max_incremental_indent = 10;
  my $options = ((scalar @_ == 2) and (ref $_[1] eq 'HASH')) ? pop : {};
  my $indent = delete $options->{indent};
  $indent = (ref $_[0] and $#_ > 0 and not ref $_[$#_]) ? pop : 0
    unless defined $indent;
  my $item = ((scalar @_ > 1) ? [ @_ ] : shift @_) // "<undef>";
  if (exists $options->{preamble}) {
    my ($hanging_preamble) =
      ($options->{preamble} =~ m&^(?:.*?\n)*(.*?)[ 	]*$&);
    my $hplen = length($hanging_preamble);
    if ($hplen > $max_incremental_indent) {
      $indent += $incremental_indent;
    } else {
      $indent += $hplen + 1;
    }
  }
  my $type = ref $item;
  my $initial_indent = ($options->{full_indent}) ? ' ' x $options->{full_indent} : '';
  $indent += $options->{full_indent} if $options->{full_indent};
  my $result;
  if (not $type or $type eq "CODE") {
    $result = "$initial_indent$item";
  } elsif ($type eq "SCALAR") {
    $result = "$initial_indent$$item";
  } elsif ($type eq "ARRAY") {
    $result =
      sprintf("$initial_indent\%s ]", offset_annotated_items($indent, '[ ', @$item));
  } elsif ($type eq "HASH") {
    $indent += $hash_indent;
    $result =
      sprintf("${initial_indent}{ \%s }",
              join(sprintf(",\n\%s", ' ' x $indent),
                   map {
                     to_string($item->{$_},
                               { preamble => "$_ => ",
                                 indent => $indent });
                   } keys %$item));
    $indent -= $hash_indent;
  } else {
    print STDERR "ERROR: cannot print item of type $type.\n";
    exit(1);
  }
  return sprintf('%s%s', $options->{preamble} || '', $result);
}

sub offset_annotated_items {
  my ($offset, $preamble, @args) = @_;
  my $indent = length($preamble) + $offset;
  return sprintf('%s%s', $preamble,
                 join(sprintf(",\n\%s", ' ' x $indent),
                      map { to_string($_, { indent => $indent }); } @args));
}

# Sort order:
#
# alpha[[-_]NN] (alpha releases);
# beta[[-_]NN] (beta releases);
# rc[[-_]NN] or pre[[-_]NN] (release candidates);
# <empty>;
# p[-_]NN or patch[[-_]NN] (patch releases);
# nightly[[-_][NN|YYYYMMDD[HHmmSS[.s]]] or
#   snapshot[[-_][NN|YYYYMMDD[HHmmSS[.s]]] (snapshot releases)
# Anything else.
sub _parse_extra {
  my $vInfo = shift or die "INTERNAL ERROR in _parse_extra()";
  return $vInfo unless exists $vInfo->{extra} and $vInfo->{extra} ne '';
  my ($enum) = ($vInfo->{extra} =~ m&(\d+(?:\.\d*)?)$&);
  my ($etext) = (defined $enum ? ($vInfo->{extra} =~ m&^(.*?)[_.-]?\Q$enum\E$&) : $vInfo->{extra});
  my $etext_l = lc $etext;
  if ($etext eq '') {
    $vInfo->{extra_type} = 0;
  } elsif ($etext =~ m&(?:^|.+-)(?:nightly|snapshot)$&) {
    $vInfo->{extra_type} = 3 + ((exists $vInfo->{bits}) ? 0 : 100);
  } elsif (not exists $vInfo->{bits}) {
    $vInfo->{extra_type} = 101;
    undef $enum;
    $etext = $vInfo->{extra};
  } elsif ($etext_l eq "patch" or
           ($enum // '' ne '' and $etext_l eq "p")) {
    $vInfo->{extra_type} = 1;
  } elsif ($etext_l eq "rc" or $etext_l eq "pre") {
    $vInfo->{extra_type} = -1;
  } elsif ($etext_l eq "gamma") {
    $vInfo->{extra_type} = -2;
  } elsif ($etext_l eq "beta") {
    $vInfo->{extra_type} = -3;
  } elsif ($etext_l eq "alpha") {
    $vInfo->{extra_type} = -4;
  } else {
    $vInfo->{extra_type} = 2;
    $vInfo->{extra_text} = $etext_l
  }
  $vInfo->{extra_text} = $etext unless exists $vInfo->{extra_text};
  $vInfo->{extra_num} = $enum if defined $enum;
  return $vInfo;
}

sub parse_version_string {
  my $dv = shift // "";
  $dv =~ s&^v&&o;
  my $result = { };
  my $def_ps = '[-_.,]';
  my ($ps, $es);
  my @bits;
  foreach my $key (qw(major minor patch tweak)) {
    my $sep = (defined $ps) ? $ps : $def_ps;
    if ($dv ne '' and $dv =~ s&^(\d+)?($sep)?&&) {
      $ps = "[$2]" if defined $2 and not defined $ps;
      $result->{$key} = $1 if defined $1;
    } else {
      last;
    }
  }
  $dv =~ s&^$def_ps&& unless $2;
  $result->{extra} = $dv if $dv ne '';
  # Make sure we insert placeholders in the array only if we need them
  foreach my $key (qw(tweak patch minor major)) {
    if (exists $result->{$key} or scalar @bits) {
      $result->{$key} = 0 unless defined $result->{$key};
      unshift @bits, $result->{$key};
    }
  }
  $result->{bits} = [ @bits ] if scalar @bits;
  return _parse_extra($result);
}

sub _format_version {
  my $v = shift;
  $v = parse_version_string($v) // {} unless ref $v;
  my $separator = shift // '.';
  my $keyword_args = { @_ };
  my $main_v_string = join($separator, @{$v->{bits} // []});
  if ($keyword_args->{want_extra} // 1) {
    $main_v_string =
      sprintf("%s%s%s", $keyword_args->{preamble} // '',
              $main_v_string,
              ($v->{extra}) ?
              sprintf("%s%s",
                      ($main_v_string) ? $keyword_args->{pre_extra_sep} // '' : '',
                      $v->{extra}) : '');
  } elsif (wantarray) {
    return ($main_v_string, $v->{extra} // '');
  }
  return $main_v_string;
}

sub to_cmake_version {
  return _format_version(shift, '.', want_extra => 0)
}

sub to_dot_version {
  return _format_version(shift, '.');
}

sub to_ups_version {
  return _format_version(shift, '_', preamble => 'v');
}

sub to_product_name {
  my $name = lc shift or error_exit("vacuous name");
  $name =~ s&[^a-z0-9]&_&g;
  return $name;
}

sub to_version_string {
  return _format_version(shift, '.', pre_extra_sep => '-');
}


# Stable sorting algorithm for versions.
sub version_sort($$) {
  # Use slower prototype method due to package scope issues for $a, $b;
  my ($vInfoA, $vInfoB) = map { (ref $_) ? $_ : parse_version_string($_); } @_;
  my $ans = version_cmp($vInfoA, $vInfoB);
  unless ($ans) {
    my ($etextA, $enumA, $etextB, $enumB) =
      map { ($_->{extra} // '' =~ m&^(.*?)[_.-]?(\d+(?:\.\d*)?)?$&); }
        ($vInfoA, $vInfoB);
    $ans = (lc ($etextA // '') eq lc ($etextB // '')) ?
      (($enumA // 0) <=> ($enumB // 0)) || (($etextA // '') cmp ($etextB // '')) :
        (($vInfoA->{extra} // '') cmp ($vInfoB->{extra} // ''));
  }
  return $ans;
}

# Comparison algorithm for versions. cf cet_version_cmp() in
# ParseVersionString.cmake.
#
# Not stable as a sorting method: use version_sort() instead.
sub version_cmp {
  @_ or error_exit("tried to use version_cmp() as a sorting algorithm: use version_sort() instead");
  my ($vInfoA, $vInfoB) = map { (ref $_) ? $_ : parse_version_string($_); } @_;
  my $ans =
    ((($vInfoA->{extra_type} // 0) > 100 or ($vInfoB->{extra_type} // 0) > 100) ? 0 :
     ($vInfoA->{major} // 0) <=> ($vInfoB->{major} // 0) ||
     ($vInfoA->{minor} // 0) <=> ($vInfoB->{minor} // 0) ||
     ($vInfoA->{patch} // 0) <=> ($vInfoB->{patch} // 0) ||
     ($vInfoA->{tweak} // 0) <=> ($vInfoB->{tweak} // 0)) ||
       ($vInfoA->{extra_type} // 0) <=> ($vInfoB->{extra_type} // 0);
  $ans or ($vInfoA->{extra_type} // 0) != 2 or
    $ans = ($vInfoA->{extra_text} // '') cmp ($vInfoB->{extra_text} // '');
  $ans or $ans = ($vInfoA->{extra_type} // 0 == 3) ?
    _date_cmp($vInfoA->{extra_num} // 0, $vInfoB->{extra_num} // 0) :
      ($vInfoA->{extra_num} // 0) <=> ($vInfoB->{extra_num} // 0);
  return $ans;
}

sub _date_cmp {
  my ($a, $b) = @_;
  my $aInfo = ($a =~ m&^(?P<date>\d{4}[0-1]\d[0-3]\d)((?P<HH>[0-2]\d)((?P<mm>[0-5]\d)((?P<SS>[0-5]\d)\.?(?P<ss>\d+)?)?)?)?$&) ? { %+ } : {};
  my $bInfo = ($b =~ m&^(?P<date>\d{4}[0-1]\d[0-3]\d)((?P<HH>[0-2]\d)((?P<mm>[0-5]\d)((?P<SS>[0-5]\d)\.?(?P<ss>\d+)?)?)?)?$&) ? { %+ } : {};
  return $aInfo->{date} ?
    $aInfo->{date} <=> ($bInfo->{date} // 0) ||
      sprintf("%s%s%s.%s", $aInfo->{HH} || "00", $aInfo->{mm} || "00", $aInfo->{SS} || "00", $aInfo->{ss} || "00") <=>
        sprintf("%s%s%s.%s", $bInfo->{HH} || "00", $bInfo->{mm} || "00", $bInfo->{SS} || "00", $bInfo->{ss} || "00") :
          $bInfo->{date} ? ($aInfo->{date} // 0) <=> $bInfo->{date} : $a <=> $b;
}

my $cqual_table =
  { e2 => ['gcc', 'g++', 'GNU', '4.7.1', '11', 'gfortran', 'GNU', '4.7.1'],
    e4 => ['gcc', 'g++', 'GNU', '4.8.1', '11', 'gfortran', 'GNU', '4.8.1'],
    e5 => ['gcc', 'g++', 'GNU', '4.8.2', '11', 'gfortran', 'GNU', '4.8.2'],
    e6 => ['gcc', 'g++', 'GNU', '4.9.1', '14', 'gfortran', 'GNU', '4.9.1'],
    e7 => ['gcc', 'g++', 'GNU', '4.9.2', '14', 'gfortran', 'GNU', '4.9.2'],
    e8 => ['gcc', 'g++', 'GNU', '5.2.0', '14', 'gfortran', 'GNU', '5.2.0'],
    e9 => ['gcc', 'g++', 'GNU', '4.9.3', '14', 'gfortran', 'GNU', '4.9.3'],
    e10 => ['gcc', 'g++', 'GNU', '4.9.3', '14', 'gfortran', 'GNU', '4.9.3'],
    e14 => ['gcc', 'g++', 'GNU', '6.3.0', '14', 'gfortran', 'GNU', '6.3.0'],
    e15 => ['gcc', 'g++', 'GNU', '6.4.0', '14', 'gfortran', 'GNU', '6.4.0'],
    e17 => ['gcc', 'g++', 'GNU', '7.3.0', '17', 'gfortran', 'GNU', '7.3.0'],
    e19 => ['gcc', 'g++', 'GNU', '8.2.0', '17', 'gfortran', 'GNU', '8.2.0'],
    e20 => ['gcc', 'g++', 'GNU', '9.3.0', '17', 'gfortran', 'GNU', '9.3.0'],
    e21 => ['gcc', 'g++', 'GNU', '10.1.0', '20', 'gfortran', 'GNU', '10.1.0'],
    e22 => ['gcc', 'g++', 'GNU', '11.1.0', '17', 'gfortran', 'GNU', '11.1.0'],
    c1 => ['clang', 'clang++', 'Clang', '5.0.0', '17', 'gfortran', 'GNU', '7.2.0'],
    c2 => ['clang', 'clang++', 'Clang', '5.0.1', '17', 'gfortran', 'GNU', '6.4.0'],
    c3 => ['clang', 'clang++', 'Clang', '5.0.1', '17', 'gfortran', 'GNU', '7.3.0'],
    c4 => ['clang', 'clang++', 'Clang', '6.0.0', '17', 'gfortran', 'GNU', '6.4.0'],
    c5 => ['clang', 'clang++', 'Clang', '6.0.1', '17', 'gfortran', 'GNU', '8.2.0'],
    c6 => ['clang', 'clang++', 'Clang', '7.0.0-rc3', '17', 'gfortran', 'GNU', '8.2.0'],
    c7 => ['clang', 'clang++', 'Clang', '7.0.0', '17', 'gfortran', 'GNU', '8.2.0'],
    c8 => ['clang', 'clang++', 'Clang', '10.0.0', '20', 'gfortran', 'GNU', '10.1.0'],
    c9 => ['clang', 'clang++', 'Clang', '12.0.0', '17', 'gfortran', 'GNU', '11.1.0'],
  };

sub cmake_project_var_for_pathspec {
  my ($pi, $dirkey) = @_;
  my $pathspec = get_pathspec($pi, $dirkey);
  return () unless ($pathspec and $pathspec->{key});
  my $var_stem = $pathspec->{var_stem} || var_stem_for_dirkey($dirkey);
  $pathspec->{var_stem} = $var_stem;
  return ("-D$pi->{cmake_project}_${var_stem}_INIT=")
    unless exists $pathspec->{path};
  my @result_elements = ();
  if (ref $pathspec->{key}) {   # PATH-like.
    foreach my $pskey (@{$pathspec->{key}}) {
      error_exit("unrecognized pathkey $pskey for $dirkey")
        unless pathkey_is_valid($pskey);
      my $path = shift @{$pathspec->{path}};
      if ($pskey eq '-') {
        last unless $path;
        error_exit("non-empty path $path must be absolute",
                   "with pathkey \`$pskey' for directory key $dirkey")
          unless $path =~ m&^/&;
      } elsif ($pskey eq 'fq_dir' and
               $pi->{fq_dir} and
               not $path =~ m&^/&) {
        # Prepend EXEC_PREFIX here to avoid confusion with defaults in CMake.
        $path = File::Spec->catfile($pi->{fq_dir}, $path);
      } elsif ($path =~ m&^/&o) {
        warning("redundant pathkey $pskey ignored for absolute path $path",
                "specified for directory key $dirkey: use '-' as a placeholder.");
      }
      push @result_elements, $path;
    }
    $pathspec->{fq_path} = [ @result_elements ];
  } else {
    # Single non-elided value.
    push @result_elements, $pathspec->{path};
  }
  return (scalar @result_elements ne 1 or $result_elements[0]) ?
    sprintf("-D$pi->{cmake_project}_${var_stem}_INIT=%s",
            join(';', @result_elements)) : undef;
}

sub process_cmakelists {
  my ($cmakelists, %options) = @_;
  my $result = {};
  open(CML, "<", "$cmakelists") or error_exit("missing file $cmakelists");
  my @buffer = <CML>;
  close(CML);
  my @func_info = ();
  my $line = '';
  my $line_no = 0;
  # Try our best to be thorough.
 lines:  while (scalar @buffer) {
    $line = join('', $line, shift @buffer);
    my $func_line = ++$line_no;
    { # BLOCK necessary to contain the scope of ${^MATCH}, etc.
      $line =~ m&^\s*(?P<func>(?i)cet_cmake_env|project|set)\b(?:\s*(?:#[^\n]*)\n?)*\s*(?P<open_paren>\()&p and
        not $+{open_paren} and do {
          # Identified an interesting CMake function call, but we still need
          # to find the open parenthesis.
          error_exit("runaway trying to parse $+{func}() call at $cmakelists:$func_line")
            unless scalar @buffer;
          $line = join('', $line, shift @buffer);
          ++$line_no;
        };
      if (${^MATCH}) {
        my $call_info = { pre => ${^MATCH}, start_line => $func_line, %+ };
        $line = ${^POSTMATCH} // '';
        # Now we loop over multiple lines if necessary, separating
        # arguments and end-of-line comments and storing them, until we
        # find the closing parenthesis.
        #
        # Double-quoted arguments (even multi-line ones) are handled
        # correctly. Note that the use of an extra "+" symbol following
        # "+," "*," or "?" indicates a "greedy" clause to prevent
        # backtracking (e.g. in the case of a dangling double-quote), so
        # we don't match extra clauses inappropriately.
        while ($line =~ s&^(?P<arg_group>\s*+(?:(?:(?:"(?:[^"\\]++|\\.)*+")|(?:[^#")]+))[ \t]*+)*)(?:(?P<comments>[ \t]?#[^\n]*)?+(?P<nl>\n?+))?+&&s) {
          push @{$call_info->{arg_lines}}, sprintf("%s%s", $+{arg_group} // '', $+{nl} // '');
          push @{$call_info->{comments}}, $+{comments} // '' unless $line ne '';
          last if $line =~ m&^\s*\)&;
          error_exit("runaway trying to parse $call_info->{func} call at $cmakelists:$func_line")
            unless scalar @buffer;
          $line = join('', $line, shift @buffer);
          ++$line_no;
        }
        $call_info->{end_line} = $line_no;
        if ($line ne '') {
          $call_info->{post} = $line;
          $line = ''; # Clear for next loop, if there is one.
        }
        # Now separate multiple arguments on each line. We process the
        # arguments in two passes like this to retain correspondence
        # between arguments and comments on the same line.
        my $current_line = $func_line + scalar split("\n", $call_info->{pre}) - 1;
        $call_info->{arg_start_line} = $current_line if scalar @{$call_info->{arg_lines}};
        $call_info->{arg_groups} =
          [ map { my $tmp = [];
                  pos() = undef;
                  my $endmatch = pos();
                  while (m&\G[ 	]*(?P<arg>(?:[\n]++|(?:"(?:[^"\\]++|\\.)*+")|(?:[^\s)]+)))[ 	]*(?P<nl>[\n])?+&sg) {
                    last if ($endmatch // 0) == pos();
                    push @{$tmp}, sprintf("$+{arg}%s", $+{nl} // '');
                    $endmatch = pos();
                  }
                  error_exit(sprintf("Unexpected leftovers at $cmakelists:%s - > %s <",
                                     $current_line,
                                     substr($_, $endmatch // 0)))
                    unless length() == ($endmatch // 0);
                  ++$current_line;
                  $tmp;
                } @{$call_info->{arg_lines}} ];
        $call_info->{arg_end_line} = $current_line - 1
          if $call_info->{arg_start_line};
        if (my $func = $options{"$call_info->{func}_callback"}) {
          %{$result} = (%{$result}, %{&$func($call_info)});
        }
      } else { # Not interesting.
        $line = '';
      } # Analysis of $line.
    }
  } # Buffer entries.
  if ($line) {
    error_exit("unparse-able text at $cmakelists:$line_no -\n$line\n");
  } elsif (not keys %{$result}) {
    error_exit("unable to obtain useful information from $cmakelists");
  }
  return $result;
}

sub _get_info_from_project_call {
  my $call_info = shift;
  my $result = {};
  my $version_next;
  for my $arg_group (@{$call_info->{arg_groups}}) {
    for my $arg (@$arg_group) {
      unless (exists $result->{cmake_project_name}) {
        $result->{cmake_project_name} = $arg;
      }
      if ($version_next) {
        %$result = (%$result,
                    cmake_project_version => $arg,
                    version_info => parse_version_string($arg));
        last;
      } elsif ($arg eq 'VERSION') {
        $version_next = 1;
      }
    }
  }
  return $result;
}

sub _set_seen_cet_cmake_env {
  $parse_deps::seen_cet_cmake_env = 1;
  return {};
}

sub _get_info_from_set_calls {
  my $call_info = shift;
  my $result = {};
  return $result if $parse_deps::seen_cet_cmake_env;
  my $var;
  for my $arg_group (@{$call_info->{arg_groups}}) {
    for my $arg (@$arg_group) {
      if ($var) {
        $result->{$var} = $arg;
        undef $var;
      } else {
        ($var) = ($arg =~ m&_(CMAKE_PROJECT_VERSION_STRING)$&);
      }
    }
  }
  return $result;
}

sub get_cmake_project_info {
  undef $parse_deps::seen_cet_cmake_env;
  my ($pkgtop, %options) = @_;
  my $cmakelists = File::Spec->catfile($pkgtop, "CMakeLists.txt");
  my $proj_info = process_cmakelists($cmakelists,
                                     project_callback => \&_get_info_from_project_call,
                                     set_callback => \&_get_info_from_set_calls,
                                     cet_cmake_env_callback => \&_set_seen_cet_cmake_env);
  if (not $proj_info or not scalar keys %{$proj_info}) {
    error_exit("unable to obtain information from $cmakelists");
  }
  return $proj_info;
}

sub ups_to_cmake {
  my ($pi) = @_;

  (not $pi->{cqual}) or
    (exists $cqual_table->{$pi->{cqual}} and
     my ($cc, $cxx, $compiler_id, $compiler_version, $cxx_standard, $fc, $fc_id, $fc_version) =
     @{$cqual_table->{$pi->{cqual}}} or
     error_exit("unrecognized compiler qualifier $pi->{cqual}"));

  my @cmake_args=();

  ##################
  # Build system bootstrap.
  if ($pi->{build_only_deps} and
      scalar @{$pi->{build_only_deps}} and
      grep { $_ eq 'cetbuildtools'; } @{$pi->{build_only_deps}}) {
    push @cmake_args, @{cmake_cetb_compat_defs()};
    $pi->{bootstrap_cetbuildtools} = 1
  } elsif ($pi->{cmake_project} ne "cetmodules" and not
           ($ENV{MRB_SOURCE} and
            $ENV{CETPKG_SOURCE} eq $ENV{MRB_SOURCE})) {
    $pi->{bootstrap_cetmodules} = 1
  }

  ##################
  # UPS-specific CMake configuration.

  push @cmake_args, '-DWANT_UPS:BOOL=ON';
  push @cmake_args,
    "-DUPS_C_COMPILER_ID:STRING=$compiler_id",
      "-DUPS_C_COMPILER_VERSION:STRING=$compiler_version",
        "-DUPS_CXX_COMPILER_ID:STRING=$compiler_id",
          "-DUPS_CXX_COMPILER_VERSION:STRING=$compiler_version",
            "-DUPS_Fortran_COMPILER_ID:STRING=$fc_id",
              "-DUPS_Fortran_COMPILER_VERSION:STRING=$fc_version"
                if $compiler_id;
  push @cmake_args, sprintf('-D%s_UPS_PRODUCT_NAME:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{name}) if $pi->{name};
  push @cmake_args, sprintf('-D%s_UPS_PRODUCT_VERSION:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{version}) if $pi->{version};
  push @cmake_args, sprintf('-D%s_UPS_QUALIFIER_STRING:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{qualspec}) if $pi->{qualspec};
  push @cmake_args, sprintf('-DUPS_%s_CMAKE_PROJECT_NAME:STRING=%s',
                            $pi->{name}, $pi->{cmake_project});
  push @cmake_args, sprintf('-DUPS_%s_CMAKE_PROJECT_VERSION:STRING=%s',
                            $pi->{name}, $pi->{cmake_project_version});
  push @cmake_args, sprintf('-D%s_UPS_PRODUCT_FLAVOR:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{flavor});
  push @cmake_args, sprintf('-D%s_UPS_BUILD_ONLY_DEPENDENCIES=%s',
                            $pi->{cmake_project},
                            join(';', @{$pi->{build_only_deps}}))
    if $pi->{build_only_deps};
  push @cmake_args, sprintf('-D%s_UPS_USE_TIME_DEPENDENCIES=%s',
                            $pi->{cmake_project},
                            join(';', @{$pi->{use_time_deps}}))
    if $pi->{use_time_deps};

  push @cmake_args, sprintf('-D%s_UPS_PRODUCT_CHAINS=%s',
                            $pi->{cmake_project},
                            join(';', (sort @{$pi->{chains}})))
    if $pi->{chains};

  ##################
  # General CMake configuration.
  push @cmake_args, "-DCMAKE_BUILD_TYPE:STRING=$pi->{cmake_build_type}"
    if $pi->{cmake_build_type};
  push @cmake_args,
    "-DCMAKE_C_COMPILER:STRING=$cc",
      "-DCMAKE_CXX_COMPILER:STRING=$cxx",
        "-DCMAKE_Fortran_COMPILER:STRING=$fc",
          "-DCMAKE_CXX_STANDARD:STRING=$cxx_standard",
            "-DCMAKE_CXX_STANDARD_REQUIRED:BOOL=ON",
              "-DCMAKE_CXX_EXTENSIONS:BOOL=OFF"
                if $compiler_id;
  push @cmake_args, sprintf('-D%s_EXEC_PREFIX_INIT:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{fq_dir}) if $pi->{fq_dir};
  push @cmake_args, sprintf('-D%s_NOARCH:BOOL=ON',
                            $pi->{cmake_project}) if $pi->{noarch};
  push @cmake_args,
    sprintf("-D$pi->{cmake_project}_DEFINE_PYTHONPATH_INIT:BOOL=ON")
      if $pi->{define_pythonpath};
  push @cmake_args,
    sprintf("-D$pi->{cmake_project}_OLD_STYLE_CONFIG_VARS:BOOL=ON")
      if $pi->{old_style_config_vars};

  ##################
  # Pathspec-related CMake configuration.

  push @cmake_args,
    (map { cmake_project_var_for_pathspec($pi, $_) || ();
         } keys %{$pathspec_info});

  my @arch_pathspecs = ();
  my @noarch_pathspecs = ();
  foreach my $pathspec (values %{$pi->{pathspec_cache}}) {
    if ($pathspec->{var_stem} and
        not ref $pathspec->{path} and
        $pathspec->{key} ne '-') {
      push @{$pathspec->{key} eq 'fq_dir' ?
               \@arch_pathspecs : \@noarch_pathspecs},
                 $pathspec->{var_stem};
    }
  }
  push @cmake_args,
    sprintf('-D%s_ADD_ARCH_DIRS:STRING=%s',
            $pi->{cmake_project}, join(';', @arch_pathspecs))
      if scalar @arch_pathspecs;
  push @cmake_args,
    sprintf('-D%s_ADD_NOARCH_DIRS:STRING=%s',
            $pi->{cmake_project}, join(';', @noarch_pathspecs))
      if scalar @noarch_pathspecs;

  ##################
  # Done.
  return \@cmake_args;
}

sub print_dep_setup {
  my ($deps, $out) = @_;

  my ($setup_cmds, $only_for_build_cmds);

  # Temporary variable connected as a filehandle.
  open(my $setup_cmds_fh, ">", \$setup_cmds) or
    die "could not open memory stream to variable \$setup_cmds";

  # Second temporary variable connected as a filehandle.
  open(my $only_cmds_fh, ">", \$only_for_build_cmds) or
    die "could not open memory stream to variable \$only_for_build_cmds";

  my $onlyForBuild="";
  foreach my $dep (keys %$deps) {
    my $dep_info = $deps->{$dep};
    my $fh;
    if ($dep_info->{only_for_build}) {
      next if $dep =~ m&^cet(buildtools|modules)$&; # Dealt with elsewhere.
      $fh = $only_cmds_fh;
    } else {
      $fh = $setup_cmds_fh;
    }
    print_dep_setup_one($dep, $dep_info, $fh);
  }
  close($setup_cmds_fh);
  close($only_cmds_fh);

  print $out <<'EOF';
# Add '-B' to UPS_OVERRIDE for safety.
tnotnull UPS_OVERRIDE || setenv UPS_OVERRIDE ''
expr "x $UPS_OVERRIDE" : '.* -[^- 	]*B' >/dev/null || setenv UPS_OVERRIDE "$UPS_OVERRIDE -B"
EOF

  # Build-time dependencies first.
  print $out <<'EOF', $only_for_build_cmds if $only_for_build_cmds;

####################################
# Build-time dependencies.
####################################
EOF

  # Now use-time dependencies.
  if ( $setup_cmds ) {
    print $out <<'EOF', $setup_cmds if $setup_cmds;

####################################
# Use-time dependencies.
####################################
EOF
  }
}

sub print_dep_setup_one {
  my ($dep, $dep_info, $out) = @_;
  my $thisver =
    (not $dep_info->{version} or $dep_info->{version} eq "-") ? "" :
      $dep_info->{version};
  my @setup_options =
    (exists $dep_info->{setup_options} and $dep_info->{setup_options}) ?
     @{$dep_info->{setup_options}} : ();
  my @prodspec =
    ("$dep", "$thisver");
  my $qualstring = join(":+", split(':', $dep_info-> {qualspec} || ''));
  push @prodspec, '-q', $qualstring if $qualstring;
  print $out "# > $dep <\n";
  if ($dep_info->{optional}) {
    my $prodspec_string = join(' ', @prodspec);
    printf $out <<"EOF";
# Setup of $dep is optional.
ups exist $prodspec_string
test "\$?" != 0 && \\
  echo \QINFO: skipping missing optional product $prodspec_string\E || \\
EOF
    print $out "  ";
  }
  my $setup_cmd = join(' ', qw(setup -B), @prodspec, @setup_options);
  if (scalar @setup_options) {
    # Work around bug in ups active -> unsetup_all for UPS<=6.0.8.
    $setup_cmd=sprintf('%s && setenv %s "`echo \"$%s\" | sed -Ee \'s&[[:space:]]+-j$&&\'`"',
                       "$setup_cmd", ("SETUP_\U$dep\E") x 2);
  }
  print $out "$setup_cmd; ";
  setup_err($out, "$setup_cmd failed");
}

sub setup_err {
  my $out = shift;
  print $out 'test "$?" != 0 && \\', "\n";
  foreach my $msg_line (@_) {
    chomp $msg_line;
    print $out "  echo \QERROR: $msg_line\E && \\\n";
  }
  print $out "  return 1 || true\n";
}

sub fq_path_for {
  my ($pi, $dirkey, $default) = @_;
  my $pathspec = get_pathspec($pi, $dirkey) ||
    { key => '-', path => $default };
  my $fq_path = $pathspec->{fq_path} || undef;
  unless ($fq_path or ($pathspec->{key} eq '-' and not $pathspec->{path})) {
    my $want_fq = $pi->{fq_dir} &&
      ($pathspec->{key} eq 'fq_dir' or
       ($pathspec->{key} eq '-' and grep { $_ eq $dirkey } qw(bindir libdir)));
    $fq_path =
      File::Spec->catfile($want_fq ? $pi->{fq_dir} : (),
              $pathspec->{path} || $default || ());
  }
  return $fq_path;
}

sub print_dev_setup_var {
  my ($var, $val, $no_errclause) = @_;
  my @vals;
  if (ref $val eq 'ARRAY') {
    @vals=@$val;
  } else {
    @vals=($val || ());
  }
  my $result;
  open(my $out, ">", \$result) or
    die "could not open memory stream to variable \$out";
  if (scalar @vals) {
    print $out "# $var\n",
      "setenv $var ", '"`dropit -p \\"${', "$var", '}\\" -sfe ';
    print $out join(" ", map { sprintf('\\"%s\\"', $_); } @vals), '`"';
    if ($no_errclause) {
      print $out "\n";
    } else {
      print $out "; ";
      setup_err($out, "failure to prepend to $var");
    }
  }
  close($out);
  return $result // '';
}

sub print_dev_setup {
  my ($pi, $out) = @_;
  my $fqdir;
  print $out <<"EOF";

####################################
# Development environment.
####################################
EOF
  my $libdir = fq_path_for($pi, 'libdir', 'lib');
  if ($libdir) {
    # (DY)LD_LIBRARY_PATH.
    print $out
      print_dev_setup_var(sprintf("%sLD_LIBRARY_PATH",
                                  ($pi->{flavor} =~ m&\bDarwin\b&) ? "DY" : ""),
                          File::Spec->catfile('${CETPKG_BUILD}', $libdir));
    # CET_PLUGIN_PATH. We only want to add to this if it's already set
    # or we're cetlib, which is the package that makes use of it.
    my ($head, @output) =
      split("\n",
            print_dev_setup_var("CET_PLUGIN_PATH",
                                File::Spec->catfile('${CETPKG_BUILD}',
                                                    $libdir)));
    print $out "$head\n",
      ($pi->{name} ne 'cetlib') ?
        "test -z \"\${CET_PLUGIN_PATH}\" || \\\n  " : '',
          join("\n", @output), "\n";
  }
  # ROOT_INCLUDE_PATH.
  print $out
    print_dev_setup_var("ROOT_INCLUDE_PATH",
                        [ qw(${CETPKG_SOURCE} ${CETPKG_BUILD}) ]);
  # CMAKE_PREFIX_PATH.
  print $out
    print_dev_setup_var("CMAKE_PREFIX_PATH", '${CETPKG_BUILD}', 1);
  # FHICL_FILE_PATH.
  $fqdir = fq_path_for($pi, 'fcldir') and
    print $out
      print_dev_setup_var("FHICL_FILE_PATH",
                          File::Spec->catfile('${CETPKG_BUILD}', $fqdir));

  # FW_SEARCH_PATH.
  my $fw_pathspec = get_pathspec($pi, 'set_fwdir') || {};
  die "INTERNAL ERROR in print_dev_setup(): ups_to_cmake() should have been called first"
    if ($fw_pathspec->{path} and not $fw_pathspec->{fq_path});
  my @fqdirs =
    map { m&^/& ? $_ : File::Spec->catfile('${CETPKG_BUILD}', $_); }
      (fq_path_for($pi, 'gdmldir', 'gdml') || (),
       fq_path_for($pi, 'fwdir') || ());
  push @fqdirs, map { m&^/& ? $_ : File::Spec->catfile('${CETPKG_SOURCE}', $_); }
    @{$fw_pathspec->{fq_path} || []};
  print $out print_dev_setup_var("FW_SEARCH_PATH", \@fqdirs);

  # WIRECELL_PATH.
  my $wp_pathspec = get_pathspec($pi, 'set_wpdir') || {};
  die "INTERNAL ERROR in print_dev_setup(): ups_to_cmake() should have been called first"
    if ($wp_pathspec->{path} and not $wp_pathspec->{fq_path});
  @fqdirs =
    map { m&^/& ? $_ : File::Spec->catfile('${CETPKG_SOURCE}', $_); }
      @{$wp_pathspec->{fq_path} || []};
  print $out print_dev_setup_var("WIRECELL_PATH", \@fqdirs);

  # PYTHONPATH.
  if ($pi->{define_pythonpath}) {
    print $out
      print_dev_setup_var("PYTHONPATH",
                          File::Spec->catfile('${CETPKG_BUILD}',
                                              $libdir ||
                                              ($pi->{fq_dir} || (), 'lib')));

  }
  # PATH.
  $fqdir = fq_path_for($pi, 'bindir', 'bin') and
    print $out
      print_dev_setup_var("PATH",
                          [ File::Spec->catfile('${CETPKG_BUILD}', $fqdir),
                            File::Spec->catfile('${CETPKG_SOURCE}', $fqdir) ]);
}

sub table_dep_setup {
  my ($dep, $dep_info, $fh) = @_;
  my @setup_cmd_args =
    ($dep,
     ($dep_info->{version} ne '-c') ? $dep_info->{version} : (),
     $dep_info->{qualspec} ?
     ('-q', sprintf("+%s", join(":+", split(':', $dep_info->{qualspec} || '')))) :
     ());
  printf $fh "setup%s(%s)\n",
    ($dep_info->{optional}) ? "Optional" : "Required",
      join(' ', @setup_cmd_args);
}

sub var_stem_for_dirkey {
  my $dirkey = shift;
  return uc($pathspec_info->{$dirkey}->{project_var} ||
            (($dirkey =~ m&^(.*?)_*dir$&) ? "${1}_dir" :
             "${dirkey}_dir"));
}

sub write_table_deps {
  my ($parent, $deps) = @_;
  open(my $fh, ">", "table_deps_$parent") or return;
  foreach my $dep (sort keys %{$deps}) {
    my $dep_info = $deps->{$dep};
    table_dep_setup($dep, $dep_info, $fh)
      unless $dep_info->{only_for_build};
  }
  close($fh);
  1;
}

sub write_table_frag {
  my ($parent, $pfile) = @_;
  my $fraglines = get_table_fragment($pfile);
  if ($fraglines and scalar @$fraglines) {
    open(my $fh, ">", "table_frag_$parent") or return;
    print $fh join("\n", @$fraglines), "\n";
    close($fh);
  } else {
    unlink("table_frag_$parent");
    1;
  }
}

sub cmake_cetb_compat_defs {
  return [ map { my $var_stem = var_stem_for_dirkey($_);
                 my $dirkey_ish = $_; $dirkey_ish =~ s&([^_])dir$&${1}_dir&;
                 "-DCETB_COMPAT_${dirkey_ish}:STRING=${var_stem}";
               } sort keys %$pathspec_info ];
}

# Adapted from
# http://blogs.perl.org/users/laurent_r/2020/04/perl-weekly-challenge-57-tree-inversion-and-shortest-unique-prefix.html
# to support minimum number of characters in substring, and to retain
# original->prefix correspondence.
use vars qw($prefix_min_length);
$parse_deps::prefix_min_length = 6;
sub shortest_unique_prefix {
  my (@words) = @_;
  my $result = {};
  my %letters;
  for my $word (@words) {
    push @{$letters{substr $word, 0, 1}}, $word;
  }
  for my $letter (keys %letters) {
    $result->{$letters{$letter}->[0]} =
      substr($letters{$letter}->[0], 0, $parse_deps::prefix_min_length) and next
        if @{$letters{$letter}} == 1;
    my $candidate;
    for my $word1 (@{$letters{$letter}}) {
      my $prefix_length = 0;
      for my $word2 (@{$letters{$letter}}) {
        next if $word1 eq $word2;
        my $i = 1;
        while (substr($word1, $i, 1) eq substr($word2, $i, 1)) { ++$i; }
        if ($i > $prefix_length) {
          $candidate = substr($word1, 0,
                              (($i + 1) > $parse_deps::prefix_min_length) ? $i + 1 :
                              $parse_deps::prefix_min_length);
          $prefix_length = $i;
        }
      }
      $result->{$word1} = $candidate // $word1;
    }
  }
  return $result;
}

1;
