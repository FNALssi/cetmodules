########################################################################
# cet_cmake_config
#
# Generate and install PackageConfig.cmake and PackageConfigVersion.cmake.
#
# USAGE: cet_cmake_config([ARCH_INDEPENDENT|NOARCH|NO_FLAVOR]
#                         [COMPATIBILITY <compatibility>]
#                         [CONFIG_FRAGMENTS <config-fragment>...])
#
####################################
# OPTIONS
#
# COMPATIBILITY
#
#   Passed through to write_basic_package_version_file(). See
#   https://cmake.org/cmake/help/latest/module/CMakePackageConfigHelpers.html#generating-a-package-version-file
#   for valid values. If not specified, we default to AnyNewerVersion.
#
# CONFIG_FRAGMENTS <config-fragment>...
#
#   These user-specified fragments are incorporated into the
#   CMakeConfig.cmake file, and any @-bracketed-identifiers are expanded
#   with the value of the corresponding CMake variable.
#
#   If recursive expansion is required, use @AT@ to delay expansion for
#   as many levels as necessary (e.g. see
#   cetmodules/config/package-config.cmake.in.top).
#
####################################
# NOTES
#
#   The ${PROJECT_NAME}Config.cmake and
#   ${PROJECT_NAME}ConfigVersion.cmake files are installed under
#   ${${PROJECT_NAME}_LIBRARY_DIR} unless the project-specific variable
#   ${PROJECT_NAME}_NOARCH is TRUE, in which case the files are
#   installed under ${${PROJECT_NAME}_DATA_ROOT_DIR}. If
#   ${PROJECT_NAME}_NOARCH is explicitly set FALSE, then we fail if
#   ${PROJECT_NAME}_LIBRARY_DIR is (explicitly) unset. If
#   ${PROJECT_NAME}_NOARCH is merely unset, we generate a warning only.
#
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CMakePackageConfigHelpers)
include(CetPackagePath)
include(Compatibility)
include(GenerateFromFragments)

