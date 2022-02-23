## no critic qw(Modules::ProhibitExcessMainComplexity)
# -*- cperl -*-
package Cetmodules::CMake::CommandInfo;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules::CMake::Util
  qw(interpolated is_comment is_whitespace separate_quotes);
use Cetmodules::Util qw(error_exit $LAST_ELEM_IDX $NO_MATCH);
use English qw(-no_match_vars);
use List::MoreUtils qw();
use List::Util qw();
use Readonly qw();

##
use warnings FATAL => qw(Cetmodules);

my @_incoming_keywords = qw(
  arg_indexes
  chunk_locations
  chunks
  cmd_start_char
  command
  end_line
  name
  pre
  pre_cmd_ws
  start_line
);
my ($_has_close_quote, $_has_open_quote, $_index_for_arg_at,
  $_recalculate_comment_indexes, $_remove_args);


sub new {
  my ($class, %args) = @_;
  my $self = { map { (exists $args{$_}) ? ($_ => $args{$_}) : (); }
               @_incoming_keywords };
  return bless $self, $class;
} ## end sub new

########################################################################
# Public methods
########################################################################
sub add_args_after {
  my ($self, $idx_idx, @to_add) = @_;
  my $n_args = scalar @{ $self->{arg_indexes} };

  if (defined $idx_idx) {
    $idx_idx < $n_args or error_exit(<<"EOF");
arg_index $idx_idx out of bounds ($n_args arguments found)
EOF
    ++$idx_idx;
  } else {
    $idx_idx = 0;
  }
  return $self->insert_args_at($idx_idx, @to_add);
} ## end sub add_args_after


