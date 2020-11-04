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

use File::Spec; # For catfile;
use List::Util qw(min max); # Numeric min / max functions.

use Exporter 'import';
our (@EXPORT, @EXPORT_OK);

use vars qw($btype_table $pathspec_info $VERBOSE $QUIET);

use File::Basename qw(basename dirname);

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
     product
     qualifier
     table_fragment_begin
     table_fragment_end
   );
push @known_keywords, sort keys %$pathspec_info;

$btype_table = { debug => 'Debug',
                 prof => 'RelWithDebInfo',
                 opt => 'Release' };

@EXPORT = qw(by_version
             cetpkg_info_file
             compiler_for_quals
             deps_for_quals
             error_exit
             get_parent_info
             get_product_list
             get_qualifier_matrix
             get_table_fragment
             info
             parse_version_string
             print_dev_setup
             sort_qual
             to_dot_version
             to_product_name
             to_string
             to_ups_version
             ups_to_cmake
             var_stem_for_dirkey
             verbose
             warning);

@EXPORT_OK = qw($btype_table $pathspec_info
                get_pathspec print_dep_setup table_dep_setup);

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

sub info {
  return if $parse_deps::QUIET;
  my (@msg) = @_;
  chomp @msg;
  print map { "INFO: $_\n"; } map { split("\n") } @msg;
}

sub verbose {
  return unless $parse_deps::VERBOSE;
  my (@msg) = @_;
  chomp @msg;
  print map { "VERBOSE: $_\n"; } map { split("\n") } @msg;
}

sub get_parent_info {
  my ($pfile, @qualstrings) = @_;
  open(my $fh, "<", "$pfile") or error_exit("couldn't open $pfile");
  my $result;
  my $chains;
  while (<$fh>) {
    chomp;
    s&\s*\#.*$&&;
    m&\w+& or next;
    my ($keyword, @pars) = split;
    if ($keyword eq "parent") {
      warning("multi-argument version of \"parent\" in $pfile",
              "is deprecated: VERSION defined in CMakeLists.txt:project() governs.",
              "Use \"chain[s] [current|test|new|old|<chain>]...\" in $pfile to specify chains.")
        if $pars[1];
      $result->{name} = shift @pars;
      $result->{version} = shift @pars if $pars[0];
      @$chains{@pars} = (1) x scalar @pars if scalar @pars;
    } elsif ($keyword =~ m&^chains?$&) {
      @$chains{@pars} = (1) x scalar @pars if scalar @pars;
    } elsif ($keyword eq "defaultqual") {
      $result->{default_qual} = sort_qual(@pars);
      $result->{default_qual} =~ m&^-nq-?$& and $result->{default_qual} = "";
    } elsif (grep { $_ eq $keyword; } qw(no_fq_dir noarch define_pythonpath)) {
      scalar @pars and
        warning(sprintf("unexpected garbage following $keyword: %s",
                        join(" ", @pars)));
      $result->{$keyword} = 1;
    } else {
    }
  }
  close($fh);
  $result->{chains} = [ sort keys %$chains ] if scalar keys %$chains;

  ##################
  # Derivative and external information.

  # CMake info.
  my ($cmake_project, $cmake_project_version) = get_cmake_project_info($pfile);
  if (defined $cmake_project) {
    $result->{cmake_project} = $cmake_project;
    $result->{name} = to_product_name($cmake_project)
      unless exists $result->{name};
  }
  if (defined $cmake_project_version) {
    $result->{cmake_project_version} = $cmake_project_version;
    $result->{version} = to_ups_version($cmake_project_version)
      unless exists $result->{version};
  }

  my @sorted;
  $result->{qual} = sort_qual(\@sorted, @qualstrings);
  @{$result}{qw(cqual extqual type)} = @sorted;
  $result->{cmake_build_type} = $btype_table->{$result->{type}} if $result->{type};

  # Derivatives of the product's UPS flavor.
  if ($result->{no_fq_dir}) {
    $result->{flavor} = "NULL";
  } else {
    my $fq_dir;
    my $flavor = `ups flavor -4`;
    error_exit("failure executing ups flavor: UPS not set up?") if $!;
    chomp $flavor;
    # We only care about OS major version no. for Darwin.
    $flavor =~ s&^(Darwin.*?\+\d+).*$&${1}&;
    $result->{flavor} = $flavor;
    if ($result->{noarch}) {
      $fq_dir = 'noarch';
    } else {
      $fq_dir = $ENV{CET_SUBDIR} or
        error_exit("CET_SUBDIR not set: missing cetpkgsupport?");
    }
    $result->{fq_dir} = join('.', $fq_dir, split(':', $result->{qual}));
  }
  return $result;
}

