# -*- cperl -*-
package Cetmodules::Migrate::CMake;

use 5.016;
use English qw(-no_match_vars);
use File::Basename qw(basename);
use File::Copy qw(move);
use File::Find;
use Exporter qw(import);
use IO::File;
use List::MoreUtils qw();
use Readonly;
use Cetmodules::CMake;
use Cetmodules::Migrate::CMake::Handlers;
use Cetmodules::Migrate::CMake::Tagging;
use Cetmodules::Migrate::Util;
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

our (@EXPORT_OK, %EXPORT_TAGS);

Readonly::Array my @CMAKE_FILE_TOOLS =>
  qw(find_cmake fix_cmake write_top_CML);
Readonly::Array my @HANDLER_TOOLS => qw(generate_cmd_handlers);
@EXPORT_OK = (@CMAKE_FILE_TOOLS, @HANDLER_TOOLS);
%EXPORT_TAGS = (CMAKE_FILE_TOOLS => \@CMAKE_FILE_TOOLS,
                HANDLER_TOOLS    => \@HANDLER_TOOLS);
Readonly::Scalar my $_LINE_LENGTH => 80;

########################################################################
# Exported functions
########################################################################
sub find_cmake {
  return (
      grep {
        ( -d and # Process most directories ...
          not(m&\Amigrate-backup&msx or m&\A\.&msx)) # except "dot" directories.
        or (
          $_ eq 'CMakeLists.txt' and # Directory-level CMake files ...
          not $File::Find::dir eq q(.)) # except already-handled top level.
        or m&\.cmake\z&msx; # Standard extension for CMake files.
      } @_);
} ## end sub find_cmake


sub fix_cmake {
  my @args = @_;
  find(
      { preprocess => \&find_cmake,
        wanted     => sub { fix_cmake_one(@args); }
      },
      q(.));
  return;
} ## end sub fix_cmake


sub fix_cmake_one {
  my ($pi, @args) = @_;

  # Called by File::find() from fix_cmake() with respect to a
  # CMakeLists.txt or *.cmake file to upgrade to use of cetmodules >=
  # 2.0 where possible to do so programmatically.
  -f and -r or return; # Only interested in readable files.
  my ($path, $filepath, $cml) =
    ($File::Find::dir, ($File::Find::name =~ m&\A(?:\./)?(.*)\z&msx), $_);
  List::MoreUtils::any { $pi->{name} eq $_; } qw(cetmodules mrb)
    or _upgrade_CML($filepath, "$filepath.new", $pi, @args);
  return;
} ## end sub fix_cmake_one


