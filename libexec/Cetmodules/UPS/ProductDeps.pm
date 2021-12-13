# -*- cperl -*-
package Cetmodules::UPS::ProductDeps;

use 5.016;
use English qw(-no_match_vars);
use Exporter qw(import);
use File::Spec;
use IO::File;
use List::MoreUtils;
use Readonly;
use Cetmodules::Util;
use strict;
use warnings FATAL => qw(
  Cetmodules
  io
  regexp
  severe
  syntax
  uninitialized
  void);
use vars qw($BTYPE_TABLE $PATHSPEC_INFO @EXPORT @EXPORT_OK);

@EXPORT = qw(
  $BTYPE_TABLE
  dirkey_is_valid
  get_parent_info
  get_pathspec
  get_product_list
  get_qualifier_list
  get_qualifier_matrix
  get_table_fragment
  pathkey_is_valid
  sort_qual
  var_stem_for_dirkey
);
@EXPORT_OK = qw(
  $PATHSPEC_INFO
);

########################################################################
# Exported variables
########################################################################
$BTYPE_TABLE =
  { q(debug) => 'Debug', q(prof) => 'RelWithDebInfo', q(opt) => 'Release' };
$PATHSPEC_INFO =
  { bindir         => {},
    cmakemoduledir => { project_var => 'CMAKE_MODULES_DIR' },
    fcldir         => { project_var => 'FHICL_DIR' },
    fwdir          => {},
    gdmldir        => {},
    incdir         => { project_var => 'INCLUDE_DIR' },
    libdir         => { project_var => 'LIBRARY_DIR' },
    perllib        => {},
    set_fwdir      => { multiple_ok => 1, project_var => "FW_SEARCH_PATH" },
    set_wpdir      => { multiple_ok => 1, project_var => "WIRECELL_PATH" },
    testdir        => {},
    wpdir          => {} };

########################################################################
# Private variables for use within this module only
########################################################################
my ($_chain_option_table, @_known_keywords, $_valid_pathkeys);
Readonly::Scalar my $_LAST_CHAR_IDX => -1;
Readonly::Scalar my $_NOT_PRESENT   => -2;
Readonly::Scalar my $_NO_MATCH      => -1;

########################################################################
# Exported functions
########################################################################
sub dirkey_is_valid {
  my ($dirkey) = @_;
  return ($dirkey
      and List::MoreUtils::any { $_ eq $dirkey } keys %{$PATHSPEC_INFO});
} ## end sub dirkey_is_valid