sub get_table_fragment {
  my $pfile = shift;
  my $reading_frag;
  my @fraglines = ();
  open(my $fh, "<$pfile") or error_exit("couldn't open $pfile");
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
  my ($product_deps, $pi, $dirkey) = @_;
  error_exit("unrecognized directory key $dirkey")
    if not dirkey_is_valid($dirkey);
  $pi->{pathspec_cache} = {} unless exists $pi->{pathspec_cache};
  my $pathspec_cache = $pi->{pathspec_cache};
  unless ($pathspec_cache->{$dirkey}) {
    my $multiple_ok = $pathspec_info->{$dirkey}->{multiple_ok} || 0;
    open(PD, "<$product_deps") or error_exit("couldn't open $product_deps");
    my ($seen_dirkey, $pathkeys, $dirnames) = (undef, [], []);
    while (<PD>) {
      chomp;
      # Skip full-line comments and whitespace-only lines.
      next if m&^\s*#&o or !m&\S&o;
      my ($found_dirkey, $pathkey, $dirname) = (m&^\s*(\Q$dirkey\E)\b(?:\s+(\S+)\s*(\S*?))?(?:\s*#.*)?$&);
      next unless $found_dirkey;
      error_exit("dangling directory key $dirkey seen in $product_deps at line $.:",
                 "path key is required") unless $pathkey;
      error_exit("unrecognized path key $pathkey for directory key $dirkey in $product_deps",
                 " at line $.") unless pathkey_is_valid($pathkey);

      if ($seen_dirkey) {
        error_exit("illegal duplicate directory key $dirkey seen in $product_deps ",
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
      my ($prod, $version, $qualspec, $modifier) = @words;
      $qualspec = '-' unless $qualspec;
      $modifier = '' unless $modifier;

      if ($prod eq "only_for_build") {
        # Archaic form.
        ($prod, $version, $qualspec, $modifier) =
          ($version, $qualspec, '-', $prod);
        print STDERR <<EOF;
WARNING: Deprecated only_for_build entry found in $pfile
WARNING: Please replace:
WARNING: $_
WARNING: with
WARNING: $prod\t$version\t$qualspec\t$modifier
WARNING: This accommodation will be removed in future.
EOF
      }

      if ($qualspec and $qualspec eq "-nq-") {
        # Under format version 1, "-nq-" meant, "always." Since format
        # version 2, it means, "when we have no qualifiers," and "-"
        # means, "always."
        $qualspec = ($pl_format == 1) ? "-" : "";
      }

      $phash->{$prod}->{$qualspec} =
        {version => (($version eq "-") ? "-c" : $version),
         ($modifier ? ($modifier => 1) : ()) };
    } else {
    }
  }
  close($fh);
  return $phash;
}

sub deps_for_quals {
  my ($phash, $qhash, $qualspec) = @_;
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
                   "Please check $ENV{CETPKG_SOURCE}/ups/product_deps");
      } else {
        error_exit(sprintf("dependency %s has no entry in the qualifier table for %s.",
                           $prod,
                           ($qualspec ? "parent qualifier $qualspec" :
                            "unqualified parent")),
                   "Please check $ENV{CETPKG_SOURCE}/ups/product_deps");
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
  my ($pfile, $efl) = @_;
  my $irow=0;
  my $get_quals;
  my $qlen = 0;
  my @qlist = ();
  my @notes;
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
      for (; $qlen < $#words and $words[$qlen+1] ne "notes"; ++$qlen) { }
      $notes[$irow] = $words[$qlen+1] || '';
      $qlist[$irow++] = [@words[0..$qlen]];
    } elsif ($get_quals) {
      unwanted_keyword($keyword) and
        error_exit(sprintf("unexpected keyword $keyword at $pfile:%d - missing end_qualifier_list?",
                           $fh->input_line_number));
      if (scalar @words < $qlen) {
        print $efl "echo ERROR: only $#words qualifiers for $keyword - need $qlen\n";
        print $efl "return 4\n";
        exit 4;
      }
      $qlist[$irow++] =
        [map { (not $_ or $_ eq "-nq-") ? "" : sort_qual($_); }
         @words[0..$qlen]];
    } else {
    }
  }
  close($fh);
  #print $efl "get_qualifier_list: found $irow qualifier rows\n";
  return ($qlen, \@qlist, \@notes);
}

sub get_qualifier_matrix {
  my ($pfile, $efl) = @_;
  my ($qlen, $qlist, $notes) = get_qualifier_list($pfile, $efl);
  my ($qhash, $qqhash, $nhash); # (by-column, by-row, notes)
  my @prods = @{shift @$qlist}; # Drop header row from @$qlist.
  $qhash = { map { my $idx = $_; ( $prods[$idx] => { map { (@$_[0] => @$_[$idx]); } @$qlist } ); } 1..$qlen };
  $qqhash = { map { my @dq = @$_; ( $dq[0] => { map { ( $prods[$_] => $dq[$_] ); } 1..$qlen } ); } @$qlist };
  my @headers = (@prods, shift @$notes || ());
  $nhash = { map { ( $_->[0] => (shift @$notes or '')); } @$qlist };
  return ($qlen, $qhash, $qqhash, $nhash, \@headers);
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
  # If we have multiple arguments and the first want is ARRAY, then that
  # is an output array reference for the result.
  my $sorted =
    ( $_[0] and scalar @_ > 1 and (ref $_[0] || '') eq 'ARRAY') ?
      shift : [];
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
    } else {
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
      error_exit(sprintf("could not output info $key of type %s", ref $val));
    }
    push @defined_vars, $var;
  }
  return @defined_vars;
}