sub generate_cmd_handlers {
  my ($pi, @cmd_handlers) = @_;
  return {
      map {
        my $func_name = "Cetmodules::Migrate::CMake::Handlers\::$_";
        "${_}_cmd" => sub {
          my ($cmd_infos, $cmd_info, $cmakelists, $options) = @_;
          not ignored($cmd_info) or return; # NOP
          local $_; ## no critic qw(RequireInitializationForLocalVars)
          my $orig_cmd = reconstitute_code(@{ $cmd_infos // [] });

          # Save for diagnostics in case they get changed:
          my $saved_info = { name       => $cmd_info->{name},
                             start_line => $cmd_info->{start_line} };

          # Invoke the real function.
          my $func_ref = \&{$func_name};
          untag_all($cmd_info);
          debug(<<"EOF");
invoking wrapped migration handler $func_name\E() for CMake command $saved_info->{name}\E() at $cmakelists:$saved_info->{start_line}
EOF
          eval {
            &{$func_ref}
            ($pi, $cmd_infos, $cmd_info, $cmakelists, $options);
          } or 1;

          if (my $err = $EVAL_ERROR) {
            $err =~ s&^FATAL_ERROR:\s*&&msxg;
            $err =~ s&^\s*&&msxg;
            $err =~ s&^&   &msxg;
            error_exit(<<"EOF");
error calling handler $func_name\E() for CMake command $saved_info->{name}\E() at $cmakelists:$saved_info->{start_line}:

$err
EOF
          } ## end if (my $err = $EVAL_ERROR)
          my $new_cmd = reconstitute_code(@{ $cmd_infos // [] });

          if ($orig_cmd ne ($new_cmd // q())) {
            my $result = {};
            @{$result}{qw(orig_cmd new_cmd)} =
            ($orig_cmd, $new_cmd // q());
            my $file_label = $options->{cmakelists_short} // $cmakelists;
            my ($div, $filler) =
              (length($file_label) > ($_LINE_LENGTH - 2))
            ? (q(=), q())
            : (
              q(=) x (($_LINE_LENGTH - length($file_label)) / 2),
              (length($file_label) % 2) ? q(=) : q());
            $options->{"dry-run"} and printf <<"EOF"

--------------------------------------old---------------------------------------
% 4d %s
$div$file_label$div$filler%s
++++++++++++++++++++++++++++++++++++++new+++++++++++++++++++++++++++++++++++++++

EOF
            , $cmd_info->{start_line},
            map { join("\n     ", split m&\n&msx); }
            ($orig_cmd, ($new_cmd) ? "\n$new_cmd" : q());
            return $result;
          } ## end if ($orig_cmd ne ($new_cmd...))
          return;
        };
      } @cmd_handlers };
} ## end sub generate_cmd_handlers


sub write_top_CML {
  my ($pkgtop, $pi, $options) = @_;
  return _upgrade_CML("CMakeLists.txt", "CMakeLists.txt.new", $pi, $options);
}

########################################################################
# Private functions
########################################################################
sub _upgrade_CML {
  my ($cml_full, $dest_full, $pi, $options, %handlers) = @_;
  my $cml    = basename($cml_full);
  my $dest   = basename($dest_full);
  my $cml_in = IO::File->new("$cml", "<")
    or error_exit("unable to open $cml_full for read");

  if (ignored($cml_in->getline)) {
    info(<<"EOF");
upgrading $cml -> $dest SKIPPED due to MIGRATE-NO-ACTION directive in line 1
EOF
    $cml_in->close();
    return;
  } ## end if (ignored($cml_in->getline...))
  verbose("upgrading <$pi->{name}>/$cml_full -> <$pi->{name}>$dest_full");
  my $cml_out = IO::File->new("$dest", ">")
    or error_exit("unable to open $dest_full for write");
  scalar keys %handlers
    or %handlers = (
      %{generate_cmd_handlers($pi,
          @Cetmodules::Migrate::CMake::Handlers::COMMAND_HANDLERS)
       },
      arg_handler     => \&Cetmodules::Migrate::CMake::Handlers::arg_handler,
      comment_handler =>
      \&Cetmodules::Migrate::CMake::Handlers::comment_handler,
      eof_handler => \&Cetmodules::Migrate::CMake::Handlers::eof_handler
    );
  my $cmakelists = [$cml_in,  $cml_full];
  my $output     = [$cml_out, $dest_full];
  $options = { %{$options},
               cmakelists_short => "<$pi->{name}>/$cml_full",
               output           => $output,
               %handlers
             };
  my $results = process_cmakelists($cmakelists, $options);
  $cml_out->close();
  my $changed = keys %{$results};

  if ($changed) {
    if ($options->{"dry-run"}) {
      $changed
        and
        notify(sprintf("[DRY_RUN] would have made $changed edit%s to $cml\n",
          ($changed != 1) ? 's' : q()));
    } else {
      info(sprintf("made $changed edit%s to $cml_full",
          ($changed != 1) ? 's' : q()));
      move("$dest", "$cml")
        or error_exit("unable to install $dest_full as $cml_full");
    } ## end else [ if ($options->{"dry-run"...})]
  } else {
    verbose(sprintf(
        "%sno changes necessary to $cml_full%s",
        $options->{"dry-run"} ? "[DRY_RUN] "       : q(),
        (-e $dest)            ? ": removing $dest" : q()
    ));
    $options->{'debug'} or (-e $dest and unlink $dest);
  } ## end else [ if ($changed) ]
  return;
} ## end sub _upgrade_CML

########################################################################
1;
__END__
