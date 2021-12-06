# -*- cperl -*-
package Cetmodules::Migrate::Tagging;

use 5.016;

use Exporter qw(import);

use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

use Cetmodules::CMake;
use Cetmodules::Migrate::ProductDeps qw($CETMODULES_VERSION);

use warnings FATAL => qw(Cetmodules);

our (@EXPORT);

@EXPORT = qw(
  flag
  flag_recommended
  flag_required
  flagged
  has_directive
  has_ignore_directive
  tag
  tag_added
  tag_changed
  tagged
);


sub flag {
  my ($textref, $type, $extra) = @_;
  return tag($textref, "ACTION-$type", $extra);
}


sub flag_recommended {
  my ($textref, $extra) = @_;
  return flag($textref, "RECOMMENDED", $extra);
}


sub flag_required {
  my ($textref, $extra) = @_;
  return flag($textref, "REQUIRED", $extra);
}


sub flagged {
  my ($textish, $type, $extra) = @_;
  return tagged($textish, "ACTION-$type", $extra);
}


sub has_directive {
  my ($textish, $directive) = @_;
  my $text = (ref $textish) ? ${$textish} : $textish;
  return $text =~ m&(?:\A|\s+)\#\#\#\s+MIGRATE-$directive\b&msx;
}


sub has_ignore_directive {
  my ($textish) = @_;
  return has_directive($textish, "NO-ACTION");
}


sub remove_all_directives {
  my ($textref) = @_;
  return ${$textref} =~
    s&(?:\A|\s+)[#]{3}\s+MIGRATE-(?!NO-ACTION\b).*?(\s+[#]|$)&$1&msgx;
}


sub remove_directive {
  my ($textref, $directive) = @_;
  return ${$textref} =~
    s&(?:\A|\s+)[#]{3}\s+MIGRATE-$directive.*?(\s+[#]|$)&$1&msgx;
}


sub tag {
  my ($textref, $type, $extra) = @_;
  my $text;
  given (ref $textref) {
    when (undef) {
      $text = $textref;
      $textref = \$text;
    }
    when ('SCALAR') { }
    when ('HASH' and exists $textref->{post}) {
      $textref = \$textref->{post};
    }
    default {
      error_exit(<<"EOF");
cannot tag unknown entity $textref
EOF
    }
  }
  tagged($textref, $type, $extra) or
    ${$textref} =~ s&[ \t]*(\Z)& ### MIGRATE-$type$extra$1&msx;
  return ${$textref};
}


sub tag_added {
  my ($textref, $extra) = @_;
  return tag($textref, "ADDED (migrate-$CETMODULES_VERSION)",
             ($extra) ? " - $extra" : ());
}


sub tag_changed {
  my ($textref, $extra) = @_;
  remove_all_directives($textref);
  return tag($textref, "CHANGED (migrate-$CETMODULES_VERSION)",
             ($extra) ? " - $extra" : ());
}


sub tagged {
  my ($textish, $type, $extra) = @_;
  defined $extra or $extra = q();
  return has_directive($textish, "$type$extra");
}

1;
