# -*- cperl -*-
package Cetmodules::CMake;

use 5.016;
use Cwd qw(abs_path);
use English qw(-no_match_vars);
use Exporter qw(import);
use Fcntl qw(:seek);
use File::Spec;
use IO::File;
use List::MoreUtils qw();
use List::Util qw();
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
  void
);

our (@EXPORT);

@EXPORT = qw(
  @PROJECT_KEYWORDS
  add_args_after
  all_values_for
  append_args
  arg_at
  arg_location
  can_interpolate
  find_all_args_for
  find_args_for
  find_args_matching
  find_first_arg_matching
  find_keyword
  find_single_value_for
  get_CMakeLists_hash
  has_keyword
  insert_args_at
  interpolated
  is_bracket_quoted
  is_comment
  is_double_quoted
  is_quoted
  is_unquoted
  is_whitespace
  keyword_arg_append_position
  keyword_arg_insert_position
  normalize_args_for
  prepend_args
  process_cmakelists
  reconstitute_code
  remove_args_at
  remove_args_for
  remove_keyword
  replace_arg_at
  replace_call_with
  single_value_for
);

use Digest::SHA qw(sha256_hex);

########################################################################
# Private variables
########################################################################
Readonly::Scalar my $_NO_MATCH      => -1;
Readonly::Scalar my $_NO_LIMIT      => -1;
Readonly::Scalar my $_LAST_CHAR_IDX => -1;
Readonly::Scalar my $_LAST_ELEM_IDX => -1;
my $_not_escape = qr&(?P<not_escape>^|[^\\]|(?>\\\\))&msx;

use vars qw(@PROJECT_KEYWORDS);

@PROJECT_KEYWORDS = qw(DESCRIPTION HOMEPAGE_URL VERSION LANGUAGES);

########################################################################
# Exported functions
########################################################################
sub add_args_after {
  my ($call_info, $idx_idx, @to_add) = @_;
  my $n_args = scalar @{ $call_info->{arg_indexes} };

  if (defined $idx_idx) {
    $idx_idx < $n_args or error_exit(<<"EOF");
arg_index $idx_idx out of bounds ($n_args arguments found)
EOF
    ++$idx_idx;
  } else {
    $idx_idx = 0;
  }
  return insert_args_at($call_info, $idx_idx, @to_add);
} ## end sub add_args_after