# Output information for buildtool.
sub cetpkg_info_file {
  my (%info) = @_;
  my @expected_keys =
    qw(source build name version chains qual cqual type extqual deps
       build_only_deps cmake_project cmake_project_version cmake_args);
  foreach my $key (qw(deps build_only_deps)) {
    if (exists $info{$key}) { # Known hash - want keys only.
      $info{$key} = [ sort keys %{$info{$key}} ];
    }
  }
  my @for_export = (qw(CETPKG_SOURCE CETPKG_BUILD));
  my $cetpkgfile = sprintf("%s/cetpkg_info.sh", $info{build} || ".");
  open(my $fh, "> $cetpkgfile") or
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
  my $item = shift;
  $item = (defined $item) ? $item : "<undef>";
  my $indent = shift || 0;
  my $type = ref $item;
  my $result;
  if (not $type) {
    $result = "$item";
  } elsif ($type eq "SCALAR") {
    $result = "$$item";
  } elsif ($type eq "ARRAY") {
    $result = sprintf("\%s ]", offset_annotated_items($indent, '[ ', @$item));
  } elsif ($type eq "HASH") {
    $indent += 2;
    $result =
      sprintf("{ \%s }",
              join(sprintf(",\n\%s", ' ' x $indent),
                   map {
                     my $key = $_;
                     sprintf("$key => \%s",
                             to_string($item->{$key},
                                       $indent + length("$key => ")));
                   } keys %$item));
    $indent -= 2;
  } else {
    print STDERR "ERROR: cannot print item of type $type.\n";
    exit(1);
  }
  return $result;
}

