########################################################################
# cet_test: specify tests in a concise and transparent way (see also
#           cet_test_env() and cet_test_assertion(), below).
#
# Usage: cet_test(target [<options>] [<args>])
#
####################################
# Options:
#
# HANDBUILT
#   Do not build the target -- it will be provided. This option is
#    mutually exclusive with the PREBUILT option.
#
# PREBUILT
#   Do not build the target -- pick it up from the source dir (eg
#    scripts).  This option is mutually exclusive with the HANDBUILT
#    option and simply calls the cet_script() function with appropriate
#    options.
#
# NO_AUTO
#   Do not add the target to the auto test list.
#
# USE_BOOST_UNIT
#   This test uses the Boost Unit Test Framework.
#
# INSTALL_BIN
#   Install this test's script / exec in the product's binary directory
#   (ignored for HANDBUILT).
#
# INSTALL_EXAMPLE
#   Install this test and all its data files into the examples area of the
#    product.
#
# INSTALL_SOURCE
#   Install this test's source in the source area of the product.
#
####################################
# Args
#
# CONFIGURATIONS
#
#   Configurations (Debug, etc, etc) under which the test shall be executed.
#
# DATAFILES
#   Input and/or references files to be copied to the test area in the
#    build tree for use by the test. If there is no path, or a relative
#    path, the file is assumed to be in or under
#    ${CMAKE_CURRENT_SOURCE_DIR}.
#
# DEPENDENCIES
#   List of top-level dependencies to consider for a PREBUILT
#    target. Top-level implies a target (not file) created with ADD_EXECUTABLE,
#    ADD_LIBRARY or ADD_CUSTOM_TARGET.
#
# LIBRARIES
#   Extra libraries with which to link this target.
#
# OPTIONAL_GROUPS
#   Assign this test to one or more named optional groups. If the CMake
#    list variable CET_TEST_GROUPS is set (e.g. with -D on the CMake
#    command line) and there is overlap between the two lists, execute
#    the test. The CET_TEST_GROUPS cache variable may additionally
#    contain the optional values ALL or NONE.
#
# REF
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
#  If REF is specified, then OUTPUT_FILTERS may also be specified
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
# REQUIRED_FILES
#   These files are required to be present before the test will be
#   executed. If any are missing, ctest will record NOT RUN for this
#   test.
#
# SOURCES
#   Sources to use to build the target (default is ${target}.cc).
#
# TEST_ARGS
#   Any arguments to the test to be run.
#
# TEST_EXEC
#   The exec to run (if not the target). The HANDBUILT option must
#    be specified in conjunction with this option.
#
# TEST_PROPERTIES
#   Properties to be added to the test. See documentation of the cmake
#    command, "set_tests_properties."
#
####################################
# Cache variables
#
# CET_TEST_GROUPS
#   Test group names specified using the OPTIONAL_GROUPS list option are
#    compared against this list to determine whether to configure the
#    test. Default value is the special value "NONE," meaning no
#    optional tests are to be configured. Optionally CET_TEST_GROUPS may
#    contain the special value "ALL." Specify multiple values separated
#    by ";" (escape or protect with quotes) or "," See explanation of
#    the OPTIONAL_GROUPS variable above for more details.
#
# CET_DEFINED_TEST_GROUPS
#  Any test group names CMake sees will be added to this list.
#
####################################
# Notes:
#
# * cet_make_exec() and art_make_exec() are more flexible than building
#   the test exec with cet_test(), and are to be preferred (use the
#   NO_INSTALL option to same as appropriate). Use
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
#   subdirectories unless include(CetTest) or cet_test_env(CLEAR ...) is
#   invoked in that directory.
#
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
cmake_policy(VERSION 3.0.1) # We've made this work for 3.0.1.

# Need argument parser.
include(CMakeParseArguments)
# Copy function.
include(CetCopy)
# May need Boost Unit Test Framework library.
#include(FindUpsBoost)
# Need cet_script for PREBUILT scripts
include(CetMake)
# May need to escape a string to avoid misinterpretation as regex
include(CetRegexEscape)

# Compatibility with older packages.
#include(CheckUpsVersion)

  if ((EXISTS $ENV{CETPKG_SOURCE}/art/tools/migration AND NOT EXISTS $ENV{CETPKG_SOURCE}/art/tools/filter-timeTracker-output) OR
      (EXISTS $ENV{CETPKG_SOURCE}/tools/migration AND NOT EXISTS $ENV{CETPKG_SOURCE}/tools/filter-timeTracker-output))
    set(CT_NEED_ART_COMPAT TRUE)
  endif()
