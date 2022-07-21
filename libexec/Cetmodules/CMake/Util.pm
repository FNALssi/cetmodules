# -*- cperl -*-
package Cetmodules::CMake::Util;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules qw();
use English qw(-no_match_vars);
use Exporter qw(import);
use Readonly qw();
use Scalar::Util qw(blessed);

##
use warnings FATAL => qw(Cetmodules);

our (@EXPORT);

@EXPORT = qw(
  can_interpolate
  interpolated
  is_bracket_quoted
  is_cmake_true
  is_command_info
  is_comment
  is_double_quoted
  is_quoted
  is_unquoted
  is_whitespace
  separate_quotes
);

########################################################################
# Private variables
########################################################################
my $_not_escape = qr&(?P<not_escape>^|[^\\]|(?>\\\\))&msx;

########################################################################
# Exported functions
########################################################################
# Check whether we can make this a truly literal CMake string, or
# whether there are CMake- or Make-style variable references or
# generator expressions.
sub can_interpolate {
  my ($candidate_string) = @_;
  return not(
    $candidate_string =~
m&$_not_escape(?:)(?<![\$])[\$] # an unescaped '$' not immediately preceded by an unescaped '$' followed by either:
      (?:<| # '>' (generator expression), or...
        (?:(?P<paren>[(])|(?P<brace>[{])) # a Make- ('(') or CMake-style ('{')
        [A-Za-z0-9_]+ # variable reference
        (?(<paren>)[)]|(?(<brace>)[}]))) # with matching closer
     &msx);
} ## end sub can_interpolate


sub interpolated {
  my @args = @_;
  scalar @args or return;
  my @separated = (scalar @args > 1) ? @args : separate_quotes(@args);
  my ($interpolated_string, $is_literal);

  if (@separated and scalar @separated > 1) {
    local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
    $interpolated_string = $separated[1];
    given ($separated[0]) {
      when (q(")) { # double-quoted
        $interpolated_string =~ s&$_not_escape\\\n&\k<not_escape>&msgx; # line continuation
      }
      default {                                                         # bracket-quoted
        $interpolated_string =~ m&\A(?>\n?)(.*)\z&msx;
        return wantarray ? ($interpolated_string, 1) : $interpolated_string;
      }
    } ## end given
  } else {
    $interpolated_string = $separated[0] || q();
  } ## end if (@separated and scalar @separated > 1)

  if (can_interpolate($interpolated_string)) {
    ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
    $interpolated_string =~ s&$_not_escape\\t&\k<not_escape>\t&msgx; # tab
    $interpolated_string =~ s&$_not_escape\\r&\k<not_escape>\r&msgx; # carriage return
    $interpolated_string =~ s&$_not_escape\\n&\k<not_escape>\n&msgx; # newline
    $interpolated_string =~                                          # "identity" escape sequences: \X -> X
s&$_not_escape\\(?P<identity>[^A-Za-z0-9_\$\\}{<])&\k<not_escape>\k<identity>&msgx;
    $interpolated_string =~                                          # remaining identity escape sequences
s&$_not_escape\\(?P<identity>[\$\\}{<])&\k<not_escape>\k<identity>&msgx;
    $is_literal = 1;
  } ## end if (can_interpolate($interpolated_string...))
  return
    wantarray ? ($interpolated_string, $is_literal) : $interpolated_string;
} ## end sub interpolated


sub is_command_info {
  my ($ref) = @_;
  return blessed($ref) && $ref->isa("Cetmodules::CMake::CommandInfo");
}


sub is_cmake_true {
  my ($cmake_val) = @_;
  return
    not (interpolated($cmake_val) // q()) =~ m&\A(?:0|OFF|NO|FALSE|N|IGNORE|(?:.*-)?NOTFOUND)?\z&imsx;
} ## end sub is_cmake_true


sub is_comment {
  return join(q(), @_) =~ m&\A\s*[#]&msx;
}


sub is_quoted {
  my @args      = @_;
  my @separated = separate_quotes(@args);
  scalar @separated > 1 and return $separated[0];
  return;
} ## end sub is_quoted


sub is_unquoted {
  is_quoted(@_) or return 1;
  return;
}


sub is_whitespace {
  scalar @_ or return;
  return join(q(), @_) =~ m&\A\s*\z&msx;
}


sub separate_quotes {
  my $item = (scalar @_) ? join(q(), @_) : return;
  return (
    ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
    $item =~ m&\A # anchor to string start
            (?| # reset alternation to allow capture groups in multiple scenarios
              (?P<q1>(?P<qs>["]) # open double-quote
                (?P<qmarker>) # empty group to preserve consistency of capture groups in reset alternation
              ) # ...followed by...
              (?P<quoted>(?>(?:(?>[^"\\]+)|\\.)*)) # ...non-special or escaped special characters, followed by...
              (?P<q2>(?P=q1)) # matching closing double-quote -> (1) double-quoted argument OR
              |(?P<q1>(?P<qs>[[])(?>(?P<qmarker>=*))[[]) # open quoting bracket followed by...
                (?P<quoted>.*?) # anything followed by...
                (?P<q2>[]](?P=qmarker)[]]) # close quoting bracket -> (2) bracket-quoted argument
              )\z # anchor to string end
           &msx
  ) ? @LAST_PAREN_MATCH{qw(q1 quoted q2)} : ($item);
} ## end sub separate_quotes

########################################################################
1;
