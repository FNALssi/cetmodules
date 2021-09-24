# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

if (NOT WANT_UPS)
  message(FATAL_ERROR
    "add -DWANT_UPS:BOOL=ON to the CMake command line (recommended:"
    " use buildtool)")
endif()

include(CetCMakeUtils)
include(CetRegexEscape)
include(GenerateFromFragments)

function(process_ups_files)
  if (NOT CETMODULES_CONFIG_CPACK_MACRO STREQUAL "_ups_config_cpack")
    message(FATAL_ERROR "Set the CMake variable WANT_UPS prior to including"
      " CetCMakeEnv.cmake to activate UPS table file and tarball generation."
      "\nUps.cmake should not be included directly.")
  endif()

  # Calculate the path for the table and version files.
  set(table_file
    "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_TABLE_SUBDIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}.table")

  if (EXISTS "${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}/${table_file}")
    message(VERBOSE "Installing package-provided UPS table file ${table_file}")
    set(tf_src_dir "${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}")
  else()
    set(tf_src_dir "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}")
    # Generate the UPS table file.
    _build_ups_table_file()
  endif()

  # Install it.
  install(FILES "${tf_src_dir}/${table_file}"
    DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_TABLE_SUBDIR})

  ##################
  # Generate the UPS version and chain files.

  # Required temporary variables for substitution.
  foreach (v IN ITEMS UPS_PRODUCT_FLAVOR UPS_PRODUCT_NAME UPS_PRODUCT_VERSION UPS_PRODUCT_SUBDIR
      UPS_QUALIFIER_STRING UPS_PRODUCT_TABLE_SUBDIR)
    set(${v} ${${CETMODULES_CURRENT_PROJECT_NAME}_${v}})
  endforeach()
  cet_timestamp(UPS_DECLARE_DATE)
  # Generate the version file.

  cet_localize_pv(cetmodules CONFIG_DIR)
  configure_file("${cetmodules_CONFIG_DIR}/ups/product-version-file.in"
    "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_TABLE_SUBDIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
    @ONLY)
  # Install it.
  install(FILES
    "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_TABLE_SUBDIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
    DESTINATION ../${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}.version)
  # Generate and install any requested chain files.
  foreach (UPS_PRODUCT_CHAIN IN LISTS ${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_CHAINS)
    # Generate with chain name prepended to avoid conflicts or the need
    # for a deeper hierarchy in the build area.
    configure_file("${cetmodules_CONFIG_DIR}/ups/product-chain-file.in"
      "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_TABLE_SUBDIR}/${UPS_PRODUCT_CHAIN}.${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
      @ONLY)
    # Install.
    install(FILES
      "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_TABLE_SUBDIR}/${UPS_PRODUCT_CHAIN}.${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}"
      DESTINATION "../${UPS_PRODUCT_CHAIN}.chain"
      RENAME "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION_FILE}")
  endforeach()
endfunction()

##################
function(_build_ups_table_file)
  ##################
  # Calculate derivative variables only needed for the table file.

  # Flavor.
  set(UPS_TABLE_FLAVOR "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_FLAVOR}")

  # Qualifiers.
  if (${CETMODULES_CURRENT_PROJECT_NAME}_UPS_QUALIFIER_STRING)
    set(UPS_QUALIFIER_STRING "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_QUALIFIER_STRING}")
  endif()

  # Dependencies.
  file(READ
    "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/table_deps_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}"
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
  if (${CETMODULES_CURRENT_PROJECT_NAME}_DEFINE_PYTHONPATH)
    if (libdir)
      set(pp_path_var [[${${UPS_PROD_NAME_UC}_LIB}]])
    elseif (${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX)
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
    IF_TEST [[test -n "@VAL@"]]
    [[pathPrepend(FW_SEARCH_PATH, "@VAL@")]])
  _table_var_clause("GDML_DIR -> FW_SEARCH_PATH" TABLE_VARS APPEND
    PVAR GDML_DIR
    IF_TEST [[test -d "@VAL@"]]
    [[pathPrepend(FW_SEARCH_PATH, "@VAL@")]])
  _table_var_clause("FW_DIR -> FW_SEARCH_PATH" TABLE_VARS APPEND
    PVAR FW_DIR
    IF_TEST [[test -d "@VAL@"]]
    [[pathPrepend(FW_SEARCH_PATH, "@VAL@")]])

  # WIRECELL_PATH.
  _table_var_clause(WIRECELL_PATH TABLE_VARS APPEND
    PVAR WIRECELL_PATH
    IF_TEST [[test -n "@VAL@"]]
    [[pathPrepend(WIRECELL_PATH, "@VAL@")]])
  _table_var_clause("WP_DIR -> WIRECELL_PATH" TABLE_VARS APPEND
    PVAR WP_DIR
    IF_TEST [[test -d "@VAL@"]]
    [[pathPrepend(WIRECELL_PATH, "@VAL@")]])

  # PERL5LIB.
  _table_var_clause(PERL5LIB TABLE_VARS APPEND
    PVAR PERLLIB_DIR
    IF_TEST [[test -d "@VAL@"]]
    [[pathPrepend(PERL5LIB, "@VAL@")]])

  # CMAKE_PREFIX_PATH.
  if (${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX)
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

  if (EXISTS "${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}/${table_file}.in")
    configure_file(${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}/${table_file}.in
      ${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${table_file} @ONLY)
  else() # Generate according to information we've gathered.
    # Find a table fragment if we have one.
    set(table_frag_file
      "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/table_frag_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")
    if (NOT EXISTS "${table_frag_file}")
      unset(table_frag_file)
    endif()

    # Generate the UPS table file from its fragments.
    cet_localize_pv(cetmodules CONFIG_DIR)
    set(UPS_SETUP_PREAMBLE "\
    ##################
    # Basic common setup.\n\
")
    # cetbuildtools is special, because we preempt it.
    if (NOT CETMODULES_CURRENT_PROJECT_NAME STREQUAL cetbuildtools)
      string(APPEND UPS_SETUP_PREAMBLE "    prodDir()\n")
    endif()
    string(APPEND UPS_SETUP_PREAMBLE "    setupEnv()\n")
    generate_from_fragments("${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${table_file}"
      NO_FRAGMENT_DELIMITERS
      FRAGMENTS
      "${cetmodules_CONFIG_DIR}/ups/product.table.top.in"
      ${table_frag_file}
      "${cetmodules_CONFIG_DIR}/ups/product.table.bottom.in")
  endif()
endfunction()

function(_project_var_to_ups_path VAR_NAME RESULT_VAR)
  if (VAR_NAME IN_LIST CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    get_project_variable_property(${VAR_NAME} PROPERTY TYPE)
  else()
    unset(${RESULT_VAR} PARENT_SCOPE)
    return()
  endif()
  set(result "${${CETMODULES_CURRENT_PROJECT_NAME}_${VAR_NAME}}")
  if (TYPE MATCHES [[_FRAGMENT$]]) # Eligible for tweak.
    if (${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX)
      cet_regex_escape("${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}/" regex)
      set(replacement [[${${UPS_PROD_NAME_UC}_FQ_DIR}/]])
      list(TRANSFORM result REPLACE "^${regex}([^/].*)$" "${replacement}\\1")
    endif()
    set(replacement [[${UPS_PROD_DIR}/]])
    list(TRANSFORM result REPLACE "^([^\$/].*)$" "${replacement}\\1")
  endif()
  list(JOIN result ":" result_string)
  set(${RESULT_VAR} "${result_string}" PARENT_SCOPE)
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
  set(${CETMODULES_CURRENT_PROJECT_NAME}_UPS_ARCHIVE_FORMATS ${UPS_ARCHIVE_FORMATS}
    CACHE STRING
    "List of desired archive formats for CMake project ${CETMODULES_CURRENT_PROJECT_NAME} (see cpack-generators)")
  mark_as_advanced(${CETMODULES_CURRENT_PROJECT_NAME}_UPS_ARCHIVE_FORMATS)
  if (NOT CPACK_GENERATOR)
    set(CPACK_GENERATOR ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_ARCHIVE_FORMATS})
  endif()

  ##################
  # Package vendor.
  if (NOT CPACK_PACKAGE_VENDOR)
    set(CPACK_PACKAGE_VENDOR "FNAL SciSoft Team")
  endif()

  ##################
  # CPACK_SYSTEM_NAME.
  if (${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX)
    # If we're NULL-flavored, ${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX will already
    # start with noarch-, per set_dev_products.
    string(REGEX REPLACE [[/$]] "" CPACK_SYSTEM_NAME "${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}")
    string(REPLACE "." "-" CPACK_SYSTEM_NAME "${CPACK_SYSTEM_NAME}")
  else()
    string(REPLACE ":" "-" CPACK_SYSTEM_NAME "${${CETMODULES_CURRENT_PROJECT_NAME}_QUALIFIER_STRING}")
    string(JOIN "-" CPACK_SYSTEM_NAME noarch ${CPACK_SYSTEM_NAME})
  endif()

  ##################
  # Installer-specific files for non-archive generators.
  foreach(v IN ITEMS LICENSE README WELCOME)
    if (DEFINED ${CETMODULES_CURRENT_PROJECT_NAME}_CPACK_RESOURCE_FILE_${v})
      set(CPACK_RESOURCE_FILE_${v} "${${CETMODULES_CURRENT_PROJECT_NAME}_CPACK_RESOURCE_FILE_${v}}")
    endif()
  endforeach()

  ##################
  # Archive internal structure per UPS conventions.
  set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
endmacro()

function(_ups_verify_compilers)
  foreach(lang IN ITEMS C CXX Fortran)
    if (CMAKE_${lang}_COMPILER_ID AND UPS_${lang}_COMPILER_ID)
      if (NOT CMAKE_${lang}_COMPILER_ID STREQUAL UPS_${lang}_COMPILER_ID)
        message(SEND_ERROR "Enabled ${lang} compiler ${CMAKE_${lang}_COMPILER_ID}"
          " does not match expected ${UPS_${lang}_COMPILER_ID}")
      endif()
    endif()
    if (CMAKE_${lang}_COMPILER_VERSION AND UPS_${lang}_COMPILER_VERSION)
      cet_compare_versions(version_ok "${CMAKE_${lang}_COMPILER_VERSION}"
        VERSION_EQUAL "${UPS_${lang}_COMPILER_VERSION}")
      if (NOT version_ok)
        message(SEND_ERROR "Enabled ${CMAKE_COMPILER_ID} ${lang} compiler version"
          " ${CMAKE_${lang}_COMPILER_VERSION} does not match expected"
          " ${UPS_${lang}_COMPILER_VERSION}")
      endif()
    endif()
  endforeach()
endfunction()

macro(_ups_product_prep)
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
    mark_as_advanced(FORCE UPS_${lang}_COMPILER_ID UPS_${lang}_COMPILER_VERSION)
  endforeach()

  # Check we're using the requested compilers.
  _ups_verify_compilers()

  if (CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME OR
      NOT DEFINED CACHE{CETMODULES_CMAKE_INSTALL_PREFIX_ORIG})
    set(CETMODULES_CMAKE_INSTALL_PREFIX_ORIG "${CMAKE_INSTALL_PREFIX}"
      CACHE INTERNAL "Original value of CMAKE_INSTALL_PREFIX")
  else()
    set(CMAKE_INSTALL_PREFIX "${CETMODULES_CMAKE_INSTALL_PREFIX_ORIG}")
  endif()
  install(CODE "\
# Tweak the value of CMAKE_INSTALL_PREFIX used by the project's
  # cmake_install.cmake files per UPS conventions.
  string(APPEND CMAKE_INSTALL_PREFIX \"/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_SUBDIR}\")\
")

  # Install a delayed installation of a delayed function call to fix
  # legacy installation calls. No, really.
  cmake_language(DEFER DIRECTORY "${PROJECT_SOURCE_DIR}" CALL
    cmake_language DEFER DIRECTORY "${PROJECT_SOURCE_DIR}" CALL _restore_install_prefix)

  ##################
  # CPack configuration
  set(CETMODULES_CONFIG_CPACK_MACRO _ups_config_cpack)
endmacro()

function(_restore_install_prefix)
  message(DEBUG "Executing delayed install(CODE...)")
  # With older CMakeLists.txt files, deal with low level install()
  # invocations with an extra "${project}/${version}"
  install(CODE "\
# Detect misplaced installs from older, cetbuildtools-using packages.
  if (IS_DIRECTORY \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}\")
    message(STATUS \"tidying legacy installations: relocate ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}/*\")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar c \"../../${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}-tmpinstall.tar\" .
                    WORKING_DIRECTORY \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}\"
                    COMMAND_ERROR_IS_FATAL ANY)
    file(REMOVE_RECURSE \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}\")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xv \"${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}-tmpinstall.tar\"
                    WORKING_DIRECTORY \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}\"
                    OUTPUT_VARIABLE _cet_install_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}_legacy
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND rmdir \"${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}\"
                    WORKING_DIRECTORY \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}\"
                    OUTPUT_QUIET
                    ERROR_QUIET)
    message(STATUS \"in \$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}: \${_cet_install_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}_legacy}\")
    unset(_cet_install_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}_legacy)
    file(REMOVE \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}-tmpinstall.tar\")
  endif()

  # We need to reset CMAKE_INSTALL_PREFIX to its original value at this
  # time.
  get_filename_component(CMAKE_INSTALL_PREFIX \"\${CMAKE_INSTALL_PREFIX}\" DIRECTORY)
  get_filename_component(CMAKE_INSTALL_PREFIX \"\${CMAKE_INSTALL_PREFIX}\" DIRECTORY)\
")
  cet_regex_escape("/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}" e_pv 1)
  # Fix the install manifest at the top level.
  cmake_language(EVAL CODE "\
cmake_language(DEFER DIRECTORY \"${CMAKE_SOURCE_DIR}\" CALL
  install CODE \"\
list(TRANSFORM CMAKE_INSTALL_MANIFEST_FILES REPLACE \\\"${e_pv}${e_pv}\\\" \\\"/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}\\\")\
\")\
")
endfunction()


cmake_policy(POP)
