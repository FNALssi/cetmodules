#[================================================================[.rst:
CetGenerateSphinxDocs
=====================
#]================================================================]
include_guard(GLOBAL)

get_property(_cgs_job_pools GLOBAL PROPERTY JOB_POOLS)
if (NOT cgs_job_pools MATCHES "(^|;)sphinx_doc=[0-9]")
  set_property(GLOBAL APPEND PROPERTY JOB_POOLS sphinx_doc=1)
endif()

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

function(cet_generate_sphinxdocs)
  if (NOT BUILD_DOCS)
    return()
  endif()
  set(flags NITPICKY NO_ALL NO_COLOR NO_CONF NO_INSTALL QUIET VERBOSE)
  set(one_arg_opts CACHE_DIR CONF_DIR SOURCE_DIR TARGET_STEM TARGETS_VAR VERBOSITY)
  set(options EXTRA_ARGS OUTPUT_FORMATS)
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
  find_package(sphinx-doc 3.0 PRIVATE QUIET REQUIRED)
  list(TRANSFORM ARGV REPLACE "\\<NO_" "" OUTPUT_VARIABLE fmt_args)
  list(FILTER fmt_args INCLUDE REGEX
    "^(.+)_(ALL|COLOR|EXTRA_ARGS|INSTALL|NITPICKY|QUIET|VERBOSE|VERBOSITY)$")
  list(TRANSFORM fmt_args REPLACE "^(.+)_(ALL|COLOR|EXTRA_ARGS|INSTALL|NITPICKY|QUIET|VERBOSE|VERBOSITY)$"
    "\\1")
  list(REMOVE_DUPLICATES fmt_args)
  foreach (fmt IN LISTS fmt_args)
    list(APPEND flags ${fmt}_ALL ${fmt}_COLOR ${fmt}_INSTALL ${fmt}_NITPICKY
      ${fmt}_NO_ALL ${fmt}_NO_COLOR ${fmt}_NO_INSTALL ${fmt}_NO_NITPICKY
      ${fmt}_NO_QUIET ${fmt}_NO_VERBOSE ${fmt}_QUIET ${fmt}_VERBOSE)
    list(APPEND one_arg_opts ${fmt}_VERBOSITY)
    list(APPEND options ${fmt}_EXTRA_ARGS)
  endforeach()
  cmake_parse_arguments(PARSE_ARGV 0 CGS
    "${flags}" "${one_arg_opts}" "${options}")
  if (NOT CGS_CACHE_DIR)
    set(CGS_CACHE_DIR "${CMAKE_CURRENT_BINARY_DIR}/_doctrees")
  endif()
  if (NOT CGS_SOURCE_DIR)
    set(CGS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  if (NOT CGS_OUTPUT_FORMATS)
    list(APPEND CGS_OUTPUT_FORMATS
      ${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS}
      ${fmt_args})
    list(REMOVE_DUPLICATES CGS_OUTPUT_FORMATS)
  else()
    set(missing_fmts)
    foreach (fmt IN LISTS fmt_args)
      if (fmt NOT IN_LIST CGS_OUTPUT_FORMATS)
        list(APPEND missing_fmts "${fmt}")
      endif()
    endforeach()
    if (missing_fmts)
      message(WARNING "options specified for non-requested document formats for ${CETMODULES_CURRENT_PROJECT_NAME}:
  ${missing_fmts}\
")
    endif()
  endif()
  if (NOT CGS_OUTPUT_FORMATS)
    return()
  elseif ("man" IN_LIST CGS_OUTPUT_FORMATS)
    project_variable(MAN_DIR ${CMAKE_INSTALL_MANDIR}
      DOCSTRING "Location of installed U**X [GT]ROFF-format manuals for \
${CETMODULES_CURRENT_PROJECT_NAME}")
  endif()
  if (CGS_NO_CONF)
    if (CGS_CONF_DIR)
      message(FATAL_ERROR "CONF_DIR and NO_CONF are mutually-exclusive")
    endif()
    list(APPEND CGS_EXTRA_ARGS -C)
    set(conf_dep)
  else()
    if (NOT CGS_CONF_DIR)
      set(CGS_CONF_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    list(APPEND CGS_EXTRA_ARGS -c "${CGS_CONF_DIR}")
  endif()    
  if (CGS_CACHE_DIR)
    list(APPEND CGS_EXTRA_ARGS -d "${CGS_CACHE_DIR}")
  endif()
  set(targets)
  set(dirs)
  if (NOT CGS_TARGET_STEM)
    cet_package_path(current_directory SOURCE)
    string(REPLACE "/" "_" CGS_TARGET_STEM "${current_directory}")
    string(PREPEND CGS_TARGET_STEM "${CETMODULES_CURRENT_PROJECT_NAME}_")
  endif()
  set(targets)
  set(dirs)
  foreach (fmt IN LISTS CGS_OUTPUT_FORMATS)
    set(sphinx_build_args ${CGS_EXTRA_ARGS})
    set(target_stem "${CGS_TARGET_STEM}_${fmt}")
    if (CGS_${fmt}_NO_ALL OR
        (CGS_NO_ALL AND NOT CGS_${fmt}_ALL))
      set(all)
    else()
      set(all ALL)
    endif()
    if (CGS_${fmt}_NO_INSTALL OR
        (CGS_NO_INSTALL AND NOT CGS_${fmt}_INSTALL))
      set(no_install TRUE)
    else()
      set(no_install)
    endif()
    if (CGS_${fmt}_NO_COLOR OR
        (CGS_NO_COLOR AND NOT CFS_${fmt}_COLOR))
      list(APPEND sphinx_build_args -N)
    else()
      list(APPEND sphinx_build_args --color)
    endif()
    if (CGS_${fmt}_NITPICKY OR
        (CGS_NITPICKY AND NOT CGS_${fmt}_NO_NITPICKY))
      list(APPEND sphinx_build_args -n)
    endif()
    if (CGS_${fmt}_QUIET OR
        (CGS_QUIET AND NOT CGS_${fmt}_NO_QUIET))
      list(APPEND sphinx_build_args -q)
    elseif (CGS_${fmt}_NO_VERBOSE OR
        (DEFINED CFS_${fmt}_VERBOSITY AND NOT CFS_${fmt}_VERBOSITY))
      list(FILTER sphinx_build_args EXCLUDE "^-v+$")
    else()
      list(REMOVE_ITEM sphinx_build_args -q)
      if (DEFINED CGS_VERBOSITY AND NOT DEFINED CGS_${fmt}_VERBOSITY)
        set(CGS_${fmt}_VERBOSITY ${CGS_VERBOSITY})
      endif()
      if (CGS_${fmt}_VERBOSITY MATCHES "^-v+$")
        list(APPEND sphinx_build_args ${CGS_${fmt}_VERBOSITY})
      elseif (CGS_${fmt}_VERBOSITY MATCHES "^[0-9]+$")
        string(REPEAT "v" ${CGS_${fmt}_VERBOSITY} tmp)
        if (tmp)
          list(APPEND sphinx_build_args "-${tmp}")
        endif()
      elseif (NOT sphinx_build_args MATCHES "(^|;)-v+(;|$)" AND
          (CGS_VERBOSE OR CGS_${fmt}_VERBOSE))
        list(APPEND sphinx_build_args "-v")
      endif()
    endif()
    if (CGS_${fmt}_EXTRA_ARGS MATCHES "(^|;)-v+(;|$)")
      list(REMOVE_ITEM sphinx_build_args -q)
    elseif (-q IN_LIST CGS_${fmt}_EXTRA_ARGS)
      list(FILTER sphinx_build_args EXCLUDE "^-v+$")
    endif()
    if ("${sphinx_build_args};${CGS_${fmt}_EXTRA_ARGS}" MATCHES "(^|;)-w;([^;]+)(;|$)")
      set(warnings_log "${CMAKE_MATCH_1}")
    else()
      set(warnings_log "${fmt}-warnings.log")
      list(APPEND CGS_${fmt}_EXTRA_ARGS -w "${warnings_log}")
    endif()
    set(cmd_args -b ${fmt} ${sphinx_build_args} ${CGS_${fmt}_EXTRA_ARGS} "${CGS_SOURCE_DIR}" ${fmt})
    # Failure semantics aren't great for sphinx-build: need to wrap. We
    # must delete the whole ${fmt}/ directory on failure otherwise we
    # have a hysteresis problem.
    add_custom_command(OUTPUT ${target_stem}
      COMMAND ${CMAKE_COMMAND}
      -DCMD_DELETE_ON_FAILURE=${fmt}
      -DCMD=$<TARGET_FILE:sphinx-doc::sphinx-build>
      -DCMD_ARGS="${cmd_args}"
      -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/CetCmdWrapper.cmake"
      COMMENT "Invoking sphinx-build to build ${fmt} documentation")
    set_property(SOURCE ${target_stem} PROPERTY SYMBOLIC TRUE)
    set(target sphinx-doc-${target_stem})
    add_custom_target(${target} ${all}
      DEPENDS "${target_stem}"
      JOB_POOL sphinx_doc)
    set_property(TARGET ${target} APPEND PROPERTY ADDITIONAL_CLEAN_FILES
      "${fmt};${warnings_log}")
    if (fmt STREQUAL man)
      cet_localize_pv(cetmodules LIBEXEC_DIR)
      add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${cetmodules_LIBEXEC_DIR}/fix-man-dirs ${fmt}
        COMMENT "Renaming manual section directories for ${target}"
        VERBATIM)
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
        set(install_dir_pv MAN_DIR)
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
