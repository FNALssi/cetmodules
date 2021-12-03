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
use Cetmodules::Migrate::Tagging;
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

Readonly::Array my @HANDLER_TOOLS => qw(generate_call_handlers);

@EXPORT_OK = (@CMAKE_FILE_TOOLS, @HANDLER_TOOLS);

%EXPORT_TAGS = (CMAKE_FILE_TOOLS => \@CMAKE_FILE_TOOLS,
                HANDLER_TOOLS    => \@HANDLER_TOOLS);


sub find_cmake {
  return (
    grep {
      (-d and not m&\Amigrate-backup&msx) or
        $_ eq 'CMakeLists.txt' or
        m&\.cmake\z&msx;
      } @_);
}


sub fix_cmake {
  my @args = @_;
  find({
         preprocess => \&find_cmake,
         wanted     => sub { fix_cmake_one(@args); }
       },
       q(.));
  return;
}


sub fix_cmake_one {
  my ($pi, @args) = @_;

  # Called by File::find() from fix_cmake() with respect to a
  # CMakeLists.txt or *.cmake file to upgrade to use of cetmodules >=
  # 2.0 where possible to do so programmatically.
  -f and -r or return; # Only interested in readable files.
  my ($path, $filepath, $cml) =
    ($File::Find::dir, ($File::Find::name =~ m&\A(?:\./)?(.*)\z&msx), $_);
  List::MoreUtils::any { $pi->{name} eq $_; } qw(cetmodules mrb) or
    _upgrade_CML($filepath, "$filepath.new", $pi, @args);
  return;
} ## end sub fix_cmake_one


sub generate_call_handlers {
  my ($pi, @call_handlers) = @_;
  return {
    map {
      my $func_name = "Cetmodules::Migrate::CMake::Handlers\::$_";
      "${_}_callback" => sub {
        my ($call_infos, $call_info, $cmakelists, $options) = @_;
        local $_; ## no critic qw(RequireInitializationForLocalVars)
        my $func_ref = \&{$func_name};
        my $result;
        (List::MoreUtils::any {
           has_ignore_directive($call_info->{chunks}->[$_]);
         }
         @{ $call_info->{arg_indexes} }
          ) and
          return $result; # NOP
        my $orig_call = reconstitute_code(@{ $call_infos // [] });
        debug(<<"EOF");
invoking wrapped migration handler $func_name\E() for CMake call $call_info->{name}\E() at $cmakelists:$call_info->{start_line}
EOF
        eval {
          &{$func_ref}($pi, $call_infos, $call_info, $cmakelists, $options);
        } or 1;
        $EVAL_ERROR and error_exit(<<"EOF");
error calling handler $func_name\E() for CMake call $call_info->{name}\E() at $cmakelists:$call_info->{start_line}:
$EVAL_ERROR
EOF
        my $new_call = reconstitute_code(@{ $call_infos // [] });
        if ($orig_call ne ($new_call // q())) {
          @{$result}[qw(orig_call new_call)] = ($orig_call, $new_call // q());
          $options->{"dry-run"} and
            printf
            <<'EOF', $call_info->{start_line}, map { join("\n     ", split m&\n&msx); } ($orig_call, $new_call);
---------------old------------------
% 4d %s
====================================
     %s
+++++++++++++++new++++++++++++++++++
EOF
        } ## end if ($orig_call ne ($new_call...))
        return $result;
      };
      } @call_handlers
  };
} ## end sub generate_call_handlers


sub write_top_CML {
  my ($pkgtop, $pi, $options) = @_;
  return
    _upgrade_CML("$pkgtop/CMakeLists.txt", "$pkgtop/CMakeLists.new", $pi,
                 $options);
}

########################################################################
# Private functions
########################################################################


sub _upgrade_CML {
  my ($cml_full, $dest_full, $pi, $options, %handlers) = @_;
  my $cml  = basename($cml_full);
  my $dest = basename($dest_full);

  my $cml_in = IO::File->new("$cml", "<") or
    error_exit("unable to open $cml_full for read");

  if (has_ignore_directive($cml_in->getline)) {
    info("upgrading $cml -> $dest SKIPPED due to \"$1\" directive in line 1");
    $cml_in->close();
    return;
  }

  info("upgrading $cml_full -> $dest_full");

  my $cml_out = IO::File->new("$dest", ">") or
    error_exit("unable to open $dest_full for write");

  scalar keys %handlers
    or
    %handlers = (
            %{
              generate_call_handlers($pi,
                         @Cetmodules::Migrate::CMake::Handlers::CALL_HANDLERS)
             },
            comment_handler =>
              \&Cetmodules::Migrate::CMake::Handlers::comment_handler,
            eof_handler => \&Cetmodules::Migrate::CMake::Handlers::eof_handler
    );

  my $results = process_cmakelists([ $cml_in, $cml_full ],
                                   output => [ $cml_out, $dest_full ],
                                   %handlers);

  $cml_out->close();

  my $changed = keys %{$results};

  if ($changed) {
    if ($options->{"dry-run"}) {
      $changed
        and notify(
                sprintf("[DRY_RUN] would have made $changed edit%s to $cml\n",
                        ($changed != 1) ? 's' : q()));
    } else {
      info(sprintf("made $changed edit%s to $cml_full",
                   ($changed != 1) ? 's' : q()));
      move("$dest", "$cml") or
        error_exit("unable to install $dest_full as $cml_full");
    }
  } else {
    verbose(sprintf("%sno changes necessary to $cml_full%s",
                    $options->{"dry-run"} ? "[DRY_RUN] "       : q(),
                    (-e $dest)            ? ": removing $dest" : q()));
    $options->{debug} or (-e $dest and unlink $dest);
  }
  return;
} ## end sub _upgrade_CML

1;
