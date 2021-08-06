#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# CetMake.cmake
#
# Identify the files in the current source directory and deal with them
# appropriately.
#
# Users may opt to just invoke cet_make() in their CMakeLists.txt
#
# This implementation is intended to be called NO MORE THAN ONCE per
# subdirectory.
#
# NOTE: cet_make_exec is no longer part of cet_make or art_make and must
# be called explicitly.
#
# cet_make( [LIBRARY_NAME <library name>]
#           [LIBRARIES <library link list>]
#           [SUBDIRS <source subdirectory>] (e.g., detail)
#           [USE_PRODUCT_NAME]
#           [EXCLUDE <ignore these files>] )
#
#   If USE_PRODUCT_NAME is specified, the product name will be prepended
#   to the calculated library name
#   USE_PRODUCT_NAME and LIBRARY_NAME are mutually exclusive
#
#   NOTE: if your code includes art plugins, you MUST use art_make
#   instead of cet_make: cet_make will ignore all known plugin code.
#
# cet_make_library( LIBRARY_NAME <library name>
#                   SOURCE <source code list>
#                   [LIBRARIES <library list>]
#                   [WITH_STATIC_LIBRARY]
#                   [NO_INSTALL] )
#
#   Make the named library.
#
# cet_make_exec( <executable name>
#                [SOURCE <source code list>]
#                [LIBRARIES <library link list>]
#                [USE_BOOST_UNIT]
#                [NO_INSTALL] )
#
#   Build a regular executable.
#
# cet_script( <script-names> ...
#             [DEPENDENCIES <deps>]
#             [NO_INSTALL]
#             [GENERATED]
#             [REMOVE_EXTENSIONS] )
#
#   Copy the named scripts to ${${CETMODULES_CURRENT_PROJECT_NAME}_SCRIPTS_DIR} (usually bin/).
#
#   If the GENERATED option is used, the script will be copied from
#   ${CMAKE_CURRENT_BINARY_DIR} (after being made by a CONFIGURE
#   command, for example); otherwise it will be copied from
#   ${CMAKE_CURRENT_SOURCE_DIR}.
#
#   If REMOVE_EXTENSIONS is specified, extensions will be removed from script names
#   when they are installed.
#
#   NOTE: If you wish to use one of these scripts in a CUSTOM_COMMAND,
#   list its name in the DEPENDS clause of the CUSTOM_COMMAND to ensure
#   it gets re-run if the script chagees.
#
# cet_lib_alias(LIB_TARGET <alias>+)
#
#   Create a courtesy link to the library specified by LIB_TARGET for
#   each specified <alias>, for e.g. backward compatibility
#   reasons. LIB_TARGET must be a target defined (ultimately) by
#   add_library.
#
#   e.g. cet_lib_alias(nutools_SimulationBase SimulationBase) would
#   create a new link (e.g.) libSimulationBase.so to the generated
#   library libnutools_SimulationBase.so (replace .so with .dylib for OS
#   X systems).
#
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetCopy)
include(CetPackagePath)
include(CetProcessLiblist)
include(CetRegisterExportSet)

set(_cet_make_usage "\
USAGE: cet_make([USE_(PROJECT|PRODUCT)_NAME|LIBRARY_NAME <library-name>]
                [LIB_LIBRARIES <library-dependencies>...]
                [LIB_LOCAL_INCLUDE_DIRS <include-dirs>...]
                [DICT_LIBRARIES <dict-library-dependencies>...]
                [DICT_LOCAL_INCLUDE_DIRS <include-dirs>...]
                [SUBDIRS <source-subdir>...]
                [EXCLUDE ([REGEX] <exclude>...)...]
                [LIB_ALIAS <alias>...]
                [VERSION] [SOVERSION <API-version>]
                [EXPORT_SET <export-name>]
                [NO_INSTALL|INSTALL_LIBS_ONLY]
                [NO_DICTIONARY] [USE_PRODUCT_NAME] [WITH_STATIC_LIBRARY])\
")

set(_cet_make_flags BASENAME_ONLY EXCLUDE_FROM_ALL INSTALL_LIBS_ONLY
  LIB_INTERFACE LIB_MODULE LIB_OBJECT LIB_ONLY LIB_SHARED LIB_STATIC
  NO_DICTIONARY NO_EXPORT NO_INSTALL NO_LIB NO_LIB_SOURCE NOP
  USE_PRODUCT_NAME USE_PROJECT_NAME VERSION WITH_STATIC_LIBRARY)

