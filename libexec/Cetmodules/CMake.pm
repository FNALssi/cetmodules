# -*- cperl -*-
package Cetmodules::CMake;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules::CMake::CommandInfo qw();
use Cetmodules::CMake::Util qw(is_command_info);
use Cetmodules::Util qw(debug info error_exit $LAST_CHAR_IDX);
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use English qw(-no_match_vars);
use Exporter qw(import);
use Fcntl qw(:seek);
use File::Spec qw();
use IO::File qw();
use Readonly qw();
use Scalar::Util qw(blessed);
use Text::Diff qw(diff);

##
use warnings FATAL => qw(Cetmodules);

our (@EXPORT);

@EXPORT = qw(
  @PROJECT_KEYWORDS
  can_interpolate
  get_CMakeLists_hash
  interpolated
  is_bracket_quoted
  is_comment
  is_double_quoted
  is_quoted
  is_unquoted
  is_whitespace
  process_cmake_file
  reconstitute_code
  report_code_diffs
);

########################################################################
# Exported variables
########################################################################
use vars qw(@PROJECT_KEYWORDS);

@PROJECT_KEYWORDS = qw(DESCRIPTION HOMEPAGE_URL VERSION LANGUAGES);

########################################################################
# Private variables
########################################################################
my $_not_escape = qr&(?P<not_escape>^|[^\\]|(?>\\\\))&msx;
Readonly::Scalar my $_DIFF_LINE_FILLER_SPACES => 4;
Readonly::Scalar my $_LINE_LENGTH             => 80;
Readonly::Scalar my $_QUARTER                 => 1 / 4;

