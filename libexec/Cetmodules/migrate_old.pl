sub old_process_cmakelists {
  my ($filename, $fh, $pi, $buffer) = @_;
  CORE::state (@shunt, $cmr_done, $project_done, $pass,
               $seen_cet_cmake_config, $seen_find_package);
  while (scalar @$buffer) {
    my $line = shift @$buffer;
    if ($line =~ m&^\s*#&) {
      $fh->print($line);
      next;
    }
    if (not $cmr_done) {
      if ($line =~ m&^\s*(?i:cmake_minimum_required)\s*\(\s*VERSION\s+(?P<vmin>.*?)(?:\.\.\.(?P<vmax>.*?))?\s*(?P<fatal>FATAL_ERROR)?\s*\)(?P<post>.*)$&) {
        my $cmr_info = { %+ };
        if ($cmr_info->{vmin} and
            version_cmp($cmr_info->{vmin},'3.19') < 0) {
          $cmr_info->{vmin} = '3.19';
          if ($cmr_info->{vmax} and version_cmp($cmr_info->{vmin}, $cmr_info->{vmax}) != -1) {
            $cmr_info->{policy} = $cmr_info->{vmax};
            undef $cmr_info->{vmax};
          }
        }
        $fh->printf("cmake_minimum_required(VERSION $cmr_info->{vmin}%s FATAL_ERROR)%s\n",
                    $cmr_info->{vmax} ? "...$cmr_info->{vmax}" : '',
                    $cmr_info->{post} // '');
        if ($cmr_info->{policy}) {
          $fh->printf("cmake_policy(VERSION %s)\n", $cmr_info->{policy});
        }
        $cmr_done = 1;
        unshift @$buffer, @shunt;
        @shunt = ();
        next;
      } elsif ($line =~ m&^\s*(?i:project)\s*\(& or $pass) {
        $fh->print("cmake_minimum_required(VERSION 3.19 FATAL_ERROR)\n");
        $cmr_done = 1;
        unshift @$buffer, @shunt;
        @shunt = ();
      } else {
        push @shunt, $line;
        next;
      }
    }
    if (not $project_done) {
      my $proj_info;
      if ($line =~ s&^\s*(?i:project)(?:\s*(?:#[^\n]*)\n?)*\s*\((?:\s*(?:#[^\n]*)\n?)*(?P<name>[^\s)]*)\s*&&sp) {
        $proj_info = { pre => ${^MATCH}, %+ };
        if ($proj_info->{name} ne $pi->{name}) {
          my $msg = <<EOF;
CMake project name $proj_info->{name} does NOT match product name
$pi->{name} - this may cause issues with (cet_)?find_package() vs
find_ups_product()
EOF
          warning($msg);
        }
        # This loop will go over the remains of the project() call -
        # over multiple lines if necessary - separating arguments and
        # end-of line comments and storing them. Double-quoted arguments
        # (even multi-line ones) are handled correctly. Note that the
        # use of extra "+" symbols following "+," "*," or "?" indicates
        # a "greedy" clause to prevent backtracking (e.g. in the case of
        # a dangling double-quote), so we match extra clauses
        # inappropriately.
        my $count = 0;
        while (1) {
          if ($line =~ s&^(?P<args>\s*+(?:(?:(?:"(?:[^"\\]++|\\.)*+")|(?:[^#")]+))[ \t]*+)*)(?:(?P<comments>[ \t]?#[^\n]*)?+(?P<nl>\n?+))?+&&s) {
            push(@{$proj_info->{args}}, sprintf("%s%s", $+{args} // '', $+{nl} // ''));
            push @{$proj_info->{comments}}, $+{comments} // '' unless $line;
          }
          last if ($line =~ m&^\s*\)& or not scalar @$buffer);
          $line = join("", $line, shift @$buffer);
        }
        error_exit("runaway trying to parse project() line in $filename?")
          unless $line =~ m&^\s*\)&;
        $proj_info->{post} = $line;
        # Now separate multiple arguments on each line. We process the
        # arguments in two passes like this in order to preserve the
        # correspondence between arguments and comments on the same
        # line.
        my @all_args =
          map { my $tmp = [];
                pos() = undef;
                my $endmatch = pos();
                while (m&\G[ 	]*(?P<arg>(?:[\n]++|(?:"(?:[^"\\]++|\\.)*+")|(?:[^\s)]+)))[ 	]*(?P<nl>[\n])?+&sg) {
                  last if ($endmatch // 0) == pos();
                  push @{$tmp}, sprintf("$+{arg}%s", $+{nl} // '');
                  $endmatch = pos();
                };
                error_exit("Leftovers: >", substr($_, $endmatch // 0), "<")
                  unless length() == ($endmatch // 0);
                $tmp;
              } @{$proj_info->{args}};
        my ($VERSION_next, $seen_version, $version_info, $seen_arg);
      all_args: foreach my $arg_group (@all_args) {
        arg_group: foreach my $arg (@$arg_group) {
            die "INTERNAL ERROR parsing project() argument line $arg"
              unless $arg =~ m&^(?P<q>"?+)(?P<v>.*?)\k{q}(?P<nl>[\n]++)?+$&s;
            unless ($seen_arg) {
              $seen_arg = 1;
              # Check first argument to see if we need to mitigate or
              # prevent an issue:
              if ($arg =~ m&^(v)?(?:\d+[_.]?)+&) {
                warning(sprintf("unexpected project() argument $arg looks like a \%sversion without the required VERSION keyword: mitigating", ($1 ? "UPS " : "")));
                $arg = to_cmake_version($arg);
                unshift @$arg_group, "VERSION";
                $VERSION_next = 1;
              } elsif (grep { $arg eq $_; } qw(NONE CXX C Fortran CUDA ISPC OBJC OBJCXX ASM)) {
                verbose "prefixing language $arg with LANGUAGES keyword in project().";
                unshift @$arg_group, "LANGUAGES";
                next;
              }
            }
            if ($VERSION_next) {
              $seen_version = \$arg;
              $version_info = { %+ };
              last all_args;
            }
            elsif ($+{v} eq "VERSION") {
              $VERSION_next = 1;
              next;
            }
          }
        }
        if ($pi->{version}) {
          my $piversion = to_cmake_version($pi->{version});
          if ($seen_version) {
            if ($piversion and $version_info->{v} ne $piversion) {
              my $msg = <<EOF;
CMake version in project() call ($version_info->{v}) does NOT match
UPS-style version in product_deps ($pi->{version} -> $piversion):
updating CMake version to $piversion (CMake version now governs)
EOF
              warning($msg);
              $$seen_version =
                sprintf("\%s$piversion\%s\%s",
                        ($version_info->{q} // '') x 2,
                        $version_info->{nl} // '');
            }
          } else {
            if ($proj_info->{pre} =~ m&^(.*?)([ 	]*+\n?+)$&) {
              $proj_info->{pre} =
                sprintf("\%s\%s", join(" ", $1, "VERSION", $piversion), $2 // '');
            }
          }
        }
        $fh->print("find_package(cetmodules $CETMODULES_VERSION REQUIRED)\n") unless
          $seen_find_package;
        $fh->print($proj_info->{pre},
                   join("  ", map({ my $l = join(" ", @$_);
                         my $r = shift @{$proj_info->{comments}};
                         if ($r) {
                           chomp $l;
                           join(" ", $l, "$r\n");
                         } else {
                           $l;
                         }
                       } @all_args)),
                   $proj_info->{post} // ());
        $project_done = 1;
        next;
      } elsif ($line =~ m&^\s*(?i:project)(?:\s*(?:#[^\n]*)\n?)*(?:\s*\((?:\s*(?:#[^\n]*)\n?)*)?$&s) {
        # Possibly the beginnings of a project call: add the next line
        # and check again.
        unshift @$buffer, join('', $line, shift @$buffer);
        next;
      } elsif ($line =~ m&^[^#]*\bcet_cmake_env\b&) {
        error_exit("unable to find a suitable project() call to update");
      }
    }
    if ($line =~ m&\s+###\s+MIGRATE-NO-ACTION\b$&) {
      $fh->print($line);
      next;
    }
    if ($line =~ m&^\s*(?i:find_(?P<find>package|ups_product))\s*\(\s*(?P<pkg>cet(?:buildtools|modules))\s+(?P<minv>(?P<minvMajor>\d+)[^\s)]+)?&) {
      if ($+{find} eq 'package' and $+{pkg} eq "cetmodules") {
        $line =~ m&^\s*find_package\s*\(\s*cetmodules(\s+[^1)]|\s*\))& or
          $line =~ s&^(\s*find_package\s*\(\s*cetmodules\s+)[^\s)]++(.*)$&${1}${CETMODULES_VERSION}${2}&;
        $seen_find_package = 1;
      } else {
        next; # We will provide one in the right place.
      }
    }
    $line =~ m&^\s*cet_cmake_config\s*\(\s*& and $seen_cet_cmake_config = 1;
    $line =~ s&^(\s*)cet_report_compiler_flags\s*\(\s*\)&${1}cet_report_compiler_flags(REPORT_THRESHOLD VERBOSE)&;
    $line =~ m&^\s*(?i:add_subdirectory)\s*\(\s*ups\b& and
      next; # No longer needed.
    if ($line =~ m&^\s*(?i:subdirs)\s*\($&) {
      flag_required($line, ": remove ups dir from args if present");
      flag_recommended($line, ": use add_subdirectory()");
      # Too hard to deal with automatically.
      my $msg = <<EOF;
ACTION REQUIRED -
ACTION REQUIRED - obsolete CMake command subdirs() command found: use add_subdirectory()
ACTION REQUIRED - instead, omitting "ups" if present
EOF
      warning($msg);
    }
    $line =~ m&^\s*(?i:include)\s*\(\s*UseCPack& and next;
    $fh->print($line);
  }
  if (scalar @shunt) {
    @$buffer = @shunt;
  } else {
    $fh->print("cet_cmake_config()\n")
      unless $seen_cet_cmake_config;
  }
  return ++$pass;
}

sub old_fix_cmake_one {
  my $pname = $pi->{name};
  my $seen_line1;
  while (my $line = <$in>) {
    if (not defined $seen_line1) {
      $seen_line1 = 1;
      if ($line =~ m&^###\s+MIGRATE-NO-ACTION\b&) {
        info("upgrading $filepath -> $filepath.new SKIPPED due to MIGRATE-NO-ACTION in line 1");
        $in->close();
        $out->close();
        system(qw(rm -f --), "$filename.new");
        return;
      }
    }
    if ($line =~ m&\s+###\s+MIGRATE-NO-ACTION\b$&) {
      $out->print($line);
      next;
    }
    while ($line =~ m&\$\{(?:\$\{product\}|\Q$pname\E)_([_\w]+)\}&g) {
      my $dirkey_ish = $1;
      my $dirkey_alt = join("", ($dirkey_ish =~ m&^(.*?)_*+(dir)$&));
      my ($var_stem) =
          map { ($dirkey_ish eq $_ or $dirkey_alt eq $_) ?
                  var_stem_for_dirkey($_) : (); } keys %$PATHSPEC_INFO;
      $line =~ s&(\$\{(?:\$\{product\}|\Q$pname\E)_\Q$dirkey_ish\E\})&\${\${CETMODULES_CURRENT_PROJECT_NAME}_$var_stem\}&g and
        pos($line) = 0 and
          verbose("$1 -> \${\${CETMODULES_CURRENT_PROJECT_NAME}_$var_stem}");
    }
    $line =~ s&\$\{gdml_install_dir\}&\${\${CETMODULES_CURRENT_PROJECT_NAME}_GDML_DIR}&g and
      verbose('${gdml_install_dir} -> ${${CETMODULES_CURRENT_PROJECT_NAME}_GDML_DIR}');
    flag_recommended($line, ": use add_subdirectory()")
      if ($line =~ m&^\s*(?i:subdirs)\s*\($&);
    flag_required($line, ": avoid using or changing CMAKE_INSTALL_PREFIX")
      if $line =~ m&\bCMAKE_INSTALL_PREFIX\b&;
    flag_required($line, ": remove")
      if $line =~ m&(\b(?:(?i:cetbuildtools)|CMAKE_MODULE_PATH\b).*)$&;
    flag_recommended($line, ": declare exportable CMake module directories with cet_cmake_module_directories()")
      if $line =~ m&\bCMAKE_MODULE_PATH\b.*SOURCE_DIR$&;
    flag_recommended($line, ": use find_package() to handle external modules directories")
      if $line =~ m&\bCMAKE_MODULE_PATH\b.*\$ENV$&;
    $line =~ s&(\$\{product\}/\${version\}/)&&g and verbose("\${product}/\${version}/ -> \"\"");
    $line =~ s&(\$\{flavorqual(?:_dir)?\})&\${\${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}&g and
      verbose("$1 -> \"\${\${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}\"");
    $line =~ s&(\$\{product\})&\${CETMODULES_CURRENT_PROJECT_NAME}&g and
      verbose("$1 -> \"\${CETMODULES_CURRENT_PROJECT_NAME}\"");
    $line =~ s&(\$\{version\})&\${CETMODULES_CURRENT_PROJECT_VERSION}&g and
      verbose("$1 -> \"\${CETMODULES_CURRENT_PROJECT_VERSION}\"");
    while ($line =~ m&\G.*?\b(?P<clause>find_package\b\s*\(\s*(?P<pkg>[^\s)"]+))&g) {
      my $safe_pos = pos($line);
      $+{pkg} ne 'cetmodules' and
        $line =~ s&\b(\Q$+{clause}\E)&cet_$1& and
          pos($line) = $safe_pos + length('cet_') and
            verbose("$1... -> cet_$1...");
    }
    flag_recommended($line, ": use target_link_directories() with target semantics")
      if $line =~ m&\binclude_directories\b&;
    flag_recommended($line, ": use target_compile_definitions()")
      if $line =~ m&\badd(?:_compile)_definitions\b&;
    flag_recommended($line, ": use target_add_definitions()")
      if $line =~ m&\badd(?:_compile)_definitions\b&;
    flag_recommended($line, ": use target_add_definitions() with -U")
      if $line =~ m&\bremove_definitions\b&;
    flag_recommended($line, ": use target_link_libraries() with target semantics")
      if $line =~ m&\blink_(?:libraries|directories)\b&;
    flag_recommended($line, ": use target_link_options()")
      if $line =~ m&\badd_link_options\b&;
    flag_recommended($line, ": use target_add_definitions() with -U")
      if $line =~ m&\bremove_definitions\b&;
    flag_recommended($line, ": use of $1... may be UPS-dependent")
      if $line =~ m&\b(\$ENV\{|ENV\s)&;
    flag_recommended($line, ": use cet_find_package() with target semantics for linking")
      if $line =~ m&\b(find_ups_product|(?:cet_)find_library)\b&;
    flag_recommended($line, ": use cet_test()")
      if $line =~ m&\b(add_test)\b&;
    flag_recommended($line, ": use art_make_library(), art_dictionary(), simple_plugin() with explicit source lists")
      if $line =~ m&\b(art_make\b)&;
    flag_recommended($line, ": use cet_make_library(), build_dictionary(), basic_plugin() with explicit source lists")
      if $line =~ m&\b(cet_make\b)&;
    $out->print($line);
  }
  $in->close();
  $out->close();
  if ($options->{"dry-run"}) {
    notify("dry run: proposed edits / annotations in $filepath.new");
  } else {
    info("installing $filepath.new as $filepath");
    move("$filename.new", "$filename") or
      error_exit("unable to install $filepath.new as $filepath");
  }
}