if (CT_NEED_ART_COMPAT)
  message(STATUS "Using or building art OLDER than v2_01_00RC1: using -DART_COMPAT=1 for REF tests.")
  set(DEFINE_ART_COMPAT -DART_COMPAT=1)
endif()

# If Boost has been specified but the library hasn't, load the library.
IF((NOT Boost_UNIT_TEST_FRAMEWORK_LIBRARY) AND BOOST_VERS)
#  find_ups_boost(${BOOST_VERS} unit_test_framework)
  findPackage( boost )
ENDIF() 

SET(CET_TEST_GROUPS "NONE"
  CACHE STRING "List of optional test groups to be configured."
  )

STRING(TOUPPER "${CET_TEST_GROUPS}" CET_TEST_GROUPS_UC)

SET(CET_TEST_ENV ""
  CACHE INTERNAL "Environment to add to every test"
  FORCE
  )

# - Programs and Modules
# Default comparator
set(CET_RUNANDCOMPARE "${CMAKE_CURRENT_LIST_DIR}/RunAndCompare.cmake")
# Test run wrapper
set(CET_CET_EXEC_TEST "${cetmods_BINDIR}/cet_exec_test")

FUNCTION(_update_defined_test_groups)
  IF(ARGC)
    SET(TMP_LIST ${CET_DEFINED_TEST_GROUPS})
    LIST(APPEND TMP_LIST ${ARGN})
    LIST(REMOVE_DUPLICATES TMP_LIST)
    SET(CET_DEFINED_TEST_GROUPS ${TMP_LIST}
      CACHE STRING "List of defined test groups."
      FORCE
      )
  ENDIF()
ENDFUNCTION()

FUNCTION(_check_want_test CET_OPTIONAL_GROUPS CET_WANT_TEST)
  IF(NOT CET_OPTIONAL_GROUPS)
    SET(${CET_WANT_TEST} YES PARENT_SCOPE)
    RETURN() # Short-circuit.
  ENDIF()
  SET (${CET_WANT_TEST} NO PARENT_SCOPE)
  LIST(FIND CET_TEST_GROUPS_UC ALL WANT_ALL)
  LIST(FIND CET_TEST_GROUPS_UC NONE WANT_NONE)
  IF(WANT_ALL GREATER -1)
    SET (${CET_WANT_TEST} YES PARENT_SCOPE)
    RETURN() # Short-circuit.
  ELSEIF(WANT_NONE GREATER -1)
    RETURN() # Short-circuit.
  ELSE()
    FOREACH(item IN LISTS CET_OPTIONAL_GROUPS)
      STRING(TOUPPER "${item}" item_uc)
      LIST(FIND CET_TEST_GROUPS_UC ${item_uc} FOUND_ITEM)
      IF(FOUND_ITEM GREATER -1)
        SET (${CET_WANT_TEST} YES PARENT_SCOPE)
        RETURN() # Short-circuit.
      ENDIF()
    ENDFOREACH()
  ENDIF()
ENDFUNCTION()

####################################
# Main macro definitions.
MACRO(cet_test_env)
  CMAKE_PARSE_ARGUMENTS(CET_TEST
    "CLEAR"
    ""
    ""
    ${ARGN}
    )
  IF(CET_TEST_CLEAR)
    SET(CET_TEST_ENV "")
  ENDIF()
  LIST(APPEND CET_TEST_ENV ${CET_TEST_UNPARSED_ARGUMENTS})
ENDMACRO()

