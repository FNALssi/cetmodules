include_guard()

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_generate_sphinxdocs)
  project_variable(DOC_DIR ${CMAKE_INSTALL_DOCDIR} OMIT_IF_NULL
    DOCSTRING "Location of installed documentation for ${PROJECT_NAME}")
  cet_find_package(sphinx-doc 3.0 REQUIRED)
  cmake_parse_arguments(PARSE_ARGV 0 CGS "NO_ALL;NO_INSTALL;QUIET;VERBOSE"
    "CACHE_DIR;CONF_DIR;SOURCE_DIR;TARGET_STEM;TARGETS_VAR"
    "OUTPUT_FORMATS")
  if (NOT CGS_CACHE_DIR)
    set(CGS_CACHE_DIR "${CMAKE_CURRENT_BINARY_DIR}/_doctrees")
  endif()
  if (NOT CGS_SOURCE_DIR)
    set(CGS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  if (NOT CGS_OUTPUT_FORMATS)
    set(CGS_OUTPUT_FORMATS html)
  elseif ("man" IN_LIST CGS_OUTPUT_FORMATS)
    project_variable(MAN_DIR ${CMAKE_INSTALL_MANDIR}
      DOCSTRING "Location of manpage documentation for ${PROJECT_NAME}")
  endif()
  if (NOT CGS_NO_ALL)
    set(all_arg ALL)
  endif()
  if (CGS_QUIET AND CGS_VERBOSE)
    message(SEND_ERROR "QUIET and VERBOSE are mutually exclusive")
  elseif (CGS_QUIET)
    set(quiet_verbose -q)
  elseif (CGS_VERBOSE MATCHES "^-v+$")
    set(quiet_verbose "${CGS_VERBOSE}")
  elseif (CGS_VERBOSE MATCHES "^[0-9]+$")
    string(REPEAT "v" ${CGS_VERBOSE} quiet_verbose)
    if (quiet_verbose)
      string(PREPEND quiet_verbose "-")
    endif()
  elseif (CGS_VERBOSE)
    set(quiet_verbose -v)
  endif()
  cet_passthrough(KEYWORD -c CGS_CONF_DIR CONF_DIR_ARGS)
  cet_passthrough(IN_PLACE KEYWORD -d CGS_CACHE_DIR)
  if (NOT CGS_TARGET_STEM)
    cet_package_path(current_directory SOURCE)
    string(REPLACE "/" "_" CGS_TARGET_STEM "${current_directory}")
  endif()
  set(targets)
  set(dirs)
  foreach (format IN LISTS CGS_OUTPUT_FORMATS)
    string(JOIN "/" sources ${CGS_CONF_DIR} "conf.py")
    set(target "${CGS_TARGET_STEM}_${format}")
    add_custom_target(${target} ${all_arg}
      sphinx-doc::sphinx-build
      ${quiet_verbose} "${CONF_DIR_ARGS}" "${CGS_CACHE_DIR}"
      "${CGS_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/${format}"
      COMMENT "Building ${format} documentation with Sphinx"
      SOURCES "${sources}"
      COMMAND_EXPAND_LISTS
      )
    list(APPEND targets ${target})
    list(APPEND dirs "${CMAKE_CURRENT_BINARY_DIR}/${format}")
  endforeach()
  if (CGS_TARGETS_VAR)
    set(${CGS_TARGETS_VAR} "${targets}" PARENT_SCOPE)
  endif()
  if (NOT CGS_NO_INSTALL)
    if (CGS_NO_ALL)
      set(efa_arg EXCLUDE_FROM_ALL)
    else()
      set(efa_arg)
    endif()
    install(DIRECTORY ${dirs} DESTINATION ${efa_arg}
      FILE_PERMISSIONS WORLD_READ OWNER_WRITE
      DIRECTORY_PERMISSIONS WORLD_READ OWNER_WRITE WORLD_EXECUTE)
  endif()
endfunction()

cmake_policy(POP)
