########################################################################
# Ups.cmake
#
# This CMake file should *not* be included directly by anyone: the CMake
# variable WANT_UPS should be set and the cet_cmake_env() function
# called in order to activate UPS functionality.
#
# Behavior configured via setup_for_development should be incorporated
# into the build configuration via command-line -D (definition) options
# to CMake. It is *strongly* recommended that this task be delegated to
# buildtool, which will add the necessary options to the CMake
# invocation automatically.
#
####################################
# Variables available to dependents via find_package()):
#
#   UPS_<product_name>_CMAKE_PROJECT_NAME:STRING=<cmake_project_name>
#
#     Provide the correspondence between the UPS product name and the
#     CMake project name.
#
####################################
# Command-line (cached) CMake variables:
#
#   <cmake_project_name>_UPS_PRODUCT_NAME:STRING=<product_name>
#
#     Specify the UPS product name. Defaults to UPS_PRODUCT_NAME (see
#     below), falls back to the lower-case "safe" representation of
#     PROJECT_NAME.
#
#   <cmake_project_name>_UPS_QUALIFIER_STRING:STRING=<qual>[:<qual>]...
#
#     Specify the `:'-delimited UPS qualifier string.
#
#   <cmake_project_name>_UPS_PRODUCT_FLAVOR:STRING=<flavor>
#
#     The UPS flavor for the product (NULL or the output of ups flavor).
#
#   UPS_<LANG>_COMPILER_ID:STRING=<id>
#
#     Specify the expected value of CMAKE_<LANG>_COMPILER_ID for the
#     purpose of verification.
#
#   UPS_<LANG>_COMPILER_VERSION:STRING=<id>
#
#     Specify the expected value of CMAKE_<LANG>_COMPILER_VERSION for
#     the purpose of verification.
#
#   UPS_TAR_DIR:PATH=${CMAKE_BINARY_DIR}
#
#     The destination directory for binary archives of UPS products.
#
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetRegexEscape)
include(Compatibility)
include(GenerateFromFragments)
include(ProjectVariable)

# These should be the same for all projects being compiled together.
set(UPS_C_COMPILER_ID "" CACHE STRING
  "Expected C compiler ID per UPS compiler qualifier")
set(UPS_C_COMPILER_VERSION "" CACHE STRING
  "Expected C compiler version per UPS compiler qualifier")
set(UPS_CXX_COMPILER_ID "" CACHE STRING
  "Expected C++ compiler ID per UPS compiler qualifier")
set(UPS_CXX_COMPILER_VERSION "" CACHE STRING
  "Expected C++ compiler version per UPS compiler qualifier")
set(UPS_Fortran_COMPILER_ID "" CACHE STRING
  "Expected Fortran compiler ID per UPS compiler qualifier")
set(UPS_Fortran_COMPILER_VERSION "" CACHE STRING
  "Expected Fortran compiler version per UPS compiler qualifier")
foreach (lang IN ITEMS C CXX Fortran)
  mark_as_advanced(UPS_${lang}_COMPILER_ID UPS_${lang}_COMPILER_VERSION)
endforeach()

if (NOT WANT_UPS)
  message(FATAL_ERROR
    "add -DWANT_UPS:BOOL=ON to the CMake command line (recommended:"
    " use buildtool)")
endif()

# Set up the correspondences for some otherwise problematic packages.
set(UPS_cppunit_CMAKE_PROJECT_NAME CppUnit)
set(UPS_range_CMAKE_PROJECT_NAME Range)
set(UPS_smc_compiler_CMAKE_PROJECT_NAME Smc)
set(UPS_sqlite_CMAKE_PROJECT_NAME SQLite3)
set(UPS_tbb_CMAKE_PROJECT_NAME TBB)
set(UPS_xerces_c_CMAKE_PROJECT_NAME XercesC)

