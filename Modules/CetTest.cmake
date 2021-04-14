#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# cet_test: specify tests in a concise and transparent way (see also
#           cet_test_env() and cet_test_assertion(), below).
#
# Usage: cet_test(target [<options>] [<args>])
#
####################################
# Target category options (specify at most one):
#
# HANDBUILT
#
#   Do not build the target -- it will be provided.
#
# PREBUILT
#
#   Do not build the target -- copy in from the source dir (ideal for
#   e.g. scripts).
#
# USE_CATCH2_MAIN
#
#   This test will use the Catch test framework
#   (https://github.com/philsquared/Catch). The specified target will be
#   built from a precompiled main program to run tests described in the
#   files specified by SOURCES.
#
#   N.B.: if you wish to use the ParseAndAddCatchTests() facility
#   contributed to the Catch system, you should specify NO_AUTO to avoid
#   generating a, "standard" test. Note also that you may have your own
#   test executables using Catch without using USE_CATCH2_MAIN. However,
#   be aware that the compilation of a Catch main is quite expensive,
#   and any tests that *do* use this option will all share the same
#   compiled main.
#
#   Note also that client packages are responsible for making sure Catch
#   is available, such as with:
#
#     catch		<version>		-nq-	only_for_build
#
#   in product_deps.
#
####################################
# Other options:
#
# CONFIGURATIONS <config>+
#
#   Configurations (Debug, etc, etc) under which the test shall be
#   executed.
#
# DATAFILES <datafile>+
#
#   Input and/or references files to be copied to the test area in the
#   build tree for use by the test. If there is no path, or a relative
#   path, the file is assumed to be in or under
#   ${CMAKE_CURRENT_SOURCE_DIR}.
#
# DEPENDENCIES <dep>+
#
#   List of top-level dependencies to consider for a PREBUILT
#   target. Top-level implies a target (not file) created with
#   ADD_EXECUTABLE, ADD_LIBRARY or ADD_CUSTOM_TARGET.
#
# DIRTY_WORKDIR
#
#   If set, the working directory will not be cleared prior to execution
#   of the test.
#
# INSTALL_BIN
#
#   Install this test's script / exec in the product's binary directory
#   (ignored for HANDBUILT).
#
# INSTALL_EXAMPLE
#
#   Install this test and all its data files into the examples area of
#   the product.
#
# INSTALL_SOURCE
#
#   Install this test's source in the source area of the product.
#
# LIBRARIES <lib>+
#
#   Extra libraries with which to link this target.
#
# NO_AUTO
#
#   Do not add the target to the auto test list. N.B. all options
#   related to the declaration of tests and setting of properties
#   thereof will be ignored.
#
# OPTIONAL_GROUPS <group>+
#
#   Assign this test to one or more named optional groups (a.k.a CMake
#   test labels). If ctest is executed specifying labels, then matching
#   tests will be executed.
#
# PARG_<label> <opt>[=] <args>+
#
#   Specify a permuted argument (multiple permitted with different
#   <label>). This allows the creation of multiple tests with arguments
#   from a set of permutations.
#
#   Labels must be unique, valid CMake identifiers. Duplicated labels
#   will cause an error.
#
#   If multiple PARG_XXX arguments are specified, then they are combined
#   linearly, with shorter permutation lists being repeated cyclically.
#
#   If the '=' is specified, then the argument lists for successive test
#   iterations will get <opt>=v1, <opt>=v2, etc., otherwise it will be
#   <opt> v1, <opt> v2, ...
#
#   Target names will have _<num> appended, where num is zero-padded to
#   give the same number of digits for each target within the set.
#
#   Permuted arguments will be placed before any specifed TEST_ARGS in
#   the order the PARG_<label> arguments were specified to cet_test().
#
#   There is no support for non-option argument toggling as yet, but
#   addition of such support should be straightforward should the use
#   case arise.
#
# REF <ref-file>
#
#  The standard output of the test will be captured and compared against
#   the specified reference file. It is an error to specify this
#   argument and either the PASS_REGULAR_EXPRESSION or
#   FAIL_REGULAR_EXPRESSION test properties to the TEST_PROPERTIES
#   argument: success is the logical AND of the exit code from execution
#   of the test as originally specified, and the success of the
#   filtering and subsequent comparison of the output (and optionally,
#   the error stream). Optionally, a second element may be specified
#   representing a reference for the error stream; otherwise, standard
#   error will be ignored.
#
#   If REF is specified, then OUTPUT_FILTERS may also be specified
#   (OUTPUT_FILTER and optionally OUTPUT_FILTER_ARGS will be accepted in
#   the alternative for historical reasons). OUTPUT_FILTER must be a
#   program which expects input on STDIN and puts the filtered output on
#   STDOUT. OUTPUT_FILTERS should be a list of filters expecting input
#   on STDIN and putting output on STDOUT. If DEFAULT is specified as a
#   filter, it will be replaced at that point in the list of filters by
#   appropriate defaults. Examples:
#
#     OUTPUT_FILTERS "filterA -x -y \"arg with spaces\"" filterB
#
#     OUTPUT_FILTERS filterA DEFAULT filterB
#
# REMOVE_ON_FAILURE <file>+
#
#   Upon TEST_EXEC failure, these files and/or directories shall be
#   removed if they exist.
#
# REQUIRED_FILES <file>+
#
#   These files are required to be present before the test will be
#   executed. If any are missing, ctest will record NOT RUN for this
#   test.
#
# *SAN_OPTIONS
#
#   Option representing the desired value of the corresponding sanitizer
#   control environment variable for the test.
#
# SCOPED
#
#   Test (but not script or compiled executable) target names will be
#   scoped by product name (<prod>:...).
#
# SOURCE[S] <source>+
#
#   Sources to use to build the target (default is ${target}.cc).
#
# TEST_ARGS <arg>+
#
#   Any arguments to the test to be run.
#
# TEST_EXEC <exec>
#
#   The exec to run (if not the target). The HANDBUILT option must be
#   specified in conjunction with this option.
#
# TEST_PROPERTIES <PROP val>+
#
#   Properties to be added to the test. See documentation of the cmake
#   command, "set_tests_properties."
#
# TEST_WORKDIR <dir>
#
#   Test to execute (and support files to be copied to) <dir>. If not
#   specified, ${CMAKE_CURRENT_BINARY_DIR}/<target>.d will be created
#   and used. If relative or not qualified, <dir> is assumed to be
#   releative to ${CMAKE_CURRENT_BINARY_DIR}.
#
# USE_BOOST_UNIT
#
#   This test uses the Boost Unit Test Framework.
#
####################################
# Cached variables.
#
# CET_DEFINED_TEST_GROUPS
#   Any test group names CMake sees will be added to this list.
#
####################################
# Notes:
#
# * cet_make_exec() and art_make_exec() are more flexible than building
#   the test exec with cet_test(), and are generally to be preferred
#   (use the NO_INSTALL option to same as appropriate). Use
#   cet_test(... HANDBUILT TEST_EXEC ...) to use test execs built this
#   way.
#
# * The CMake properties PASS_REGULAR_EXPRESSION and
#   FAIL_REGULAR_EXPRESSION are incompatible with the REF option, but we
#   cannot check for them if you use CMake's add_tests_properties()
#   rather than cet_test(CET_TEST_PROPERTIES ...).
#
# * If you intend to set the property SKIP_RETURN_CODE, you should use
#   CET_TEST_PROPERTIES to set it rather than add_tests_properties(), as
#   cet_test() needs to take account of your preference.
#
########################################################################