FUNCTION(cet_test CET_TARGET)
  # Parse arguments
  IF(${CET_TARGET} MATCHES .*/.*)
    MESSAGE(FATAL_ERROR "${CET_TARGET} shuld not be a path. Use a simple "
      "target name with the HANDBUILT and TEST_EXEC options instead.")
  ENDIF()
  CMAKE_PARSE_ARGUMENTS (CET
    "HANDBUILT;PREBUILT;NO_AUTO;USE_BOOST_UNIT;INSTALL_BIN;INSTALL_EXAMPLE;INSTALL_SOURCE"
    "OUTPUT_FILTER;TEST_EXEC"
    "CONFIGURATIONS;DATAFILES;DEPENDENCIES;LIBRARIES;OPTIONAL_GROUPS;OUTPUT_FILTERS;OUTPUT_FILTER_ARGS;REQUIRED_FILES;SOURCES;TEST_ARGS;TEST_PROPERTIES;REF"
    ${ARGN}
    )
  IF (CET_OUTPUT_FILTERS AND CET_OUTPUT_FILTER_ARGS)
    MESSAGE(FATAL_ERROR "OUTPUT_FILTERS is incompatible with FILTER_ARGS:\nEither use the singular OUTPUT_FILTER or use double-quoted strings in OUTPUT_FILTERS\nE.g. OUTPUT_FILTERS \"filter1 -x -y\" \"filter2 -y -z\"")
  ENDIF()
  # Set up to handle a per-test work directory for parallel testing.
  SET(CET_TEST_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/${CET_TARGET}.d")
  file(MAKE_DIRECTORY "${CET_TEST_WORKDIR}")
  IF(CET_TEST_EXEC)
    IF(NOT CET_HANDBUILT)
      MESSAGE(FATAL_ERROR "cet_test: target ${CET_TARGET} cannot specify "
        "TEST_EXEC without HANDBUILT")
    ENDIF()
  ELSE()
    SET(CET_TEST_EXEC ${EXECUTABLE_OUTPUT_PATH}/${CET_TARGET})
  ENDIF()
  IF(CET_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "cet_test: DATAFILES option is now mandatory: non-option arguments are no longer permitted.")
  ENDIF()
  if (DEFINED CET_DATAFILES)
    list(REMOVE_DUPLICATES CET_DATAFILES)
    set(datafiles_tmp)
    foreach (df ${CET_DATAFILES})
      get_filename_component(dfd ${df} DIRECTORY)
      if (dfd)
        list(APPEND datafiles_tmp ${df})
      else(dfd)
        list(APPEND datafiles_tmp ${CMAKE_CURRENT_SOURCE_DIR}/${df})
      endif(dfd)
    endforeach()
    set(CET_DATAFILES ${datafiles_tmp})
  endif(DEFINED CET_DATAFILES)
  IF(CET_HANDBUILT AND CET_PREBUILT)
    # CET_HANDBUILT and CET_PREBUILT are mutually exclusive.
    MESSAGE(FATAL_ERROR "cet_test: target ${CET_TARGET} cannot have both CET_HANDBUILT "
      "and CET_PREBUILT options set.")
  ELSEIF(CET_PREBUILT) # eg scripts.
    IF (NOT CET_INSTALL_BIN)
      SET(CET_NO_INSTALL "NO_INSTALL")
    ENDIF()
    cet_script(${CET_TARGET} ${CET_NO_INSTALL} DEPENDENCIES ${CET_DEPENDENCIES})
  ELSEIF(NOT CET_HANDBUILT) # Normal build.
# Too noisy for now!
#    MESSAGE(WARNING "Building the test executable with cet_test is deprecated: use cet_make_exec(NO_INSTALL) or art_make_exec(NO_INSTALL) and cet_test(HANDBUILT) instead.")
    # Build the executable.
    IF(NOT CET_SOURCES) # Useful default.
      SET(CET_SOURCES ${CET_TARGET}.cc)
    ENDIF()
    ADD_EXECUTABLE(${CET_TARGET} ${CET_SOURCES})
    IF(CET_USE_BOOST_UNIT)
      # Make sure we have the correct library available.
      IF (NOT Boost_UNIT_TEST_FRAMEWORK_LIBRARY)
        MESSAGE(FATAL_ERROR "cet_test: target ${CET_TARGET} has USE_BOOST_UNIT "
          "option set but Boost Unit Test Framework Library cannot be found: is "
          "boost set up?")
      ENDIF()
      # Compile options (-Dxxx) for simple-format unit tests.
      SET_TARGET_PROPERTIES(${CET_TARGET} PROPERTIES
        COMPILE_DEFINITIONS "BOOST_TEST_MAIN;BOOST_TEST_DYN_LINK"
        )
      TARGET_LINK_LIBRARIES(${CET_TARGET} ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY})
    ENDIF()
    IF(COMMAND find_tbb_offloads)
      find_tbb_offloads(FOUND_VAR have_tbb_offload ${CET_SOURCES})
      IF(have_tbb_offload)
        SET_TARGET_PROPERTIES(${CET_TARGET} PROPERTIES LINK_FLAGS ${TBB_OFFLOAD_FLAG})
      ENDIF()
    ENDIF()
    if(CET_LIBRARIES)
      set(link_lib_list "")
      foreach (lib ${CET_LIBRARIES})
	      string(REGEX MATCH [/] has_path "${lib}")
	      if( has_path )
	        list(APPEND link_lib_list ${lib})
	      else()
	        string(TOUPPER  ${lib} ${lib}_UC )
	        #_cet_debug_message( "simple_plugin: check ${lib}" )
	        if( ${${lib}_UC} )
            _cet_debug_message( "changing ${lib} to ${${${lib}_UC}}")
            list(APPEND link_lib_list ${${${lib}_UC}})
	        else()
            list(APPEND link_lib_list ${lib})
	        endif()
	      endif( has_path )
      endforeach()
      TARGET_LINK_LIBRARIES(${CET_TARGET} ${link_lib_list})
    endif()
  ENDIF()
  cet_copy(${CET_DATAFILES} DESTINATION ${CET_TEST_WORKDIR} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  IF(CET_CONFIGURATIONS)
    SET(CONFIGURATIONS_CMD CONFIGURATIONS)
  ENDIF()
  _update_defined_test_groups(${CET_OPTIONAL_GROUPS})
  _check_want_test("${CET_OPTIONAL_GROUPS}" WANT_TEST)
  IF(NOT CET_NO_AUTO AND WANT_TEST)
    LIST(FIND CET_TEST_PROPERTIES SKIP_RETURN_CODE skip_return_code)
    IF (skip_return_code GREATER -1)
      MATH(EXPR skip_return_code "${skip_return_code} + 1")
      LIST(GET CET_TEST_PROPERTIES ${skip_return_code} skip_return_code)
    ELSE()
      SET(skip_return_code 247)
      LIST(APPEND CET_TEST_PROPERTIES SKIP_RETURN_CODE ${skip_return_code})
    ENDIF()
    IF(CET_REF)
      LIST(FIND CET_TEST_PROPERTIES PASS_REGULAR_EXPRESSION has_pass_exp)
      LIST(FIND CET_TEST_PROPERTIES FAIL_REGULAR_EXPRESSION has_fail_exp)
      IF(has_pass_exp GREATER -1 OR has_fail_exp GREATER -1)
        MESSAGE(FATAL_ERROR "Cannot specify REF option for test ${CET_TARGET} in conjunction with (PASS|FAIL)_REGULAR_EXPESSION.")
      ENDIF()
      LIST(LENGTH CET_REF CET_REF_LEN)
      IF(CET_REF_LEN EQUAL 1)
        SET(OUTPUT_REF ${CET_REF})
      ELSE()
        LIST(GET CET_REF 0 OUTPUT_REF)
        LIST(GET CET_REF 1 ERROR_REF)
        SET(DEFINE_ERROR_REF "-DTEST_REF_ERR=${ERROR_REF}")
        SET(DEFINE_TEST_ERR "-DTEST_ERR=${CET_TARGET}.err")
      ENDIF()
      SEPARATE_ARGUMENTS(TEST_ARGS UNIX_COMMAND "${CET_TEST_ARGS}")
      IF(CET_OUTPUT_FILTER)
        SET(DEFINE_OUTPUT_FILTER "-DOUTPUT_FILTER=${CET_OUTPUT_FILTER}")
        IF(CET_OUTPUT_FILTER_ARGS)
          SEPARATE_ARGUMENTS(FILTER_ARGS UNIX_COMMAND "${CET_OUTPUT_FILTER_ARGS}")
          SET(DEFINE_OUTPUT_FILTER_ARGS "-DOUTPUT_FILTER_ARGS=${FILTER_ARGS}")
        ENDIF()
      ELSEIF(CET_OUTPUT_FILTERS)
        STRING(REPLACE ";" "::" DEFINE_OUTPUT_FILTERS "${CET_OUTPUT_FILTERS}")
        SET(DEFINE_OUTPUT_FILTERS "-DOUTPUT_FILTERS=${DEFINE_OUTPUT_FILTERS}")
      ENDIF()
      ADD_TEST(NAME ${CET_TARGET}
        ${CONFIGURATIONS_CMD} ${CET_CONFIGURATIONS}
        COMMAND ${CET_CET_EXEC_TEST} --wd ${CET_TEST_WORKDIR}
        --required-files "${CET_REQUIRED_FILES}"
        --datafiles "${CET_DATAFILES}"
        --skip-return-code ${skip_return_code}
        ${CMAKE_COMMAND}
        -DTEST_EXEC=${CET_TEST_EXEC}
        -DTEST_ARGS=${TEST_ARGS}
        -DTEST_REF=${OUTPUT_REF}
        ${DEFINE_ERROR_REF}
        ${DEFINE_TEST_ERR}
        -DTEST_OUT=${CET_TARGET}.out
        ${DEFINE_OUTPUT_FILTER} ${DEFINE_OUTPUT_FILTER_ARGS} ${DEFINE_OUTPUT_FILTERS}
        ${DEFINE_ART_COMPAT}
        -P ${CET_RUNANDCOMPARE}
        )
    ELSE(CET_REF)
      # Add the test.
      ADD_TEST(NAME ${CET_TARGET}
        ${CONFIGURATIONS_CMD} ${CET_CONFIGURATIONS}
        COMMAND
        ${CET_CET_EXEC_TEST} --wd ${CET_TEST_WORKDIR}
        --required-files "${CET_REQUIRED_FILES}"
        --datafiles "${CET_DATAFILES}"
        --skip-return-code ${skip_return_code}
        ${CET_TEST_EXEC} ${CET_TEST_ARGS})
    ENDIF(CET_REF)
    IF(${CMAKE_VERSION} VERSION_GREATER "2.8")
      SET_TESTS_PROPERTIES(${CET_TARGET} PROPERTIES WORKING_DIRECTORY ${CET_TEST_WORKDIR})
    ENDIF()
    IF(CET_TEST_PROPERTIES)
      SET_TESTS_PROPERTIES(${CET_TARGET} PROPERTIES ${CET_TEST_PROPERTIES})
    ENDIF()
    IF(CET_TEST_ENV)
      # Set global environment.
      GET_TEST_PROPERTY(${CET_TARGET} ENVIRONMENT CET_TEST_ENV_TMP)
      IF(CET_TEST_ENV_TMP)
        SET_TESTS_PROPERTIES(${CET_TARGET} PROPERTIES ENVIRONMENT "${CET_TEST_ENV};${CET_TEST_ENV_TMP}")
      ELSE()
        SET_TESTS_PROPERTIES(${CET_TARGET} PROPERTIES ENVIRONMENT "${CET_TEST_ENV}")
      ENDIF()
    ENDIF()
    IF(CET_REF)
      GET_TEST_PROPERTY(${CET_TARGET} REQUIRED_FILES REQUIRED_FILES_TMP)
      IF(REQUIRED_FILES_TMP)
        SET_TESTS_PROPERTIES("${CET_TARGET}" PROPERTIES REQUIRED_FILES "${REQUIRED_FILES_TMP};${CET_REF}")
      ELSE()
        SET_TESTS_PROPERTIES("${CET_TARGET}" PROPERTIES REQUIRED_FILES "${CET_REF}")
      ENDIF()
    ENDIF()
  ELSE(NOT CET_NO_AUTO AND WANT_TEST)
    IF(CET_OUTPUT_FILTER OR CET_OUTPUT_FILTER_ARGS)
      MESSAGE(FATAL_ERROR "OUTPUT_FILTER and OUTPUT_FILTER_ARGS are not accepted if REF is not specified.")
    ENDIF()
  ENDIF(NOT CET_NO_AUTO AND WANT_TEST)
  IF(CET_INSTALL_BIN)
    IF(CET_HANDBUILT)
      MESSAGE(WARNING "INSTALL_BIN option ignored for HANDBUILT tests.")
    ELSEIF(NOT CET_PREBUILT)
      INSTALL(TARGETS ${CET_TARGET} DESTINATION ${flavorqual_dir}/bin)
    ENDIF()
  ENDIF()
  IF(CET_INSTALL_EXAMPLE)
    # Install to examples directory of product.
    INSTALL(FILES ${CET_SOURCES} ${CET_DATAFILES}
      DESTINATION ${product}/${version}/example
      )
  ENDIF()
  IF(CET_INSTALL_SOURCE)
    # Install to sources/test (will need to be amended for eg ART's
    # multiple test directories.
    INSTALL(FILES ${CET_SOURCES}
      DESTINATION ${product}/${version}/source/test
      )
  ENDIF()
ENDFUNCTION(cet_test)

FUNCTION(cet_test_assertion CONDITION FIRST_TARGET)
  IF (${CMAKE_SYSTEM_NAME} MATCHES "Darwin" )
    SET_TESTS_PROPERTIES(${FIRST_TARGET} ${ARGN} PROPERTIES
      PASS_REGULAR_EXPRESSION
      "Assertion failed: \\(${CONDITION}\\), "
      )
  ELSE()
    SET_TESTS_PROPERTIES(${FIRST_TARGET} ${ARGN} PROPERTIES
      PASS_REGULAR_EXPRESSION
      "Assertion `${CONDITION}' failed\\."
      )
  ENDIF()
ENDFUNCTION()
########################################################################
