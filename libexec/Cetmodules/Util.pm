# -*- cperl -*-
package Cetmodules::Util;

use 5.016;

use strict;

use English qw(-no_match_vars);
use Exporter qw(import);
use Readonly;
use Cetmodules qw(:DIAG_VARS);

use warnings FATAL =>
  qw(Cetmodules io regexp severe syntax uninitialized void);
use vars qw($DEFAULT_PREFIX_MIN_LENGTH);

our (@EXPORT);

@EXPORT = qw(
  $DEFAULT_PREFIX_MIN_LENGTH
  debug
  error
  error_exit
  info
  notify
  offset_annotated_items
  parse_version_string
  shortest_unique_prefix
  to_cmake_version
  to_dot_version
  to_product_name
  to_string
  to_ups_version
  to_version_string
  verbose
  version_cmp
  version_sort
  warning
);

########################################################################
# Private variables
########################################################################

Readonly::Scalar my $_INIT_DEFAULT_PREFIX_MIN_LENGTH => 6;
Readonly::Scalar my $_NO_NUMERIC_VERSION_OFFSET      => 100;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_NO_NUMERIC => 1 +
  $_NO_NUMERIC_VERSION_OFFSET;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_PATCH   => 1;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_GENERIC => 2;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_NIGHTLY => 3;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_PRE     => -1;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_GAMMA   => -2;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_BETA    => -3;
Readonly::Scalar my $_VERSION_EXTRA_TYPE_ALPHA   => -4;

########################################################################
# Exported variables
########################################################################

$DEFAULT_PREFIX_MIN_LENGTH = $_INIT_DEFAULT_PREFIX_MIN_LENGTH;

########################################################################
# Exported functions
########################################################################


sub debug {
  my @msg = @_;
  $DEBUG or return;
  chomp @msg;
  print STDERR map { "DEBUG: $_\n"; } map { split(m&\n&msx) } @msg;
  return;
}


sub error {
  my (@msg) = @_;
  chomp @msg;
  print STDERR map { "ERROR: $_\n"; }
    (q(), (map { split(m&\n&msx) } @msg), q());
  return;
}


sub error_exit {
  my (@msg) = @_;
  chomp @msg;
  die map { "FATAL_ERROR: $_\n"; } (q(), (map { split(m&\n&msx) } @msg), q());
}


sub info { ## no critic qw(Bangs::ProhibitVagueNames)
  $QUIET or notify(@_);
  return;
}


sub notify {
  my (@msg) = @_;
  chomp @msg;
  print map { "INFO: $_\n"; } map { split(m&\n&msx) } @msg;
  return;
}


sub offset_annotated_items {
  my ($offset, $preamble, @args) = @_;
  my $indent = length($preamble) + $offset;
  return
    sprintf('%s%s',
            $preamble,
            join(sprintf(",\n\%s", q( ) x $indent),
                 map { to_string($_, { indent => $indent }); } @args
                ));
} ## end sub offset_annotated_items


sub parse_version_string {
  my $dv = shift // q();
  $dv =~ s&\Av&&msx;
  my $result = {};
  my $def_ps = '[-_.,]';
  my $ps;
  my @bits;
  foreach my $key (qw(major minor patch tweak)) {
    my $sep = (defined $ps) ? $ps : $def_ps;
    if ($dv ne q() and $dv =~ s&\A(?<num>\d+)?(?<sep>$sep)?&&msx) {
      $LAST_PAREN_MATCH{sep} and not $ps and $ps = "[$LAST_PAREN_MATCH{sep}]";
      defined $LAST_PAREN_MATCH{num} and
        $result->{$key} = $LAST_PAREN_MATCH{num};
    } else {
      last;
    }
  } ## end foreach my $key (qw(major minor patch tweak))
  $LAST_PAREN_MATCH{sep} or $dv =~ s&\A$def_ps&&msx;
  $dv ne q() and $result->{extra} = $dv;

  # Make sure we insert placeholders in the array only if we need them
  foreach my $key (qw(tweak patch minor major)) {
    if (exists $result->{$key} or scalar @bits) {
      defined $result->{$key} or $result->{$key} = 0;
      unshift @bits, $result->{$key};
    }
  }
  scalar @bits and $result->{bits} = [@bits];
  return _parse_extra($result);
} ## end sub parse_version_string

