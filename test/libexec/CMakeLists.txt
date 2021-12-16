####################################
# Check Perl programs and modules.

set(PERL_TEST_SCRIPTS
  ${CMAKE_CURRENT_SOURCE_DIR}/parse_version_string_t
  ${CMAKE_CURRENT_SOURCE_DIR}/quote_handling_t
  ${CMAKE_CURRENT_SOURCE_DIR}/shortest_unique_prefix_t
  )

set(PERL_FILES
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Util.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Util/LintWarn.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Util/VariableSaver.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/CMake/Util.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/CMake/CommandInfo.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/UPS/ProductDeps.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/UPS/Setup.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/CMake.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Migrate/Util.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Migrate/CMake/Tagging.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Migrate/CMake/Handlers.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Migrate/CMake.pm
  ${PROJECT_SOURCE_DIR}/libexec/Cetmodules/Migrate/ProductDeps.pm
  ${PROJECT_SOURCE_DIR}/libexec/set_dev_products
  ${PROJECT_SOURCE_DIR}/tools/migrate
  ${PERL_TEST_SCRIPTS}
  ${PROJECT_SOURCE_DIR}/test/Modules/version_cmp-cmake_t
  )

execute_process(COMMAND perl -MO=Lint INPUT_FILE /dev/null
  OUTPUT_QUIET ERROR_QUIET
  RESULTS_VARIABLE CHECK_BLint)
if (CHECK_BLint EQUAL 0)
  set(HAVE_BLint TRUE)
else()
  set(HAVE_BLint FALSE)
endif()

find_program(PERLCRITIC NAMES perlcritic)
if (PERLCRITIC)
  set(BLINT_IS_FIXTURE TRUE)
else()
  unset(BLINT_IS_FIXTURE)
endif()

##################
# B::Lint.
if (HAVE_BLint)
  set(lintwarn_t Cetmodules::Util::LintWarn_Blint)
  string(JOIN ":" p5lib "${PROJECT_BINARY_DIR}/libexec" "${PROJECT_SOURCE_DIR}/libexec" $ENV{PERL5LIB} "")
  foreach(pfut IN LISTS PERL_FILES)
    if (pfut MATCHES "(^|/)Cetmodules/Util/LintWarn\.pm$")
      set(pfut_t ${lintwarn_t})
      set(lintwarn_opts "-Mwarnings FATAL => qw(all)")
      unset(REQ_LINTWARN)
    else()
      string(MAKE_C_IDENTIFIER "${pfut}_BLint" pfut_t)
      set(lintwarn_opts -MCetmodules::Util::LintWarn)
      set(REQ_LINTWARN TRUE)
    endif()
    add_test(NAME ${pfut_t}
      COMMAND perl
      ${lintwarn_opts}
      -MO=Lint,all,no-implicit-read,no-implicit-write,no-dollar-underscore
      "${pfut}"
      )
    set_tests_properties(${pfut_t} PROPERTIES
      ENVIRONMENT "PERL5LIB=${p5lib}"
      LABELS "DEFAULT;RELEASE"
      )
    if (BLINT_IS_FIXTURE OR NOT REQ_LINTWARN)
      set_property(TEST ${pfut_t}
        PROPERTY FIXTURES_SETUP ${pfut_t}
        )
    endif()
    if (REQ_LINTWARN)
      set_property(TEST ${pfut_t}
        PROPERTY FIXTURES_REQUIRED ${lintwarn_t}
        )
    endif()
  endforeach()
endif()

##################
# perlcritic

if (PERLCRITIC)
  # Run perlcritic with decreasing tolerance for each file in turn; a
  # lower tolerance test for a given file will not be run if a higher
  # tolerance test failed, allowing the failed test's identity to denote
  # the severity level of any failed perlcritic criteria.
  set(PERLCRITIC_COMMAND perlcritic --color --verbose=8)
  set(PERLCRITIC_THEMES_EXP "\
(
  ( bangs
  + bugs
  + certrec
  + certrule
  + compatibility
  + complexity
  + core
  + cosmetic
  + editor
  + efficiency
  + maintenance
  + moose
  + pbp
  + performance
  + portability
  + readability
  + roles
  + security
  + storable
  + tests
  + unicode
  )
  -
  ( JTRAMMELL
  + danger
  + itch
  + lax
  + nits
  + notrecommended
  + petpeeves
  + pulp
  + risky
  + strictersubs
  + swift
  + tics
  )
)
*
( ! more ) \
")
  if (NOT "${PERLCRITIC_THEMES_EXP}" STREQUAL "")
    string(REGEX REPLACE "[ \t\n]+" "" PERLCRITIC_THEMES_EXP
      "${PERLCRITIC_THEMES_EXP}")
    list(APPEND PERLCRITIC_COMMAND --theme "(${PERLCRITIC_THEMES_EXP})")
  endif()
  list(APPEND PERLCRITIC_COMMAND --exclude "\\bBangs::ProhibitCommentedOutCode\$"
    --exclude "\\bMiscellanea::ProhibitUselessNoCritic\$")
  list(APPEND PERLCRITIC_COMMAND --statistics)
  set(MAX_SEV 5)
  set(MIN_SEV 2)
  foreach (pfut IN LISTS PERL_FILES)
    set(last_sev)
    # Use a .perlcriticrc file in the same directory as the file under
    # test, if such exists.
    cmake_path(REPLACE_FILENAME pfut .perlcriticrc OUTPUT_VARIABLE rcfile)
    if (EXISTS "${rcfile}")
      set(rc_args -p "${rcfile}")
    else()
      set(rc_args)
    endif()
    if (HAVE_BLint)
      string(MAKE_C_IDENTIFIER "${pfut}_BLint" pfut_BLint)
    endif()
    set(sev ${MAX_SEV})
    while (NOT MIN_SEV GREATER sev)
      string(MAKE_C_IDENTIFIER "${pfut}_perlcritic_${sev}" pfut_t)
      add_test(NAME ${pfut_t}
        COMMAND ${PERLCRITIC_COMMAND} --severity ${sev} ${rc_args} "${pfut}"
        )
      if (HAVE_BLint)
        set_property(TEST ${pfut_t} PROPERTY FIXTURES_REQUIRED ${pfut_BLint})
      endif()
      set_tests_properties(${pfut_t} PROPERTIES
        FIXTURES_SETUP ${pfut_t}
        LABELS "DEFAULT;RELEASE")
      if (last_sev)
        set_property(TEST ${pfut_t} APPEND PROPERTY FIXTURES_REQUIRED ${last_sev})
      endif()
      set(last_sev "${pfut_t}")
      math(EXPR sev "${sev} - 1")
    endwhile()
  endforeach()
endif()

foreach (ptest IN LISTS PERL_TEST_SCRIPTS)
  cmake_path(GET ptest FILENAME ptest_stem)
  string(MAKE_C_IDENTIFIER "${ptest_stem}" ptest_stem)
  string(MAKE_C_IDENTIFIER "${ptest}" full_ptest_stem)
  add_test(NAME perl-${ptest_stem} COMMAND ${ptest})
  if (MIN_SEV)
    set_property(TEST perl-${ptest_stem} PROPERTY FIXTURES_REQUIRED ${full_ptest_stem}_perlcritic_${MIN_SEV})
  elseif (HAVE_BLint)
    set_property(TEST perl-${ptest_stem} PROPERTY FIXTURES_REQUIRED ${full_ptest_stem}_BLint)
  endif()
  set_tests_properties(perl-${ptest_stem} PROPERTIES LABELS "DEFAULT;RELEASE")
endforeach()

