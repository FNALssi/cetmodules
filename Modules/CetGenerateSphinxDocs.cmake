include_guard(GLOBAL)

get_property(_cgs_job_pools GLOBAL PROPERTY JOB_POOLS)
if (NOT cgs_job_pools MATCHES "(^|;)sphinx_doc=[0-9]")
  set_property(GLOBAL APPEND PROPERTY JOB_POOLS sphinx_doc=1)
endif()

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_generate_sphinxdocs)
  if (NOT BUILD_DOCS)
    return()
  endif()
  if (NOT "SPHINX_DOC_DIR" IN_LIST
      CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(SPHINX_DOC_DIR ${${CETMODULES_CURRENT_PROJECT_NAME}_DOC_DIR}
      BACKUP_DEFAULT ${CMAKE_INSTALL_DOCDIR}
      DOCSTRING "Location of installed Sphinx-generated documentation for ${CETMODULES_CURRENT_PROJECT_NAME}")
  endif()
  if (NOT "SPHINX_DOC_FORMATS" IN_LIST
      CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(SPHINX_DOC_FORMATS html
      DOCSTRING "Output formats in which Sphinx should generate documentation")
  endif()
  cet_find_package(sphinx-doc 3.0 PRIVATE QUIET REQUIRED)
  foreach(loop IN ITEMS 0 1)
    set(flags NITPICKY NO_ALL NO_INSTALL NOP QUIET VERBOSE)
    set(options OUTPUT_FORMATS)
    foreach (fmt IN LISTS ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS)
      string(TOUPPER "${fmt}" FMT)
      list(APPEND flags ${FMT}_ALL ${FMT}_INSTALL ${FMT}_NITPICKY
        ${FMT}_NO_ALL ${FMT}_NO_INSTALL ${FMT}_NO_NITPICKY)
      list(APPEND options ${FMT}_EXTRA_ARGS)
    endforeach()
    cmake_parse_arguments(PARSE_ARGV 0 CGS "${flags}"
      "CACHE_DIR;CONF_DIR;SOURCE_DIR;TARGET_STEM;TARGETS_VAR"
      "${options}")
    if (CGS_OUTPUT_FORMATS AND
        NOT CGS_OUTPUT_FORMATS STREQUAL
        ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS)
      set(${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS
        "${CGS_OUTPUT_FORMATS}")
    else()
      break()
    endif()
  endforeach()
  set(args "${ARGV}")
  list(FILTER args INCLUDE REGEX "^([^_]+)_(NO_)?(ALL|INSTALL|NITPICKY|EXTRA_ARGS)$")
  list(TRANSFORM args REPLACE "^(.+_)NO_(ALL|INSTALL|NITPICKY|EXTRA_ARGS)$" "\\1")
  list(TRANSFORM args REPLACE "^(.+_)(ALL|INSTALL|NITPICKY|EXTRA_ARGS)$" "\\1")
  if (args)
    list(REMOVE_DUPLICATES args)
    message(WARNING "received options prefixed with ${args} for Sphinx output formats we haven't been asked to produce.
Specify the Sphinx-recognized (case-correct) builder name with OUTPUT_FORMATS option or amend ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS\
")
  endif()
  if (NOT CGS_CACHE_DIR)
    set(CGS_CACHE_DIR "${CMAKE_CURRENT_BINARY_DIR}/_doctrees")
  endif()
  if (NOT CGS_SOURCE_DIR)
    set(CGS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  if (CGS_QUIET AND CGS_VERBOSE)
    message(SEND_ERROR "QUIET and VERBOSE are mutually exclusive")
  elseif (CGS_QUIET)
    list(APPEND sphinx_build_args -q)
  elseif (CGS_VERBOSE MATCHES "^-v+$")
    list(APPEND sphinx_build_args "${CGS_VERBOSE}")
  elseif (CGS_VERBOSE MATCHES "^[0-9]+$")
    string(REPEAT "v" ${CGS_VERBOSE} tmp)
    if (tmp)
      list(APPEND sphinx_build_args "-${tmp}")
    endif()
  elseif (CGS_VERBOSE)
    list(APPEND sphinx_build_args -v)
  endif()
  if (CGS_CONF_DIR)
    list(APPEND sphinx_build_args -c "${CGS_CONF_DIR}")
  endif()
  if (CGS_CACHE_DIR)
    list(APPEND sphinx_build_args -d "${CGS_CACHE_DIR}")
  endif()
  set(targets)
  set(dirs)
  if (CGS_CONF_DIR)
    set(src_conf "${CGS_CONF_DIR}")
  else()
    set(src_conf "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  if (NOT CGS_TARGET_STEM)
    set(CGS_TARGET_STEM "${CETMODULES_CURRENT_PROJECT_NAME}_sphinx_doc")
  endif()
  string(APPEND src_conf "/conf.py")
  if ("man" IN_LIST ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS AND
      NOT "SPHINX_MAN_DIR" IN_LIST
      CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(SPHINX_MAN_DIR ${${CETMODULES_CURRENT_PROJECT_NAME}_MAN_DIR}
      BACKUP_DEFAULT ${CMAKE_INSTALL_MANDIR}
      DOCSTRING "Location of Sphinx-generated manpage documentation for ${CETMODULES_CURRENT_PROJECT_NAME}")
  endif()
  foreach (fmt IN LISTS ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS)
    string(TOUPPER "${fmt}" FMT)
    set(target_stem "${CGS_TARGET_STEM}_${fmt}")
    if (CGS_${FMT}_NO_ALL OR
        (CGS_NO_ALL AND NOT CGS_${FMT}_ALL))
      set(all)
    else()
      set(all ALL)
    endif()
    if (CGS_${FMT}_NO_INSTALL OR
        (CGS_${FMT}_NO_INSTALL AND NOT CGS_${FMT}_INSTALL))
      set(no_install TRUE)
    else()
      set(no_install)
    endif()
    if (CGS_${FMT}_NITPICKY OR
        (CGS_${FMT}_NITPICKY AND NOT CGS_${FMT}_NO_NITPICKY))
      list(PREPEND CGS_${FMT}_EXTRA_ARGS -n)
    endif()
    add_custom_command(OUTPUT ${target_stem}
      COMMAND sphinx-doc::sphinx-build -b ${fmt}
      "${sphinx_build_args}" "${CGS_${FMT}_EXTRA_ARGS}"
      "${CGS_SOURCE_DIR}"
      "${CMAKE_CURRENT_BINARY_DIR}/${fmt}"
      COMMENT "Invoking $<TARGET_FILE_NAME:sphinx-doc::sphinx-build> to build ${fmt} documentation"
      SOURCES "${src_conf}"
      COMMAND_EXPAND_LISTS)
    set_property(SOURCE ${target_stem} PROPERTY SYMBOLIC TRUE)
    set(target sphinx-doc-${target_stem})
    add_custom_target(${target} ${all}
      DEPENDS ${target_stem} JOB_POOL sphinx_doc)
    if (fmt STREQUAL man)
      cet_localize_pv(cetmodules LIBEXEC_DIR)
      add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${cetmodules_LIBEXEC_DIR}/fix-man-dirs ${fmt}
        COMMENT "Renaming manual section directories for ${target}")
    endif()
    list(APPEND targets ${target})
    if (all)
      if (NOT TARGET sphinx-doc)
        add_custom_target(sphinx-doc ALL
          COMMENT "Building documentation with Sphinx"
          JOB_POOL sphinx_doc)
      endif()     
      add_dependencies(sphinx-doc ${target})
      if (NOT TARGET doc)
        add_custom_target(doc ALL
          COMMENT "Building documentation")
        add_dependencies(doc sphinx-doc)
      endif()
      set(efa_arg)
    else()
      set(efa_arg EXCLUDE_FROM_ALL)
    endif()
    if (NOT no_install)
      if (fmt STREQUAL "man")
        set(install_dir_pv SPHINX_MAN_DIR)
      else()
        set(install_dir_pv SPHINX_DOC_DIR)
      endif()
      install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${fmt}" ${efa_arg}
        DESTINATION "${${CETMODULES_CURRENT_PROJECT_NAME}_${install_dir_pv}}"
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
        DIRECTORY_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    endif()
  endforeach()
  if (CGS_TARGETS_VAR)
    set(${CGS_TARGETS_VAR} "${targets}" PARENT_SCOPE)
  endif()
endfunction()

cmake_policy(POP)