# Return a list of all arguments for a given keyword (assumes
# multi-value keyword).
sub all_values_for {
  my ($call_info, @args) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $result;
  $result = map { arg_at($call_info, $_) }
    (find_all_args_for($call_info, @args) // return $result);
  return $result;
} ## end sub all_values_for


sub append_args {
  my ($call_info, @to_add) = @_;
  return add_args_after($call_info, $#{ $call_info->{arg_indexes} }, @to_add);
}

# Return specified argument. In list context, returns argument and any
# quotes as separate list elements, otherwise returns the
# possibly-quoted argument as a single string.
sub arg_at {
  my ($call_info, $idx_idx) = @_;
  my @result;
  my $index = _index_for_arg_at($call_info, $idx_idx);
  defined $index
    and @result =
    _has_close_quote($call_info, $idx_idx)
    ? ($call_info->{chunks}->[($index - 1) .. ($index + 1)])
    : ($call_info->{chunks}->[$index]);
  return wantarray ? @result : join(q(), @result);
} ## end sub arg_at


sub arg_location {
  my ($call_info, $idx_idx) = @_;
  my $result;
  $result = $call_info->{chunk_locations}
    ->{ _index_for_arg_at($call_info, $idx_idx) // return $result };
  return $result;
} ## end sub arg_location

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

# Return a list of arg indexes for all arguments (including comments) to
# given keyword (assumes multi-value keyword).
sub find_all_args_for {
  my ($call_info, @args) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $found_args = find_args_for($call_info, @args);
  return (defined $found_args)
    ? map { @{ $found_args->{$_} }; } sort keys %{$found_args}
    : undef;
} ## end sub find_all_args_for

# Return arg indexes of all arguments to given keyword, grouped by
# keyword location.
sub find_args_for {
  my ($call_info, $wanted_keyword, @all_keywords) = @_;
  $wanted_keyword or return;
  my $offset =
    (scalar @all_keywords and $all_keywords[0] =~ m&\A[[:digit:]]+\z&msx)
    ? shift @all_keywords
    : 0;
  scalar @all_keywords or @all_keywords = ($wanted_keyword);
  my $other_kw_re = sprintf('\A%s\z', join(q(|), @all_keywords));
  my $results;

  while (defined(
      my $kw_idx = find_keyword($call_info, $wanted_keyword, $offset)
    )) {
    $results->{$kw_idx} = [];
    $kw_idx < $#{ $call_info->{arg_indexes} } or last;
    my $end =
      find_first_arg_matching($call_info, qr&$other_kw_re&msx,
        ($offset = $kw_idx + 1)) // scalar @{ $call_info->{arg_indexes} };
    $end == $offset and next;
    $results->{$kw_idx} = [$offset .. $end - 1];
  } ## end while (defined(my $kw_idx...))
  return $results;
} ## end sub find_args_for

# Return all arg_indexes matching supplied regex.
sub find_args_matching {
  my ($call_info, $re, $offset) = @_;
  return
    grep { interpolated($call_info, $_) =~ $re; }
    (($offset // 0) .. $#{ $call_info->{arg_indexes} });
} ## end sub find_args_matching

# Find arg_index for first argument matching regex.
sub find_first_arg_matching {
  my ($call_info, $re, $offset) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  return List::MoreUtils::first_value { interpolated($call_info, $_) =~ $re; }
  (($offset // 0) .. $#{ $call_info->{arg_indexes} });
} ## end sub find_first_arg_matching

# Return arg_index of first instance of keyword.
sub find_keyword {
  my ($call_info, $kw, $offset) = @_;
  return find_first_arg_matching($call_info, qr&\A\Q$kw\E\z&msx, $offset);
}

# Return the arg_index of the overriding value single-value keyword.
sub find_single_value_for {
  my ($call_info, @args) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $found_args = find_args_for($call_info, @args);
  my $value;

  if (defined $found_args) {
    foreach my $kw_idx (reverse sort keys %{$found_args}) {
      $value = $found_args->{$kw_idx}->[0] and last;
    }
  } ## end if (defined $found_args)
  return $value;
} ## end sub find_single_value_for


sub get_CMakeLists_hash {
  return sha256_hex(
      abs_path(File::Spec->catfile(shift // q(), 'CMakeLists.txt')));
}

# Check for the presence of a given keyword
sub has_keyword {
  my @args = @_;
  return defined find_keyword(@args);
}


sub insert_args_at {
  my ($call_info, $idx_idx, @to_add) = @_;
  my ($point_index_start, $line_no_init);
  my $n_arg_indexes = scalar @{ $call_info->{arg_indexes} };
  my ($need_preceding_whitespace, $need_following_whitespace);

  if (($idx_idx // $n_arg_indexes) < $n_arg_indexes) {
    $point_index_start = $call_info->{arg_indexes}->[$idx_idx];
    $line_no_init      = $call_info->{chunk_locations}->{$point_index_start};
    _has_open_quote($call_info, $idx_idx) and --$point_index_start;
    $need_following_whitespace = 1;
  } else { # appending
    $idx_idx           = $n_arg_indexes;
    $point_index_start = scalar @{ $call_info->{chunks} };
    $line_no_init      = $call_info->{end_line};
    $need_following_whitespace =
      (scalar @{ $call_info->{chunks} }
        and is_whitespace($call_info->{chunks}->[$_LAST_ELEM_IDX]));
    $need_preceding_whitespace =
      ($n_arg_indexes
        and not is_whitespace($call_info->{chunks}->[$_LAST_ELEM_IDX]));
  } ## end else [ if (($idx_idx // $n_arg_indexes...))]
  my (@new_chunks, @new_indexes, @new_locations);
  $need_preceding_whitespace and push @new_chunks, q( );
  my $n_newlines_tot = 0;
  my $point_index    = $point_index_start;

  foreach my $item (@to_add) {
    push @new_locations, $line_no_init + $n_newlines_tot;
    my $ws;
    ($item, $ws) = ($item =~ m&\A(.*?)(\s*)\z&msx);

    if (is_comment($item)) {
      push @new_chunks, $item, ($ws =~ m&\n\z&msx) ? $ws : "$ws\n";
      ++$n_newlines_tot;
      $point_index += 2;
    } else {
      my @item_chunks = _separate_quotes($item);
      push @new_chunks,  @item_chunks, ($ws eq q()) ? q( ) : $ws;
      push @new_indexes, $point_index + ((@item_chunks > 1) ? 1 : 0);
      $point_index += scalar @item_chunks + 1;
      my $n_newlines =()= $item =~ m&\n&msgx;
      $n_newlines_tot += $n_newlines;
    } ## end else [ if (is_comment($item))]
  } ## end foreach my $item (@to_add)

  if (not(
      $new_chunks[$_LAST_ELEM_IDX] eq qq(\n) or $need_following_whitespace)) {
    pop @new_chunks;
    --$point_index;
  } ## end if (not($new_chunks[$_LAST_ELEM_IDX...]))
  my $n_new_chunks = scalar @new_chunks;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  for (reverse($idx_idx .. $#{ $call_info->{arg_indexes} })) {
    my $index = $call_info->{arg_indexes}->[$_];
    $call_info->{arg_indexes}->[$_] += $n_new_chunks;
    $call_info->{chunk_locations}->{ $index + $n_new_chunks } =
      $call_info->{chunk_locations}->{$index} + $n_newlines_tot;
  } ## end for (reverse($idx_idx .....))
  $call_info->{end_line} += $n_newlines_tot;

  # Splice in the new arg_index entries.
  splice(@{ $call_info->{arg_indexes} }, $idx_idx, 0, @new_indexes);

  # Fill in the locations of the new arguments.
  @{ $call_info->{chunk_locations} }{@new_indexes} = @new_locations;

  # Add the arguments (and any whitespace, etc.) to the chunks list.
  splice(@{ $call_info->{chunks} }, $point_index_start, 0, @new_chunks);

  # Recalculate comment indexes.
  _recalculate_comment_indexes($call_info);
  return $idx_idx;
} ## end sub insert_args_at

########################################################################
# Return a *partial* interpolation of the CMake function/macro call
# argument at the given arg_index:
#
# * Surrounding double- or bracket-quotes are elided.
#
# * Escape sequences '\n', '\t' and '\r' in double-quoted and unquoted
#   strings are expanded to their corresponding ASCII character codes.
#
# * The escape sequence '\;' is replaced by a literal ';' in
#   double-quoted and unquoted strings.
#
# * An unescaped newline at the beginning of a bracket-quoted string is
#   elided.
#
# * The given string is assumed to be legal and interpreted by CMake as
#   a single argument (_i.e._ **not** a ;/space-delimited or legacy
#   undelimited list.
#
# * Other escape sequences (_e.g._ '\$', '\\', _etc._) are only
#   interpolated in the absence of unescaped Make- or CMake-style
#   variable references or generator expressions (which we cannot
#   expand, not being CMake).
#
# Returns the interpolated string in scalar context, or the string with
# a boolean indicator of whether the string is truly literal (1) or not
# (undef).
########################################################################
sub interpolated {
  my @args = @_;
  my (@separated);

  if (((ref $args[0]) // q()) eq 'HASH') {
    @separated = arg_at(@args);
  } elsif (scalar @args > 1) {
    @separated = @args;
  } else {
    @separated = _separate_quotes(@args);
  }
  my ($interpolated_string, $is_literal);

  if (defined @separated) {
    if (scalar @separated > 1) {
      $interpolated_string = $separated[1];
      given ($separated[0]) {
        when (q(")) { # double-quoted
          $interpolated_string =~ s&$_not_escape\\\n&\k<not_escape>&msgx; # line continuation
        }
        default {                                                         # bracket-quoted
          $interpolated_string =~ m&\A(?>\n?)(.*)\z&msx;
          return ($interpolated_string, 1)
        }
      } ## end given
    } else {
      $interpolated_string = $separated[0] || q();
    }

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
  } ## end if (defined @separated)
  return
    wantarray ? ($interpolated_string, $is_literal) : $interpolated_string;
} ## end sub interpolated


sub is_bracket_quoted {
  my $quote = is_quoted(@_) // q();
  return (not $quote or $quote eq q(")) ? undef : $quote;
}


sub is_comment {
  return join(q(), @_) =~ m&\A\s*[#]&msx;
}


sub is_double_quoted {
  my $quote = is_quoted(@_) // q();
  return ($quote eq q(")) ? $quote : undef;
}


sub is_quoted {
  my @args = @_;
  my $result;

  if (((ref $args[0]) // q()) eq 'HASH') { # ($call_info, $idx_idx)
    my $search_result = _has_close_quote(@args) // return $result;
    $result =
      ($search_result->{qs} eq q(]))
      ? "[$search_result->{qmarker}\E["
      : $search_result->{q};
  } else {
    my @separated = _separate_quotes(@args);
    scalar @separated > 1 and $result = $separated[0];
  }
  return $result;
} ## end sub is_quoted


sub is_unquoted {
  return is_quoted(@_) ? 0 : 1;
}


sub is_whitespace {
  return join(q(), @_) =~ m&\A\s*\z&msx;
}


sub keyword_arg_append_position {
  my ($call_info, $keyword, @all_keywords) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $found_args = find_args_for($call_info, $keyword, @all_keywords);

  if (defined $found_args) {
    my $kw_idx = List::Util::max keys %{$found_args};
    return
      add_args_after($call_info,
        $found_args->{kw_idx}->[$_LAST_ELEM_IDX] // $kw_idx);
  } else {
    return keyword_arg_insert_position($call_info, $keyword);
  }
} ## end sub keyword_arg_append_position


sub keyword_arg_insert_position {
  my ($call_info, $keyword) = @_;
  my $kw_idx = find_keyword($call_info, $keyword)
    // append_args($call_info, $keyword);
  return add_args_after($call_info, $kw_idx);
} ## end sub keyword_arg_insert_position

# Consolidate arguments for a given keyword, returning the arg index of
# the first argument or undef if missing or not applicable.
sub normalize_args_for {
  my ($call_info, $kw, @all_keywords) = @_;
  has_keyword($call_info, $kw) or return;
  my $n_args =
    (scalar @all_keywords and $all_keywords[0] =~ m&\A[[:digit:]]+\z&msx)
    ? shift @all_keywords
    : undef;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ($n_args // 1) {

    # One or more arguments to save and reinsert after removal.
    my @saved_args = (defined $n_args)
      ?

      # single-value case
      single_value_for($call_info, $kw, @all_keywords)
      :

      # standard case: multiple arguments
      remove_args_for($call_info, $kw, @all_keywords);
    scalar @saved_args and return
      insert_args_at($call_info,
        keyword_arg_append_position($call_info, $kw, @all_keywords),
        @saved_args);
  } ## end if ($n_args // 1)
  return;
} ## end sub normalize_args_for


sub prepend_args {
  my ($call_info, @to_add) = @_;
  return insert_args_at($call_info, 0, @to_add);
}

# Process a CMakeLists file statement-wise, dealing correctly with
# multi-line statements with zero or more end-of-line comments.
#
# Invokes configured callbacks which may change or add statements.
#
# usage: process_cmakelists(<in>, <kw-options>...)
#
# Options:
#
#   comment_handler => <callback>
#
#      Invoke <callback>(<call-infos>) for a block of full-line comments.
#
#   output => <out>
#
#      Write each statement (modified or not) to <out>.
#
#  <func>_callback => <callback>
#
#      Invoke <callback>(<call-infos>) for a CMake statement:
#
#        <func>(...)
####################################
# Notes
#
# * <in> and <out> each may be specified as either a filename or as
#
#   [ <filehandle>, <filename> ].
#
#   <filehandle> must be valid and opened, and correspond to <filename>
#   (the latter being used for reports and diagnostics). Additionally
#   for <in>, <filehandle> must be rewindable if present.
#
# * <call-infos> is an ARRAY of <call-info> to allow for deletions,
#   edits, additions, etc.
#
# * <call-info> is a HASH with keys that may include:
#
#   * func
#
#     The name of the function, e.g. my_func, my_macro, endwhile()...
#
#   * start_line
#
#     The (1-based) line number in the CMake file containing the
#     beginning of the function.
#
#   * pre
#
#     Everything before the name of <command> on line <start_line>
#     (including whitespace).
#
#   * end_line
#
#     The line number containing the closing parenthesis of <command>.
#
#   * chunks
#
#     An ARRAY of strings representing everything between the
#     parentheses of <command>(), which may be:
#
#     * whitespace (including \n)
#
#     * a function argument
#
#     * a double quote character, or
#
#     * an end-of-line comment (possibly including trailing whitespace
#       but exclusive of \n).
#
#   * arg_indexes
#
#     An ARRAY of indexes into the chunks ARRAY representing all the
#     arguments to func, stripped of any quotes.
#
#   * comment_indexes
#
#     An ARRAY of indexes into the chunks ARRAY representing all the
#     end-of-line comments.
#
#   * chunk_locations
#
#     An ARRAY of line numbers in the CMake file containing the
#     beginning of each argument to func (including quotes) referenced
#     in arg_indexes.
#
#   * post
#
#     A string containing all text (sans trailing whitespace) on the
#     line following the last argument to func (including the closing
#     parenthesis).
########################################################################
sub process_cmakelists {
  my ($cmakelists, $options) = @_;
  my ($cml_in, $cml_out);
  ($cml_in, $cml_out, $cmakelists) = _prepare_cml_io($cmakelists, $options);
  my $line_no = 0;
  my $cml_data =
    {
    callback_results => {},
    callbacks        => {
        map {
          m&\A(.*)_callback\z&msx ? ((lc $1) => delete $options->{$_}) : ();
        } keys %{$options}
    },
    cmakelists       => $cmakelists,
    cml_in           => $cml_in,
    pending_comments => {} };
  $cml_out and $cml_data->{cml_out} = $cml_out;
  grep {
      m&_handler\z&msx and $cml_data->{$_} = delete $options->{$_};
  } keys %{$options};
  $cml_data->{callback_regex} = join(q(|),
      map { quotemeta(sprintf('%s', $_)); } keys %{ $cml_data->{callbacks} });

  while (my $line = <$cml_in>) {
    $line_no = _process_cml_lines($line, ++$line_no, $cml_data, $options);
  } # Reading file.

  # Process any pending full-line comments.
  _process_pending_comments($cml_data, $line_no, $options);

  # If we have an EOF handler, call it.
  if ($cml_data->{eof_handler}) {
    debug("invoking registered EOF handler for $cmakelists");
    &{ $cml_data->{eof_handler} }($cml_data, $line_no, $options);
  }

  # Close and return.
  $cml_out and not ref $options->{output} and $cml_out->close();
  return $cml_data->{callback_results};
} ## end sub process_cmakelists


sub reconstitute_code {
  return join(
      q(),
      map {
        (ref)
        ? sprintf('%s%s%s',
          $_->{pre} // q(),
          join(q(), map { $_ // (); } @{ $_->{chunks} // [] }),
          $_->{post} // q())
        : $_;
      } @_);
} ## end sub reconstitute_code

# Remove specified arguments from CMake call by arg_index.
#
# Returns a list of removed arguments *with* any quotes.
sub remove_args_at {
  my ($call_info, @arg_indexes) = @_;
  @arg_indexes = sort { $a <=> $b } @arg_indexes or return;
  my @removers = ();

  # Compact into contiguous sections to reduce the need for offset
  # correction.
  while (@arg_indexes) {
    my $idx_idx      = shift @arg_indexes;
    my $n_items      = 1;
    my $last_idx_idx = $idx_idx;

    while (defined $last_idx_idx
        and ($arg_indexes[0] // $_NO_MATCH) == $last_idx_idx + 1) {
      ++$n_items;
      $last_idx_idx = shift @arg_indexes;
    } ## end while (defined $last_idx_idx...)
    push @removers,
      sub { return _remove_args($call_info, $idx_idx, $n_items); };
  } ## end while (@arg_indexes)

  # Execute the removers in descending order to avoid invalidating
  # indexes in the remaining calls.
  return map { &{$_}; } reverse @removers;
} ## end sub remove_args_at

# Remove all arguments for a given keyword while leaving all instances
# of said keyword in place. Returns a list of removed arguments *with*
# any quotes.
sub remove_args_for {
  my ($call_info, $kw, @args) = @_;
  my $found_args = find_args_for($call_info, $kw, @args);
  return (defined $found_args)
    ? remove_args_at($call_info,
      map { @{ $found_args->{$_} }; } keys %{$found_args})
    : undef;
} ## end sub remove_args_for

# Remove all instances of keyword and any arguments thereto, and return
# a list of removed items *with* any quotes.
sub remove_keyword {
  my ($call_info, $kw, @args) = @_;
  my $found_args = find_args_for($call_info, $kw, @args);
  return (defined $found_args)
    ? remove_args_at($call_info,
      map { ($_, @{ $found_args->{$_} }); } keys %{$found_args})
    : undef;
} ## end sub remove_keyword


sub replace_arg_at {
  my ($call_info, $idx_idx, @replacements) = @_;
  my @removed = _remove_args($call_info, $idx_idx, 1);

  if (scalar @replacements) {
    insert_args_at($call_info, (defined $idx_idx) ? $idx_idx : undef,
        @replacements);
  }
  return @removed;
} ## end sub replace_arg_at


sub replace_call_with {
  my ($call_info, $new_call, @args) = @_;
  my $old_call = $call_info->{name};

  if (@args) {
    remove_args_at($call_info, 0 .. $#{ $call_info->{arg_indexes} });

    if ($args[0] ne q()) {
      insert_args_at($call_info, 0, @args);
    }
  } ## end if (@args)
  $call_info->{name} = $new_call;
  $call_info->{pre} =~ s&\b\Q$old_call\E\b&$new_call&imsx;
  return;
} ## end sub replace_call_with

# Return the overriding value for a single-value keyword.
sub single_value_for {
  my ($call_info, @args) = @_;
  my $sv_idx = find_single_value_for($call_info, @args) or return;
  return arg_at($call_info, $sv_idx);
} ## end sub single_value_for

########################################################################
# Private functions
########################################################################
my $_seen_unquoted_open_parens = 0;


sub _index_for_arg_at {
  my ($call_info, $idx_idx) = @_;
  my $result;
  $result = $call_info->{arg_indexes}->[$idx_idx // return $result];
  return $result;
} ## end sub _index_for_arg_at


sub _complete_call {
  my ($call_info, $cml_in, $cmakelists, $line, $line_no) = @_;
  my $current_linepos = length($call_info->{pre});

  # Now we loop over multiple lines if necessary, separating
  # arguments and end-of-line comments and storing them, until we
  # find the closing parenthesis.
  #
  # Quoted arguments (even multi-line ones) are handled
  # correctly. Note that the use of an extra "+" symbol following
  # "+," "*," or "?" indicates a "greedy" clause to prevent
  # backtracking (e.g. in the case of a dangling double-quote), so
  # we don't match extra clauses inappropriately.
  my $in_quote         = q();
  my $chunk_start_line = $call_info->{start_line};
  my $eof_counter      = 0;
  my $expect_whitespace;
  $_seen_unquoted_open_parens = 0;

  while (1) {
    ($line, $chunk_start_line, $line_no, $current_linepos,
     $expect_whitespace, $in_quote)
      = @{
        _extract_args_from_string(
          $cmakelists,
          { line              => $line,
            chunk_start_line  => $chunk_start_line,
            line_no           => $line_no,
            current_linepos   => $current_linepos,
            expect_whitespace => $expect_whitespace,
            in_quote          => $in_quote
          },
          $call_info)
      }{qw(line chunk_start_line
        line_no current_linepos
        expect_whitespace in_quote) };

    # If we're down to whitespace or an incomplete quoted argument, try to
    # get more substantive content from the file.
    if (
        ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
        $line =~ m&\A # anchor to string start
                   (?:[;\s]* # whitespace-ish OR
                   |(?P<q>["]) # open double-quote followed by...
                     (?>(?:(?>[^"\\]+)|\\.)*) # ...non-special or escaped special characters OR
                   |(?P<q>[[](?>(?P<qmarker>=*))[[]) # open bracket-quote followed by...
                     (?P<quoted>.*) # ...anything OR
                   )\z # to end-of-string
                  &msx
      ) {
      $in_quote = $LAST_PAREN_MATCH{q};
      my $current_line_no = $line_no;

      while (my $next_line = <$cml_in>) {
        $line = join(q(), $line, $next_line);
        ++$line_no;
        $next_line =~ m&\A\s*\z&msx or last;
      } ## end while (my $next_line = <$cml_in>)
      $line_no > $current_line_no and next; # Reprocess what we have.
    } ## end if ( $line =~ m&\A # anchor to string start )

    if ($line =~ m&\A([)])&msx) {
      last;                                 # found end of function call
    } elsif (not $in_quote and $line =~ m&$_not_escape\\\n\z&msx) {
      error_exit(<<"EOF");
illegal escaped vertical whitespace as part of unquoted string starting at $cmakelists:$chunk_start_line:$current_linepos:
  \Q$line\E
EOF
    } elsif ($cml_in->eof()) {
      _eof_error(
          $cmakelists,
          { line             => $line,
            line_no          => $line_no,
            chunk_start_line => $chunk_start_line,
            current_linepos  => $current_linepos,
            in_quote         => $in_quote
          },
          $call_info);
    } else {
      error_exit(<<"EOF");
unknown error at $cmakelists:$chunk_start_line parsing:
  \Q$line\E
EOF
    } ## end else [ if ($line =~ m&\A([)])&msx) [... [elsif ($cml_in->eof()) ]](([(]))]
  } ## end while (1)

  # Found the end of the call.
  $call_info->{end_line} = $line_no;
  $call_info->{post}     = $line;
  chomp($line);
  debug(sprintf(<<"EOF", $call_info->{name}));
read CALL \%s() POSTAMBLE "$line" from $cmakelists:$chunk_start_line:$current_linepos
EOF
  return $line_no;
} ## end sub _complete_call


sub _dquote_postprocess {
  my ($pm, $lref) = @_;
  $pm->{q1} eq q(") or return;
  $pm->{quoted} eq q() and return 1; # Reprocess.
                                     # If we have embedded, unescaped semicolons in a double-quoted
                                     # string, we must treat the string as if it were multiple
                                     # space-separated double-quoted strings.
  my @splitcheck = ();

  # Can't use split here because we need the semicolons to be not
  # escaped in order to split on them.
  while ($pm->{quoted} =~ m&$_not_escape;+&msxp) {
    push @splitcheck, "${^PREMATCH}$LAST_PAREN_MATCH{not_escape}";
    $pm->{quoted} = "${^POSTMATCH}";
  }

  if (scalar @splitcheck) {

    # Quote each part, then prepend to $line and send it back for
    # reprocessing.
    ${$lref} = sprintf("$pm->{q1}%s$pm->{q2}${$lref}",
        join("$pm->{q2} $pm->{q1}", @splitcheck, $pm->{quoted}));
    return 1; # Reprocess.
  } ## end if (scalar @splitcheck)
  return;
} ## end sub _dquote_postprocess

# Look for pre-argument whitespace, an unquoted argument,
# complete quoted argument ("..." or [={n}[...]={n}]), or an
# end-of-line comment.
sub _extract_args_from_string {
  my ($cmakelists, $state_data, $call_info) = @_;
  my ($line, $chunk_start_line, $line_no, $current_linepos,
      $expect_whitespace, $in_quote)
    = @{$state_data}{
    qw(line chunk_start_line line_no current_linepos expect_whitespace in_quote)
    };

  while ( ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
      $line =~ s&\A # anchor to start of string
           (?P<chunk>(?| # (reset alternation to allow the same capture groups in multiple scenarios)
               (?P<q1>(?P<qs>["]) # open double-quote
                 (?P<qmarker>) # empty group to preserve consistency of capture groups in reset alternation
               ) # ...followed by...
               (?P<quoted>(?>(?:(?>[^"\\]+)|\\.)*)) # ...non-special or escaped special characters, followed by...
               (?P<q2>(?P=q1)) # matching closing double-quote -> (1) double-quoted argument OR
             |(?P<q1>(?P<qs>[[])(?>(?P<qmarker>=*))[[]) # open quoting bracket followed by...
               (?P<quoted>.*?) # ...anything followed by...
               (?P<q2>[]](?P=qmarker)[]]) # ...close quoting bracket followed by...
               (?=[\s#);]|\z) # ...token terminator -> (2) bracket-quoted argument OR
             ) # (end reset alternation for quoted strings)
           |(?!(?>["#]|[[](?>=*)[[]))(?>;*)(?P<unquoted> # something *other* a double or bracket quote beginning...
               (?>(?(?{ $_seen_unquoted_open_parens; })[)(]|[(]))| # a single open or (matching) closing paren or...
               (?:(?>(?:(?>[^\s()#"\\;]+)|\\[^\n])+) # ...1 or more instances of a group of non-special, non-whitespace, non-paren characters or escaped non-newline characters, followed by...
                 (?>(?:\$\((?>(?:(?>[^\s()#"\\;]+)|\\[^\n])+)\)|["](?>(?:(?>[^"()\\\n]+)|\\[^\n])*)["])*))+ # ...0 or more make-style ("$()") variable references or double-quoted strings containing no unescaped whitespace or parens, or embedded (even escaped) newlines followed by...
               (?=[\s#()";]|\z)) # ...token terminator -> (3) unquoted argument OR
           |(?P<comment>[#](?>[^\n]*)) # (4) an end-of-line comment OR
           |(?P<delim>(?>[;\s]+))(?!\z) # -> (5) list delimiters/inter-argument whitespace
           )&&msx # Whew!
    ) {
    my $value_index;              # Chunk index of current "interesting" text.
    my $pm = {%LAST_PAREN_MATCH}; # Save in case it gets clobbered.

    if (defined $pm->{quoted}) {
      _dquote_postprocess($pm, \$line) and next;

      if ($expect_whitespace) {

        # Missing whitespace between quoted / unquoted strings: insert
        # spacer.
        push @{ $call_info->{chunks} }, q();
      } else {
        $expect_whitespace = 1;
      }
      debug(sprintf(
          'read `%s\'-style quoted argument %s to %s() at %s',
          $pm->{qs}, $pm->{chunk}, $call_info->{name},
          "$cmakelists:$chunk_start_line:$current_linepos"
      ));
      push @{ $call_info->{chunks} }, $pm->{q1}, $pm->{quoted}, $pm->{q2};
      $value_index = $#{ $call_info->{chunks} } - 1;
      push @{ $call_info->{arg_indexes} }, $value_index;
      $in_quote = q();
    } elsif (defined $pm->{unquoted}) {
      $pm->{unquoted} eq '(' and ++$_seen_unquoted_open_parens;
      $pm->{unquoted} eq ')' and

        # Only recognized if $_seen_unquoted_parens > 0.
        --$_seen_unquoted_open_parens;

      if ($expect_whitespace) {

        # Missing whitespace between quoted / unquoted strings: insert
        # spacer.
        push @{ $call_info->{chunks} }, q(;);
      } else {
        $expect_whitespace = 1;
      }
      debug(sprintf(
          'read unquoted argument %s to %s() at %s',
          $pm->{chunk}, $call_info->{name},
          "$cmakelists:$chunk_start_line:$current_linepos"
      ));
      push @{ $call_info->{chunks} }, $pm->{chunk};
      $value_index = $#{ $call_info->{chunks} };
      push @{ $call_info->{arg_indexes} }, $value_index;
    } elsif (defined $pm->{comment}) {
      if ($expect_whitespace) {

        # Missing whitespace between quoted / unquoted strings: insert
        # spacer.
        push @{ $call_info->{chunks} }, q(;);
      } else {
        $expect_whitespace = 1;
      }
      push @{ $call_info->{chunks} }, $pm->{chunk};
      $value_index = $#{ $call_info->{chunks} };
      debug(<<"EOF");
read end-of-line comment "$pm->{comment}" at $cmakelists:$chunk_start_line:$current_linepos
EOF
      push @{ $call_info->{comment_indexes} }, $value_index;
    } else {
      push @{ $call_info->{chunks} }, $pm->{chunk};
      $expect_whitespace and undef $expect_whitespace;

      if (not defined $pm->{delim}) {
        print STDERR "oops\n";
      }
      debug(<<"EOF");
read inter-argument delimiter "$pm->{delim}" while parsing $call_info->{name}\E() arguments at $cmakelists:$chunk_start_line:$current_linepos
EOF

      # Skip adding to chunk_locations for whitespace and quotes.
      undef $value_index;
    } ## end else [ if (defined $pm->{quoted... [... [elsif (defined $pm->{comment...})]]})]

    # Keep track of the line numbers on which we find each
    # argument or end-of-line comment.
    defined $value_index
      and $call_info->{chunk_locations}->{$value_index} = $chunk_start_line;

    # Update line position for next read attempt.
    if ($pm->{chunk} =~ m&\n([^\n]*)\z&msx) {
      $current_linepos = length($1);
    } else {
      $current_linepos += length($pm->{chunk});
    }
    $chunk_start_line = $line_no; # Next argument start line;
  } ## end while (  $line =~ s&\A # anchor to start of string...)
  @{$state_data}{
    qw(line chunk_start_line line_no current_linepos expect_whitespace in_quote)
    } = ($line, $chunk_start_line, $line_no, $current_linepos,
         $expect_whitespace, $in_quote);
  return $state_data;
} ## end sub _extract_args_from_string


sub _eof_error {
  my ($cmakelists, $state_data, $call_info) = @_;
  my ($line, $chunk_start_line, $line_no, $current_linepos, $in_quote) =
    @{$state_data}
    {qw(line chunk_start_line line_no current_linepos in_quote)};

  # We have an error: find out what kind.
  my $error_message;

  if (($in_quote // q()) =~ m&\A[\"\[]&msx) {
    $error_message = <<"EOF";
unclosed quote '$in_quote' at $cmakelists:$chunk_start_line:$current_linepos
EOF
  } elsif (length($in_quote) and $in_quote !~ m&\A(?:\s*|\[(?>=*)\[)\z&msx) {
    my $quote_start_line    = $chunk_start_line;
    my $quote_start_linepos = $current_linepos;

    while ($in_quote =~ m&\n&msgcx) {
      ++$quote_start_line;
    }

    if ($quote_start_line == $chunk_start_line) {
      $quote_start_linepos += length($in_quote);
    } else {
      $quote_start_linepos = length($in_quote) - pos($in_quote);
    }

    if (substr($in_quote, $_LAST_CHAR_IDX) eq q(")) {
      --$quote_start_linepos;
      my $msg_fmt = <<"EOF";
unclosed quoted adjunct at $cmakelists:\%d:\%d to unquoted string starting at \%d:\%d\n\%s"
EOF
      $error_message = sprintf($msg_fmt,
          $quote_start_line, $quote_start_linepos, $chunk_start_line,
          $current_linepos,  join(q(), reconstitute_code($call_info), $line));
    } else {
      $error_message =
        sprintf(<<"EOF", join(q(), reconstitute_code($call_info), $line));
unquoted string at $cmakelists:$chunk_start_line:$current_linepos runs into EOF at $quote_start_line:$quote_start_linepos
%s
EOF
    } ## end else [ if (substr($in_quote, ...))]
  } else {
    $error_message =
      sprintf(<<"EOF", join(q(), reconstitute_code($call_info), $line));
incomplete call to $call_info->{name}() at $cmakelists:$call_info->{start_line}:$call_info->{call_start_char} runs into EOF at $line_no:$current_linepos
%s
EOF
  } ## end else [ if (($in_quote // q())... [elsif (length($in_quote) ...)])]
  error_exit($error_message);
  return;
} ## end sub _eof_error

# Detect whether the referenced argument has a close quote to match an
# opening quote: returns the match hash ref if so, else undef.
sub _has_close_quote {
  ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
  my ($call_info, $idx_idx) = @_;
  my $result;
  my $index     = $call_info->{arg_indexes}->[$idx_idx] // return $result;
  my $open_info = _has_open_quote($call_info, $idx_idx) // return $result;
  $index < $#{ $call_info->{chunks} }
    and (
      (     $open_info->{qs} eq q(")
        and $call_info->{chunks}->[$index + 1] =~
        m&\A(?P<q>(?P<qs>")(?P<qmarker>))\z&msx)
      or $call_info->{chunks}->[$index + 1] =~
      m&\A(?P<q>(?P<qs>[]])(?P<qmarker>\Q$open_info->{qmarker}\E)[]])\z&msx)
    and $result = {%LAST_PAREN_MATCH};
  return $result;
} ## end sub _has_close_quote

# Detect whether the referenced argument has a valid close quote:
# returns the match hash ref if so, else undef.
sub _has_open_quote {
  ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
  my ($call_info, $idx_idx) = @_;
  my $result;
  my $index = _index_for_arg_at($call_info, $idx_idx) // return $result;
  $call_info->{chunks}->[$index - 1] =~
m&\A(?P<q>(?|(?P<qs>["])(?P<qmarker>)|(?P<qs>[[])(?P<qmarker>=*)[[]))\z&msx
    and $result = {%LAST_PAREN_MATCH};
  return $result;
} ## end sub _has_open_quote


sub _prepare_cml_io {
  my ($cmakelists, $options) = @_;
  my ($cml_in, $cml_out);

  if (ref $cmakelists) {
    ref $cmakelists eq "ARRAY"
      or
      error_exit("expect <filename> or ARRAY [ <fh>, <filename> ] for input");
    ($cml_in, $cmakelists) = @{$cmakelists};
    debug("reading from pre-opened CMake file $cmakelists");
    $cml_in->opened() and $cml_in->seek(0, Fcntl::SEEK_SET)
      or error_exit(
      "input filehandle provided for $cmakelists must be open and rewindable"
      );
  } else {
    debug("opening CMake file $cmakelists");
    $cml_in = IO::File->new("$cmakelists", "<")
      or error_exit("unable to open $cmakelists for read");
  } ## end else [ if (ref $cmakelists) ]

  if ($options->{output}) {
    if (ref $options->{output}) {
      ref $options->{output} eq "ARRAY"
        or error_exit(
          "expect <filename> or ARRAY [ <fh>, <filename> ] for output");
      ($cml_out, $options->{output}) = @{ $options->{output} };
      $cml_out->opened
        or error_exit(
"filehandle provided by \"output\" option must be already open for write"
        );
    } else {
      $cml_out = IO::File->new(">$options->{output}")
        or error_exit("failure to open \"$options->{output}\" for write");
    }
  } ## end if ($options->{output})
  return ($cml_in, $cml_out, $cmakelists);
} ## end sub _prepare_cml_io

# Process a comment block.
sub _process_pending_comments {
  my ($cml_data, $line_no, $options) = @_;
  my ($cmakelists, $cml_out, $pending_comments) =
    @{$cml_data}{qw(cmakelists cml_out pending_comments)};
  $pending_comments
    and $pending_comments->{start_line}
    and exists $cml_data->{comment_handler}
    or return;

  # Make our comment block hash look like a "real" $call_info.
  @{$pending_comments}
    {qw(end_line arg_indexes comment_indexes chunk_locations)} = (
                           $line_no - 1,
                           ([0 .. $#{ $pending_comments->{chunks} }]) x 2,
                           [$pending_comments->{start_line} .. ($line_no - 1)]
    );
  debug(sprintf(
      'processing comments from %s:%s%s',
      $cmakelists,
      $pending_comments->{start_line},
      ($pending_comments->{end_line} != $pending_comments->{start_line})
      ? qq(--$pending_comments->{end_line})
      : q()
  ));

  # Call the comment handler.
  &{ $cml_data->{comment_handler} }($pending_comments, $cmakelists, $options);

  # Output the (possibly-changed) comment lines, if we care.
  my @tmp_lines = reconstitute_code($pending_comments);
  $cml_out and scalar @tmp_lines and $cml_out->print(@tmp_lines);
  %{$pending_comments} = ();
  return;
} ## end sub _process_pending_comments


sub _process_cml_lines {
  my ($line, $line_no, $cml_data, $options) = @_;
  my ($cmakelists, $cml_in, $cml_out, $pending_comments) =
    @{$cml_data}{qw(cmakelists cml_in cml_out pending_comments)}; # Convenience.
  my $current_linepos = 0;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  if ($line =~ m&\A\s*[#].*\z&msx) {                              # Full-line comment.
    debug("read COMMENT from $cmakelists:$line_no: $line");
    push @{ $pending_comments->{chunks} }, $line;
    exists $pending_comments->{start_line}
      or $pending_comments->{start_line} = $line_no;
    return $line_no;
  } ## end if ($line =~ m&\A\s*[#].*\z&msx)
  _process_pending_comments($cml_data, $line_no, $options);

  if (
      ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
      $line =~ s&\A # anchor to string start
               (?P<pre>(?P<pre_call_ws>\s*) # save whitespace
                 (?P<command>(?i:$cml_data->{callback_regex})) # Interesting function calls
                 [(] # function argument start (*no whitespace before*)
               )&&msx # swallow
    ) {
    # We've found the beginning of an interesting call.
    my $call_info = {
                    %LAST_PAREN_MATCH,
                    call_start_char => length($LAST_PAREN_MATCH{pre_call_ws}),
                    name            => lc $LAST_PAREN_MATCH{command},
                    start_line      => $line_no,
                    chunks          => [],
                    arg_indexes     => [] };
    debug(sprintf(<<"EOF", $call_info->{name}));
reading CALL %s() at $cmakelists:$call_info->{start_line}:$call_info->{call_start_char}",
EOF
    $line_no =
      _complete_call($call_info, $cml_in, $cmakelists, $line, $line_no,
        $options);

    # If we have end-of-line comments, process them first.
    if ($call_info->{post} =~ m&[)]\s*[#]&msx
        or scalar @{ $call_info->{comment_indexes} // [] }
        and exists $cml_data->{comment_handler}) {
      debug(sprintf(<<"EOF", $call_info->{name}));
invoking registered comment handler for end-of-line comments for CALL \%s()
EOF
      &{ $cml_data->{comment_handler} }($call_info, $cmakelists, $options);
    } ## end if ($call_info->{post}...)
    my $call_infos = [$call_info];

    # Now see if someone is interested in this call.
    if (my $func = $cml_data->{arg_handler}) {
      debug(<<"EOF");
invoking generic argument handler for CALL $call_info->{name}()
EOF
      &{$func}($call_info, $cmakelists, $options);
    } ## end if (my $func = $cml_data...)

    if (my $func = $cml_data->{callbacks}->{ $call_info->{name} }) {
      debug(<<"EOF");
invoking registered callback for CALL $call_info->{name}
EOF
      my $tmp_result =
        &{$func}($call_infos, $call_info, $cmakelists, $options);
      defined $tmp_result
        and $cml_data->{callback_results}->{ $call_info->{start_line} } =
        $tmp_result;
    } ## end if (my $func = $cml_data...)

    # Reconstitute the call information.
    if ($cml_out) {
      my @tmp_lines = reconstitute_code(@{$call_infos});
      scalar @tmp_lines and $cml_out->print(@tmp_lines);
    }
  } else { # Not interesting.
    $cml_out and $cml_out->print($line);
  }        # Line analysis.
  return $line_no;
} ## end sub _process_cml_lines


sub _recalculate_comment_indexes {
  my ($call_info) = @_;
  @{ $call_info->{comment_indexes} } =
    List::MoreUtils::indexes { is_comment($_); } @{ $call_info->{chunks} };
  return;
} ## end sub _recalculate_comment_indexes

# Removes $n_args contiguous CMake arguments starting at $idx_idx.
# See remove_args_at() for possibly-non-contiguous arguments.
#
# Returns a list of removed arguments *with* any quotes and trailing
# whitespace/comments.
sub _remove_args {
  my ($call_info, $idx_idx, $n_args) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my @removed;
  my $last_arg_idx =
    List::Util::min(
      ($idx_idx // return @removed) + (($n_args // 1) || return @removed) - 1,
      $#{ $call_info->{arg_indexes} });
  my $index      = $call_info->{arg_indexes}->[$idx_idx];
  my $last_index = $call_info->{arg_indexes}->[$last_arg_idx];

  # Remove any preceding quote.
  _has_open_quote($call_info, $idx_idx) and --$index;

  # Remove any trailing quote.
  _has_close_quote($call_info, $last_arg_idx) and ++$last_index;

  # Remove any trailing whitespace or comments
  while (
      $last_index < $#{ $call_info->{chunks} }
      and (is_whitespace($call_info->{chunks}->[$last_index + 1])
        or is_comment($call_info->{chunks}->[$last_index + 1]))
    ) {
    ++$last_index;
  } ## end while ($last_index < $#{ ...})
  my $chunks_to_remove = $last_index - $index + 1;

  # Remove all relevant chunks.
  my @removed_chunks =
    splice(@{ $call_info->{chunks} }, $index, $chunks_to_remove);

  # Remove corresponding arg_indexes.
  splice(@{ $call_info->{arg_indexes} }, $idx_idx, $n_args);

  # Recalculate indexes for remaining args.
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

  for ($idx_idx .. $#{ $call_info->{arg_indexes} }) {
    $call_info->{arg_indexes}->[$_] -= $chunks_to_remove;
  }

  # Recalculate comment indexes.
  _recalculate_comment_indexes($call_info);
  my $prev_index    = 0;
  my $in_whitespace = 0;
  @removed = map { join(q(), $removed_chunks[$prev_index .. ($_ - 1)]); }
    List::MoreUtils::indexes {
    my $prev_in_whitespace = $in_whitespace;
    $in_whitespace = is_whitespace($_);
    $prev_in_whitespace and not $in_whitespace;
  } ## end List::MoreUtils::indexes
  @removed_chunks;
  return @removed;
} ## end sub _remove_args


sub _separate_quotes {
  my $item = join(q(), @_);
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
} ## end sub _separate_quotes
1;
__END__