sub offset_annotated_items {
  my ($offset, $preamble, @args) = @_;
  my $indent = length($preamble) + $offset;
  return sprintf('%s%s', $preamble,
                 join(sprintf(",\n\%s", ' ' x $indent),
                      map { to_string($_, $indent); } @args));
}

# Sort order:
#
# alpha[[-_]NN] (alpha releases);
# beta[[-_]NN] (beta releases);
# rc[[-_]NN] or pre[[-_]NN] (prereleases);
# <empty>;
# p[-_]NN or patch[[-_]NN] (patch releases);
# Anything else.
sub parse_version_extra {
  my $vInfo = shift;
  # Swallow optional _ or - separator to 4th field.
  if (($vInfo->{micro} || '') =~ m&^(\d+)[-_]?((.*?)[-_]?(\d*))$&o) {
    $vInfo->{micro} = "$1";
  } else {
    $vInfo->{micro} = '';
  }
  my ($extra, $etext, $enum) = (${2} || "", ${3} || "", ${2} ? ${4} || -1 : -1);
  if (not $etext) {
    $vInfo->{extra_type} = 0;
  } elsif ($etext eq "patch" or ($enum >= 0 and $etext eq "p")) {
    $vInfo->{extra_type} = 1;
  } elsif ($etext eq "rc" or
           $etext eq "pre") {
    $vInfo->{extra_type} = -1;
    $etext = "pre";
  } elsif ($etext eq "beta") {
    $vInfo->{extra_type} = -2;
  } elsif ($etext eq "alpha") {
    $vInfo->{extra_type} = -3;
  } else {
    $vInfo->{extra_type} = 2;
  }
  $vInfo->{extra} = $extra;
  $vInfo->{extra_num} = $enum;
  $vInfo->{extra_text} = $etext;
}

sub parse_version_string {
  my $dv = shift || "";
  $dv =~ s&^v&&o;
  my $result = {};
  if ($dv) {
    @{$result}{qw(major minor micro)} = split /[_.]/, $dv, 3;
    parse_version_extra($result);
  } else {
    @{$result}{qw(major minor micro extra extra_type extra_text extra_num)} =
      (-1, -1, -1, 0, "", "", -1);
  }
  return $result;
}

sub _format_version {
  my $v = shift;
  $v = parse_version_string($v) unless ref $v;
  my $separator = shift || '.';
  my $preamble = shift || '';
  return sprintf("${preamble}%s%s",
                 join($separator,
                      defined $v->{major} ? $v->{major} : (),
                      defined $v->{minor} ? $v->{minor} : (),
                      defined $v->{micro} ? $v->{micro} : ()),
                 $v->{extra} || '');
}

sub to_dot_version {
  return _format_version(shift);
}


sub to_ups_version {
  return _format_version(shift, '_', 'v');
}

sub to_product_name {
  my $name = lc shift or error_exit("vacuous name");
  $name =~ s&[^a-z0-9]&_&g;
  return $name;
}