sub get_parent_info {
  my ($pfile, %options) = @_;
  my $fh = IO::File->new("$pfile", "<") or error_exit("couldn't open $pfile");
  my $result = { pfile => $pfile };
  my $chains;

  while (<$fh>) {
    chomp;
    s&\s*\#.*\z&&msx;
    m&\w+&msx or next;
    my ($keyword, @pars) = split;
    given ($keyword) {
      when ('parent') {
        $#pars < 1
          or $options{quiet_warnings}
          or warning(
            "multi-argument version of \"parent\" in $pfile",
            "is deprecated: VERSION defined via project() or",
            "via <project>_CMAKE_PROJECT_VERSION_STRING in",
            "CMakeLists.txt governs.",
            "Use \"chain[s] [current|test|new|old|<chain>] ...\" in",
            "$pfile to specify chains.");
        $result->{name}    = shift @pars;
        $result->{version} = shift @pars;
        @{$chains}{@pars} = (1) x scalar @pars;
      } ## end when ('parent')
      when (m&\Achains?\z&msx) {
        @{$chains}{@pars} = (1) x scalar @pars;
      }
      when ('defaultqual') {
        $result->{default_qual} =
          (($pars[0] // q()) eq '-nq-') ? q() : sort_qual(@pars);
      }
      when ([qw(define_pythonpath
             no_fq_dir
             noarch
             old_style_config_vars)
        ]) {
        scalar @pars
          and warning(sprintf("unexpected garbage following $keyword: %s",
            join(q( ), @pars)));
        $result->{$keyword} = 1;
      } ## end when ([qw(define_pythonpath...)])
      default {
      }
    } ## end given
  } ## end while (<$fh>)
  $fh->close();

  # Make the chain list, translating -c... ups declare options to their
  # corresponding chain names.
  scalar keys %{$chains}
    and $result->{chains} =
    [sort map { $_chain_option_table->{$_} // $_; } keys %{$chains}];
  return $result;
} ## end sub get_parent_info

# Retrieve possibly multiple pathspecs from product_deps.
sub get_pathspec {
  my ($pi, @requested_dirkeys) = @_;
  scalar @requested_dirkeys or return;
  defined $pi->{pathspec_cache} or $pi->{pathspec_cache} = {};
  my $pathspec_cache = $pi->{pathspec_cache}; # Convenience.

  # Compile a hash of the dirkeys we're looking for indicating whether
  # they've been seen before. Note that we actually want the side effect
  # of creating the entry in $pathspec_cache if they don't already
  # exist, so we won't look for them again.
  my $requested_dirkeys = {
      map {
        my ($dirkey) = ($_);
        dirkey_is_valid($dirkey)
        or error_exit("unrecognized directory key $dirkey");
        ($dirkey => $pathspec_cache->{$dirkey}->{seen_at} // $_NO_MATCH);
      } @requested_dirkeys
  };
  _pathspecs_for_keys(
      $pi,
      [map {
         (($requested_dirkeys->{$_} // 0) == $_NO_MATCH) ? "\Q$_\E" : ();
       } keys %{$requested_dirkeys}]);
  my @results = map {
      (     $pathspec_cache->{$_}
        and $_NOT_PRESENT ne
        ($pathspec_cache->{$_}->{seen_at} // $_NOT_PRESENT))
      ? $pathspec_cache->{$_}
      : undef;
  } @requested_dirkeys;
  return (scalar @results > 1) ? @results : pop @results;
} ## end sub get_pathspec


sub get_product_list {
  my ($pfile) = @_;
  my $fh = IO::File->new("$pfile", "<") or error_exit("couldn't open $pfile");
  my $get_phash;
  my $pv        = q();
  my $dqiter    = $_NO_MATCH;
  my $piter     = $_NO_MATCH;
  my $phash     = {};
  my $pl_format = 1;         # Default format.

  while (<$fh>) {
    chomp;
    s&\s*\#.*\z&&msx;        # Eat all comments.
    m&\w+&msx or next;
    my (@words) = split;
    my $keyword = $words[0];

    if ($keyword eq "end_product_list") {
      last;                  # Done.
    } elsif ($keyword eq "product") {
      $get_phash = "true";

      if ($words[$_LAST_CHAR_IDX] =~
          m&\A<\s*(?:table_)?format\s*=\s*(\d+)\s*>&msx) {
        $pl_format = ${1};
      }
    } elsif ($get_phash) {
      _unwanted_keyword($keyword)
        and error_exit(sprintf(
"unexpected keyword $keyword at $pfile:%d - missing end_product_list?",
          $fh->input_line_number));

      # Also covers archaic "only_for_build" lines: do *not* put a
      # special case above.
      ++$piter;
      my ($prod, $version, $qualspec, @modifiers) = @words;
      $qualspec or $qualspec = q(-);

      if ($prod eq "only_for_build") {

        # Archaic form.
        ($prod, $version, $qualspec, @modifiers) =
          ($version, $qualspec, q(-), $prod);
        warning(
"Deprecated only_for_build entry found in $pfile: please replace:\n",
            "  \"$_\"\n",
            "with\n",
            "  \"$prod\t$version\t$qualspec\t$modifiers[0]\"\n",
            "This accommodation will be removed in future.");
      } ## end if ($prod eq "only_for_build")

      if ($qualspec and $qualspec eq "-nq-") {

        # Under format version 1, "-nq-" meant, "always." Since format
        # version 2, it means, "when we have no qualifiers," and "-"
        # means, "always."
        $qualspec = ($pl_format == 1) ? q(-) : q();
      } ## end if ($qualspec and $qualspec...)
      $phash->{$prod}->{$qualspec} =
        { version => (($version eq q(-)) ? "-c" : $version),
          map { ($_ => 1) } @modifiers
        };
    } else {
    }
  } ## end while (<$fh>)
  $fh->close();
  return $phash;
} ## end sub get_product_list


sub get_qualifier_list {
  my ($pfile) = @_;
  my $get_quals;
  my $qlen  = 0;
  my @qlist = ();
  my @notes = ();
  my $fh = IO::File->new("$pfile", "<") or error_exit("couldn't open $pfile");

  while (<$fh>) {
    chomp;
    s&\s*\#.*\z&&msx;
    m&\w+&msx or next;
    my (@words) = split;
    my $keyword = $words[0];

    if ($keyword eq "end_qualifier_list") {
      last; # Done.
    } elsif ($get_quals) {
      _unwanted_keyword($keyword) and error_exit(<<"EOF");
unexpected keyword $keyword at $pfile:$INPUT_LINE_NUMBER - missing end_qualifier_list?
EOF
      scalar @words < $qlen and error_exit(<<"EOF");
require $qlen qualifier_list entries for $keyword at $pfile:$INPUT_LINE_NUMBER - found only $#words
EOF
      push @notes, $words[$qlen + 1] || q();
      push @qlist,
        [map { (not $_ or $_ eq "-nq-") ? (q()) : sort_qual($_); }
         @words[0 .. $qlen]];
    } elsif ($keyword eq "qualifier") {
      $get_quals = 1;
      push @qlist, [List::MoreUtils::before { $_ eq 'notes' } @words];

      # N.B. qlen does not count the qualifier column for historical
      # reasons, though @qlist includes it.
      $qlen = $#{ $qlist[0] };
      $qlen < $#words and @notes = ($words[$qlen + 1]);
    } else {
    }
  } ## end while (<$fh>)
  $fh->close();
  return ($qlen, \@qlist, \@notes);
} ## end sub get_qualifier_list


sub get_qualifier_matrix {
  my ($pinfo) = @_;
  my ($qlen, $qlist, $notes) = get_qualifier_list($pinfo);
  my ($qhash, $qqhash, $nhash, $headers); # (by-column, by-row, notes, headers)

  if ($qlist and scalar @{$qlist}) {
    my @prods = @{ shift @{$qlist} };     # Drop header row from @{$qlist}.
    $qhash = {
        map {
          my $idx = $_;
          ($prods[$idx] => { map { (@{$_}[0] => @{$_}[$idx]); } @{$qlist} });
        } 1 .. $qlen
    };
    $qqhash = {
        map {
          my @dq = @{$_};
          ($dq[0] => { map { ($prods[$_] => $dq[$_]); } 1 .. $qlen });
        } @{$qlist} };
    $headers = [@prods, shift @{$notes} || ()];
    $nhash   = { map { ($_->[0] => (shift @{$notes} or q())); } @{$qlist} };
  } ## end if ($qlist and scalar ...)
  return ($qlen, $qhash, $qqhash, $nhash, $headers);
} ## end sub get_qualifier_matrix


sub get_table_fragment {
  my $pfile = shift;
  my $reading_frag;
  my @fraglines = ();
  my $fh = IO::File->new("$pfile", "<") or error_exit("couldn't open $pfile");

  while (<$fh>) {
    chomp;
    next if (m&\A\s*\#&msx and not $reading_frag);
    m&\A\s*table_fragment_end&msx and undef $reading_frag;
    $reading_frag and push @fraglines, $_;
    m&\A\s*table_fragment_begin&msx and $reading_frag = 1;
  } ## end while (<$fh>)
  $fh->close();
  return (scalar @fraglines) ? \@fraglines : undef;
} ## end sub get_table_fragment


sub pathkey_is_valid {
  my ($pathkey) = @_;
  return $pathkey
    and List::MoreUtils::any { $_ eq $pathkey } @{$_valid_pathkeys};
} ## end sub pathkey_is_valid


sub sort_qual {
  my @args = @_;

  # If the first argument is a reference to ARRAY, then it is an output
  # array reference for the result.
  my $sorted       = ref($args[0] // undef) eq 'ARRAY' ? shift @args : [];
  my @resplit_args = split(/:/msx, join(q(:), @args));
  my ($cqual, $btype);
  my @extquals = ();

  foreach my $q (map { (m&\A\+(.*)?&msx) or $_; } @resplit_args) {
    if ($q =~ m&\A[ce]\d+z&msx) {
      $cqual
        and error_exit("multiple primary qualifiers encountered: $cqual, $q")
        or $cqual = $q;
    } elsif (exists $BTYPE_TABLE->{$q}) {
      $btype
        and
        error_exit("multiple build type qualifiers encountered: $btype, $q")
        or $btype = $q;
    } elsif ($q ne '-nq-') {
      push @extquals, $q;
    }
  } ## end foreach my $q (map { (m&\A\+(.*)?&msx...)})

  # Re-order.
  my $eq = join(q(:), sort @extquals);
  @{$sorted} = ($cqual, $eq, $btype);
  return join(q(:), map { $_ || (); } @{$sorted});
} ## end sub sort_qual


sub var_stem_for_dirkey {
  my $dirkey = shift;
  return
    uc($PATHSPEC_INFO->{$dirkey}->{project_var}
      || (($dirkey =~ m&\A(.*?)_*dir\z&msx) ? "${1}_dir" : "${dirkey}_dir"));
} ## end sub var_stem_for_dirkey

########################################################################
# Private variables
########################################################################
$_chain_option_table = { '-c' => 'current',
                         '-d' => 'development',
                         '-n' => 'new',
                         '-o' => 'old',
                         '-t' => 'test'
                       };
@_known_keywords = (
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
    ), sort keys %{$PATHSPEC_INFO});
$_valid_pathkeys = [qw(product_dir fq_dir -)];

########################################################################
# Private functions
########################################################################
sub _pathspecs_for_keys {
  my ($pi, $dirkeys) = @_;
  scalar @{ $dirkeys // [] } or return;
  my $pathspec_cache = $pi->{pathspec_cache};
  my $dirkeys_regex  = sprintf(
qr&\A\s*(?P<dirkey>%s)\b(?:\s+(?P<pathkey>\S+)\s*(?P<dirname>\S*?))?(?:\s*\#.*)?\z&msx,
      join(q(|), @{$dirkeys}));
  my $fh = IO::File->new("$pi->{pfile}", "<")
    or error_exit("couldn't open $pi->{pfile} for read");

  while (<$fh>) {
    chomp;
    m&$dirkeys_regex&msx or next;
    my ($dirkey, $pathkey, $dirname) =
      _validate_pathspec_entry($pi->{pfile}, $pathspec_cache,
        (@LAST_PAREN_MATCH{qw(dirkey pathkey dirname)}));
    push @{ $pathspec_cache->{$dirkey}->{key} }, $pathkey;

    if ($pathkey eq q(-) and not $dirname) {
      delete $pathspec_cache->{$dirkey}->{path};
    } else {
      push @{ $pathspec_cache->{$dirkey}->{path} }, $dirname;
    }
  } ## end while (<$fh>)
  $fh->close();

  # Simplify new cache entries.
  for (@{$dirkeys}) {
    if (not defined $pathspec_cache->{$_}->{seen_at}) {
      $pathspec_cache->{$_}->{seen_at} = $_NOT_PRESENT;
    } elsif (not $PATHSPEC_INFO->{$_}->{multiple_ok}) {
      $pathspec_cache->{$_}->{key} = $pathspec_cache->{$_}->{key}->[0];
      exists $pathspec_cache->{$_}->{path}
        and $pathspec_cache->{$_}->{path} =
        $pathspec_cache->{$_}->{path}->[0];
    } ## end elsif (not $PATHSPEC_INFO... [ if (not defined $pathspec_cache...)])
  } ## end for (@{$dirkeys})
  return;
} ## end sub _pathspecs_for_keys


sub _unwanted_keyword {
  my ($keyword, @allowed) = @_;
  return (List::MoreUtils::any { $keyword eq $_ } @_known_keywords
      and List::MoreUtils::none { $keyword eq $_ } @allowed);
} ## end sub _unwanted_keyword


sub _validate_pathspec_entry {
  my ($pfile, $pathspec_cache, $dirkey, $pathkey, $dirname) = @_;
  $pathkey or error_exit(<<"EOF");
dangling directory key $dirkey seen in $pfile at line $INPUT_LINE_NUMBER:
path key is required
EOF
  pathkey_is_valid($pathkey) or error_exit(<<"EOF");
unrecognized path key $pathkey for directory key $dirkey in $pfile
at line $INPUT_LINE_NUMBER
EOF
  my $multiple_ok = $PATHSPEC_INFO->{$dirkey}->{multiple_ok} // 0;

  if (exists $pathspec_cache->{$dirkey}->{seen_at}) {
    $multiple_ok or error_exit(<<"EOF");
illegal duplicate directory key $dirkey seen in $pfile
at line $INPUT_LINE_NUMBER (first seen at line $pathspec_cache->{$dirkey}->{seen_at})
EOF
    $pathkey eq q(-) and not $dirname and error_exit(<<"EOF");
elision request (pathkey '-' with no path) at line $INPUT_LINE_NUMBER
is only valid for the first mention of a directory key
($dirkey first seen at line $pathspec_cache->{$dirkey}->{seen_at})
EOF
  } else {
    $pathspec_cache->{$dirkey}->{seen_at} = $INPUT_LINE_NUMBER;
  }
  return ($dirkey, $pathkey, $dirname);
} ## end sub _validate_pathspec_entry

########################################################################
1;
__END__

# Not currently needed.
sub _wanted_keyword {
  my ($keyword, @allowed) = @_;
  return List::MoreUtils::any { $keyword eq $_ } @allowed;
}