# Adapted from
# http://blogs.perl.org/users/laurent_r/2020/04/perl-weekly-challenge-57-tree-inversion-and-shortest-unique-prefix.html
# to support minimum number of characters in substring, and to retain
# original->prefix correspondence.
sub shortest_unique_prefix {
  my @args              = @_;
  my $prefix_min_length = $DEFAULT_PREFIX_MIN_LENGTH;
  my $result            = {};
  my %letters;
  my @words = ();
  if (ref $args[0]) {
    @words = @{ shift @args };
  } elsif (ref $args[1] // undef) {
    $prefix_min_length = shift @args;
    @words             = @{ shift @args };
  } else {
    @words = @args;
  }
  for my $word (@words) {
    push @{ $letters{ substr $word, 0, 1 } }, $word;
  }
  for my $letter (keys %letters) {
    if (scalar @{ $letters{$letter} } == 1) {
      $result->{ $letters{$letter}->[0] } =
        substr($letters{$letter}->[0], 0, $prefix_min_length);
      next;
    }
    my $candidate;
    for my $word1 (@{ $letters{$letter} }) {
      my $prefix_length = 0;
      for my $word2 (@{ $letters{$letter} }) {
        next if $word1 eq $word2;
        my $i = 1;
        while (substr($word1, $i, 1) eq substr($word2, $i, 1)) { ++$i; }
        if ($i > $prefix_length) {
          $candidate = substr($word1, 0,
               (($i + 1) > $prefix_min_length) ? $i + 1 : $prefix_min_length);
          $prefix_length = $i;
        }
      } ## end for my $word2 (@{ $letters...})
      $result->{$word1} = $candidate // $word1;
    } ## end for my $word1 (@{ $letters...})
  } ## end for my $letter (keys %letters)
  return $result;
} ## end sub shortest_unique_prefix


sub to_cmake_version {
  return _format_version(shift, q(.), want_extra => 0);
}


sub to_dot_version {
  return _format_version(shift, q(.));
}


sub to_product_name {
  my $name = lc shift or error_exit("vacuous name");
  $name =~ s&[^a-z0-9]&_&msxg;
  return $name;
}


sub to_ups_version {
  return _format_version(shift, q(_), preamble => q(v));
}


sub to_version_string {
  return _format_version(shift, q(.), pre_extra_sep => q(-));
}