sub by_version {
  my $vInfoA = parse_version_string($a || shift);
  my $vInfoB = parse_version_string($b || shift);
  return
    $vInfoA->{major} <=> $vInfoB->{major} ||
      $vInfoA->{minor} <=> $vInfoB->{minor} ||
        $vInfoA->{micro} <=> $vInfoB->{micro} ||
          $vInfoA->{extra_type} <=> $vInfoB->{extra_type} ||
            $vInfoA->{extra_text} cmp $vInfoB->{extra_text} ||
              $vInfoA->{extra_num} <=> $vInfoB->{extra_num};
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
    e21 => ['gcc', 'g++', 'GNU', '10.1.0', '17', 'gfortran', 'GNU', '10.1.0'],
    c1 => ['clang', 'clang++', 'Clang', '5.0.0', '17', 'gfortran', 'GNU', '7.2.0'],
    c2 => ['clang', 'clang++', 'Clang', '5.0.1', '17', 'gfortran', 'GNU', '6.4.0'],
    c3 => ['clang', 'clang++', 'Clang', '5.0.1', '17', 'gfortran', 'GNU', '7.3.0'],
    c4 => ['clang', 'clang++', 'Clang', '6.0.0', '17', 'gfortran', 'GNU', '6.4.0'],
    c5 => ['clang', 'clang++', 'Clang', '6.0.1', '17', 'gfortran', 'GNU', '8.2.0'],
    # Technically c6 referred to LLVM/Clang 7.0.0rc3, but CMake can't
    # tell the difference.
    c6 => ['clang', 'clang++', 'Clang', '7.0.0', '17', 'gfortran', 'GNU', '8.2.0'],
    c7 => ['clang', 'clang++', 'Clang', '7.0.0', '17', 'gfortran', 'GNU', '8.2.0'],
    c8 => ['clang', 'clang++', 'Clang', '10.0.0', '20', 'gfortran', 'GNU', '10.1.0']
  };

