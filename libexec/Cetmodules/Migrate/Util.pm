# -*- cperl -*-
package Cetmodules::Migrate::Util;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules qw();
use Exporter qw(import);
use POSIX qw(strftime);

##
use warnings FATAL => qw(Cetmodules);

our (@EXPORT);

@EXPORT = qw(
  gentime
  trim_lines
);

########################################################################
# Exported functions
########################################################################
sub gentime {
  my @lt = localtime;
  return strftime('%a %b %d %H:%M:%S %Z', @lt);
}


sub trim_lines {
  my @text = @_;
  my $text = join(q(), @text);
  $text =~ s&(?-s:\s+)$&&msgx;
  return $text;
} ## end sub trim_lines

########################################################################
1;
__END__