set(_cet_make_one_arg_options EXPORT_SET LIBRARY_NAME LIBRARY_NAME_VAR
  SOVERSION)

set(_cet_make_list_options DICT_LIBRARIES DICT_LOCAL_INCLUDE_DIRS
  EXCLUDE LIB_ALIAS LIB_LIBRARIES LIB_LOCAL_INCLUDE_DIRS LIB_SOURCE
  LIBRARIES SUBDIRS)

function(cet_make)
  cmake_parse_arguments(PARSE_ARGV 0 CM
    "${_cet_make_flags}"
    "${_cet_make_one_arg_options}"
    "${_cet_make_list_options}")
  # Argument verification.
  _cet_verify_cet_make_args()
  ##################
  # Prepare common passthroughs.
  cet_passthrough(IN_PLACE CM_EXPORT_SET)
  foreach (flag EXCLUDE_FROM_ALL NO_EXPORT NO_INSTALL USE_PROJECT_NAME VERSION)
    cet_passthrough(FLAG IN_PLACE CM_${flag})
  endforeach()
  ##################
  if (NOT (CM_NO_LIB OR "LIB_SOURCE" IN_LIST CM_KEYWORDS_MISSING_VALUES))
    # We want a library.
    _cet_maybe_make_library()
    if (CM_LIBRARY_NAME_VAR)
      set(${CM_LIBRARY_NAME_VAR} "${${CM_LIBRARY_NAME_VAR}}" PARENT_SCOPE)
    endif()
  endif()
  if (CM_LIB_ONLY)
    return()
  endif()
  # Look for the makings of a dictionary and decide how to make it.
  if (NOT CM_NO_DICTIONARY AND
      EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/classes.h")
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/classes_def.xml")
      cet_passthrough(IN_PLACE KEYWORD LOCAL_INCLUDE_DIRS
        CM_DICT_LOCAL_INCLUDE_DIRS)
      include(BuildDictionary)
      build_dictionary(${CM_LIBRARY_NAME}
        DICTIONARY_LIBRARIES ${CM_DICT_LIBRARIES} NOP
        ${CM_DICT_LOCAL_INCLUDE_DIRS} ${CM_USE_PROJECT_NAME}
        ${CM_EXPORT_SET} ${CM_NO_EXPORT} ${CM_NO_INSTALL}
        ${CM_VERSION})
    elseif (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/LinkDef.h")
      include(CetRootCint)
      cet_rootcint(${CM_LIBRARY_NAME}
        ${CM_DICT_LOCAL_INCLUDE_DIRS} ${CM_USE_PROJECT_NAME}
        ${CM_EXPORT_SET} ${CM_NO_EXPORT} ${CM_NO_INSTALL}
        ${CM_VERSION})
    endif()
  endif()
endfunction()

set(_cet_make_exec_usage "")

function(cet_make_exec)
  cmake_parse_arguments(PARSE_ARGV 0 CME
    "EXCLUDE_FROM_ALL;NO_EXPORT;NO_EXPORT_ALL_SYMBOLS;NO_INSTALL;NOP;USE_BOOST_UNIT;USE_CATCH_MAIN;USE_CATCH2_MAIN"
    "EXEC_NAME;EXPORT_SET;NAME" "LIBRARIES;LOCAL_INCLUDE_DIRS;SOURCE")
  # Argument verification.
  if (CME_EXEC_NAME)
    warn_deprecated("EXEC_NAME" NEW "NAME")
    set(CME_NAME "${CME_EXEC_NAME}")
    unset(CME_EXEC_NAME)
  elseif (NOT CME_NAME)
    warn_deprecated("<name> as non-option argument to cet_make_exec()"
      NEW "cet_make_exec(NAME <name> ...)")
    list(POP_FRONT CME_UNPARSED_ARGUMENTS CME_NAME)
  endif()
  if (NOT CME_NAME)
    message(FATAL_ERROR "NAME <name> *must* be provided")
  elseif (CME_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "non-option arguments prohibited: ${CME_UNPARSED_ARGUMENTS}")
  endif()
  if (CME_USE_CATCH_MAIN)
    warn_deprecated("cet_make_exec(): USE_CATCH_MAIN" NEW "USE_CATCH2_MAIN")
    set(CME_USE_CATCH2_MAIN TRUE)
    unset(CME_USE_CATCH_MAIN)
  endif()
  if (NOT DEFINED CME_SOURCE)
    cet_source_file_extensions(source_glob)
    list(TRANSFORM source_glob PREPEND "${CME_NAME}.")
    file(GLOB found_sources CONFIGURE_DEPENDS ${source_glob})
    list(LENGTH found_sources n_sources)
    if (n_sources EQUAL 1)
      list(POP_FRONT found_sources CME_SOURCE)
    elseif (n_sources EQUAL 0)
      message(WARNING "no suitable candidate source found for ${CME_NAME} from \
enabled languages ${_cet_enabled_languages} in ${CMAKE_CURRENT_SOURCE_DIR}.
If this is intentional, specify with dangling SOURCE keyword to silence this warning\
")
    else()
      message(FATAL_ERROR
        "unable to identify a unique candidate source for ${CME_NAME} - found:"
        "\n${found_sources}\nUse SOURCE <sources> to remove ambiguity")
    endif()
  endif()
  cet_passthrough(FLAG IN_PLACE CME_EXCLUDE_FROM_ALL)
  # Define the main executable target.
  add_executable(${CME_NAME} ${CME_SOURCE} ${CME_EXCLUDE_FROM_ALL})
  # Local include directories.
  if (NOT (DEFINED CME_LOCAL_INCLUDE_DIRS OR
        "LOCAL_INCLUDE_DIRS" IN_LIST CME_KEYWORDS_MISSING_VALUES))
    set(CME_LOCAL_INCLUDE_DIRS
      "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}" "${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}")
  endif()
  target_include_directories(${CME_NAME}
    PRIVATE ${CME_LOCAL_INCLUDE_DIRS})
  # Handle Boost unit test framework.
  if (CME_USE_BOOST_UNIT)
    find_package(Boost PRIVATE QUIET COMPONENTS unit_test_framework REQUIRED)
    if (TARGET Boost::unit_test_framework AND Boost_VERSION VERSION_GREATER_EQUAL 1.70.0)
      target_link_libraries(${CME_NAME} PRIVATE Boost::unit_test_framework)
      # Belt and braces (cf historical bug in fhiclcpp tests).
      target_compile_definitions(${CME_NAME} PRIVATE BOOST_TEST_NO_OLD_TOOLS)
    else()
      # *Someone* didn't use Boost's CMake config file to define targets.
      target_link_libraries(${CME_NAME} PRIVATE ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY})
      target_compile_definitions(${CME_NAME} PRIVATE
        "BOOST_TEST_MAIN;BOOST_TEST_DYN_LINK")
    endif()
  endif()
  # Handle request for Catch2 main.
  if (CME_USE_CATCH2_MAIN)
    find_package(Catch2 PRIVATE QUIET REQUIRED)
    if (NOT TARGET Catch2_main)
      cet_localize_pv(cetmodules CATCH2_MAIN)
      get_property(catch2_include_dir TARGET Catch2::Catch2 PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
      list(POP_FRONT catch2_include_dir catch2_include_subdir)
      if (EXISTS "${catch2_include_subdir}/catch2")
        set(catch2_include_subdir "catch2")
      else()
        set(catch2_include_subdir "catch")
      endif()
      cet_make_library(LIBRARY_NAME Catch2_main STATIC STRIP_LIBS
        EXCLUDE_FROM_ALL NO_INSTALL
        SOURCE ${cetmodules_CATCH2_MAIN}
        LIBRARIES PRIVATE Catch2::Catch2)
      target_compile_definitions(Catch2_main PRIVATE
        "CET_CATCH2_INCLUDE_SUBDIR=${catch2_include_subdir}")
    endif()
    target_link_libraries(${CME_NAME} PRIVATE Catch2_main Catch2::Catch2)
  endif()
  if (NOT CME_NO_EXPORT_ALL_SYMBOLS)
    target_link_options(${CME_NAME} PRIVATE -rdynamic)
  endif()
  # Library links.
  cet_process_liblist(liblist ${CME_NAME} PRIVATE ${CME_LIBRARIES})
  target_link_libraries(${CME_NAME} ${liblist})
  # For target aliases.
  cet_register_export_set(SET_NAME ${CME_EXPORT_SET} SET_VAR CME_EXPORT_SET NAMESPACE_VAR namespace)
  ##################
  # Installation.
  if (NOT CME_NO_INSTALL)
    install(TARGETS ${CME_NAME} EXPORT ${CME_EXPORT_SET}
      RUNTIME DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_BIN_DIR})
    if (NOT CME_NO_EXPORT)
      _add_to_exported_targets(EXPORT_SET ${CME_EXPORT_SET} TARGETS ${CME_NAME})
    endif()
  endif()
  add_executable(${namespace}::${CME_NAME} ALIAS ${CME_NAME})
  foreach (alias IN LISTS CME_ALIAS)
    add_executable(${namespace}::${alias} ALIAS ${CME_NAME})
  endforeach()
  if (NOT (CME_NO_INSTALL OR CME_NO_EXPORT))
    cet_export_alias(ALIAS_NAMESPACE ${namespace}
      EXPORT_SET ${CME_EXPORT_SET} ALIAS ${CME_ALIAS})
  endif()
endfunction()

function(cet_script)
  cmake_parse_arguments(PARSE_ARGV 0 CS "ALWAYS_COPY;GENERATED;NO_EXPORT;NO_INSTALL;NOP;REMOVE_EXTENSIONS"
    "DESTINATION;EXPORT_SET" "DEPENDENCIES")
  if (CS_GENERATED)
    warn_deprecated("cet_script(GENERATED)"
      " - CMake source property GENERATED is set automatically by add_custom_command, etc. or can be set manually otherwise")
  endif()
  if (NOT CS_DESTINATION)
    set(CS_DESTINATION "${${CETMODULES_CURRENT_PROJECT_NAME}_SCRIPTS_DIR}")
  endif()
  foreach(script IN LISTS CS_UNPARSED_ARGUMENTS)
    unset(need_copy)
    get_property(generated SOURCE "${script}" PROPERTY GENERATED)
    get_filename_component(script_name "${script}" NAME)
    if (generated OR CS_GENERATED)
      get_filename_component(script_source "${script}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    else()
      # Should exist: make sure we can find it and that it is
      # executable.
      get_filename_component(script_source "${script}" ABSOLUTE)
      if (NOT EXISTS "${script_source}")
        message(FATAL_ERROR "${script} is not accessible: correct location or set GENERATED source property")
      endif()
      if (CS_ALWAYS_COPY)
        set(need_copy TRUE)
      else()
        execute_process(COMMAND test -x "${script_source}"
          OUTPUT_QUIET ERROR_QUIET RESULT_VARIABLE need_copy)
      endif()
    endif()
    if (CS_REMOVE_EXTENSIONS)
      get_filename_component(target "${script_source}" NAME_WE)
      cet_passthrough(KEYWORD RENAME target rename_arg)
    else()
      set(target "${script_name}")
    endif()
    cet_register_export_set(SET_NAME ${CS_EXPORT_SET} SET_VAR CS_EXPORT_SET NAMESPACE_VAR ns)
    if (need_copy)
      if (NOT CS_ALWAYS_COPY)
        message(WARNING "${script} is not executable: copying to ${CMAKE_RUNTIME_OUTPUT_DIRECTORY} as PROGRAM")
      endif()
      cet_copy("${script_source}" PROGRAMS
        NAME ${target} NAME_AS_TARGET
        DEPENDENCIES ${CS_DEPENDENCIES}
        DESTINATION "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
      # cet_copy() will create the primary (non-qualified) target as a
      # custom target. We create the namespaced target as IMPORTED
      # rather than ALIAS because one can only create ALIASes to
      # libraries, executables or IMPORTED targets.
      add_executable(${ns}::${target} IMPORTED GLOBAL)
      set_target_properties(${ns}::${target} PROPERTIES
        IMPORTED_LOCATION "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${target}")
    else()
      # "Normal" - non-qualified target is an IMPORTED reference to the
      # source file, and the namespaced target is an ALIAS for
      # transparency between standalone and multi-project (e.g. MRB)
      # builds.
      add_executable(${target} IMPORTED GLOBAL)
      set_target_properties(${target} PROPERTIES
        IMPORTED_LOCATION "${script_source}")
      add_executable(${ns}::${target} ALIAS ${target})
    endif()
    if (NOT CS_NO_INSTALL)
      install(PROGRAMS "${script_source}"
        DESTINATION "${CS_DESTINATION}"
        ${rename_arg})
      if (NOT CS_NO_EXPORT)
        _cet_export_import_cmd(TARGETS ${ns}::${target} COMMANDS "\
add_executable(${ns}::${target} IMPORTED)
set_target_properties(${ns}::${target}
  PROPERTIES IMPORTED_LOCATION \"\${PACKAGE_PREFIX_DIR}/${CS_DESTINATION}/${target}\")\
")
      endif()
    endif()
  endforeach()
endfunction()

macro(_cet_verify_cet_make_args)
  if (CM_UNPARSED_ARGUMENTS)
    warn_deprecated("non-option arguments" NEW "LIBRARIES")
  endif()
  if (CM_NO_INSTALL AND CM_INSTALL_LIBS_ONLY)
    message(FATAL_ERROR "cet_make(): NO_INSTALL and INSTALL_LIBS_ONLY are mutually exclusive")
  endif()
  if (CM_USE_PROJECT_NAME AND CM_USE_PRODUCT_NAME)
    message(WARNING "cet_make(): USE_PRODUCT_NAME and USE_PROJECT_NAME are synonymous")
    unset(CM_USE_PRODUCT_NAME)
  elseif (CM_USE_PROJECT_NAME OR CM_USE_PRODUCT_NAME)
    set(CM_USE_PROJECT_NAME TRUE)
    unset(CM_USE_PRODUCT_NAME)
  endif()
endmacro()

function(_cet_maybe_make_library)
  if (NOT (CM_NO_LIB_SOURCE OR CM_LIB_SOURCE))
    # Look for suitable source files for the library.
    unset(src_file_globs)
    cet_source_file_extensions(source_file_patterns)
    list(TRANSFORM source_file_patterns PREPEND "*.")
    set(src_file_globs ${source_file_patterns})
    foreach(sub IN LISTS CM_SUBDIRS CMAKE_CURRENT_BINARY_DIR)
      list(TRANSFORM source_file_patterns PREPEND "${sub}/"
        OUTPUT_VARIABLE sub_globs)
      list(APPEND src_file_globs ${sub_globs})
    endforeach()
    if (src_file_globs)
      # Invoke CONFIGURE_DEPENDS to force the build system to regenerate
      # if the result of this glob changes. Note that in the case of
      # generated files (in and under ${CMAKE_CURRENT_BINARY_DIR}), this
      # can only be accurate for files generated at configure rather
      # than generate or build time.
      file(GLOB CM_LIB_SOURCE CONFIGURE_DEPENDS ${src_file_globs})
    endif()
    cet_exclude_files_from(CM_LIB_SOURCE ${CM_EXCLUDE} NOP
      REGEX [=[_(generator|module|plugin|service|source|tool)\.cc$]=]
      [=[_dict\.cpp$]=] NOP)
  endif()
  if (CM_LIB_SOURCE OR CM_NO_LIB_SOURCE) # We have a library to build.
    set(cml_args)
    # Simple passthrough.
    cet_passthrough(IN_PLACE CM_LIBRARY_NAME)
    if (CM_LIBRARY_NAME_VAR)
      list(APPEND cml_args LIBRARY_NAME_VAR "${CM_LIBRARY_NAME_VAR}")
    endif()
    cet_passthrough(APPEND CM_SO_VERSION cml_args)
    foreach (kw IN ITEMS BASENAME_ONLY INSTALL_LIBS_ONLY
        WITH_STATIC_LIBRARY)
      cet_passthrough(FLAG APPEND CM_${kw} cml_args)
    endforeach()
    # Deal with synonyms.
    cet_passthrough(APPEND VALUES ${CM_LIB_LOCAL_INCLUDE_DIRS}
      ${CM_LOCAL_INCLUDE_DIRS} KEYWORD LOCAL_INCLUDE_DIRS
      cml_args)
    # Deal with LIB_XXX.
    foreach (kw IN ITEMS INTERFACE MODULE OBJECT SHARED STATIC)
      cet_passthrough(FLAG APPEND KEYWORD ${kw} CM_LIB_${kw} cml_args)
    endforeach() 
    cet_passthrough(APPEND KEYWORD ALIAS CM_LIB_ALIAS cml_args)
    # Generate the library.
    cet_make_library(${CM_LIBRARY_NAME} ${CM_EXPORT_SET} ${CM_EXCLUDE_FROM_ALL}
      ${CM_NO_EXPORT} ${CM_NO_INSTALL} ${CM_VERSION} ${CM_USE_PROJECT_NAME} ${cml_args}
      LIBRARIES ${CM_LIBRARIES} ${CM_LIB_LIBRARIES} NOP
      SOURCE ${CM_LIB_SOURCE})
    if (CM_LIBRARY_NAME_VAR)
      set(${CM_LIBRARY_NAME_VAR} "${${CM_LIBRARY_NAME_VAR}}" PARENT_SCOPE)
    endif()
  endif()
endfunction()

cmake_policy(POP)
