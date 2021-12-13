# -*- cperl -*-
package Cetmodules::Migrate::CMake::Tagging;

use 5.016;
use Exporter qw(import);
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);
use Cetmodules::CMake;
use Cetmodules::Migrate::ProductDeps qw($CETMODULES_VERSION);
use Cetmodules::Util;
use warnings FATAL => qw(Cetmodules);

our (@EXPORT);

@EXPORT = qw(
  flag
  flag_recommended
  flag_required
  flagged
  ignored
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
  my ($textish, $type, $extra) = @_;
  return tag($textish, "ACTION-$type", $extra // ());
}


sub flag_recommended {
  my ($textish, $extra) = @_;
  return flag($textish, "RECOMMENDED", $extra // ());
}


sub flag_required {
  my ($textish, $extra) = @_;
  return flag($textish, "REQUIRED", $extra // ());
}


sub flagged {
  my ($textish, $type, $extra) = @_;
  return tagged($textish, "ACTION-$type", $extra // ());
}


sub ignored {
  my ($textish) = @_;
  return tagged($textish, 'NO-ACTION');
}


sub tag {
  my ($textish, $type, $extra) = @_;
  not ignored($textish) or return;
  $type or $type = 'UNKNOWN';
  not tagged($textish, $type, $extra // ()) or return;
  my $textref  = _to_textref($textish);
  my $tag_text = sprintf(" ### MIGRATE-$type (migrate-$CETMODULES_VERSION)%s",
      $extra ? " - $extra" : q());
  ${$textref} =~ s&[ \t]*(\Z)&$tag_text$1&msx;
  return $textref;
} ## end sub tag


sub tag_added {
  my ($textish, $extra) = @_;
  return tag($textish, "ADDED", $extra // ());
}


sub tag_changed {
  my ($textish, $extra) = @_;
  return tag($textish, "CHANGED", $extra // ());
}


sub tagged {
  my ($textish, $type, $extra) = @_;
  my $type_re  = (defined $type)  ? qr&\Q-$type\E&msx    : q();
  my $extra_re = (defined $extra) ? qr&\Q - $extra\E&msx : q();
  my $textref  = _to_textref($textish);
  return ${ ${textref} } =~
    m& [#]{3} MIGRATE$type_re(?: \(migrate-[^)]+\)\s*?)?$extra_re&msx;
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
  local $_; ## no critic qw(Variables::RequireInitializationForLocalVars)
  my ($result);
  given (ref $textish) {
    when ('SCALAR') { $result = $textish; }
    when ('HASH') {
      defined $textish->{post} or continue;
      $result = \$textish->{post};
    }
    when (q()) { $result = \$textish; }
    default {
      error_exit(<<"EOF");
cannot identify tag text from unknown entity $textish
EOF
    } ## end default
  } ## end given
  return $result;
} ## end sub _to_textref

########################################################################
1;
__END__