function(process_ups_files)
  if (NOT UPS_TAR_DIR)
    message(FATAL_ERROR "Set the CMake variable WANT_UPS prior to including"
      " CetCMakeEnv.cmake to activate UPS table file and tarball generation."
      "\nUps.cmake should not be included directly.")
  endif()

  # Calculate the path for the table and version files.
  set(table_file
    "${${PROJECT_NAME}_UPS_PRODUCT_UPS_DIR}/${${PROJECT_NAME}_UPS_PRODUCT_NAME}.table")

  # Generate the UPS table file.
  _build_ups_table_file()

  # Install it.
  install(FILES
    "${PROJECT_BINARY_DIR}/${table_file}"
    DESTINATION ${${PROJECT_NAME}_UPS_PRODUCT_UPS_DIR})

  ##################
  # Generate the UPS version and chain files.

  # Required temporary variables for substitution.
  foreach (v IN ITEMS UPS_PRODUCT_FLAVOR UPS_PRODUCT_NAME UPS_PRODUCT_VERSION UPS_PRODUCT_SUBDIR
      UPS_QUALIFIER_STRING UPS_PRODUCT_UPS_DIR)
    set(${v} ${${PROJECT_NAME}_${v}})
  endforeach()
  cet_timestamp(UPS_DECLARE_DATE)
  # Generate the version file.

  cet_localize_pv(cetmodules CONFIG_DIR)
  configure_file("${cetmodules_CONFIG_DIR}/ups/product-version-file.in"
    "${PROJECT_BINARY_DIR}/${${PROJECT_NAME}_UPS_PRODUCT_UPS_DIR}/${${PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
    @ONLY)
  # Install it.
  install(FILES
    "${PROJECT_BINARY_DIR}/${${PROJECT_NAME}_UPS_PRODUCT_UPS_DIR}/${${PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
    DESTINATION ../${${PROJECT_NAME}_UPS_PRODUCT_VERSION}.version)
  # Generate and install any requested chain files.
  foreach (UPS_PRODUCT_CHAIN IN LISTS ${PROJECT_NAME}_UPS_PRODUCT_CHAINS)
    # Generate with chain name prepended to avoid conflicts or the need
    # for a deeper hierarchy in the build area.
    configure_file("${cetmodules_CONFIG_DIR}/ups/product-chain-file.in"
      "${PROJECT_BINARY_DIR}/${${PROJECT_NAME}_UPS_PRODUCT_UPS_DIR}/${UPS_PRODUCT_CHAIN}.${${PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
      @ONLY)
    # Install.
    install(FILES
      "${PROJECT_BINARY_DIR}/${${PROJECT_NAME}_UPS_PRODUCT_UPS_DIR}/${UPS_PRODUCT_CHAIN}.${${PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
      DESTINATION "../${UPS_PRODUCT_CHAIN}.chain"
      RENAME "${${PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}")
  endforeach()
endfunction()