sub to_string {
  my @args = @_;
  Readonly::Scalar my $INCREMENTAL_INDENT     => 2;
  Readonly::Scalar my $HASH_INDENT            => length('{ ');
  Readonly::Scalar my $MAX_INCREMENTAL_INDENT => 14;
  my $options = ((@args == 2) and (ref $args[1] eq 'HASH')) ? pop @args : {};
  my $indent  = delete $options->{indent};
  defined $indent or
    $indent = (ref $args[0] and $#args > 0 and not ref $args[-1]) ? pop : 0;
  my $item = ((@args > 1) ? [@args] : shift @args) // "<undef>";

  if (exists $options->{preamble}) {
    my ($hanging_preamble) =
      ($options->{preamble} =~ m&\A(?:.*?\n)*(.*?)[ \t]*\z&msx);
    my $hplen = length($hanging_preamble);
    if ($hplen > $MAX_INCREMENTAL_INDENT) {
      $indent += $INCREMENTAL_INDENT;
    } else {
      $indent += $hplen + 1;
    }
  } ## end if (exists $options->{...})
  my $type = ref $item;
  my $initial_indent =
    ($options->{full_indent}) ? q( ) x $options->{full_indent} : q();
  $options->{full_indent} and $indent += $options->{full_indent};
  my $result;
  given ($type) {
    when ([ q(), 'CODE' ]) { $result = "$initial_indent$item"; }
    when ('SCALAR')        { $result = "$initial_indent$$item"; }
    when ('ARRAY') {
      $result = sprintf("$initial_indent\%s ]",
                        offset_annotated_items($indent, '[ ', @{$item}));
    }
    when ('HASH') {
      $indent += $HASH_INDENT;
      $result = sprintf(
        "${initial_indent}{ \%s }",
        join(
          sprintf(",\n\%s", q( ) x $indent),
          map {
            to_string($item->{$_},
                      { preamble => "$_ => ", indent => $indent });
          } keys %{$item}));
      $indent -= $HASH_INDENT;
    } ## end when ('HASH')
    default {
      die "ERROR: cannot print item of type $_.\n";
    }
  } ## end given
  return sprintf('%s%s', $options->{preamble} || q(), $result);
} ## end sub to_string


sub verbose {
  my @msg = @_;
  $VERBOSE or return;
  chomp @msg;
  print map { "VERBOSE: $_\n"; } map { split(m&\n&msx) } @msg;
  return;
}

# Comparison algorithm for versions. cf cet_version_cmp() in
# ParseVersionString.cmake.
#
# Not stable as a sorting method: use version_sort() instead.
sub version_cmp {
  my @args = @_;
  @args == 2 or
    error_exit(
"tried to use version_cmp() as a sorting algorithm: use version_sort() instead"
    );
  my ($vInfoA, $vInfoB) =
    map { (ref) ? $_ : parse_version_string($_); } @args;
  my $ans = (
             (($vInfoA->{extra_type}   // 0) > $_NO_NUMERIC_VERSION_OFFSET or
                ($vInfoB->{extra_type} // 0) > $_NO_NUMERIC_VERSION_OFFSET
             ) ? 0 : ($vInfoA->{major} // 0) <=> ($vInfoB->{major} // 0) ||
               ($vInfoA->{minor} // 0) <=> ($vInfoB->{minor} // 0) ||
               ($vInfoA->{patch} // 0) <=> ($vInfoB->{patch} // 0) ||
               ($vInfoA->{tweak} // 0) <=> ($vInfoB->{tweak} // 0)
    ) ||
    ($vInfoA->{extra_type} // 0) <=> ($vInfoB->{extra_type} // 0);
  $ans or
    ($vInfoA->{extra_type} // 0) != $_VERSION_EXTRA_TYPE_GENERIC or
    $ans = ($vInfoA->{extra_text} // q()) cmp
    ($vInfoB->{extra_text} // q());
  $ans or
    $ans =
    ((($vInfoA->{extra_type} // 0) % $_NO_NUMERIC_VERSION_OFFSET) ==
     $_VERSION_EXTRA_TYPE_NIGHTLY) ?
    _date_cmp($vInfoA->{extra_num} // 0, $vInfoB->{extra_num} // 0) :
    ($vInfoA->{extra_num} // 0) <=> ($vInfoB->{extra_num} // 0);
  return $ans;
} ## end sub version_cmp

# Stable sorting algorithm for versions.
#
#
# Use slower prototype form due to package scope issues for $a, $b;
sub version_sort($$) { ## no critic qw(ProhibitSubroutinePrototypes)
  my @args = @_;
  my ($vInfoA, $vInfoB) =
    map { (ref) ? $_ : parse_version_string($_); } @args;
  my $ans = version_cmp($vInfoA, $vInfoB);
  if (not $ans) {
    my ($etextA, $enumA, $etextB, $enumB) =
      map { ($_->{extra} // q() =~ m&\A(.*?)[_.-]?(\d+(?:\.\d*)?)?\z&msx); }
      ($vInfoA, $vInfoB);
    $ans =
      (lc($etextA // q()) eq lc($etextB // q())) ?
      (($enumA    // 0) <=> ($enumB // 0)) ||
      (($etextA // q()) cmp($etextB // q())) :
      (($vInfoA->{extra} // q()) cmp($vInfoB->{extra} // q()));
  } ## end if (not $ans)
  return $ans;
} ## end sub version_sort($$)


sub warning {
  my (@msg) = @_;
  $QUIET_WARNINGS and return;
  chomp @msg;
  print STDERR map { "WARNING: $_\n"; }
    (q(), (map { split(m&\n&msx) } @msg), q());
  return;
}

########################################################################
# Private variables and functions
########################################################################
sub _date_cmp {
  my ($a, $b) = @_;
  my $date_regex      = qr&(?P<date>\d{4}[0-1]\d[0-3]\d)&msx;
  my $sec_regex       = qr&((?P<SS>[0-5]\d)\.?(?P<ss>\d+)?)&msx;
  my $time_regex      = qr&((?P<HH>[0-2]\d)((?P<mm>[0-5]\d)$sec_regex?)?)&msx;
  my $date_time_regex = qr&\A$date_regex$time_regex?\z&msx;
  my $aInfo = ($a =~ m&$date_time_regex&msx) ? {%LAST_PAREN_MATCH} : {};
  my $bInfo = ($b =~ m&$date_time_regex&msx) ? {%LAST_PAREN_MATCH} : {};
  return
    $aInfo->{date} ? $aInfo->{date} <=> ($bInfo->{date} // 0)
    || sprintf("%s%s%s.%s",
               $aInfo->{HH} || "00",
               $aInfo->{mm} || "00",
               $aInfo->{SS} || "00",
               $aInfo->{ss} || "00") <=> sprintf("%s%s%s.%s",
                                                 $bInfo->{HH} || "00",
                                                 $bInfo->{mm} || "00",
                                                 $bInfo->{SS} || "00",
                                                 $bInfo->{ss} || "00") :
    $bInfo->{date} ? ($aInfo->{date} // 0) <=> $bInfo->{date} :
    $a <=> $b;
} ## end sub _date_cmp


sub _format_version {
  my @args = @_;
  my $v    = shift @args;
  ref $v or $v = parse_version_string($v) // {};
  my $separator     = (shift @args) // q(.);
  my $keyword_args  = {@args};
  my $main_v_string = join($separator, @{ $v->{bits} // [] });
  if ($keyword_args->{want_extra} // 1) {
    $main_v_string = sprintf(
                           "%s%s%s",
                           $keyword_args->{preamble} // q(),
                           $main_v_string,
                           ($v->{extra}) ?
                             sprintf("%s%s",
                                     ($main_v_string) ?
                                       $keyword_args->{pre_extra_sep} // q() :
                                       q(),
                                     $v->{extra}) :
                             q());
  } elsif (wantarray) {
    return ($main_v_string, $v->{extra} // q());
  }
  return $main_v_string;
} ## end sub _format_version

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
  exists $vInfo->{extra} and $vInfo->{extra} ne q() or return $vInfo;
  my ($enum) = ($vInfo->{extra} =~ m&(\d+(?:\.\d*)?)\z&msx);
  my ($etext) = (
         defined $enum ? ($vInfo->{extra} =~ m&\A(.*?)[_.-]?\Q$enum\E\z&msx) :
           $vInfo->{extra});
  my $etext_l = lc $etext;
  given ($etext_l) {
    when (q()) { $vInfo->{extra_type} = 0; }
    when (m&(?:\A|.+-)(?:nightly|snapshot)\z&msx) {
      $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_NIGHTLY +
        ((exists $vInfo->{bits}) ? 0 : $_NO_NUMERIC_VERSION_OFFSET);
    }
    when (not exists $vInfo->{bits}) {
      $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_NO_NUMERIC;
      undef $enum;
      $etext = $vInfo->{extra};
    }
    when ([ 'patch', ('p' and ($enum // q()) ne q()) ]) {
      $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_PATCH;
    }
    when ([ 'rc', 'pre' ]) {
      $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_PRE;
    }
    when ('gamma') { $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_GAMMA; }
    when ('beta')  { $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_BETA; }
    when ('alpha') { $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_ALPHA; }
    default {
      $vInfo->{extra_type} = $_VERSION_EXTRA_TYPE_GENERIC;
      $vInfo->{extra_text} = $etext_l;
    }
  } ## end given
  exists $vInfo->{extra_text} or $vInfo->{extra_text} = $etext;
  defined $enum and $vInfo->{extra_num} = $enum;
  return $vInfo;
} ## end sub _parse_extra

1;