sub cmake_project_var_for_pathspec {
  my ($pfile, $pi, $dirkey) = @_;
  my $pathspec = get_pathspec($pfile, $pi, $dirkey);
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
        $path = "$pi->{fq_dir}/$path";
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

sub get_cmake_project_info {
  my ($pfile) = @_;
  my $cmakelists = sprintf("%s/CMakeLists.txt", dirname(dirname($pfile)));
  open(CML, "<$cmakelists") or error_exit("missing CMakeLists.txt from \${CETPKG_SOURCE}");
  my $filedata = join('',<CML>);
  my ($prod, $ver) =
    $filedata =~ m&^\s*(?:(?i)project)\s*\(\s*(\S+)(?:.*\s+VERSION\s+"?(\S+)"?)?&ms;
  error_exit("unable to find CMake project() declaration in $cmakelists")
    unless $prod;
  warning("unable to extract version information from project call for $prod")
    unless $ver;
  return ($prod, ${ver} || undef);
}

sub ups_to_cmake {
  my ($pfile, $pi) = @_;
  $pi->{cmake_project} and
    $pi->{name} and
      $pi->{cmake_project} ne
        $pi->{name} and
          warning("UPS product name is $pi->{name}.",
                  "CMake project name is $pi->{cmake_project}.",
                  "CMake variable names will be based on CMake project name.");

  (not $pi->{cqual}) or
    (exists $cqual_table->{$pi->{cqual}} and
     my ($cc, $cxx, $compiler_id, $compiler_version, $cxx_standard, $fc, $fc_id, $fc_version) =
     @{$cqual_table->{$pi->{cqual}}} or
     error_exit("unrecognized compiler qualifier $pi->{cqual}"));

  my @cmake_vars=();

  ##################
  # UPS-specific CMake configuration.

  push @cmake_vars, '-DWANT_UPS:BOOL=ON';
  push @cmake_vars,
    "-DUPS_C_COMPILER_ID:STRING=$compiler_id",
      "-DUPS_C_COMPILER_VERSION:STRING=$compiler_version",
        "-DUPS_CXX_COMPILER_ID:STRING=$compiler_id",
          "-DUPS_CXX_COMPILER_VERSION:STRING=$compiler_version",
            "-DUPS_Fortran_COMPILER_ID:STRING=$fc_id",
              "-DUPS_Fortran_COMPILER_VERSION:STRING=$fc_version"
                if $compiler_id;
  push @cmake_vars, sprintf('-D%s_UPS_PRODUCT_NAME:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{name}) if $pi->{name};
  push @cmake_vars, sprintf('-D%s_UPS_QUALIFIER_STRING:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{qual}) if $pi->{qual};
  push @cmake_vars, sprintf('-DUPS_%s_CMAKE_PROJECT_NAME:STRING=%s',
                            $pi->{name}, $pi->{cmake_project});
  push @cmake_vars, sprintf('-DUPS_%s_CMAKE_PROJECT_VERSION:STRING=%s',
                            $pi->{name}, $pi->{cmake_project_version});
  push @cmake_vars, sprintf('-D%s_UPS_PRODUCT_FLAVOR:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{flavor});
  push @cmake_vars, sprintf('-D%s_UPS_BUILD_ONLY_DEPENDENCIES=%s',
                            $pi->{cmake_project},
                            join(';', (sort keys %{$pi->{build_only_deps}})))
    if $pi->{build_only_deps};
  push @cmake_vars, sprintf('-D%s_UPS_USE_TIME_DEPENDENCIES=%s',
                            $pi->{cmake_project},
                            join(';', (sort keys %{$pi->{deps}})))
    if $pi->{deps};

  ##################
  # General CMake configuration.
  push @cmake_vars, "-DCMAKE_BUILD_TYPE:STRING=$pi->{cmake_build_type}"
    if $pi->{cmake_build_type};
  push @cmake_vars,
    "-DCMAKE_C_COMPILER:STRING=$cc",
      "-DCMAKE_CXX_COMPILER:STRING=$cxx",
        "-DCMAKE_Fortran_COMPILER:STRING=$fc",
          "-DCMAKE_CXX_STANDARD:STRING=$cxx_standard",
            "-DCMAKE_CXX_STANDARD_REQUIRED:BOOL=ON",
              "-DCMAKE_CXX_EXTENSIONS:BOOL=OFF"
                if $compiler_id;
  push @cmake_vars, sprintf('-D%s_EXEC_PREFIX_INIT:STRING=%s',
                            $pi->{cmake_project},
                            $pi->{fq_dir}) if $pi->{fq_dir};
  push @cmake_vars, sprintf('-D%s_NOARCH:BOOL=ON',
                            $pi->{cmake_project}) if $pi->{noarch};
  push @cmake_vars,
    sprintf("-D$pi->{cmake_project}_DEFINE_PYTHONPATH_INIT:BOOL=ON")
      if $pi->{define_pythonpath};

  ##################
  # Pathspec-related CMake configuration.

  push @cmake_vars,
    (map { cmake_project_var_for_pathspec($pfile, $pi, $_) || ();
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
  push @cmake_vars,
    sprintf('-D%s_ADD_ARCH_DIRS:STRING=%s',
            $pi->{cmake_project}, join(';', @arch_pathspecs))
      if scalar @arch_pathspecs;
  push @cmake_vars,
    sprintf('-D%s_ADD_NOARCH_DIRS:STRING=%s',
            $pi->{cmake_project}, join(';', @noarch_pathspecs))
      if scalar @noarch_pathspecs;

  ##################
  # Done.
  return \@cmake_vars;
}

sub print_dep_setup {
  my ($pi, $dep, $dep_info, $efl, @fail_msg) = @_;
  # Log build_only vs use-time deps.
  $pi->{$dep_info->{only_for_build} ?
        "build_only_deps" : "deps"}->{$dep} = 1;
  my $ql =
    sprintf(" -q +\%s",
            join(":+", split(':', $dep_info-> {qualspec} || '')));
  my $thisver =
    (not $dep_info->{version} or $dep_info->{version} eq "-") ? "" :
      $dep_info->{version};
  print $efl "# > $dep <\n";
  if ($dep_info->{optional}) {
    print $efl <<"EOF";
# Setup of $dep is optional.
ups exist $dep $thisver$ql
test "\$?" != 0 && \\
  echo \QINFO: skipping missing optional product $dep $thisver$ql\E || \\
EOF
    print $efl "  ";
  }
  print $efl "setup -B $dep $thisver$ql; ";
  setup_err($efl, "setup -B $dep $thisver$ql failed", @fail_msg);
}

sub setup_err {
  my $efl = shift;
  print $efl 'test "$?" != 0 && \\', "\n";
  foreach my $msg_line (@_) {
    chomp $msg_line;
    print $efl "  echo \QERROR: $msg_line\E && \\\n";
  }
  print $efl "  return 1 || true\n";
}

sub fq_path_for {
  my ($pfile, $pi, $dirkey, $default) = @_;
  my $pathspec = get_pathspec($pfile, $pi, $dirkey) ||
    { key => '-', path => $default };
  my $fq_path = $pathspec->{fq_path} || undef;
  unless ($fq_path or ($pathspec->{key} eq '-' and not $pathspec->{path})) {
    my $want_fq = $pi->{fq_dir} and
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
    @vals=($val);
  }
  my $result;
  open(my $efl, ">", \$result) or
    die "could not open memory stream to variable \$efl";
  print $efl "# $var\n",
    "setenv $var ", '"`dropit -p \\"${', "$var", '}\\" -sfe ';
  print $efl join(" ", map { sprintf('\\"%s\\"', $_); } @vals), '`"';
  if ($no_errclause) {
    print $efl "\n";
  } else {
    print $efl "; ";
    setup_err($efl, "failure to prepend to $var");
  }
  close($efl);
  return $result;
}

sub print_dev_setup {
  my ($pfile, $pi, $efl, @fail_msg) = @_;
  my $fqdir;
  print $efl <<"EOF";

####################################
# Development environment.
####################################
EOF
  my $libdir = fq_path_for($pfile, $pi, 'libdir', 'lib');
  if ($libdir) {
    # (DY)LD_LIBRARY_PATH.
    print $efl
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
    print $efl "$head\n",
      ($pi->{name} ne 'cetlib') ?
        "test -z \"\${CET_PLUGIN_PATH}\" || \\\n  " : '',
          join("\n", @output), "\n";
  }
  # ROOT_INCLUDE_PATH.
  print $efl
    print_dev_setup_var("ROOT_INCLUDE_PATH",
                        [ qw(${CETPKG_SOURCE} ${CETPKG_BUILD}) ]);
  # CMAKE_PREFIX_PATH.
  print $efl
    print_dev_setup_var("CMAKE_PREFIX_PATH", '${CETPKG_BUILD}', 1);
  # FHICL_FILE_PATH.
  $fqdir = fq_path_for($pfile, $pi, 'fcldir') and
    print $efl
      print_dev_setup_var("FHICL_FILE_PATH",
                          File::Spec->catfile('${CETPKG_BUILD}', $fqdir));
  # PYTHONPATH.
  if ($pi->{define_pythonpath}) {
    print $efl
      print_dev_setup_var("PYTHONPATH",
                          File::Spec->catfile('${CETPKG_BUILD}',
                                              $libdir ||
                                              ($pi->{fq_dir} || (), 'lib')));

  }
  # PATH.
  $fqdir = fq_path_for($pfile, $pi, 'bindir', 'bin') and
    print $efl
      print_dev_setup_var("PATH",
                          File::Spec->catfile('${CETPKG_BUILD}', $fqdir));
}

sub table_dep_setup {
  my ($dep, $dep_info, $fh) = @_;
  printf $fh
    "setup%s(%s %s -q+%s)\n",
      $dep_info->{optional} ? "Optional" : "Required",
        $dep,
          $dep_info->{version},
            join(":+", split(':', $dep_info->{qualspec} || ''));
}

sub var_stem_for_dirkey {
  my $dirkey = shift;
  return uc($pathspec_info->{$dirkey}->{project_var} ||
            (($dirkey =~ m&^(.*?)_*dir$&) ? "${1}_dir" :
             "${dirkey}_dir"));
}

1;
