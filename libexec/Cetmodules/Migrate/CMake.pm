# -*- cperl -*-
package Cetmodules::Migrate::CMake;

use 5.016;
use strict;
use warnings FATAL => qw(io regexp severe syntax uninitialized void);

##
use Cetmodules::CMake qw(process_cmake_file);
use Cetmodules::Migrate::CMake::Handlers qw(:EVENT_HANDLERS);
use Cetmodules::Migrate::CMake::Tagging qw(ignored);
use Cetmodules::Util qw(debug error_exit info notify verbose);
use English qw(-no_match_vars);
use Exporter qw(import);
use File::Basename qw(basename);
use File::Copy qw(move);
use File::Find qw();
use IO::File qw();
use List::MoreUtils qw();
use Readonly qw();

##
use warnings FATAL => qw(Cetmodules);

our (@EXPORT_OK, %EXPORT_TAGS);

Readonly::Array my @CMAKE_FILE_TOOLS =>
  qw(find_cmake fix_cmake write_top_CMakeLists);
Readonly::Array my @HANDLER_TOOLS => qw(generate_cmd_handlers);
@EXPORT_OK = (@CMAKE_FILE_TOOLS, @HANDLER_TOOLS);
%EXPORT_TAGS = (CMAKE_FILE_TOOLS => \@CMAKE_FILE_TOOLS,
                HANDLER_TOOLS    => \@HANDLER_TOOLS);

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
  File::Find::find(
    {   preprocess => \&find_cmake,
        wanted     => sub { _fix_cmake_one(@args); }
    },
    q(.));
  return;
} ## end sub fix_cmake


sub generate_cmd_handlers {
  my ($pi, @cmd_handlers) = @_;
  return {
      map {
        my $func_name = "Cetmodules::Migrate::CMake::Handlers\::$_";
        "${_}_cmd" => sub {
          my ($cmd_infos, $cmd_info, $cmake_file, $options) = @_;
          not ignored($cmd_info) or return; # NOP
          local $_; ## no critic qw(RequireInitializationForLocalVars)

          # Save for diagnostics in case they get changed:
          my $saved_info = { name       => $cmd_info->{name},
                             start_line => $cmd_info->{start_line} };

          # Invoke the real function.
          my $func_ref = \&{$func_name};
          debug(<<"EOF");
invoking wrapped migration handler $func_name\E() for CMake command $saved_info->{name}\E() at $cmake_file:$saved_info->{start_line}
EOF
          eval {
            &{$func_ref}($pi, $cmd_infos, $cmd_info, $cmake_file, $options);
          } or 1;

          if (my $err = $EVAL_ERROR) {
            $err =~ s&^FATAL_ERROR:\s*&&msxg;
            $err =~ s&^\s*&&msxg;
            $err =~ s&^&   &msxg;
            error_exit(<<"EOF");
error calling handler $func_name\E() for CMake command $saved_info->{name}\E() at $cmake_file:$saved_info->{start_line}:

$err
EOF
          } ## end if (my $err = $EVAL_ERROR)
          return;
        };
      } @cmd_handlers };
} ## end sub generate_cmd_handlers


sub write_top_CMakeLists {
  return _process_cmake_file("CMakeLists.txt", "CMakeLists.txt.new", @_);
}

########################################################################
# Private functions
########################################################################
sub _fix_cmake_one {
  my ($pi, @args) = @_;

  # Called by File::find() from fix_cmake() with respect to a
  # CMakeLists.txt or *.cmake file to upgrade to use of cetmodules >=
  # 2.0 where possible to do so programmatically.
  -f and -r or return; # Only interested in readable files.
  my ($path, $filepath) =
    ($File::Find::dir, ($File::Find::name =~ m&\A(?:\./)?(.*)\z&msx));
  List::MoreUtils::any { $pi->{name} eq $_; } qw(cetmodules mrb)
    or _process_cmake_file($filepath, "$filepath.new", $pi, @args);
  return;
} ## end sub _fix_cmake_one


sub _process_cmake_file {
  my ($cmake_filename_full, $dest_full, $pi, $options, %handlers) = @_;
  my $cmake_filename = basename($cmake_filename_full);
  my $dest           = basename($dest_full);
  my $changed =
    _upgrade_cmake_file($cmake_filename_full, $dest_full, $pi, $options,
      %handlers);

  if ($changed) {
    if ($options->{"dry-run"}) {
      $changed
        and notify(sprintf(
"[DRY_RUN] would have made $changed edit%s to $options->{cmake_filename_short}",
          ($changed != 1) ? 's' : q()));
    } else {
      info(sprintf("made $changed edit%s to $options->{cmake_filename_short}",
        ($changed != 1) ? 's' : q()));
      move("$dest", "$cmake_filename")
        or error_exit("unable to install $dest_full as $cmake_filename_full");
    } ## end else [ if ($options->{"dry-run"...})]
  } else {
    verbose(sprintf(
      "%sno changes necessary to $options->{cmake_filename_short}%s",
      $options->{"dry-run"} ? "[DRY_RUN] "       : q(),
      (-e $dest)            ? ": removing $dest" : q()));
    $options->{'debug'} or (-e $dest and unlink $dest);
  } ## end else [ if ($changed) ]
  return;
} ## end sub _process_cmake_file


sub _upgrade_cmake_file {
  my ($cmake_filename_full, $dest_full, $pi, $options, %handlers) = @_;
  my $cmake_filename = basename($cmake_filename_full);
  my $dest           = basename($dest_full);
  verbose(
    "upgrading <$pi->{name}>/$cmake_filename_full -> <$pi->{name}>$dest_full"
  );
  my $cmake_file_in = IO::File->new("$cmake_filename", "<")
    or error_exit("unable to open $cmake_filename_full for read");
  my $cmake_file_out = IO::File->new("$dest", ">")
    or error_exit("unable to open $dest_full for write");
  my $cmake_file = [$cmake_file_in,  $cmake_filename_full];
  my $output     = [$cmake_file_out, $dest_full];
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
  %{$options} = (%{$options},
                 MIGRATE              => 1,
                 cmake_filename_short => "<$pi->{name}>/$cmake_filename_full",
                 output               => $output,
                 %handlers
                );
  my ($results, $status) = process_cmake_file($cmake_file, $options);
  $cmake_file_out->close();
  return scalar keys %{$status};
} ## end sub _upgrade_cmake_file

########################################################################
1;
__END__