##################
function(_build_ups_table_file)
  ##################
  # Calculate derivative variables only needed for the table file.

  # Flavor.
  set(UPS_TABLE_FLAVOR "${${PROJECT_NAME}_UPS_PRODUCT_FLAVOR}")

  # Qualifiers.
  if (${PROJECT_NAME}_UPS_QUALIFIER_STRING)
    set(UPS_QUALIFIER_STRING "${${PROJECT_NAME}_UPS_QUALIFIER_STRING}")
  endif()

  # Dependencies.
  file(READ
    "${PROJECT_BINARY_DIR}/table_deps_${${PROJECT_NAME}_UPS_PRODUCT_NAME}"
    SETUP_DEPENDENCIES)
  if (SETUP_DEPENDENCIES)
    string(REGEX REPLACE "\n(.)" "\n    \\1"
      SETUP_DEPENDENCIES
      "    ##################\n# Set up dependencies.\n${SETUP_DEPENDENCIES}")
  endif()
  ##################

  ##################
  # Define product environment variables.

  # FQ_DIR.
  _table_var_clause(FQ_DIR TABLE_VARS
    PVAR EXEC_PREFIX [[prodDir(_FQ_DIR, "@VAL@")]])

  # INC.
  #
  # Store derived UPS value for use by ROOT_INCLUDE_PATH.
  _project_var_to_ups_path(INCLUDE_DIR incdir)
  _table_var_clause(INC TABLE_VARS APPEND
    PVAR INCLUDE_DIR
    [[envSet(${UPS_PROD_NAME_UC}_INC, "@VAL@")]]
    IF_TEST [[test -d "@VAL@"]])

  # LIB.
  #
  # Store derived UPS value for use by PYTHONPATH and PKG_CONFIG_PATH.
  _project_var_to_ups_path(LIBRARY_DIR libdir)
  _table_var_clause(LIB TABLE_VARS
    VAL "${libdir}" APPEND
    IF_TEST [[test -d "@VAL@"]]
    [[
envSet(${UPS_PROD_NAME_UC}_LIB, "@VAL@")
if ( test `uname` = "Darwin" )
  pathPrepend(DYLD_LIBRARY_PATH, ${${UPS_PROD_NAME_UC}_LIB})
else()
  pathPrepend(LD_LIBRARY_PATH, ${${UPS_PROD_NAME_UC}_LIB})
endIf ( test `uname` = "Darwin" )
pathPrepend(CET_PLUGIN_PATH, ${${UPS_PROD_NAME_UC}_LIB})]])

  # PYTHONPATH.
  if (${PROJECT_NAME}_DEFINE_PYTHONPATH)
    if (libdir)
      set(pp_path_var [[${${UPS_PROD_NAME_UC}_LIB}]])
    elseif (${PROJECT_NAME}_EXEC_PREFIX)
      set(pp_path_var [[${${UPS_PROD_NAME_UC}_FQ}/lib]])
    else()
      set(pp_path_var [[${UPS_PROD_DIR}/lib]])
    endif()
    _table_var_clause(PYTHONPATH TABLE_VARS
      VAL ${pp_path_var} APPEND
      IF_TEST [[test -n "@VAL@" -a -d "@VAL@"]]
      [[pathPrepend(PYTHONPATH, "@VAL@")]])
  endif()

  # PATH.
  _table_var_clause(BIN TABLE_VARS APPEND
    PVAR BIN_DIR
    IF_TEST [[test -d "@VAL@"]]
    [[pathPrepend(PATH, "@VAL@")]])

  # FHICL_FILE_PATH.
  _table_var_clause(FHICL_FILE_PATH TABLE_VARS APPEND
    PVAR FHICL_DIR
    IF_TEST [[test -d "@VAL@"]]
    [[pathPrepend(FHICL_FILE_PATH, "@VAL@")]])

  # FW_SEARCH_PATH.
  _table_var_clause(FW_SEARCH_PATH TABLE_VARS APPEND
    PVAR FW_SEARCH_PATH
    [[pathPrepend(FW_SEARCH_PATH, "@VAL@")]])

  # WIRECELL_PATH.
  _table_var_clause(WIRECELL_PATH TABLE_VARS APPEND
    PVAR WIRECELL_PATH
    [[pathPrepend(WIRECELL_PATH, "@VAL@")]])

  # PERL5LIB.
  _table_var_clause(PERL5LIB TABLE_VARS APPEND
    PVAR PERLLIB_DIR
    IF_TEST [[test -d "@VAL@"]]
    [[pathPrepend(PERL5LIB, "@VAL@")]])

  # CMAKE_PREFIX_PATH.
  if (${PROJECT_NAME}_EXEC_PREFIX)
    set(prefix_path [[${${UPS_PROD_NAME_UC}_FQ_DIR}]])
  else()
    set(prefix_path [[${UPS_PROD_DIR}]])
  endif()
  _table_var_clause(CMAKE_PREFIX_PATH TABLE_VARS
    VAL "${prefix_path}" APPEND
    [[pathPrepend(CMAKE_PREFIX_PATH, "@VAL@")]])

  # PKG_CONFIG_PATH.
  _table_var_clause(PKG_CONFIG_PATH TABLE_VARS
    VAL "${libdir}" APPEND
    IF_TEST [[test -n "${${UPS_PROD_NAME_UC}_LIB}" -a -d "${${UPS_PROD_NAME_UC}_LIB}/pkgconfig"]]
    [[pathPrepend(PKG_CONFIG_PATH, "${${UPS_PROD_NAME_UC}_LIB}/pkgconfig")]])

  # ROOT_INCLUDE_PATH.
  _table_var_clause("ROOT_INCLUDE_PATH for dictionaries." TABLE_VARS
    VAL "${incdir}" APPEND
    IF_TEST [[test -n "${${UPS_PROD_NAME_UC}_INC}"]]
    [[pathPrepend(ROOT_INCLUDE_PATH, "${${UPS_PROD_NAME_UC}_INC}")]])

  if (TABLE_VARS)
    string(PREPEND TABLE_VARS "    ##################\n"
      "    # Set environment variables.\n")
  endif()
  ##################

  if (EXISTS "${PROJECT_SOURCE_DIR}/${table_file}.in")
    configure_file(${PROJECT_SOURCE_DIR}/${table_file}.in
      ${PROJECT_BINARY_DIR}/${table_file} @ONLY)
  else() # Generate according to information we've gathered.
    # Find a table fragment if we have one.
    set(table_frag_file
      "${PROJECT_BINARY_DIR}/table_frag_${${PROJECT_NAME}_UPS_PRODUCT_NAME}")
    if (NOT EXISTS "${table_frag_file}")
      unset(table_frag_file)
    endif()

    # Generate the UPS table file from its fragments.
    cet_localize_pv(cetmodules CONFIG_DIR)
    generate_from_fragments("${PROJECT_BINARY_DIR}/${table_file}"
      NO_FRAGMENT_DELIMITERS
      FRAGMENTS
      "${cetmodules_CONFIG_DIR}/ups/product.table.top.in"
      ${table_frag_file}
      "${cetmodules_CONFIG_DIR}/ups/product.table.bottom.in")
  endif()
