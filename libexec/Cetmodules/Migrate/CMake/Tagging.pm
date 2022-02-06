# -*- cperl -*-
package Cetmodules::Migrate::CMake::Tagging;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules::CMake qw(reconstitute_code);
use Cetmodules::Migrate::ProductDeps qw($CETMODULES_VERSION);
use Cetmodules::Util::PosResetter qw();
use Cetmodules::Util qw(error_exit info);
use English qw(-no_match_vars);
use Exporter qw(import);
use Scalar::Util qw(blessed);

##
use warnings FATAL => qw(Cetmodules);

our (@EXPORT, @EXPORT_OK, $FLAGS_ONLY);

@EXPORT = qw(
  flag
  flag_error
  flag_recommended
  flag_required
  flagged
  ignored
  report_removed
  tag
  tag_added
  tag_changed
  tagged
  unflag_all
  unflag_matching
  unflag_not_matching
  untag_all
  untag_informational
  untag_matching
  untag_not_matching
);
@EXPORT_OK = qw($FLAGS_ONLY);

use vars qw($_FLAGGING);

########################################################################
# Exported functions
########################################################################
sub flag {
  my ($textish, $type, @msg) = @_;
  local $_FLAGGING = 1; ## no critic qw(Variables::ProhibitLocalVars)
  return tag($textish, "ACTION-$type", @msg);
} ## end sub flag


sub flag_error {
  my ($textish, @msg) = @_;
  return flag($textish, "ERROR", @msg);
}


sub flag_recommended {
  my ($textish, @msg) = @_;
  return flag($textish, "RECOMMENDED", @msg);
}


sub flag_required {
  my ($textish, @msg) = @_;
  return flag($textish, "REQUIRED", @msg);
}


sub flagged {
  my ($textish, $flag_selector) = @_;
  return tagged($textish, "ACTION-$flag_selector");
}


sub ignored {
  return tagged(shift, 'NO-ACTION');
}


sub report_removed {
  my ($cmake_file, $msg, @args) = @_;
  defined $msg or $msg = q();
  map {
      info("command removed from $cmake_file:$_->{start_line}$msg:\n",
        reconstitute_code($_));
  } @args;
  return;
} ## end sub report_removed


sub tag {
  my ($textish, $type, @msg) = @_;
  $type or $type = 'UNKNOWN';
  my $textref = _to_textref($textish);
  not(   ignored($textish)
      or tagged($textish, $type)
      or ($FLAGS_ONLY and not $_FLAGGING))
    or return $textref;
  my $msg = join(q(), @msg);
  chomp $msg;
  my $tag_text = sprintf("### MIGRATE-$type (migrate-$CETMODULES_VERSION)%s",
      $msg ? " - $msg" : q());
  my $line_end = qq(\n) x chomp ${$textref};
  my ($text, $space) =
    (${$textref} =~ m&\A(.*?)([ \t]*)\z&msx);

  if (length($text)) {
    length($space) or $space = q( );
  } else {
    $space = q();
  }
  ${$textref} = "$text$space$tag_text$line_end";
  return $textref;
} ## end sub tag


sub tag_added {
  my ($textish, @msg) = @_;
  return tag($textish, "ADDED", @msg);
}


sub tag_changed {
  my ($textish, @msg) = @_;
  return tag($textish, "CHANGED", @msg);
}


sub tagged {
  my ($textish, $tag_selector) = @_;
  return _filter_tags($textish, $tag_selector, { shortcircuit => 1 });
}


sub unflag_all {
  return untag_matching(shift, "ACTION*");
}


sub unflag_matching {
  my ($textish, $flag_selector) = @_;
  return untag_matching($textish, "ACTION-$flag_selector");
}


sub unflag_not_matching {
  my ($textish, $flag_selector) = @_;
  return untag_not_matching($textish, "ACTION-$flag_selector");
}


sub untag_all {
  return untag_matching(shift);
}


sub untag_informational {
  return untag_not_matching(shift, "ACTION*");
}


sub untag_matching {
  my ($textish, $tag_selector) = @_;
  return _filter_tags($textish, $tag_selector, { exclude => 1 });
}


sub untag_not_matching {
  my ($textish, $tag_selector) = @_;
  return _filter_tags($textish, $tag_selector);
}

########################################################################
# Private functions
########################################################################
my $_tag_preamble   = qr&(?:^|[ \t]+)[#]{3}[ \t]+&msx;
my $_tag_stamp      = qr&(?:[ ]\(migrate-[^)]+\)[ \t]*?)?&msx;
my $_tag_fmt_tag    = qr&MIGRATE-(?P<found_tag>[A-Za-z0-9_-]+)&msx;
my $_tag_fmt_msg    = qr&(?:[ \t]+-[ \t]+.*?)?&msx;
my $_tag_full_match = "$_tag_preamble$_tag_fmt_tag$_tag_stamp$_tag_fmt_msg";
my $_tag_buffer     = qr&(?=[ \t]+[#]|$)&msx;


sub _filter_tags {
  my ($textish, $tag_selector, $options) = @_;
  length($textish)
    or ($options->{shortcircuit} and return or return _to_textref($textish));
  my $textref  = _to_textref($textish);
  my $resetter = Cetmodules::Util::PosResetter->new($textref);
  $options->{shortcircuit} or not ignored($textref) or return $textref;

  if (not defined $tag_selector or $tag_selector eq q()) {
    $tag_selector = qr&\A[-a-z0-9_]+\z&imsx;
  } elsif ($tag_selector =~ m&\A([-A-Za-z0-9_*]+)\z&msx) {
    $tag_selector =~ s&([-A-Za-z0-9_]+)&\Q$1\E&msgx;
    $tag_selector =~ s&[*]&(?:\\b[-A-Za-z0-9_]+)?&msgx;
    $tag_selector = qr&\A$tag_selector\z&msx;
  } ## end elsif ($tag_selector =~ m&\A([-A-Za-z0-9_*]+)\z&msx) [ if (not defined $tag_selector...)]
  my $new_text = q();

  while ( ## no critic qw(RegularExpressions::ProhibitUnusedCapture)
      ${$textref} =~
    m&\G(?P<pre_match>.*?)(?P<full_match>$_tag_full_match)$_tag_buffer&mscgx
    ) {
    my ($pre_match, $found_tag, $full_match) =
      @LAST_PAREN_MATCH{qw(pre_match found_tag full_match)};
    my $matched = ($found_tag =~ m&$tag_selector&msx);
    $options->{shortcircuit} and ($matched and return 1 or next);
    $new_text = "$new_text$pre_match";
    ($matched xor $options->{exclude}) and $new_text = "$new_text$full_match";
  } ## end while (  ${$textref} =~ ...)
  $options->{shortcircuit} and return; # Match / no match only.
  ${$textref} = sprintf("$new_text%s", ${$textref} =~ m&\G(.*)\z&msx);
  return $textref;
} ## end sub _filter_tags


sub _to_textref {
  my ($textish) = @_;
  defined $textish or $textish = q();
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my $result;

  if (blessed($textish) and $textish->isa('Cetmodules::CMake::CommandInfo')) {
    $result = \$textish->{post};
  } elsif (ref $textish eq 'SCALAR') {
    $result = $textish;
  } elsif (not ref $textish) {
    $result = \$textish;
  } else {
    error_exit(<<"EOF");
cannot identify tag text from unknown entity $textish
EOF
  } ## end else [ if (blessed($textish) ... [... [elsif (not ref $textish) ]])]
  return $result;
} ## end sub _to_textref

########################################################################
1;
__END__