########################################################################
# cet_test_env: set environment for all tests here specified.
#
# Usage: cet_test_env([<options] [<env>])
#
####################################
# Options:
#
# CLEAR
#   Clear the global test environment (ie anything previously set with
#    cet_test_env()) before setting <env>.
#
####################################
# Notes:
#
# * <env> may be omitted. If so and the CLEAR option is not specified,
#   then cet_test_env() is a NOP.
#
# * If cet_test_env() is called in a directory to set the environment
#   for tests then that will be propagated to tests defined in
#   subdirectories unless cet_test_env(CLEAR ...) is invoked in that
#   directory.
#
########################################################################

########################################################################
# cet_test_assertion: require assertion failure on given condition
#
# Usage: cet_test_assertion(CONDITION TARGET...)
#
####################################
# Notes:
#
# * CONDITION should be a CMake regex which should have any escaped
#   items doubly-escaped due to being passed as a string argument
#   (e.g. "\\\\(" for a literal open-parenthesis, "\\\\." for a literal
#   period).
#
# * TARGET...: the name(s) of the test target(s) as specified to
#   cet_test() or add_test() -- require at least one.
#
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.19 FATAL_ERROR)

# Copy function.
include(CetCopy)
# Need cet_script for PREBUILT scripts
include(CetMake)
# To ascertain the current subdirectory within a package.
include(CetPackagePath)
# May need to escape a string to avoid misinterpretation as regex
include(CetRegexEscape)

##################
# Programs and Modules

# Default comparator
set(CET_RUNANDCOMPARE "${CMAKE_CURRENT_LIST_DIR}/RunAndCompare.cmake")

# Test run wrapper
set(CET_TEST_WRAPPER cetmodules::cet_exec_test)

