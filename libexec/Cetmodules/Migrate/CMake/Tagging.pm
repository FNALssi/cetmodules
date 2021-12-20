# -*- cperl -*-
package Cetmodules::Migrate::CMake::Tagging;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules::CMake qw(reconstitute_code);
use Cetmodules::Migrate::ProductDeps qw($CETMODULES_VERSION);
use Cetmodules::Util qw(error_exit info);
use Exporter qw(import);
use Scalar::Util qw(blessed);

##
use warnings FATAL => qw(Cetmodules);

our (@EXPORT);

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
  unflag
  untag
  untag_all
);

########################################################################
# Exported functions
########################################################################
sub flag {
  my ($textish, $type, @extra) = @_;
  return tag($textish, "ACTION-$type", @extra);
}


sub flag_error {
  my ($textish, @extra) = @_;
  return flag($textish, "ERROR", @extra);
}


sub flag_recommended {
  my ($textish, @extra) = @_;
  return flag($textish, "RECOMMENDED", @extra);
}


sub flag_required {
  my ($textish, @extra) = @_;
  return flag($textish, "REQUIRED", @extra);
}


sub flagged {
  my ($textish, $type, @extra) = @_;
  return tagged($textish, "ACTION-$type", @extra);
}


sub ignored {
  return tagged(@_, 'NO-ACTION');
}


sub report_removed {
  my ($cmake_file, $extra, @args) = @_;
  defined $extra or $extra = q();
  map {
      info("command removed from $cmake_file:$_->{start_line}$extra:\n",
        reconstitute_code($_));
  } @args;
  return;
} ## end sub report_removed


sub tag {
  my ($textish, $type, @extra) = @_;
  not(ignored($textish, @extra) or tagged($textish, $type, @extra)) or return;
  my $textref = _to_textref($textish);
  $type or $type = 'UNKNOWN';
  my $extra    = join(q(), @extra);
  my $tag_text = sprintf("### MIGRATE-$type (migrate-$CETMODULES_VERSION)%s",
      $extra ? " - $extra" : q());
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
  my ($textish, @extra) = @_;
  return tag($textish, "ADDED", @extra);
}


sub tag_changed {
  my ($textish, @extra) = @_;
  return tag($textish, "CHANGED", @extra);
}


sub tagged {
  my ($textish, $type, @extra) = @_;
  my $textref = _to_textref($textish);
  length(${$textref}) or return;
  my $type_re  = length($type // q()) ? qr&\Q-$type\E&msx : qr&(?:-\S*)?&msx;
  my $extra    = join(q(), @extra);
  my $extra_re = length($extra) ? qr&\Q - $extra\E&msx : q();
  return ${$textref} =~
m&(\A|[ \t])[#]{3} MIGRATE$type_re(?: \(migrate-[^)]+\)\s*?)?$extra_re&msx;
} ## end sub tagged


sub untag {
  my ($textish, $type) = @_;
  not ignored($textish) or return;
  my $textref = _to_textref($textish);
  ${$textref} =~ s&(?:\A|\s+)[#]{3}\s+MIGRATE-$type.*?(\s+[#]|$)&$1&msgx;
  return $textref;
} ## end sub untag


sub untag_all {
  my ($textish) = @_;
  not ignored($textish) or return;
  my $textref = _to_textref($textish);
  ${$textref} =~ s&(?:\A|\s+)[#]{3}\s+MIGRATE-.*?(\s+[#]|$)&$1&msgx;
  return $textref;
} ## end sub untag_all

########################################################################
# Private functions
########################################################################
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