sub all_idx_idx {
  my ($self) = @_;
  defined $self->{arg_indexes} and return (0 .. $#{ $self->{arg_indexes} });
  return;
} ## end sub all_idx_idx

# Return a list of all arguments for a given keyword (assumes
# multi-value keyword).
sub all_values_for {
  my ($self, @args) = @_;
  my $result;
  $result = map { $self->arg_at($_) }
    ($self->find_all_args_for(@args) // return $result);
  return $result;
} ## end sub all_values_for


sub append_args {
  my ($self, @to_add) = @_;
  return $self->add_args_after($#{ $self->{arg_indexes} }, @to_add);
}

# Return specified argument. In list context, returns argument and any
# quotes as separate list elements, otherwise returns the
# possibly-quoted argument as a single string.
sub arg_at {
  my ($self, $idx_idx) = @_;
  my @result;
  my $index = $self->$_index_for_arg_at($idx_idx);
  defined $index
    and @result =
    $self->$_has_close_quote($idx_idx)
    ? @{ $self->{chunks} }[($index - 1) .. ($index + 1)]
    : ($self->{chunks}->[$index])
    and return wantarray ? @result
    : join(q(), @result);
  return;
} ## end sub arg_at


sub arg_location {
  my ($self, $idx_idx) = @_;
  my $result;
  $result = $self->{chunk_locations}
    ->{ $self->$_index_for_arg_at($idx_idx) // return $result };
  return $result;
} ## end sub arg_location

# Return a list of arg indexes for all arguments (including comments) to
# given keyword (assumes multi-value keyword).
sub find_all_args_for {
  my ($self, @args) = @_;
  my $found_args = $self->find_args_for(@args);
  return (defined $found_args)
    ? map { @{ $found_args->{$_} }; } sort keys %{$found_args}
    : undef;
} ## end sub find_all_args_for

# Return arg indexes of all arguments to given keyword, grouped by
# keyword location.
sub find_args_for {
  my ($self, $wanted_keyword, @all_keywords) = @_;
  $wanted_keyword or return;
  my $offset =
    (scalar @all_keywords and $all_keywords[0] =~ m&\A[[:digit:]]+\z&msx)
    ? shift @all_keywords
    : 0;
  scalar @all_keywords or @all_keywords = ($wanted_keyword);
  my $other_kw_re = sprintf('\A%s\z', join(q(|), @all_keywords));
  my $results;

  while (defined(my $kw_idx = $self->find_keyword($wanted_keyword, $offset)))
  {
    $results->{$kw_idx} = [];
    $kw_idx < $#{ $self->{arg_indexes} } or last;
    my $end =
      $self->find_first_arg_matching(qr&$other_kw_re&msx,
        ($offset = $kw_idx + 1)) // scalar @{ $self->{arg_indexes} };
    $end == $offset and next;
    $results->{$kw_idx} = [$offset .. $end - 1];
  } ## end while (defined(my $kw_idx...))
  return $results;
} ## end sub find_args_for

# Return all arg_indexes matching supplied regex.
sub find_args_matching {
  my ($self, $re, $offset) = @_;
  return
    grep { $self->interpolated_arg_at($_) =~ $re; }
    (($offset // 0) .. $#{ $self->{arg_indexes} });
} ## end sub find_args_matching

# Find arg_index for first argument matching regex.
sub find_first_arg_matching {
  my ($self, $re, $offset) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  return
    List::MoreUtils::first_value { $self->interpolated_arg_at($_) =~ $re; }
  (($offset // 0) .. $#{ $self->{arg_indexes} });
} ## end sub find_first_arg_matching

# Return arg_index of first instance of keyword.
sub find_keyword {
  my ($self, $kw, $offset) = @_;
  return $self->find_first_arg_matching(qr&\A\Q$kw\E\z&msx, $offset);
}

# Return the arg_index of the overriding value single-value keyword.
sub find_single_value_for {
  my ($self, @args) = @_;
  my $found_args = $self->find_args_for(@args);
  my $value;

  if (defined $found_args) {
    foreach my $kw_idx (reverse sort keys %{$found_args}) {
      $value = $found_args->{$kw_idx}->[0] and last;
    }
  } ## end if (defined $found_args)
  return $value;
} ## end sub find_single_value_for

# Check for the presence of a given keyword
sub has_keyword {
  my ($self, @args) = @_;
  return defined $self->find_keyword(@args);
}


sub insert_args_at {
  my ($self, $idx_idx, @to_add) = @_;
  my ($point_index_start, $line_no_init);
  my $n_arg_indexes = scalar @{ $self->{arg_indexes} };
  my ($need_preceding_whitespace, $need_following_whitespace);

  if (($idx_idx // $n_arg_indexes) < $n_arg_indexes) {
    $point_index_start = $self->{arg_indexes}->[$idx_idx];
    $line_no_init      = $self->{chunk_locations}->{$point_index_start};
    $self->$_has_open_quote($idx_idx) and --$point_index_start;
    $need_following_whitespace = 1;
  } else { # appending
    $idx_idx           = $n_arg_indexes;
    $point_index_start = scalar @{ $self->{chunks} };
    $line_no_init      = $self->{end_line};
    $need_following_whitespace =
      (scalar @{ $self->{chunks} }
        and is_whitespace($self->{chunks}->[$LAST_ELEM_IDX]));
    $need_preceding_whitespace =
      ($n_arg_indexes
        and not is_whitespace($self->{chunks}->[$LAST_ELEM_IDX]));
  } ## end else [ if (($idx_idx // $n_arg_indexes...))]

  if (scalar @to_add) {
    my (@new_chunks, @new_indexes, @new_locations);
    $need_preceding_whitespace and push @new_chunks, q( );
    my $n_newlines_tot = 0;
    my $point_index = $point_index_start + ($need_preceding_whitespace // 0);

    foreach my $item (@to_add) {
      push @new_locations, $line_no_init + $n_newlines_tot;
      my $ws;
      ($item, $ws) = ($item =~ m&\A(.*?)(\s*)\z&msx);

      if (is_comment($item)) {
        push @new_chunks, $item, ($ws =~ m&\n\z&msx) ? $ws : "$ws\n";
        ++$n_newlines_tot;
        $point_index += 2;
      } else {
        my @item_chunks = separate_quotes($item);
        push @new_chunks,  @item_chunks, ($ws eq q()) ? q( ) : $ws;
        push @new_indexes, $point_index + ((@item_chunks > 1) ? 1 : 0);
        $point_index += scalar @item_chunks + 1;
        my $n_newlines =()= $item =~ m&\n&msgx;
        $n_newlines_tot += $n_newlines;
      } ## end else [ if (is_comment($item))]
    } ## end foreach my $item (@to_add)

    if (not(
      $new_chunks[$LAST_ELEM_IDX] eq qq(\n) or $need_following_whitespace))
    {
      pop @new_chunks;
      --$point_index;
    } ## end if (not($new_chunks[$LAST_ELEM_IDX...]))
    my $n_new_chunks = scalar @new_chunks;
    local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)

    for (reverse($idx_idx .. $#{ $self->{arg_indexes} })) {
      my $index = $self->{arg_indexes}->[$_];
      $self->{arg_indexes}->[$_] += $n_new_chunks;
      $self->{chunk_locations}->{ $index + $n_new_chunks } =
        $self->{chunk_locations}->{$index} + $n_newlines_tot;
    } ## end for (reverse($idx_idx .....))
    $self->{end_line} += $n_newlines_tot;

    # Splice in the new arg_index entries.
    splice(@{ $self->{arg_indexes} }, $idx_idx, 0, @new_indexes);

    # Fill in the locations of the new arguments.
    @{ $self->{chunk_locations} }{@new_indexes} = @new_locations;

    # Add the arguments (and any whitespace, etc.) to the chunks list.
    splice(@{ $self->{chunks} }, $point_index_start, 0, @new_chunks);

    # Recalculate comment indexes.
    $self->$_recalculate_comment_indexes();
  } ## end if (scalar @to_add)
  return $idx_idx;
} ## end sub insert_args_at


sub interpolated_arg_at {
  my ($self, @args) = @_;
  return interpolated($self->arg_at(@args));
}


sub is_quoted {
  my ($self, @args) = @_;
  my $search_result = $self->$_has_close_quote(@args) or return;
  return ($search_result->{qs} eq q(]))
    ? "[$search_result->{qmarker}\E["
    : $search_result->{q};
} ## end sub is_quoted


sub keyword_arg_append_position {
  my ($self, $keyword, @all_keywords) = @_;
  my $found_args = $self->find_args_for($keyword, @all_keywords);

  if (defined $found_args) {
    my $kw_idx = List::Util::max keys %{$found_args};
    return $self->add_args_after($found_args->{$kw_idx}->[$LAST_ELEM_IDX]
        // $kw_idx);
  } else {
    return $self->keyword_arg_insert_position($keyword);
  }
} ## end sub keyword_arg_append_position


sub keyword_arg_insert_position {
  my ($self, $keyword) = @_;
  my $kw_idx = $self->find_keyword($keyword) // $self->append_args($keyword);
  return $self->add_args_after($kw_idx);
} ## end sub keyword_arg_insert_position


sub last_arg_idx {
  my ($self) = @_;
  return $#{ $self->{arg_indexes} // [] };
}


sub last_chunk_idx {
  my ($self) = @_;
  return $#{ $self->{chunks} // [] };
}


sub n_args {
  my ($self) = @_;
  return scalar @{ $self->{arg_indexes} // [] };
}


sub n_chunks {
  my ($self) = @_;
  return scalar @{ $self->{chunks} // [] };
}

# Consolidate arguments for a given keyword, returning the arg index of
# the first argument or undef if missing or not applicable.
sub normalize_args_for {
  my ($self, $kw, @all_keywords) = @_;
  $self->has_keyword($kw) or return;
  my $n_args =
    (scalar @all_keywords and $all_keywords[0] =~ m&\A[[:digit:]]+\z&msx)
    ? shift @all_keywords
    : undef;

  if ($n_args // 1) { # One or more arguments to save and reinsert after removal.
    my @saved_args = (defined $n_args)
      ? $self->single_value_for($kw, @all_keywords) # single-value case
      : $self->remove_args_for($kw, @all_keywords); # standard case: multiple arguments
    scalar @saved_args
      and return $self->insert_args_at(
        $self->keyword_arg_append_position($kw, @all_keywords), @saved_args);
  } ## end if ($n_args // 1)
  return;
} ## end sub normalize_args_for


sub prepend_args {
  my ($self, @to_add) = @_;
  return $self->insert_args_at(0, @to_add);
}


sub reconstitute {
  my ($self) = @_;
  return sprintf('%s%s%s',
    $self->{pre} // q(),
    join(q(), map { $_ // (); } @{ $self->{chunks} // [] }),
    $self->{post} // q());
} ## end sub reconstitute

# Remove specified arguments from CMake command by arg_index.
#
# Returns a list of removed arguments *with* any quotes.
sub remove_args_at {
  my ($self, @arg_indexes) = @_;
  @arg_indexes = sort { $a <=> $b } @arg_indexes or return;
  my @removers = ();

  # Compact into contiguous sections to reduce the need for offset
  # correction.
  while (@arg_indexes) {
    my $idx_idx      = shift @arg_indexes;
    my $n_items      = 1;
    my $last_idx_idx = $idx_idx;

    while (defined $last_idx_idx
      and ($arg_indexes[0] // $NO_MATCH) == $last_idx_idx + 1) {
      ++$n_items;
      $last_idx_idx = shift @arg_indexes;
    } ## end while (defined $last_idx_idx...)
    push @removers, sub { return $self->$_remove_args($idx_idx, $n_items); };
  } ## end while (@arg_indexes)

  # Execute the removers in descending order to avoid invalidating
  # indexes in the remaining calls.
  return map { &{$_}; } reverse @removers;
} ## end sub remove_args_at

# Remove all arguments for a given keyword while leaving all instances
# of said keyword in place. Returns a list of removed arguments *with*
# any quotes.
sub remove_args_for {
  my ($self, $kw, @args) = @_;
  my $found_args = $self->find_args_for($kw, @args);
  defined $found_args
    and return $self->remove_args_at(map { @{ $found_args->{$_} }; }
      keys %{$found_args});
  return;
} ## end sub remove_args_for

# Remove all instances of keyword and any arguments thereto, and return
# a list of removed items *with* any quotes.
sub remove_keyword {
  my ($self, $kw, @args) = @_;
  my $found_args = $self->find_args_for($kw, @args);
  defined $found_args
    and return $self->remove_args_at(map { ($_, @{ $found_args->{$_} }); }
      keys %{$found_args});
  return;
} ## end sub remove_keyword


sub remove_single_valued_keyword {
  my ($self, $kw, @args) = @_;
  my $found_args = $self->find_args_for($kw, @args);
  my @to_remove  = ();

  foreach my $arg_idx (sort keys %{$found_args}) {
    my $num_nc_args   = 0;
    my $num_to_remove = 0;

    foreach my $arg_arg_idx (@{ $found_args->{$arg_idx} }) {
      is_comment($self->arg_at($arg_arg_idx)) or not $num_nc_args++ or break;
      ++$num_to_remove;
    }

    if ($num_to_remove) {
      splice @{ $found_args->{$arg_idx} }, $num_to_remove;
      push @to_remove, $arg_idx, @{ $found_args->{$arg_idx} };
    }
  } ## end foreach my $arg_idx (sort keys...)
  return $self->remove_args_at(@to_remove);
} ## end sub remove_single_valued_keyword


sub replace_arg_at {
  my ($self, $idx_idx, @replacements) = @_;
  my @removed = $self->$_remove_args($idx_idx, 1);

  if (scalar @replacements) {
    $self->insert_args_at((defined $idx_idx) ? $idx_idx : undef,
      @replacements);
  }
  return @removed;
} ## end sub replace_arg_at


sub replace_cmd_with {
  my ($self, $new_cmd, @args) = @_;
  my $old_cmd = $self->{name};

  if (@args) {
    $self->remove_args_at(0 .. $#{ $self->{arg_indexes} });

    if ($args[0] ne q()) {
      $self->insert_args_at(0, @args);
    }
  } ## end if (@args)
  $self->{name} = $new_cmd;
  $self->{pre} =~ s&\b\Q$old_cmd\E\b&$new_cmd&imsx;
  return;
} ## end sub replace_cmd_with

# Return the overriding value for a single-value keyword.
sub single_value_for {
  my ($self, @args) = @_;
  my $sv_idx = $self->find_single_value_for(@args) or return;
  return $self->arg_at($sv_idx);
} ## end sub single_value_for

########################################################################
# Private methods
########################################################################
# Detect whether the referenced argument has a close quote to match an
# opening quote: returns the match hash ref if so, else undef.
$_has_close_quote = sub {
  ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
  my ($self, $idx_idx) = @_;
  my $result;
  my $index     = $self->{arg_indexes}->[$idx_idx]  // return $result;
  my $open_info = $self->$_has_open_quote($idx_idx) // return $result;
  $index < $#{ $self->{chunks} }
    and (
      (     $open_info->{qs} eq q(")
        and $self->{chunks}->[$index + 1] =~
        m&\A(?P<q>(?P<qs>")(?P<qmarker>))\z&msx)
      or $self->{chunks}->[$index + 1] =~
      m&\A(?P<q>(?P<qs>[]])(?P<qmarker>\Q$open_info->{qmarker}\E)[]])\z&msx)
    and $result = {%LAST_PAREN_MATCH};
  return $result;
};

# Detect whether the referenced argument has a valid close quote:
# returns the match hash ref if so, else undef.
$_has_open_quote = sub {
  ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
  my ($self, $idx_idx) = @_;
  my $result;
  my $index = $self->$_index_for_arg_at($idx_idx) // return $result;
  $self->{chunks}->[$index - 1] =~
m&\A(?P<q>(?|(?P<qs>["])(?P<qmarker>)|(?P<qs>[[])(?P<qmarker>=*)[[]))\z&msx
    and $result = {%LAST_PAREN_MATCH};
  return $result;
}; ## end sub _has_open_quote
$_index_for_arg_at = sub {
  my ($self, $idx_idx) = @_;
  return $self->{arg_indexes}->[$idx_idx] // ();
}; ## end sub _index_for_arg_at
$_recalculate_comment_indexes = sub {
  my ($self) = @_;
  @{ $self->{comment_indexes} } =
    List::MoreUtils::indexes { is_comment($_); } @{ $self->{chunks} };
  return;
}; ## end sub _recalculate_comment_indexes

# Removes $n_args contiguous CMake arguments starting at $idx_idx.
# See remove_args_at() for possibly-non-contiguous arguments.
#
# Returns a list of removed arguments *with* any quotes and trailing
# whitespace/comments.
$_remove_args = sub {
  my ($self, $idx_idx, $n_args) = @_;
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my @removed      = ();
  my $last_arg_idx = List::Util::min(
    ($idx_idx // return @removed) + (($n_args // 1) || return @removed) - 1,
    $#{ $self->{arg_indexes} });
  my $index      = $self->{arg_indexes}->[$idx_idx] // return;
  my $last_index = $self->{arg_indexes}->[$last_arg_idx];

  # Remove any preceding quote.
  $self->$_has_open_quote($idx_idx) and --$index;

  # Remove any trailing quote.
  $self->$_has_close_quote($last_arg_idx) and ++$last_index;

  # If we're removing the last argument, remove any preceding
  # whitespace.
  if ($last_arg_idx == $#{ $self->{arg_indexes} }) {
    while ($index > 1 and is_whitespace($self->{chunks}->[$index - 1])) {
      --$index;
    }
  } ## end if ($last_arg_idx == $#...)

  # Remove any trailing whitespace or comments.
  while (
    ( $last_index < $#{ $self->{chunks} }
      and is_comment($self->{chunks}->[$last_index + 1]))
    or ($last_index < ($#{ $self->{chunks} } - 1)
      and is_whitespace($self->{chunks}->[$last_index + 1]))
    ) {
    ++$last_index;
  } ## end while (($last_index < $#{...}))
  my $chunks_to_remove = $last_index - $index + 1;

  # Remove all relevant chunks.
  my @removed_chunks =
    splice(@{ $self->{chunks} }, $index, $chunks_to_remove);

  # Remove corresponding arg_indexes.
  splice(@{ $self->{arg_indexes} }, $idx_idx, $n_args);

  # Recalculate indexes for remaining args.
  for ($idx_idx .. $#{ $self->{arg_indexes} }) {
    $self->{arg_indexes}->[$_] -= $chunks_to_remove;
  }

  # Recalculate comment indexes.
  $self->$_recalculate_comment_indexes();
  my $in_whitespace = 1;
  my $current       = q();

  foreach my $item (@removed_chunks) {
    my $prev_in_whitespace = $in_whitespace;
    $in_whitespace = is_whitespace($item);

    if ($in_whitespace and not $prev_in_whitespace and $current ne q()) {
      push @removed, $current;
      $current = q();
    } elsif (not $in_whitespace) {
      $current = "$current$item";
    }
  } ## end foreach my $item (@removed_chunks)
  $current ne q() and push @removed, $current;
  return @removed;
}; ## end sub _remove_args

########################################################################
1;
__END__