# Properties
define_property(TEST PROPERTY KEYWORDS
  BRIEF_DOCS "Keywords describing the test engine used, test type, etc."
  FULL_DOCS "ETHEL")
##################

function(_update_defined_test_groups)
  set(TMP_LIST ${CET_DEFINED_TEST_GROUPS} ${ARGN})
  list(REMOVE_DUPLICATES TMP_LIST)
  set(CET_DEFINED_TEST_GROUPS ${TMP_LIST}
    CACHE STRING "List of defined test groups."
    FORCE
    )
endfunction()

function(_cet_process_pargs NTEST_VAR)
  set(NTESTS 1)
  foreach (label IN LISTS ARGN)
    list(LENGTH CETP_PARG_${label} ${label}_length)
    math(EXPR ${label}_length "${${label}_length} - 1")
    if (NOT ${label}_length)
      message(FATAL_ERROR "For test ${TEST_TARGET_NAME}: Permuted options are not yet supported.")
    endif()
    if (${label}_length GREATER NTESTS)
      set(NTESTS ${${label}_length})
    endif()
    list(GET CETP_PARG_${label} 0 ${label}_arg)
    set(${label}_arg ${${label}_arg} PARENT_SCOPE)
    list(REMOVE_AT CETP_PARG_${label} 0)
    set(CETP_PARG_${label} ${CETP_PARG_${label}} PARENT_SCOPE)
    set(${label}_length ${${label}_length} PARENT_SCOPE)
  endforeach()
  foreach (label IN LISTS ARGN)
    if (${label}_length LESS NTESTS)
      # Need to pad
      math(EXPR nextra "${NTESTS} - ${${label}_length}")
      set(nind 0)
      while (nextra)
        math(EXPR lind "${nind} % ${${label}_length}")
        list(GET CETP_PARG_${label} ${lind} item)
        list(APPEND CETP_PARG_${label} ${item})
        math(EXPR nextra "${nextra} - 1")
        math(EXPR nind "${nind} + 1")
      endwhile()
      set(CETP_PARG_${label} ${CETP_PARG_${label}} PARENT_SCOPE)
    endif()
  endforeach()
  set(${NTEST_VAR} ${NTESTS} PARENT_SCOPE)
endfunction()

function(_cet_print_pargs)
  string(TOUPPER "${CMAKE_BUILD_TYPE}" BTYPE_UC)
  if (NOT BTYPE_UC STREQUAL "DEBUG")
    return()
  endif()
  list(LENGTH ARGN nlabels)
  if (NOT nlabels)
    return()
  endif()
  message(STATUS "Test ${TEST_TARGET_NAME}: found ${nlabels} labels for permuted test arguments")
  foreach (label IN LISTS ARGN)
    message(STATUS "  Label: ${label}, arg: ${${label}_arg}, # vals: ${${label}_length}, vals: ${CETP_PARG_${label}}")
  endforeach()
  message(STATUS "  Calculated ${NTESTS} tests")
endfunction()

function(_cet_test_pargs VAR)
  foreach (label IN LISTS parg_labels)
    list(GET CETP_PARG_${label} ${tid} arg)
    if (${label}_arg MATCHES [[=$]])
      list(APPEND test_args "${${label}_arg}${arg}")
    else()
      list(APPEND test_args "${${label}_arg}" "${arg}")
    endif()
  endforeach()
  set(${VAR} ${test_args} ${ARGN} PARENT_SCOPE)
endfunction()

function(_cet_add_test_detail TNAME TEXEC TEST_WORKDIR)
  _cet_test_pargs(test_args ${ARGN})
  add_test(NAME "${TNAME}"
    CONFIGURATIONS ${CET_CONFIGURATIONS}
    COMMAND
    ${CET_TEST_WRAPPER} --wd ${TEST_WORKDIR}
    --remove-on-failure "${CET_REMOVE_ON_FAILURE}"
    --required-files "${CET_REQUIRED_FILES}"
    --datafiles "${CET_DATAFILES}" ${CET_DIRTY_WORKDIR}
    --skip-return-code ${skip_return_code}
    ${TEXEC} ${test_args})
  _cet_add_test_properties(${TNAME} ${TEXEC})
endfunction()

function(_cet_exec_location LOC_VAR)
  list(POP_FRONT ARGN EXEC)
  if (TARGET "${EXEC}")
    get_property(target_type TARGET ${EXEC} PROPERTY TYPE)
    if (target_type STREQUAL "EXECUTABLE")
      set(EXEC "$<TARGET_FILE:${EXEC}>")
    else()
      get_property(imported TARGET ${EXEC} PROPERTY IMPORTED)
      if (imported)
        set(EXEC "$<TARGET_PROPERTY:${EXEC},IMPORTED_LOCATION>")
      else()
        get_property(exec_location TARGET ${EXEC} PROPERTY CET_EXEC_LOCATION)
        if (exec_location)
          set(EXEC "${exec_location}")
        endif()
      endif()
    endif()
  endif()
  set(${LOC_VAR} "${EXEC}" PARENT_SCOPE)