# Generate config and version files for the current project.
function(cet_cmake_config)
  project_variable(NOARCH TYPE BOOL
    DOCSTRING "If TRUE, ${PROJECT_NAME} is (at least nominally) architecture-independent.")
  # Save CMAKE_MODULE_PATH for later.
  cet_checkpoint_cmp()
  # Save INCLUDE_DIRECTORIES for later.
  cet_checkpoint_did()
  ####################################
  # Parse and verify arguments.
  cmake_parse_arguments(PARSE_ARGV 0 CCC
    ""
    "COMPATIBILITY;WORKDIR"
    "CONFIG_PRE_INIT;CONFIG_POST_INIT;CONFIG_POST_VARS;CONFIG_POST_DEPS;CONFIG_POST_TARGETS;PATH_VARS")
  if (CCC_NO_FLAVOR)
    message(WARNING "cet_cmake_config: NO_FLAVOR is deprecated: use ARCH_INDEPENDENT (a.k.a. NOARCH) instead")
  endif()
  set(distdir "${${PROJECT_NAME}_DATA_ROOT_DIR}")
  if (${PROJECT_NAME}_NOARCH)
    set(ARCH_INDEPENDENT ARCH_INDEPENDENT)
  elseif (${PROJECT_NAME}_LIBRARY_DIR)
    set(distdir "${${PROJECT_NAME}_LIBRARY_DIR}")
  elseif (NOT ${PROJECT_NAME}_NOARCH STREQUAL "")
    message(SEND_ERROR "refusing to install architecture-dependent \
CMake Config files in ${distdir}: set ${PROJECT_NAME}_NOARCH to TRUE or \
set ${PROJECT_NAME}_LIBRARY_DIR.\
")
  else()
    message(WARNING "${PROJECT_NAME}_LIBRARY_DIR is explicitly cleared \
but ${PROJECT_NAME}_NOARCH is undefined: installing possibly \
architecture-dependent CMake Config files under ${distdir}.

To suppress this warning, set ${PROJECT_NAME}_NOARCH to TRUE or \
set ${PROJECT_NAME}_LIBRARY_DIR.
")
  endif()
  if (NOT CCC_COMPATIBILITY)
    set(CCC_COMPATIBILITY AnyNewerVersion)
  endif()
  string(APPEND distdir "/${PROJECT_NAME}/cmake")
  if (NOT CCC_WORKDIR)
    set(CCC_WORKDIR "genConfig")
  endif()
  if (NOT IS_ABSOLUTE "${CCC_WORKDIR}")
    string(PREPEND CCC_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/")
  endif()
  ####################################
  # Generate UPS table files, etc. if requested.
  if (WANT_UPS)
    process_ups_files()
  endif()
  ####################################
  # Generate and install config files.
  _install_package_config_files()
  ####################################
  # Packaging.
  if (PROJECT_BINARY_DIR STREQUAL CMAKE_CURRENT_BINARY_DIR)
    include(UseCPack)
  endif()
endfunction()

# Add a separator to STRINGVAR iff it already has content.
macro(_add_sep STRINGVAR)
  if (${STRINGVAR})
    string(APPEND ${STRINGVAR} "\n\n")
  endif()
endmacro()

function(_write_stage STAGE FRAG_LIST)
  set(stage_file
    "${CCC_WORKDIR}/${PROJECT_NAME}-generated-config.cmake.${STAGE}.in")
  file(WRITE "${stage_file}" ${ARGN})
  list(APPEND ${FRAG_LIST} "${stage_file}")
  set(${FRAG_LIST} "${${FRAG_LIST}}" PARENT_SCOPE)
endfunction()

# Generate config file body for substitution into
# cetmodules/config/package-config.cmake.in.top.
function(_generate_config_parts FRAG_LIST PATH_VARS_VAR)
  set(_GCP_${PATH_VARS_VAR})
  ####################################
  # Stage: vars
  ####################################
  _generate_config_vars(${FRAG_LIST} _GCP_${PATH_VARS_VAR})
  list(APPEND ${FRAG_LIST} ${CCC_CONFIG_POST_VARS})
  ####################################
  # Stage: targets
  ####################################
  _generate_target_imports(${FRAG_LIST})
  list(APPEND ${FRAG_LIST} ${CCC_CONFIG_POST_TARGETS})
  ####################################
  # Stage: target_vars
  ####################################
  _generate_target_vars(${FRAG_LIST})
  list(APPEND ${FRAG_LIST} ${CCC_CONFIG_POST_TARGET_VARS})
  ####################################
  # Stage: deps
  ####################################
  _generate_transitive_deps(${FRAG_LIST})
  list(APPEND ${FRAG_LIST} ${CCC_CONFIG_POST_DEPS})
  # Propogate variables required upstream.
  list(APPEND ${PATH_VARS_VAR} "${_GCP_${PATH_VARS_VAR}}")
  set(${PATH_VARS_VAR} "${${PATH_VARS_VAR}}" PARENT_SCOPE)
  foreach (pvar IN LISTS _GCP_${PATH_VARS_VAR})
    set(${pvar} "${${pvar}}" PARENT_SCOPE)
  endforeach()
  set(${FRAG_LIST} "${${FRAG_LIST}}" PARENT_SCOPE)
endfunction()

function(_generate_config_vars FRAG_LIST PATH_VARS_VAR)
  set(var_defs)
  set(_GCV_${PATH_VARS_VAR})
  # Package variable definitions.
  _generate_pvar_defs(var_defs _GCV_${PATH_VARS_VAR})
  # Include directories.
  if ("INCLUDE_DIR" IN_LIST _GCV_${PATH_VARS_VAR})
    _add_sep(var_defs)
    string(APPEND var_defs "\
####################################
# Package include directories.
####################################
if (IS_DIRECTORY \"@PACKAGE_INCLUDE_DIR@\")
  # CMake convention:
  set(${PROJECT_NAME}_INCLUDE_DIRS \"@PACKAGE_INCLUDE_DIR@\")
endif()\
")
  endif()
  # Library directories.
  if ("LIBRARY_DIR" IN_LIST _GCV_${PATH_VARS_VAR})
    _add_sep(var_defs)
    string(APPEND var_defs "\
####################################
# Package library directories.
####################################
if (IS_DIRECTORY \"@PACKAGE_LIBRARY_DIR@\")
  # CMake convention:
  set(${PROJECT_NAME}_LIBRARY_DIRS \"@PACKAGE_LIBRARY_DIR@\")
endif()\
")
  endif()
  _prepend_cmake_module_path(var_defs _GCV_${PATH_VARS_VAR})
  # Propogate variables required upstream.
  list(APPEND ${PATH_VARS_VAR} "${_GCV_${PATH_VARS_VAR}}")
  set(${PATH_VARS_VAR} "${${PATH_VARS_VAR}}" PARENT_SCOPE)
  foreach(pvar IN LISTS _GCV_${PATH_VARS_VAR})
    set(${pvar} "${${pvar}}" PARENT_SCOPE)
  endforeach()
  # Finish.
  _write_stage(vars ${FRAG_LIST} "${var_defs}")
  set(${FRAG_LIST} "${${FRAG_LIST}}" PARENT_SCOPE)
endfunction()

# Generate package variable definitions
function(_generate_pvar_defs RESULTS_VAR PATH_VARS_VAR)
  set(defs_list)
  set(_GPD_${PATH_VARS_VAR})
  foreach (VAR_NAME IN LISTS CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    get_property(VAL_DEFINED CACHE ${PROJECT_NAME}_${VAR_NAME} PROPERTY VALUE SET)
    get_property(VAR_VAL CACHE ${PROJECT_NAME}_${VAR_NAME} PROPERTY VALUE)
    # We can check for nullity and lack of CONFIG now; path
    # existence and directory content must be delayed to find_package()
    # time.
    get_project_variable_property(${VAR_NAME} PROPERTY CONFIG)
    get_project_variable_property(${VAR_NAME} PROPERTY OMIT_IF_NULL)
    if (NOT CONFIG OR (OMIT_IF_NULL AND (NOT VAL_DEFINED OR VAR_VAL
        STREQUAL "")))
      continue()
    endif()
    list(APPEND defs_list "# ${PROJECT_NAME}_${VAR_NAME}")
    get_project_variable_property(${VAR_NAME} PROPERTY OMIT_IF_MISSING)
    get_project_variable_property(${VAR_NAME} PROPERTY OMIT_IF_EMPTY)
    # Add logic for conditional definitions.
    if (OMIT_IF_MISSING OR OMIT_IF_EMPTY)
      set(indent "  ")
      list(APPEND defs_list "if (EXISTS \"@PACKAGE_${VAR_NAME}@\")")
      if (OMIT_IF_EMPTY)
        list(APPEND defs_list "${indent}file(GLOB _${PROJECT_NAME}_TMP_DIR_ENTRIES \"@PACKAGE_${VAR_NAME}@/*\")"
          "${indent}if (_${PROJECT_NAME}_TMP_DIR_ENTRIES)")
        string(APPEND indent "  ")
      endif()
    else()
      set(indent)
    endif()
    # Logic for handling paths and path fragments.
    get_project_variable_property(${VAR_NAME} PROPERTY IS_PATH)
    if (IS_PATH)
      list(APPEND _GPD_${PATH_VARS_VAR} ${VAR_NAME})
      if (VAL_DEFINED)
        set(${VAR_NAME} "${VAR_VAL}" PARENT_SCOPE)
      else()
        unset(${VAR_NAME} PARENT_SCOPE)
      endif()
      if (MISSING_OK)
        set(set_func "set")
      else()
        set(set_func "set_and_check")
      endif()
      list(APPEND defs_list "${indent}${set_func}(${PROJECT_NAME}_${VAR_NAME} \"@PACKAGE_${VAR_NAME}@\")")
    else()
      list(APPEND defs_list
        "${indent}set(${PROJECT_NAME}_${VAR_NAME} \"${VAR_VAL}\")")
    endif()
    if (indent)
      if (OMIT_IF_EMPTY)
        list(APPEND defs_list "  endif()"
          "  unset(_${PROJECT_NAME}_TMP_DIR_ENTRIES)")
      endif()
      list(APPEND defs_list "endif()")
    endif()
  endforeach()
  if (defs_list)
    # Add to result.
    list(PREPEND defs_list "####################################
# Package variable definitions.
####################################\
")
    list(JOIN defs_list "\n" tmp)
    _add_sep(${RESULTS_VAR})
    set(${RESULTS_VAR} "${${RESULTS_VAR}}${tmp}" PARENT_SCOPE)
  endif()
  # Send back list of path variables.
  list(APPEND ${PATH_VARS_VAR} "${_GPD_${PATH_VARS_VAR}}")
  set(${PATH_VARS_VAR} "${${PATH_VARS_VAR}}" PARENT_SCOPE)
endfunction()

function(_generate_target_imports FRAG_LIST)
  set(exports)
  if (CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME} OR
      CETMODULES_IMPORT_COMMANDS_PROJECT_${PROJECT_NAME})
    set(exports "\
####################################
# Exported targets, and package components.
####################################\
")
    foreach (export_name IN LISTS CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME})
      list(APPEND exports "\

##################
# Automatically-generated runtime targets: ${export_name}
##################
include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_name}.cmake\")
foreach (component IN LISTS ${PROJECT_NAME}_FIND_COMPONENTS)
  include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_name}_\${component}.cmake\")
endforeach()\
")
    endforeach()
    if (CETMODULES_IMPORT_COMMANDS_PROJECT_${PROJECT_NAME})
      list(TRANSFORM CETMODULES_EXPORTED_MANUAL_TARGETS_PROJECT_${PROJECT_NAME}
        PREPEND "    " OUTPUT_VARIABLE tmp)
      list(APPEND exports "\

##################
# Manually-generated non-runtime targets.
##################
set(_targetsDefined)
set(_targetsNotDefined)
set(_expectedTargets)
foreach (_expectedTarget IN ITEMS \
" "${tmp})" "\
  list(APPEND _expectedTargets \${_expectedTarget})
  if (NOT TARGET \${_expectedTarget})
    list(APPEND _targetsNotDefined \${_expectedTarget})
  endif()
  if (TARGET \${_expectedTarget})
    list(APPEND _targetsDefined \${_expectedTarget})
  endif()
endforeach()
if (\"\${_targetsDefined}\" STREQUAL \"\${_expectedTargets}\")\
  # Nothing to do.
elseif (\"\${_targetsDefined}\" STREQUAL \"\") # Need to define targets.\
")
      list(TRANSFORM CETMODULES_IMPORT_COMMANDS_PROJECT_${PROJECT_NAME}
        PREPEND "  " OUTPUT_VARIABLE tmp)
      list(APPEND exports "${tmp}" "\
else()
  message(FATAL_ERROR \"Some (but not all) targets in this export set were already defined.\nTargets Defined: \${_targetsDefined}\nTargets not yet defined: \${_targetsNotDefined}\n\")
endif()
unset(_targetsDefined)
unset(_targetsNotDefined)
unset(_expectedTargets)\
")
    endif()
    list(JOIN exports "\n" tmp)
    set(exports "${tmp}")
  endif()
  _write_stage(targets ${FRAG_LIST} "${exports}")
  set(${FRAG_LIST} "${${FRAG_LIST}}" PARENT_SCOPE)
endfunction()

# Generate old cetbuildtools-style variables for targets produced by
# this package.
function(_generate_target_vars FRAG_LIST)
  set(var_settings)
  cet_regex_escape("${PROJECT_NAME}" e_proj)
  list(TRANSFORM CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME} REPLACE
    "^(.+)$" "CETMODULES_EXPORTED_TARGETS_EXPORT_\\1_PROJECT_${PROJECT_NAME}"
    OUTPUT_VARIABLE target_lists)
  foreach (target IN LISTS ${target_lists}
      CETMODULES_EXPORTED_MANUAL_TARGETS_PROJECT_${PROJECT_NAME})
    string(REGEX REPLACE "^.*::" "" var "${target}")
    string(TOUPPER "${var}" var)
    list(APPEND var_settings "  set(${var} ${target})")
  endforeach()
  if (var_settings)
    list(JOIN var_settings "\n" tmp)
    set(var_settings "\
####################################
# Old cetbuildtools-style target variables.
####################################
if (\${PROJECT_NAME}_OLD_STYLE_CONFIG_VARS OR # Per-dependent setting.
 cetbuildtools IN_LIST \${PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES) # Backward-compatibility.
${tmp}
endif()\
")
  endif()
  _write_stage(target_vars ${FRAG_LIST} "${var_settings}")
  set(${FRAG_LIST} "${${FRAG_LIST}}" PARENT_SCOPE)
endfunction()

function(_generate_transitive_deps FRAG_LIST)
  set(transitive_deps)
  # Top level dependencies.
  if (CETMODULES_FIND_DEPS_PROJECT_${PROJECT_NAME})
    list(APPEND transitive_deps
      "${CETMODULES_FIND_DEPS_PROJECT_${PROJECT_NAME}}")
  endif()
  # Find component-specific dependencies.
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  cet_regex_escape("${PROJECT_NAME}" e_proj)
  set(component_regex "^CETMODULES_FIND_DEPS_COMPONENT_(.*)_PROJECT_${eproj}$")
  list(FILTER cache_vars INCLUDE REGEX "${component_regex}")
  list(TRANSFORM cache_vars REPLACE "${component_regex}" "\\1")
  # Load dependencies iff component is requested.
  foreach (component IN LISTS cache_vars)
    string(REPLACE "\n(.)" "\n  \\1" tmp "${CETMODULES_FIND_DEPS_COMPONENT_${component}_PROJECT_${PROJECT_NAME}}")
    list(APPEND transitive_deps "\
if (\"${component}\" IN LISTS ${PROJECT_NAME}_FIND_COMPONENTS)
  ${tmp}
endif()\
")
  endforeach()
  if (transitive_deps)
    # Add to result.
    list(PREPEND transitive_deps "\
####################################
# Transitive dependencies.
####################################\
")
    list(JOIN transitive_deps "\n" tmp)
    set(transitive_deps "${tmp}")
  endif()
  _write_stage(deps ${FRAG_LIST} "${transitive_deps}")
  set(${FRAG_LIST} "${${FRAG_LIST}}" PARENT_SCOPE)
endfunction()

function(_prepend_cmake_module_path RESULTS_VAR PATH_VARS_VAR)
  if (CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${PROJECT_NAME})
    set(_PCMP_${PATH_VARS_VAR})
    set(_PCMP_COUNT 0)
    foreach (dir IN LISTS
        CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${PROJECT_NAME})
      set(_PCMP_PACKAGE_VAR PCMP_PACKAGE_VAR_${_PCMP_COUNT})
      math(EXPR _PCMP_COUNT "${_PCMP_COUNT} + 1")
      set(${_PCMP_PACKAGE_VAR} "${dir}" PARENT_SCOPE)
      list(APPEND _PCMP_${PATH_VARS_VAR} "${_PCMP_PACKAGE_VAR}")
    endforeach()
    list(TRANSFORM _PCMP_${PATH_VARS_VAR} REPLACE "^(.+)$" "\"@PACKAGE_\\1@\""
      OUTPUT_VARIABLE _PCMP_PACKAGE_VARS)
    _add_sep(${RESULTS_VAR})
    list(JOIN _PCMP_PACKAGE_VARS " " tmp)
    string(APPEND ${RESULTS_VAR} "
####################################
# Add to CMAKE_MODULE_PATH.
####################################
list(PREPEND CMAKE_MODULE_PATH ${tmp})\
")
    set(${RESULTS_VAR} "${${RESULTS_VAR}}" PARENT_SCOPE)
    list(APPEND ${PATH_VARS_VAR} "${_PCMP_${PATH_VARS_VAR}}")
    set(${PATH_VARS_VAR} "${${PATH_VARS_VAR}}" PARENT_SCOPE)
  endif()
endfunction()

# Generate the package config file from its component parts.
function(_install_package_config_files)
  set(configStem "${PROJECT_NAME}Config")
  set(config "${configStem}.cmake")
  set(configVersion "${configStem}Version.cmake")
  file(MAKE_DIRECTORY "${CCC_WORKDIR}")

  write_basic_package_version_file(
    "${PROJECT_BINARY_DIR}/${configVersion}"
	  VERSION "${PROJECT_VERSION}"
	  COMPATIBILITY "${CCC_COMPATIBILITY}"
    ${ARCH_INDEPENDENT})

  cet_localize_pv(cetmodules CONFIG_DIR)
  set(frag_list "${cetmodules_CONFIG_DIR}/package-config.cmake.preamble.in"
    ${CCC_CONFIG_PRE_INIT}
    "${cetmodules_CONFIG_DIR}/package-config.cmake.init.in"
    ${CCC_CONFIG_POST_INIT})

  _generate_config_parts(frag_list path_vars)

  list(APPEND frag_list 
    "${cetmodules_CONFIG_DIR}/package-config.cmake.bottom.in")

  # Generate a version config file.
  # Generate the config.in file from components.
  generate_from_fragments("${CCC_WORKDIR}/${config}.in"
    FRAGMENTS ${frag_list})

  # Generate a top-level config file for the install tree.
  configure_package_config_file(
    "${CCC_WORKDIR}/${config}.in"
    "${CCC_WORKDIR}/${config}"
	  INSTALL_DESTINATION "${distdir}"
    PATH_VARS ${path_vars} ${CCC_PATH_VARS})

  # Install top level config files.
  install(FILES
    "${CCC_WORKDIR}/${config}"
    "${PROJECT_BINARY_DIR}/${configVersion}"
    DESTINATION "${distdir}")

  # Generate and install target definition files (included by top-level
  # configs as appropriate).
  foreach(export_name IN LISTS
      CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME})
    cet_passthrough(KEYWORD NAMESPACE
      ${PROJECT_NAME}_${export_name}_NAMESPACE
      export_namespace)
    # Export targets for import from the build tree.
    export(EXPORT ${export_name}
      FILE "${PROJECT_BINARY_DIR}/${export_name}.cmake"
      ${export_namespace}::)
    # Export targets for import from the installed package.
    install(EXPORT ${export_name}
      DESTINATION "${distdir}"
      ${export_namespace}::
      EXPORT_LINK_INTERFACE_LIBRARIES)
  endforeach()

  # Generate a top-level config file for the build tree directly at its
  # final location.
  configure_package_config_file(
    "${CCC_WORKDIR}/${config}.in"
    "${PROJECT_BINARY_DIR}/${config}"
    INSTALL_PREFIX "${PROJECT_BINARY_DIR}"
	  INSTALL_DESTINATION "."
    PATH_VARS "${path_vars}")
endfunction()

# Get targets matching specific types.
function(_targets_for RESULTS_VAR)
  cmake_parse_arguments(PARSE_ARGV 1 _TF "APPEND;RECURSIVE" "DIRECTORY" "TARGETS;TYPES")
  if (_TF_APPEND)
    set(results ${${RESULTS_VAR}})
  else()
    set(results)
  endif()
  if (_TF_TARGETS) # Already have a list of targets to deal with.
    if (_TF_DIRECTORY OR _TF_RECURSIVE)
      message(WARNING "DIRECTORY and RECURSIVE ignored when TARGETS specified")
    endif()
    if (NOT _TF_TYPES) # All targets are good.
      list(APPEND results ${_TF_TARGETS})
    else()
      # Check each target for wanted types.
      foreach (target IN LISTS _TF_TARGETS)
        get_property(ttype TARGET "${target}" PROPERTY TYPE)
        if (ttype IN_LIST _TF_TYPES)
          list(APPEND results "${target}")
        endif()
      endforeach()
    endif()
  elseif (_TF_DIRECTORY)
    cet_passthrough(IN_PLACE _TF_TYPES)
    # Get targets in for the current directory and then call ourselves
    # with the list to do the vetting.
    get_property(targets DIRECTORY "${_TF_DIRECTORY}" PROPERTY BUILDSYSTEM_TARGETS)
    if (targets)
      _targets_for(results APPEND TARGETS ${targets} ${_TF_TYPES})
    endif()
    if (_TF_RECURSIVE) # Recursive: descend the directory tree.
      get_property(subdirs DIRECTORY "${_TF_DIRECTORY}" PROPERTY SUBDIRECTORIES)
      if (subdirs)
        foreach (subdir IN LISTS subdirs)
          _targets_for(results APPEND DIRECTORY "${subdir}" RECURSIVE ${_TF_TYPES})
        endforeach()
      endif()
    endif()
  endif()
  if (results)
    set(${RESULTS_VAR} "${results}" PARENT_SCOPE)
  else()
    unset(${RESULTS_VAR} PARENT_SCOPE)
  endif()
endfunction()

cmake_policy(POP)