endfunction()

function(_ups_use_maybe_unused)
  get_property(vars DIRECTORY PROPERTY CACHE_VARIABLES)
  set(lang_vars ${vars})
  list(FILTER lang_vars INCLUDE REGEX
    [[^CMAKE_[^_]+_(COMPILER|STANDARD(_REQUIRED)?|EXTENSIONS|FLAGS)$]])
  cet_regex_escape("${PROJECT_NAME}" e_proj)
  list(FILTER vars INCLUDE REGEX "^(UPS_${e_proj}|${e_proj}_UPS)_")
  foreach (var IN LISTS vars lang_vars)
    if (${var})
    endif()
  endforeach()
endfunction()

function(_project_var_to_ups_path VAR_NAME RESULT_VAR)
  if (VAR_NAME IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    get_project_variable_property(${VAR_NAME} PROPERTY TYPE)
  else()
    unset(${RESULT_VAR} PARENT_SCOPE)
    return()
  endif()
  if (NOT TYPE MATCHES [[_FRAGMENT$]]) # Not eligible for tweak.
    set(${RESULT_VAR} ${${PROJECT_NAME}_${VAR_NAME}} PARENT_SCOPE)
    return()
  endif()
  if (${PROJECT_NAME}_EXEC_PREFIX)
    cet_regex_escape("${${PROJECT_NAME}_EXEC_PREFIX}/" regex)
    set(replacement [[${${UPS_PROD_NAME_UC}_FQ_DIR}/]])
    list(TRANSFORM ${PROJECT_NAME}_${VAR_NAME} REPLACE
      "^${regex}([^/].*)$" "${replacement}\\1" OUTPUT_VARIABLE result)
  else()
    set(result "${${PROJECT_NAME}_${VAR_NAME}}")
  endif()
  set(replacement [[${UPS_PROD_DIR}/]])
  list(TRANSFORM result REPLACE "^([^\$/].*)$" "${replacement}\\1")
  list(JOIN result ":" result_string)
  set(${RESULT_VAR} "${result_string}" PARENT_SCOPE)
endfunction()

function(_ups_set_variables)
  ##################
  # UPS product name (project-specific, cached).
  string(TOLOWER "${PROJECT_NAME}" default_product_name)
  string(REGEX REPLACE [=[[^a-z0-9]]=] "_" default_product_name
    "${default_product_name}")
  set(${PROJECT_NAME}_UPS_PRODUCT_NAME "${default_product_name}"
    CACHE STRING "The UPS product name for CMake project ${PROJECT_NAME}")
  ##################

  ##################
  # Version consistency check.
  ##################
  if (CETPKG_CMAKE_PROJECT_VERSION AND
      NOT CETPKG_CMAKE_PROJECT_VERSION STREQUAL PROJECT_VERSION)
    message(FATAL_ERROR "consistency error! Mismatch between version \
project(${PROJECT_NAME} VERSION ${CETPKG_CMAKE_PROJECT_VERSION}...) \
and PROJECT_VERSION as-set (${PROJECT_VERSION}). Verify \
cmake_minimum_required(VERSION X) or \
cmake_minimum_required(VERSION X...Y) with X >=3.16 and CMake policy \
CMP0096 NEW *PRIOR* to project() call to preserve leading \
zeros in project versions.\
")
  endif()

  ##################
  # UPS product version (project-specific).
  to_ups_version("${PROJECT_VERSION}" UPS_PRODUCT_VERSION)
  set(${PROJECT_NAME}_UPS_PRODUCT_VERSION ${UPS_PRODUCT_VERSION} CACHE STRING
    "Project's UPS version")

  ##################
  # Qualifiers (project-specific, cached).
  set(${PROJECT_NAME}_UPS_QUALIFIER_STRING CACHE STRING
    "The `:'-delimited list of UPS qualifers")

  ##################
  # UPS flavor (project-specific, cached)
  set(${PROJECT_NAME}_UPS_PRODUCT_FLAVOR CACHE STRING
    "The appropriate UPS flavor for CMake project ${PROJECT_NAME}")

  mark_as_advanced(${PROJECT_NAME}_UPS_PRODUCT_NAME
    ${PROJECT_NAME}_UPS_PRODUCT_VERSION
    ${PROJECT_NAME}_UPS_QUALIFIER_STRING
    ${PROJECT_NAME}_UPS_PRODUCT_FLAVOR)

  ##################
  # UPS product installation directory (project-specific).
  set(UPS_PRODUCT_SUBDIR
    "${${PROJECT_NAME}_UPS_PRODUCT_NAME}/${UPS_PRODUCT_VERSION}")
  set(${PROJECT_NAME}_UPS_PRODUCT_SUBDIR "${UPS_PRODUCT_SUBDIR}" PARENT_SCOPE)

  ##################
  # UPS table file directory (project-specific).
  set(UPS_PRODUCT_UPS_DIR ups)
  if (${PROJECT_NAME}_EXEC_PREFIX)
    string(PREPEND UPS_PRODUCT_UPS_DIR "${${PROJECT_NAME}_EXEC_PREFIX}/")
  endif()
  set(${PROJECT_NAME}_UPS_PRODUCT_UPS_DIR "${UPS_PRODUCT_UPS_DIR}" PARENT_SCOPE)

  ##################
  # UPS version file name and installation location (project-specific).
  string(REPLACE ":" "_" UPS_PRODUCT_VERSION_FILE
    "${${PROJECT_NAME}_UPS_QUALIFIER_STRING}")
  string(PREPEND UPS_PRODUCT_VERSION_FILE "${${PROJECT_NAME}_UPS_PRODUCT_FLAVOR}_")
  set(${PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE ${UPS_PRODUCT_VERSION_FILE}
    PARENT_SCOPE)

  ##################
  # UPS binary archive destination directory.
  set(UPS_TAR_DIR "${CMAKE_BINARY_DIR}"
    CACHE PATH "The output directory for all generated UPS product archives.")

  ##################
  # Should we configure PYTHONPATH in the table file?
  project_variable(DEFINE_PYTHONPATH TYPE BOOL)

  ##################
  # CPack configuration
  set(CETMODULES_CONFIG_CPACK_MACRO _ups_config_cpack PARENT_SCOPE)
endfunction()

function(_table_var_clause LABEL OUT_VAR)
  cmake_parse_arguments(PARSE_ARGV 2 _TVC
    "APPEND"
    "BASE_INDENT;IF_TEST;INDENT;PVAR"
    "ELSE_IMPL;VAL")
  if (_TVC_PVAR AND _TVC_VAL)
    message(FATAL_ERROR "INTERNAL: PVAR and VAL are mutually-exclusive in _table_var_clause()")
  endif()
  if (_TVC_PVAR)
    _project_var_to_ups_path(${_TVC_PVAR} VAL)
  else()
    set(VAL "${_TVC_VAL}")
  endif()
  if (NOT VAL)
    if (NOT _TVC_APPEND) # Truncate.
      set(${VAR} PARENT_SCOPE)
    endif()
    return()
  endif()
  if (NOT _TVC_BASE_INDENT MATCHES [=[^[1-9]]=])
    set(_TVC_BASE_INDENT 4)
  endif()
  if (NOT _TVC_INDENT MATCHES [=[^[1-9]]=])
    set(_TVC_INDENT 2)
  endif()
  string(REPEAT " " ${_TVC_BASE_INDENT} BI)
  string(REPEAT " " ${_TVC_INDENT} I)
  set(in_text "# ${LABEL}\n")
  if (_TVC_IF_TEST)
    string(REGEX REPLACE "(\n|;)" "\\1${I}" tmp "${I}${_TVC_UNPARSED_ARGUMENTS}")
    list(JOIN tmp "\n" tmp_string)
    string(APPEND in_text
      "if ( ${_TVC_IF_TEST} )\n" "${tmp_string}" "\nelse()\n")
    if (_TVC_ELSE_IMPL)
      string(REGEX REPLACE "(\n|;)" "\\1${I}" tmp "${I}${_TVC_ELSE_IMPL}")
      string(JOIN tmp "\n" tmp_string)
      string(APPEND in_text "${tmp_string}\n")
    endif()
    string(APPEND in_text "endIf ( ${_TVC_IF_TEST} )\n")
  else()
    string(JOIN "\n" tmp ${_TVC_UNPARSED_ARGUMENTS})
    string(APPEND in_text "${tmp}\n")
  endif()
  string(CONFIGURE "${in_text}" RESULT @ONLY)
  set(pre)
  if (_TVC_APPEND)
    set(pre "${${OUT_VAR}}")
  endif()
  string(REGEX REPLACE "\n(.)" "\n${BI}\\1" RESULT "${BI}${RESULT}")
  set(${OUT_VAR} "${pre}${RESULT}" PARENT_SCOPE)
endfunction()

function(_ups_verify_compilers)
  foreach(lang IN ITEMS C CXX Fortran)
    if (CMAKE_${lang}_COMPILER_ID AND UPS_${lang}_COMPILER_ID)
      if (NOT CMAKE_${lang}_COMPILER_ID STREQUAL UPS_${lang}_COMPILER_ID)
        message(ERROR "Enabled ${lang} compiler ${CMAKE_${lang}_COMPILER_ID}"
          " does not match expected ${UPS_${lang}_COMPILER_ID}")
      endif()
    endif()
    if (CMAKE_${lang}_COMPILER_VERSION AND UPS_${lang}_COMPILER_VERSION)
      if (NOT CMAKE_${lang}_COMPILER_VERSION VERSION_EQUAL
          UPS_${lang}_COMPILER_VERSION)
        message(ERROR "Enabled ${CMAKE_COMPILER_ID} ${lang} compiler version"
          " ${CMAKE_${lang}_COMPILER_VERSION} does not match expected"
          " ${UPS_${lang}_COMPILER_VERSION}")
      endif()
    endif()
  endforeach()
endfunction()

macro(_ups_config_cpack)
  ##################
  # General options.
  set(CPACK_PACKAGE_CHECKSUM SHA256) # Checksums! Dancing bears! Fire eaters!
  set(CPACK_VERBATIM_VARIABLES ON) # Escape contents of CPACK_* variables.

  ##################
  # Package archive location.
  set(CPACK_PACKAGE_DIRECTORY ${UPS_TAR_DIR})

  ##################
  # Archive format(s).

  # Configure as desired globally...
  set(UPS_ARCHIVE_FORMATS TBZ2 CACHE STRING
    "Default list of desired formats for UPS archives")
  # ...or per-project.
  set(${PROJECT_NAME}_UPS_ARCHIVE_FORMATS ${UPS_ARCHIVE_FORMATS}
    CACHE STRING
    "List of desired archive formats for CMake project ${PROJECT_NAME} (see cpack-generators)")
  mark_as_advanced(${PROJECT_NAME}_UPS_ARCHIVE_FORMATS)
  if (NOT CPACK_GENERATOR)
    set(CPACK_GENERATOR ${${PROJECT_NAME}_UPS_ARCHIVE_FORMATS})
  endif()

  ##################
  # Package vendor.
  if (NOT CPACK_PACKAGE_VENDOR)
    set(CPACK_PACKAGE_VENDOR "FNAL SciSoft Team")
  endif()

  ##################
  # CPACK_SYSTEM_NAME.
  if (${PROJECT_NAME}_EXEC_PREFIX)
    # If we're NULL-flavored, ${PROJECT_NAME}_EXEC_PREFIX will already
    # start with noarch-, per set_dev_products.
    string(REGEX REPLACE [[/$]] "" CPACK_SYSTEM_NAME "${${PROJECT_NAME}_EXEC_PREFIX}")
    string(REPLACE "." "-" CPACK_SYSTEM_NAME "${CPACK_SYSTEM_NAME}")
  else()
    string(REPLACE ":" "-" CPACK_SYSTEM_NAME "${${PROJECT_NAME}_QUALIFIER_STRING}")
    string(JOIN "-" CPACK_SYSTEM_NAME noarch ${CPACK_SYSTEM_NAME})
  endif()

  ##################
  # Installer-specific files for non-archive generators.
  foreach(v IN ITEMS LICENSE README WELCOME)
    if (DEFINED ${PROJECT_NAME}_CPACK_RESOURCE_FILE_${v})
      set(CPACK_RESOURCE_FILE_${v} "${${PROJECT_NAME}_CPACK_RESOURCE_FILE_${v}}")
    endif()
  endforeach()

  ##################
  # Archive internal structure per UPS conventions.
  set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
endmacro()

macro(_ups_init)
  # Define UPS-specific variables.
  _ups_set_variables()

  # Check we're using the requested compilers.
  _ups_verify_compilers()

  # Avoid warning messages for unused variables defined on the command
  # line by buildtool.
  _ups_use_maybe_unused()
endmacro()

cmake_policy(POP)