endfunction()

function(_cet_add_test)
  _cet_exec_location(TEXEC ${CET_TEST_EXEC})
  if (${NTESTS} EQUAL 1)
    _cet_add_test_detail(${TEST_TARGET_NAME} ${TEXEC} ${CET_TEST_WORKDIR} ${ARGN})
    list(APPEND ALL_TEST_TARGETS ${TEST_TARGET_NAME})
    file(MAKE_DIRECTORY "${CET_TEST_WORKDIR}")
    set_tests_properties(${TEST_TARGET_NAME} PROPERTIES WORKING_DIRECTORY ${CET_TEST_WORKDIR})
    cet_copy(${CET_DATAFILES} DESTINATION ${CET_TEST_WORKDIR} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  else()
    math(EXPR tidmax "${NTESTS} - 1")
    string(LENGTH "${tidmax}" nd)
    foreach (tid RANGE ${tidmax})
      execute_process(COMMAND printf "_%0${nd}d" ${tid}
        OUTPUT_VARIABLE tnum
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )
      set(tname "${TEST_TARGET_NAME}${tnum}")
      string(REGEX REPLACE [[\.d$]] "${tnum}.d" test_workdir "${CET_TEST_WORKDIR}")
      _cet_add_test_detail(${tname} ${TEXEC} ${test_workdir} ${ARGN})
      list(APPEND ALL_TEST_TARGETS ${tname})
      file(MAKE_DIRECTORY "${test_workdir}")
      set_tests_properties(${tname} PROPERTIES WORKING_DIRECTORY ${test_workdir})
      cet_copy(${CET_DATAFILES} DESTINATION ${test_workdir} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    endforeach()
  endif()
  set(ALL_TEST_TARGETS ${ALL_TEST_TARGETS} PARENT_SCOPE)
endfunction()

function(_cet_add_ref_test_detail TNAME TEST_WORKDIR)
  _cet_test_pargs(tmp_args ${ARGN})
  separate_arguments(test_args UNIX_COMMAND "${tmp_args}")
  cet_localize_pv(cetmodules LIBEXEC_DIR)
  add_test(NAME "${TNAME}"
    CONFIGURATIONS ${CET_CONFIGURATIONS}
    COMMAND ${CET_TEST_WRAPPER} --wd ${TEST_WORKDIR}
    --remove-on-failure "${CET_REMOVE_ON_FAILURE}"
    --required-files "${CET_REQUIRED_FILES}"
    --datafiles "${CET_DATAFILES}" ${CET_DIRTY_WORKDIR}
    --skip-return-code ${skip_return_code}
    ${CMAKE_COMMAND}
    -DTEST_EXEC=${CET_TEST_EXEC}
    -DTEST_ARGS=${test_args}
    -DTEST_REF=${OUTPUT_REF}
    ${DEFINE_ERROR_REF}
    ${DEFINE_TEST_ERR}
    -DTEST_OUT=${CET_TARGET}.out
    ${DEFINE_OUTPUT_FILTER} ${DEFINE_OUTPUT_FILTER_ARGS} ${DEFINE_OUTPUT_FILTERS}
    -Dcetmodules_LIBEXEC_DIR=${cetmodules_LIBEXEC_DIR}
    -P ${CET_RUNANDCOMPARE}
    )
endfunction()

function(_cet_add_ref_test)
  if (${NTESTS} EQUAL 1)
    _cet_add_ref_test_detail(${TEST_TARGET_NAME} ${CET_TEST_WORKDIR} ${ARGN})
    list(APPEND ALL_TEST_TARGETS ${TEST_TARGET_NAME})
    file(MAKE_DIRECTORY "${CET_TEST_WORKDIR}")
    set_tests_properties(${TEST_TARGET_NAME} PROPERTIES WORKING_DIRECTORY ${CET_TEST_WORKDIR})
    cet_copy(${CET_DATAFILES} DESTINATION ${CET_TEST_WORKDIR} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  else()
    math(EXPR tidmax "${NTESTS} - 1")
    string(LENGTH "${tidmax}" nd)
    foreach (tid RANGE ${tidmax})
      execute_process(COMMAND printf "_%0${nd}d" ${tid}
        OUTPUT_VARIABLE tnum
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )
      set(tname "${TEST_TARGET_NAME}${tnum}")
      string(REGEX REPLACE [[\.d$]] "${tnum}.d" test_workdir "${CET_TEST_WORKDIR}")
      _cet_add_ref_test_detail(${tname} ${test_workdir} ${ARGN})
      list(APPEND ALL_TEST_TARGETS ${tname})
      file(MAKE_DIRECTORY "${test_workdir}")
      set_tests_properties(${tname} PROPERTIES WORKING_DIRECTORY ${test_workdir})
      if (CET_DATAFILES)
        cet_copy(${CET_DATAFILES} DESTINATION ${test_workdir} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
      endif()
    endforeach()
  endif()
  set(ALL_TEST_TARGETS ${ALL_TEST_TARGETS} PARENT_SCOPE)
endfunction()

####################################
# Main function definitions.
function(cet_test_env)
  cmake_parse_arguments(PARSE_ARGV 0 CET_TEST "CLEAR" "" "")
  if (CET_TEST_CLEAR)
    set(CET_TEST_ENV)
  endif()
  list(APPEND CET_TEST_ENV "${CET_TEST_UNPARSED_ARGUMENTS}")
  set(CET_TEST_ENV "${CET_TEST_ENV}" PARENT_SCOPE)
endfunction()

function(cet_test CET_TARGET)
  if (NOT BUILD_TESTING) # See CMake's CTest module.
    return()
  endif()
  # Parse arguments.
  if (CET_TARGET MATCHES /)
    message(FATAL_ERROR "${CET_TARGET} should not be a path. Use a simple "
      "target name with the HANDBUILT and TEST_EXEC options instead.")
  endif()
  cmake_parse_arguments(PARSE_ARGV 1 CET
    "DIRTY_WORKDIR;HANDBUILT;INSTALL_BIN;INSTALL_EXAMPLE;INSTALL_SOURCE;NO_AUTO;NO_EXPORT;NO_OPTIONAL_GROUPS;PREBUILT;SCOPED;USE_BOOST_UNIT;USE_CATCH2_MAIN;USE_CATCH_MAIN"
    "EXPORT_SET;OUTPUT_FILTER;TEST_EXEC;TEST_WORKDIR"
    "CONFIGURATIONS;DATAFILES;DEPENDENCIES;LIBRARIES;OPTIONAL_GROUPS;OUTPUT_FILTERS;OUTPUT_FILTER_ARGS;REF;REMOVE_ON_FAILURE;REQUIRED_FILES;SOURCE;SOURCES;TEST_ARGS;TEST_PROPERTIES")
  if (CET_OUTPUT_FILTERS AND CET_OUTPUT_FILTER_ARGS)
    message(FATAL_ERROR "OUTPUT_FILTERS is incompatible with FILTER_ARGS:\nEither use the singular OUTPUT_FILTER or use double-quoted strings in OUTPUT_FILTERS\nE.g. OUTPUT_FILTERS \"filter1 -x -y\" \"filter2 -y -z\"")
  endif()

  # CET_SOURCES is obsolete.
  if (CET_SOURCES)
    warn_deprecated("cet_test(): SOURCES" NEW "SOURCE")
    list(APPEND CET_SOURCE ${CET_SOURCES})
    unset(CET_SOURCES)
  endif()

  # CET_USE_CATCH_MAIN is obsolete.
  if (CET_USE_CATCH_MAIN)
    warn_deprecated("cet_test(): USE_CATCH_MAIN" NEW "USE_CATCH2_MAIN")
    set(CET_USE_CATCH2_MAIN TRUE)
    unset(CET_USE_CATCH_MAIN)
  endif()

  # For passthrough to cet_script, cet_make_exec, etc.
  set(exec_install_args EXPORT_SET ${CET_EXPORT_SET} NOP)
  if (NOT CET_INSTALL_BIN)
    list(APPEND exec_install_args NO_INSTALL)
  endif()
  cet_passthrough(FLAG APPEND CET_NO_EXPORT exec_install_args)

  # Find any arguments related to permuted test arguments.
  foreach (OPT IN LISTS CET_UNPARSED_ARGUMENTS)
    if (OPT MATCHES [[^PARG_([A-Za-z_][A-Za-z0-9_]*)$]])
      if (OPT IN_LIST parg_option_names)
        message(SEND_ERROR "For test ${TEST_TARGET_NAME}, permuted argument label ${CMAKE_MATCH_1} specified multiple times.")
      endif()
      list(APPEND parg_option_names "${OPT}")
      list(APPEND parg_labels "${CMAKE_MATCH_1}")
    elseif (OPT MATCHES [[SAN_OPTIONS$]])
      if (OPT IN_LIST san_option_names)
        message(FATAL_ERROR "For test ${TEST_TARGET_NAME}, ${OPT} specified multiple times")
      endif()
      list(APPEND san_option_names "${OPT}")
    endif()
  endforeach()
  set(cetp_list_options PERMUTE_OPTS ${parg_option_names})
  set(cetp_onearg_options PERMUTE ${san_option_names})
  cmake_parse_arguments(CETP ""
    "${cetp_onearg_options}"
    "${cetp_list_options}"
    "${CET_UNPARSED_ARGUMENTS}")
  if (CETP_PERMUTE)
    message(FATAL_ERROR "PERMUTE is a keyword reserved for future functionality.")
  elseif (CETP_PERMUTE_OPTS)
    message(FATAL_ERROR "PERMUTE_OPTS is a keyword reserved for future functionality.")
  endif()
  list(LENGTH parg_labels NPARG_LABELS)
  _cet_process_pargs(NTESTS "${parg_labels}")
  if (CETP_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "cet_test: Unparsed (non-option) arguments detected: \"${CETP_UNPARSED_ARGUMENTS}.\" Check for missing keyword(s) in the definition of test ${CET_TARGET} in your CMakeLists.txt.")
  endif()

  if (CET_TEST_EXEC)
    if (NOT CET_HANDBUILT)
      message(FATAL_ERROR "cet_test: target ${CET_TARGET} cannot specify "
        "TEST_EXEC without HANDBUILT")
    endif()
  else()
    set(CET_TEST_EXEC ${CET_TARGET})
  endif()
  if ((CET_HANDBUILT AND CET_PREBUILT) OR
      (CET_HANDBUILT AND CET_USE_CATCH2_MAIN) OR
      (CET_PREBUILT AND CET_USE_CATCH2_MAIN))
    # CET_HANDBUILT, CET_PREBUILT and CET_USE_CATCH2_MAIN are mutually exclusive.
    message(FATAL_ERROR "cet_test: target ${CET_TARGET} must have only one of the"
      " CET_HANDBUILT, CET_PREBUILT, or CET_USE_CATCH2_MAIN options set.")
  elseif (CET_PREBUILT) # eg scripts.
    cet_script(${CET_TARGET} ${exec_install_args} DEPENDENCIES ${CET_DEPENDENCIES})
  elseif (NOT CET_HANDBUILT) # Normal build, possibly with CET_USE_CATCH2_MAIN set.
    # Build the executable.
    if (NOT CET_SOURCE) # Useful default.
      set(CET_SOURCE ${CET_TARGET}.cc)
    endif()
    cet_passthrough(FLAG IN_PLACE CET_USE_BOOST_UNIT)
    cet_passthrough(FLAG IN_PLACE CET_USE_CATCH2_MAIN)
    cet_make_exec(NAME ${CET_TARGET} ${exec_install_args}
      ${CET_USE_BOOST_UNIT} ${CET_USE_CATCH2_MAIN}
      SOURCE ${CET_SOURCE} LIBRARIES ${CET_LIBRARIES})
  endif()

  if (NOT CET_NO_AUTO)
    # If GLOBAL is not set, prepend ${CETMODULES_CURRENT_PROJECT_NAME}: to the target name
    if (CET_SCOPED)
      set(TEST_TARGET_NAME "${CETMODULES_CURRENT_PROJECT_NAME}:${CET_TARGET}")
    else()
      set(TEST_TARGET_NAME "${CET_TARGET}")
    endif()

    # For which configurations should this test (set) be valid?
    # Print configured permuted arguments.
    _cet_print_pargs("${parg_labels}")

    # Set up to handle a per-test work directory for parallel testing.
    if (IS_ABSOLUTE "${CET_TEST_WORKDIR}")
      cet_package_path(source_path_subdir PATH "${CET_TEST_WORKDIR}" SOURCE)
      if (source_path_subdir) # Be careful in source tree.
        if (NOT IS_DIRECTORY "${CET_TEST_WORKDIR}")
          message(SEND_ERROR "Refusing to create working directory ${CET_TEST_WORKDIR} in source tree")
        endif()
        set(CET_DIRTY_WORKDIR TRUE)
      endif()
    else()
      if (NOT CET_TEST_WORKDIR)
        set(CET_TEST_WORKDIR "${CET_TARGET}.d")
      endif()
      get_filename_component(CET_TEST_WORKDIR "${CET_TEST_WORKDIR}"
        ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    endif()
    file(MAKE_DIRECTORY "${CET_TEST_WORKDIR}")
    cet_passthrough(FLAG IN_PLACE KEYWORD --dirty-workdir CET_DIRTY_WORKDIR)

    # Deal with specified data files.
    if (DEFINED CET_DATAFILES)
      list(REMOVE_DUPLICATES CET_DATAFILES)
      set(datafiles_tmp)
      foreach (df IN LISTS CET_DATAFILES)
        get_filename_component(dfd ${df} DIRECTORY)
        if (dfd)
          list(APPEND datafiles_tmp ${df})
        else(dfd)
          list(APPEND datafiles_tmp ${CMAKE_CURRENT_SOURCE_DIR}/${df})
        endif(dfd)
      endforeach()
      set(CET_DATAFILES ${datafiles_tmp})
    endif(DEFINED CET_DATAFILES)

    list(FIND CET_TEST_PROPERTIES SKIP_RETURN_CODE skip_return_code)
    if (skip_return_code GREATER -1)
      math(EXPR skip_return_code "${skip_return_code} + 1")
      list(GET CET_TEST_PROPERTIES ${skip_return_code} skip_return_code)
    else()
      set(skip_return_code 247)
      list(APPEND CET_TEST_PROPERTIES SKIP_RETURN_CODE ${skip_return_code})
    endif()
    if (CET_REF)
      if ("PASS_REGULAR_EXPRESSION" IN_LIST CET_TEST_PROPERTIES OR
          "FAIL_REGULAR_EXPRESSION" IN_LIST CET_TEST_PROPERTIES)
        message(FATAL_ERROR "Cannot specify REF option for test ${CET_TARGET} in conjunction with (PASS|FAIL)_REGULAR_EXPESSION.")
      endif()
      list(POP_FRONT CET_REF OUTPUT_REF ERROR_REF)
      if (ERROR_REF)
        set(DEFINE_ERROR_REF "-DTEST_REF_ERR=${ERROR_REF}")
        set(DEFINE_TEST_ERR "-DTEST_ERR=${CET_TARGET}.err")
      endif()
      if (CET_OUTPUT_FILTER)
        set(DEFINE_OUTPUT_FILTER "-DOUTPUT_FILTER=${CET_OUTPUT_FILTER}")
        if (CET_OUTPUT_FILTER_ARGS)
          separate_arguments(FILTER_ARGS NATIVE_COMMAND "${CET_OUTPUT_FILTER_ARGS}")
          string(PREPEND DEFINE_OUTPUT_FILTER_ARGS "-DOUTPUT_FILTER_ARGS=")
        endif()
      elseif (CET_OUTPUT_FILTERS)
        foreach (filter IN LISTS CET_OUTPUT_FILTERS)
          separate_arguments(args NATIVE_COMMAND "${filter}")
          cet_convert_target_args(args "${filter}")
          set(filter)
          foreach (arg IN LISTS args)
            _cet_exec_location(arg "${arg}")
            list(APPEND filter "${arg}")
          endforeach()
          list(APPEND DEFINE_OUTPUT_FILTERS "${filter}")
        endforeach()
        string(REPLACE ";" "\\;" DEFINE_OUTPUT_FILTERS "${DEFINE_OUTPUT_FILTERS}")
        string(PREPEND DEFINE_OUTPUT_FILTERS "-DOUTPUT_FILTERS=")
      endif()
      _cet_add_ref_test(${CET_TEST_ARGS})
    else(CET_REF)
      _cet_add_test(${CET_TEST_ARGS})
    endif(CET_REF)
    if (NOT (CET_OPTIONAL_GROUPS OR CET_NO_OPTIONAL_GROUPS))
      set(CET_OPTIONAL_GROUPS DEFAULT RELEASE)
    endif()
    if (NTESTS GREATER 1)
      list(APPEND CET_OPTIONAL_GROUPS ${TEST_TARGET_NAME})
    endif()
    _update_defined_test_groups(${CET_OPTIONAL_GROUPS})
    set_tests_properties(${ALL_TEST_TARGETS} PROPERTIES LABELS "${CET_OPTIONAL_GROUPS}")
    if (CET_TEST_PROPERTIES)
      set_tests_properties(${ALL_TEST_TARGETS} PROPERTIES ${CET_TEST_PROPERTIES})
    endif()
    if (CETB_SANITIZER_PRELOADS)
      set_property(TEST ${ALL_TEST_TARGETS} APPEND PROPERTY
        ENVIRONMENT "LD_PRELOAD=$ENV{LD_PRELOAD} ${CETB_SANITIZER_PRELOADS}")
    endif()
    foreach (san_env IN ITEMS
        ASAN_OPTIONS MSAN_OPTIONS LSAN_OPTIONS TSAN_OPTIONS UBSAN_OPTIONS)
      if (CETP_${san_env})
        set_property(TEST ${ALL_TEST_TARGETS} APPEND PROPERTY
          ENVIRONMENT "${san_env}=${CETP_${san_env}}")
      elseif (DEFINED ENV{${san_env}})
        set_property(TEST ${ALL_TEST_TARGETS} APPEND PROPERTY
          ENVIRONMENT "${san_env}=$ENV{${san_env}}")
      endif()
    endforeach()
    foreach (target IN LISTS ALL_TEST_TARGETS)
      if (CET_TEST_ENV)
        # Set global environment.
        get_test_property(${target} ENVIRONMENT CET_TEST_ENV_TMP)
        if (CET_TEST_ENV_TMP)
          set_tests_properties(${target} PROPERTIES
            ENVIRONMENT "${CET_TEST_ENV};${CET_TEST_ENV_TMP}")
        else()
          set_tests_properties(${target} PROPERTIES
            ENVIRONMENT "${CET_TEST_ENV}")
        endif()
      endif()
      if (CET_REF)
        get_test_property(${target} REQUIRED_FILES REQUIRED_FILES_TMP)
        if (REQUIRED_FILES_TMP)
          set_tests_properties(${target} PROPERTIES REQUIRED_FILES "${REQUIRED_FILES_TMP};${CET_REF}")
        else()
          set_tests_properties(${target} PROPERTIES REQUIRED_FILES "${CET_REF}")
        endif()
      else(CET_REF)
        if (CET_OUTPUT_FILTER OR CET_OUTPUT_FILTER_ARGS)
          message(FATAL_ERROR "OUTPUT_FILTER and OUTPUT_FILTER_ARGS are not accepted if REF is not specified.")
        endif()
      endif()
    endforeach()
  else(NOT CET_NO_AUTO)
    if (CET_CONFIGURATIONS OR CET_DATAFILES OR CET_DIRTY_WORKDIR OR CET_NO_OPTIONAL_GROUPS OR
        CET_OPTIONAL_GROUPS OR CET_OUTPUT_FILTER OR CET_OUTPUT_FILTERS OR
        CET_OUTPUT_FILTER_ARGS OR CET_REF OR CET_REQUIRED_FILES OR
        CET_SCOPED OR CET_TEST_ARGS OR CET_TEST_PROPERTIES OR
        CET_TEST_WORKDIR OR NPARG_LABELS)
      message(FATAL_ERROR "The following arguments are not meaningful in the presence of NO_AUTO:
CONFIGURATIONS DATAFILES DIRTY_WORKDIR NO_OPTIONAL_GROUPS_OPTIONAL_GROUPS OUTPUT_FILTER OUTPUT_FILTERS OUTPUT_FILTER_ARGS PARG_<label> REF REQUIRED_FILES SCOPED TEST_ARGS TEST_PROPERTIES TEST_WORKDIR")
    endif()
  endif(NOT CET_NO_AUTO)
  if (CET_INSTALL_BIN AND CET_HANDBUILT)
    message(WARNING "INSTALL_BIN option ignored for HANDBUILT tests.")
  endif()
  if (CET_INSTALL_EXAMPLE)
    # Install to examples directory of product.
    install(FILES "${CET_SOURCE}" ${CET_DATAFILES}
      DESTINATION example
      )
  endif()
  if (CET_INSTALL_SOURCE)
    cet_package_path(CURRENT_SUBDIR)
    cet_regex_escape("${${CETMODULES_CURRENT_PROJECT_NAME}_TEST_DIR}" e_test_dir)
    string(REGEX REPLACE "^(test|${e_test_dir})(/|$)"
      "" CURRENT_SUBDIR "${CURRENT_SUBDIR}")
    install(FILES "${CET_SOURCE}"
      DESTINATION "${${CETMODULES_CURRENT_PROJECT_NAME}_TEST_DIR}/${CURRENT_SUBDIR}")
  endif()
endfunction(cet_test)

function(cet_test_assertion CONDITION FIRST_TARGET)
  if (CMAKE_SYSTEM_NAME MATCHES "Darwin" )
    set_tests_properties(${FIRST_TARGET} ${ARGN} PROPERTIES
      PASS_REGULAR_EXPRESSION
      "Assertion failed: \\(${CONDITION}\\), "
      )
  else()
    set_tests_properties(${FIRST_TARGET} ${ARGN} PROPERTIES
      PASS_REGULAR_EXPRESSION
      "Assertion `${CONDITION}' failed\\."
      )
  endif()
endfunction()

# FIXME: Needs work!
function(_cet_add_test_properties TEST_NAME TEST_EXEC)
  if (NOT TARGET ${TEST_EXEC}) # Not interested.
    return()
  endif()
  set_property(TEST ${TEST_NAME} APPEND PROPERTY KEYWORDS CET
    $<TARGET_PROPERTY:${TEST_EXEC}>)
endfunction()

cmake_policy(POP)
