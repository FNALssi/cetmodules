# -*- cperl -*-
package Cetmodules::Migrate::Tagging;

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
  has_directive
  has_ignore_directive
  remove_all_directives
  remove_directive
  tag
  tag_added
  tag_changed
  tagged
);


sub flag {
  my ($textish, $type, $extra) = @_;
  return tag($textish, "ACTION-$type", $extra);
}


sub flag_recommended {
  my ($textish, $extra) = @_;
  return flag($textish, "RECOMMENDED", $extra);
}


sub flag_required {
  my ($textish, $extra) = @_;
  return flag($textish, "REQUIRED", $extra);
}


sub flagged {
  my ($textish, $type, $extra) = @_;
  return tagged($textish, "ACTION-$type", $extra);
}


sub has_directive {
  my ($textish, $directive) = @_;
  my $textref = _tag_textref($textish);
  return ${$textref} =~ m&(?:\A|\s+)\#\#\#\s+MIGRATE-$directive\b&msx;
} ## end sub has_directive


sub has_ignore_directive {
  my ($textish) = @_;
  return has_directive($textish, "NO-ACTION");
}


sub remove_all_directives {
  my ($textish) = @_;
  my $textref = _tag_textref($textish);
  ${$textref} =~
    s&(?:\A|\s+)[#]{3}\s+MIGRATE-(?!NO-ACTION\b).*?(\s+[#]|$)&$1&msgx;
  return $textref;
} ## end sub remove_all_directives


sub remove_directive {
  my ($textish, $directive) = @_;
  my $textref = _tag_textref($textish);
  ${$textref} =~ s&(?:\A|\s+)[#]{3}\s+MIGRATE-$directive.*?(\s+[#]|$)&$1&msgx;
  return $textref;
} ## end sub remove_directive


sub tag {
  my ($textish, $type, $extra) = @_;
  my $textref = _tag_textref($textish);
  tagged($textref, $type, $extra)
    or ${$textref} =~ s&[ \t]*(\Z)& ### MIGRATE-$type$extra$1&msx;
  return $textref;
} ## end sub tag


sub tag_added {
  my ($textish, $extra) = @_;
  return
    tag($textish,
      "ADDED (migrate-$CETMODULES_VERSION)",
      ($extra) ? " - $extra" : ());
} ## end sub tag_added


sub tag_changed {
  my ($textish, $extra) = @_;
  return
    tag($textish,
      "CHANGED (migrate-$CETMODULES_VERSION)",
      ($extra) ? " - $extra" : ());
} ## end sub tag_changed


sub tagged {
  my ($textish, $type, $extra) = @_;
  defined $extra or $extra = q();
  return has_directive($textish, "$type$extra");
} ## end sub tagged


sub _tag_textref {
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
} ## end sub _tag_textref

########################################################################
1;
__END__