########################################################################
# Exported functions
########################################################################
sub get_CMakeLists_hash {
  return sha256_hex(
    abs_path(File::Spec->catfile(shift // q(), 'CMakeLists.txt')));
}

########################################################################
# Return a *partial* interpolation of the CMake function/macro
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
  my ($first_arg, @rest) = @_;
  return is_command_info($first_arg)
    ? $first_arg->interpolate(@rest)
    : Cetmodules::CMake::Util::interpolated($first_arg, @rest);
} ## end sub interpolated


sub is_bracket_quoted {
  my @args  = @_;
  my $quote = is_quoted(@args) // q();
  $quote and $quote ne q(") and return $quote;
  return;
} ## end sub is_bracket_quoted


sub is_double_quoted {
  my @args  = @_;
  my $quote = is_quoted(@args) // q();
  $quote eq q(") and return $quote;
  return;
} ## end sub is_double_quoted


sub is_quoted {
  my ($first_arg, @rest) = @_;
  return is_command_info($first_arg)
    ? $first_arg->is_quoted(@rest)
    : Cetmodules::CMake::Util::is_quoted($first_arg, @rest);
} ## end sub is_quoted


sub is_unquoted {
  return is_quoted(@_) ? 0 : 1;
}

# Process a CMakeLists file statement-wise, dealing correctly with
# multi-line statements with zero or more end-of-line comments.
#
# Invokes configured handlers which may change or add statements.
#
# usage: process_cmake_file(<in>, <kw-options>...)
#
# Options:
#
#   comment_handler => <handler>
#
#      Invoke <handler>(<cmd-infos>) for a block of full-line comments.
#
#   output => <out>
#
#      Write each statement (modified or not) to <out>.
#
#  <func>_cmd => <handler>
#
#      Invoke <handler>(<cmd-infos>) for a CMake statement:
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
# * <cmd-infos> is an ARRAY of <call-info> to allow for deletions,
#   edits, additions, etc.
#
# * <cmd-info> is a HASH with keys that may include:
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
sub process_cmake_file {
  my ($cmake_file, $options) = @_;
  my ($cmake_file_in, $cmake_file_out);
  ($cmake_file_in, $cmake_file_out, $cmake_file) =
    _prepare_cmake_file_io($cmake_file, $options);
  my $line_no = 0;
  my $cmake_file_data =
    { cmd_handler_results => {},
      cmd_handlers        => {
        map {
          m&\A(.*)_cmd\z&msx ? ((lc $1) => delete $options->{$_}) : ();
        } keys %{$options}
      },
      cmake_file       => $cmake_file,
      cmake_file_in    => $cmake_file_in,
      pending_comments => {} };
  $cmake_file_out and $cmake_file_data->{cmake_file_out} = $cmake_file_out;
  foreach my $option_key (keys %{$options}) {
    $option_key =~ m&_handler\z&msx and
      $cmake_file_data->{$option_key} = delete $options->{$option_key};
  }
  $cmake_file_data->{cmd_handler_regex} = join(q(|),
    map { quotemeta(sprintf('%s', $_)); }
      keys %{ $cmake_file_data->{cmd_handlers} });

  while (my $line = <$cmake_file_in>) {
    $line_no = _process_cmake_file_lines($line, ++$line_no, $cmake_file_data,
      $options);
  } # Reading file.

  # Process any pending full-line comments.
  _process_pending_comments($cmake_file_data, $line_no, $options);

  # If we have an EOF handler, call it.
  if ($cmake_file_data->{eof_handler}) {
    debug("invoking registered EOF handler for $cmake_file");
    &{ $cmake_file_data->{eof_handler} }
      ($cmake_file_data, $line_no, $options);
  } ## end if ($cmake_file_data->...)

  # Close and return.
  $cmake_file_out and not ref $options->{output} and $cmake_file_out->close();
  return $cmake_file_data->{cmd_handler_results},
    $cmake_file_data->{cmd_status};
} ## end sub process_cmake_file


sub reconstitute_code {
  return join(q(), map { is_command_info($_) ? $_->reconstitute() : $_; } @_);
}


sub report_code_diffs {
  my ($file_label, $start_line, $orig_cmd, $new_cmd, $options) = @_;
  $orig_cmd ne ($new_cmd // q()) or return;
  my $result = { orig_cmd => $orig_cmd, new_cmd => $new_cmd // q() };
  $options->{"dry-run"} or $Cetmodules::VERBOSE or return $result;
  my ($n_lines_orig, $n_lines_new) = map { scalar split m&\n&msx; } $orig_cmd,
    $new_cmd;
  my $diff = diff(
    \$orig_cmd,
    \$new_cmd,
    {   STYLE   => "Context",
        CONTEXT => List::Util::max($n_lines_orig, $n_lines_new) });
  my $diff_fh = IO::File->new(\$diff, q(<))
    or error_exit("unable to open variable for stream input");
  my $offset    = $start_line - 1;
  my $line      = <$diff_fh>;                                   # Drop first line.
  my $fh_report = $options->{fh_report} // \*STDOUT;
  print $fh_report _labeled_divider($file_label, q(*)),         # Header.
    _format_diff_lines($diff_fh, $offset, $n_lines_orig, q(-)), # Orig.
    _format_diff_lines($diff_fh, $offset, $n_lines_new,  q(+)), # New.
    _labeled_divider(q(), q(*));                                # Footer.
  $diff_fh->close();
  return $result;
} ## end sub report_code_diffs

########################################################################
# Private functions
########################################################################
# Private state.
my $_seen_unquoted_open_parens = 0;
##
sub _complete_cmd {
  my ($cmd_info, $cmake_file_in, $cmake_file, $line, $line_no) = @_;
  my $current_linepos = length($cmd_info->{pre});

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
  my $chunk_start_line = $cmd_info->{start_line};
  my $eof_counter      = 0;
  my $expect_whitespace;
  $_seen_unquoted_open_parens = 0;

  while (1) {
    ($line, $chunk_start_line, $line_no, $current_linepos,
     $expect_whitespace, $in_quote)
      = @{
        _extract_args_from_string(
          $cmake_file,
          { line              => $line,
            chunk_start_line  => $chunk_start_line,
            line_no           => $line_no,
            current_linepos   => $current_linepos,
            expect_whitespace => $expect_whitespace,
            in_quote          => $in_quote
          },
          $cmd_info)
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

      while (my $next_line = <$cmake_file_in>) {
        $line = join(q(), $line, $next_line);
        ++$line_no;
        $next_line =~ m&\A\s*\z&msx or last;
      } ## end while (my $next_line = <$cmake_file_in>)
      $line_no > $current_line_no and next; # Reprocess what we have.
    } ## end if ( $line =~ m&\A # anchor to string start )

    if ($line =~ m&\A([)])&msx) {
      last;                                 # found end of function call
    } elsif (not $in_quote and $line =~ m&$_not_escape\\\n\z&msx) {
      error_exit(<<"EOF");
illegal escaped vertical whitespace as part of unquoted string starting at $cmake_file:$chunk_start_line:$current_linepos:
  \Q$line\E
EOF
    } elsif ($cmake_file_in->eof()) {
      _eof_error(
        $cmake_file,
        {   line             => $line,
            line_no          => $line_no,
            chunk_start_line => $chunk_start_line,
            current_linepos  => $current_linepos,
            in_quote         => $in_quote
        },
        $cmd_info);
    } else {
      error_exit(<<"EOF");
unknown error at $cmake_file:$chunk_start_line parsing:
  \Q$line\E
EOF
    } ## end else [ if ($line =~ m&\A([)])&msx) [... [elsif ($cmake_file_in->eof...)]](([(]))]
  } ## end while (1)

  # Found the end of the call.
  $cmd_info->{end_line} = $line_no;
  $cmd_info->{post}     = $line;
  chomp($line);
  debug(sprintf(<<"EOF", $cmd_info->{name}));
read COMMAND \%s() POSTAMBLE "$line" from $cmake_file:$chunk_start_line:$current_linepos
EOF
  return $line_no;
} ## end sub _complete_cmd

# Look for pre-argument whitespace, an unquoted argument,
# complete quoted argument ("..." or [={n}[...]={n}]), or an
# end-of-line comment.
sub _extract_args_from_string {
  my ($cmake_file, $state_data, $cmd_info) = @_;
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
      if ($expect_whitespace) {

        # Missing whitespace between quoted / unquoted strings: insert
        # spacer.
        push @{ $cmd_info->{chunks} }, q();
      } else {
        $expect_whitespace = 1;
      }
      debug(sprintf(
        'read `%s\'-style quoted argument %s to %s() at %s',
        $pm->{qs}, $pm->{chunk}, $cmd_info->{name},
        "$cmake_file:$chunk_start_line:$current_linepos"));
      push @{ $cmd_info->{chunks} }, $pm->{q1}, $pm->{quoted}, $pm->{q2};
      $value_index = $#{ $cmd_info->{chunks} } - 1;
      push @{ $cmd_info->{arg_indexes} }, $value_index;
      $in_quote = q();
    } elsif (defined $pm->{unquoted}) {
      $pm->{unquoted} eq '(' and ++$_seen_unquoted_open_parens;
      $pm->{unquoted} eq ')' and

        # Only recognized if $_seen_unquoted_parens > 0.
        --$_seen_unquoted_open_parens;

      if ($expect_whitespace) {

        # Missing whitespace between quoted / unquoted strings: insert
        # spacer.
        push @{ $cmd_info->{chunks} }, q(;);
      } else {
        $expect_whitespace = 1;
      }
      debug(sprintf(
        'read unquoted argument %s to %s() at %s',
        $pm->{chunk}, $cmd_info->{name},
        "$cmake_file:$chunk_start_line:$current_linepos"));
      push @{ $cmd_info->{chunks} }, $pm->{chunk};
      $value_index = $#{ $cmd_info->{chunks} };
      push @{ $cmd_info->{arg_indexes} }, $value_index;
    } elsif (defined $pm->{comment}) {
      if ($expect_whitespace) {

        # Missing whitespace between quoted / unquoted strings: insert
        # spacer.
        push @{ $cmd_info->{chunks} }, q(;);
      } else {
        $expect_whitespace = 1;
      }
      push @{ $cmd_info->{chunks} }, $pm->{chunk};
      $value_index = $#{ $cmd_info->{chunks} };
      debug(<<"EOF");
read end-of-line comment "$pm->{comment}" at $cmake_file:$chunk_start_line:$current_linepos
EOF
      push @{ $cmd_info->{comment_indexes} }, $value_index;
    } else {
      push @{ $cmd_info->{chunks} }, $pm->{chunk};
      $expect_whitespace and undef $expect_whitespace;

      if (not defined $pm->{delim}) {
        print STDERR "oops\n";
      }
      debug(<<"EOF");
read inter-argument delimiter "$pm->{delim}" while parsing $cmd_info->{name}\E() arguments at $cmake_file:$chunk_start_line:$current_linepos
EOF

      # Skip adding to chunk_locations for whitespace and quotes.
      undef $value_index;
    } ## end else [ if (defined $pm->{quoted... [... [elsif (defined $pm->{comment...})]]})]

    # Keep track of the line numbers on which we find each
    # argument or end-of-line comment.
    defined $value_index
      and $cmd_info->{chunk_locations}->{$value_index} = $chunk_start_line;

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
  my ($cmake_file, $state_data, $cmd_info) = @_;
  my ($line, $chunk_start_line, $line_no, $current_linepos, $in_quote) =
    @{$state_data}
    {qw(line chunk_start_line line_no current_linepos in_quote)};

  # We have an error: find out what kind.
  my $error_message;

  if (($in_quote // q()) =~ m&\A[\"\[]&msx) {
    $error_message = <<"EOF";
unclosed quote '$in_quote' at $cmake_file:$chunk_start_line:$current_linepos
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

    if (substr($in_quote, $LAST_CHAR_IDX) eq q(")) {
      --$quote_start_linepos;
      my $msg_fmt = <<"EOF";
unclosed quoted adjunct at $cmake_file:\%d:\%d to unquoted string starting at \%d:\%d\n\%s"
EOF
      $error_message = sprintf($msg_fmt,
        $quote_start_line, $quote_start_linepos, $chunk_start_line,
        $current_linepos,  join(q(), reconstitute_code($cmd_info), $line));
    } else {
      $error_message =
        sprintf(<<"EOF", join(q(), reconstitute_code($cmd_info), $line));
unquoted string at $cmake_file:$chunk_start_line:$current_linepos runs into EOF at $quote_start_line:$quote_start_linepos
%s
EOF
    } ## end else [ if (substr($in_quote, ...))]
  } else {
    $error_message =
      sprintf(<<"EOF", join(q(), reconstitute_code($cmd_info), $line));
incomplete command $cmd_info->{name}() at $cmake_file:$cmd_info->{start_line}:$cmd_info->{cmd_start_char} runs into EOF at $line_no:$current_linepos
%s
EOF
  } ## end else [ if (($in_quote // q())... [elsif (length($in_quote) ...)])]
  error_exit($error_message);
  return;
} ## end sub _eof_error


sub _format_diff_lines {
  my ($fh, $offset, $n_lines, $divider_char, $divider_length) = @_;
  my $result;
  my $fh_out = IO::File->new(\$result, q(>))
    or error_exit("unable to open stream variable for write");
  defined $divider_length or $divider_length = $_LINE_LENGTH * $_QUARTER;
  my $line = <$fh>;
  my ($diff_start, $diff_length) =
    ($line =~ m&([-[:digit:]]*)(?:,\s*([-[:digit:]]+))?&msx);
  print $fh_out _labeled_divider(
    sprintf("%d,%d", $diff_start + $offset, $diff_length // $n_lines),
    $divider_char, $divider_length);
  my $line_counter = 0;
  my $filler       = q( ) x $_DIFF_LINE_FILLER_SPACES;

  while ($line_counter++ < $n_lines and $line = <$fh>) {
    chomp $line;
    my ($prefix, $indent, $content) = ($line =~ m&\A(.) (\s*)(.*)\z&msx);
    print $fh_out "  $prefix$filler$indent$content\n";
  } ## end while ($line_counter++ < ...)
  $fh_out->close();
  return $result;
} ## end sub _format_diff_lines


sub _labeled_divider {
  my ($label, $fill_char, $line_length) = @_;
  defined $fill_char   or $fill_char   = q(=);
  defined $line_length or $line_length = $_LINE_LENGTH;
  $label eq q()        or $label       = " $label ";
  my ($div, $filler) =
      (length($label) > ($line_length - 2))
    ? ($fill_char, q())
    : (
      $fill_char x (($line_length - length($label)) / 2),
      (length($label) % 2) ? $fill_char : q());
  return "$div$label$div$filler\n";
} ## end sub _labeled_divider


sub _prepare_cmake_file_io {
  my ($cmake_file, $options) = @_;
  my ($cmake_file_in, $cmake_file_out);

  if (ref $cmake_file) {
    ref $cmake_file eq "ARRAY"
      or
      error_exit("expect <filename> or ARRAY [ <fh>, <filename> ] for input");
    ($cmake_file_in, $cmake_file) = @{$cmake_file};
    debug("reading from pre-opened CMake file $cmake_file");
    $cmake_file_in->opened() and $cmake_file_in->seek(0, Fcntl::SEEK_SET)
      or error_exit(
      "input filehandle provided for $cmake_file must be open and rewindable"
      );
  } else {
    debug("opening CMake file $cmake_file");
    $cmake_file_in = IO::File->new("$cmake_file", "<")
      or error_exit("unable to open $cmake_file for read");
  } ## end else [ if (ref $cmake_file) ]

  if ($options->{output}) {
    if (ref $options->{output}) {
      ref $options->{output} eq "ARRAY"
        or error_exit(
          "expect <filename> or ARRAY [ <fh>, <filename> ] for output");
      ($cmake_file_out, $options->{output}) = @{ $options->{output} };
      $cmake_file_out->opened
        or error_exit(
"filehandle provided by \"output\" option must be already open for write"
        );
    } else {
      $cmake_file_out = IO::File->new(">$options->{output}")
        or error_exit("failure to open \"$options->{output}\" for write");
    }
  } ## end if ($options->{output})
  return ($cmake_file_in, $cmake_file_out, $cmake_file);
} ## end sub _prepare_cmake_file_io

# Process a comment block.
sub _process_pending_comments {
  my ($cmake_file_data, $line_no, $options) = @_;
  my ($cmake_file, $cmake_file_out, $pending_comments) =
    @{$cmake_file_data}{qw(cmake_file cmake_file_out pending_comments)};
  $pending_comments and $pending_comments->{start_line} or return;

  # Make our comment block hash look like a "real" $cmd_info.
  @{$pending_comments}
    {qw(end_line arg_indexes comment_indexes chunk_locations)} = (
                           $line_no - 1,
                           ([0 .. $#{ $pending_comments->{chunks} }]) x 2,
                           [$pending_comments->{start_line} .. ($line_no - 1)]
    );
  debug(sprintf(
    'processing comments from %s:%s%s',
    $cmake_file,
    $pending_comments->{start_line},
    ($pending_comments->{end_line} != $pending_comments->{start_line})
    ? qq(--$pending_comments->{end_line})
    : q()));

  # Call the comment handler.
  $cmake_file_data->{comment_handler}
    and $cmake_file_data->{comment_handler}
    ->($pending_comments, $cmake_file, $options);

  # Output the (possibly-changed) comment lines, if we care.
  my @tmp_lines = reconstitute_code(@{ $pending_comments->{chunks} });
  $cmake_file_out
    and scalar @tmp_lines
    and $cmake_file_out->print(@tmp_lines);
  %{$pending_comments} = ();
  return;
} ## end sub _process_pending_comments


sub _process_cmake_file_lines {
  my ($line, $line_no, $cmake_file_data, $options) = @_;
  my ($cmake_file, $cmake_file_in, $cmake_file_out, $pending_comments) =
    @{$cmake_file_data}
    {qw(cmake_file cmake_file_in cmake_file_out pending_comments)}; # Convenience.
  my $current_linepos = 0;

  if (  $line =~ m&\A\s*[#]{3}\s+MIGRATE-NO-ACTION\b&msx
    and $options->{MIGRATE}) {                                      # Skip remainder of file.
    $options->{SKIPPING} = 1;
    info(<<"EOF");
$cmake_file SKIPPED due to MIGRATE-NO-ACTION directive in line $line_no
EOF
  } elsif ($line =~ m&\A\s*[#].*\z&msx) { # Full-line comment.
    debug("read COMMENT from $cmake_file:$line_no: $line");
    push @{ $pending_comments->{chunks} }, $line;
    exists $pending_comments->{start_line}
      or $pending_comments->{start_line} = $line_no;
    return $line_no;
  } ## end elsif ($line =~ m&\A\s*[#].*\z&msx) [ if ($line =~ m&\A\s*[#]{3}\s+MIGRATE-NO-ACTION\b&msx...)]
  _process_pending_comments($cmake_file_data, $line_no, $options);

  if (
    not $options->{SKIPPING}
    and
    ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
    $line =~ s&\A # anchor to string start
               (?P<pre>(?P<pre_cmd_ws>\s*) # save whitespace
                 (?P<command>[-\w]+) # Interesting function calls
                 \s*[(] # function argument start
               )&&msx # swallow
    ) {
    # We've found the beginning of an interesting call.
    my $cmd_info = Cetmodules::CMake::CommandInfo->new(
      %LAST_PAREN_MATCH,
      cmd_start_char => length($LAST_PAREN_MATCH{pre_cmd_ws}),
      name           => lc $LAST_PAREN_MATCH{command},
      start_line     => $line_no,
      chunks         => [],
      arg_indexes    => []);
    debug(sprintf(<<"EOF", $cmd_info->{name}));
reading COMMAND %s() at $cmake_file:$cmd_info->{start_line}:$cmd_info->{cmd_start_char}",
EOF
    $line_no =
      _complete_cmd($cmd_info, $cmake_file_in, $cmake_file, $line, $line_no,
        $options);
    my $saved_info =
      { name => $cmd_info->{name}, start_line => $cmd_info->{start_line} };
    my $cmd_infos = [$cmd_info];
    my $orig_cmd  = reconstitute_code(@{ $cmd_infos // [] });

    # If we have end-of-line comments, process them first.
    if (
      exists $cmake_file_data->{comment_handler}
      and ($cmd_info->{post} =~ m&[)]\s*[#]&msx
        or scalar @{ $cmd_info->{comment_indexes} // [] })
      ) {
      debug(sprintf(<<"EOF", $cmd_info->{name}));
invoking registered comment handler for end-of-line comments for COMMAND \%s()
EOF
      &{ $cmake_file_data->{comment_handler} }
        ($cmd_info, $cmake_file, $options);
    } ## end if (exists $cmake_file_data...)

    # Now see if someone is interested in this call.
    if (my $func = $cmake_file_data->{arg_handler}) {
      debug(<<"EOF");
invoking generic argument handler for COMMAND $cmd_info->{name}()
EOF
      &{$func}($cmd_info, $cmake_file, $options);
    } ## end if (my $func = $cmake_file_data...)

    if (my $func = $cmake_file_data->{cmd_handlers}->{ $cmd_info->{name} }) {
      debug(<<"EOF");
invoking registered handler for COMMAND $cmd_info->{name}
EOF
      my $tmp_result = &{$func}($cmd_infos, $cmd_info, $cmake_file, $options);
      defined $tmp_result
        and
        $cmake_file_data->{cmd_handler_results}->{ $saved_info->{start_line} }
        = $tmp_result;
    } ## end if (my $func = $cmake_file_data...)
    my $new_cmd = reconstitute_code(@{ $cmd_infos // [] });

    # Compose and (if configured) output the new command(s).
    $cmake_file_out and $cmake_file_out->print($new_cmd);

    # Compose and (if configured) report on changes.
    my $cmd_status = report_code_diffs(
      $options->{cmake_filename_short} // $cmake_file,
      $saved_info->{start_line},
      $orig_cmd, $new_cmd, $options);
    $cmd_status
      and $cmake_file_data->{cmd_status}->{ $saved_info->{start_line} } =
      $cmd_status;
  } else { # Not interesting.
    $cmake_file_out and $cmake_file_out->print($line);
  }        # Line analysis.
  return $line_no;
} ## end sub _process_cmake_file_lines

########################################################################
1;
__END__
