#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# cet_cmake_config
#
# Generate and install PackageConfig.cmake and PackageConfigVersion.cmake.
#
# USAGE: cet_cmake_config([ARCH_INDEPENDENT|NOARCH|NO_FLAVOR]
#                         [COMPATIBILITY <compatibility>]
#                         [NO_CMAKE_CONFIG|CONFIG_FRAGMENTS <config-fragment>...])
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
#   The ${CETMODULES_CURRENT_PROJECT_NAME}Config.cmake and
#   ${CETMODULES_CURRENT_PROJECT_NAME}ConfigVersion.cmake files are installed under
#   ${${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIR} unless the project-specific variable
#   ${CETMODULES_CURRENT_PROJECT_NAME}_NOARCH is TRUE, in which case the files are
#   installed under ${${CETMODULES_CURRENT_PROJECT_NAME}_DATA_ROOT_DIR}. If
#   ${CETMODULES_CURRENT_PROJECT_NAME}_NOARCH is explicitly set FALSE, then we fail if
#   ${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIR is (explicitly) unset. If
#   ${CETMODULES_CURRENT_PROJECT_NAME}_NOARCH is merely unset, we generate a warning only.
#
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.19.6 FATAL_ERROR)

include(CMakePackageConfigHelpers)
include(CetPackagePath)
include(compat/Compatibility)
include(GenerateFromFragments)
include(ParseVersionString)

function(cet_cmake_config)
  # Delay the call until we're (almost) done with the project.
  cmake_language(EVAL CODE "
    cmake_language(DEFER DIRECTORY \"${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}\"
      CALL _cet_cmake_config_impl ${ARGV})\
")
endfunction()

# Generate config and version files for the current project.
function(_cet_cmake_config_impl)
  message(VERBOSE "executing delayed generation of config files")
  project_variable(NOARCH TYPE BOOL
    DOCSTRING "If TRUE, ${CETMODULES_CURRENT_PROJECT_NAME} is (at least nominally) architecture-independent.")
  # Save CMAKE_MODULE_PATH for later.
  cet_checkpoint_cmp()
  # Save INCLUDE_DIRECTORIES for later.
  cet_checkpoint_did()
  ####################################
  # Parse and verify arguments.
  cmake_parse_arguments(PARSE_ARGV 0 CCC
    "NO_CMAKE_CONFIG"
    "COMPATIBILITY;WORKDIR"
    "CONFIG_PRE_INIT;CONFIG_POST_INIT;CONFIG_POST_VARS;CONFIG_POST_DEPS;CONFIG_POST_TARGET_VARS;CONFIG_POST_TARGETS;EXTRA_TARGET_VARS;PATH_VARS")
  if (CCC_NO_CMAKE_CONFIG AND
      (CCC_COMPATIBILITY OR CCC_WORKDIR OR CCC_CONFIG_PRE_INIT OR
        CCC_CONFIG_POST_INIT OR CCC_CONFIG_POST_VARS OR
        CCC_CONFIG_POST_DEPS OR CCC_CONFIG_POST_TARGET_VARS OR
        CCC_CONFIG_POST_TARGETS OR CCC_EXTRA_TARGET_VARS OR
        CCC_PATH_VARS))
    message(AUTHOR_WARNING "all other options are ignored when NO_CMAKE_CONFIG is set")
  endif()
  if (CCC_NO_FLAVOR)
    warn_deprecated("cet_cmake_config(NO_FLAVOR)"
      NEW "cet_cmake_config(ARCH_INDEPENDENT) (a.k.a. NOARCH)")
  endif()
  ####################################
  # Generate UPS table files, etc. if requested.
  if (WANT_UPS)
    process_ups_files()
  endif()
  ####################################
  # Process config-related arguments.
  if (NOT CCC_NO_CMAKE_CONFIG)
    if (${CETMODULES_CURRENT_PROJECT_NAME}_NOARCH)
      set(ARCH_INDEPENDENT ARCH_INDEPENDENT)
    endif()
    if (${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY AND NOT
        ${CETMODULES_CURRENT_PROJECT_NAME}_NOARCH)
      set(config_out_default_var LIBRARY_DIR)
    else()
      set(config_out_default_var DATA_ROOT_DIR)
    endif()
    project_variable(CONFIG_OUTPUT_ROOT_DIR "${${CETMODULES_CURRENT_PROJECT_NAME}_${config_out_default_var}}"
      DOCSTRING "Output location for CMake Config files, etc. for find_package()")
    cet_get_pv_property(origin CONFIG_OUTPUT_ROOT_DIR PROPERTY ORIGIN)
    set(distdir "${${CETMODULES_CURRENT_PROJECT_NAME}_CONFIG_OUTPUT_ROOT_DIR}")
    if ("${distdir}" STREQUAL "") # Oops.
      if (origin STREQUAL "<initial-value>") # Defaulted...
        if (${CETMODULES_CURRENT_PROJECT_NAME}_NOARCH) # from DATA_ROOT_DIR; OR
          message(SEND_ERROR "cannot install CMake Config files due to \
an explicitly vacuous value for the DATA_ROOT_DIR project variable.
Set it, or set the project variable CONFIG_OUTPUT_ROOT_DIR to the desired \
subdirectory to allow dependent packages to use \
find_package(${CETMODULES_CURRENT_PROJECT_NAME})\
")
        elseif (${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX)
          message(SEND_ERROR "cannot install CMake Config files due to \
an explicitly vacuous value for the LIBRARY_DIR project variable.
If this package is not architecture-dependent, set the project variable NOARCH; \
otherwise set project variable CONFIG_OUTPUT_ROOT_DIR to the desired \
subdirectory to allow dependent packages to use \
find_package(${CETMODULES_CURRENT_PROJECT_NAME})\
")
        elseif (${CETMODULES_CURRENT_PROJECT_NAME}_DATA_ROOT_DIR)
          message(WARNING "vacuous default location for CMake Config files \
due to explicitly vacuous values for the LIBRARY_DIR and EXEC_PREFIX \
project variables. Installing under DATA_ROOT_DIR \
(${${CETMODULES_CURRENT_PROJECT_NAME}_DATA_ROOT_DIR}/) instead.
Set project variable NOARCH TRUE, or set project variable \
CONFIG_OUTPUT_ROOT_DIR to suppress this message\
")
          set(distdir "${${CETMODULES_CURRENT_PROJECT_NAME}_DATA_ROOT_DIR}")
          # Put corrected value in cache for subsequent runs.
          set_property(CACHE ${CETMODULES_CURRENT_PROJECT_NAME}_CONFIG_OUTPUT_ROOT_DIR
            PROPERTY VALUE "${distdir}")
        else()
          message(SEND_ERROR "cannot install CMake Config files due to \
explicitly vacuous values for project variables LIBRARY_DIR and DATA_ROOT_DIR.
Set the project variable CONFIG_OUTPUT_ROOT_DIR, or call \
cet_cmake_config() with the NO_CMAKE_CONFIG flag to prevent the generation \
of these configuration files\
")
        endif()
      else() # Explicitly set empty.
        message(SEND_ERROR "cannot install CMake Config files due to \
an explicitly vacuous value for the CONFIG_OUTPUT_ROOT_DIR project variable.
Set it to the desired subdirectory to allow dependent packages to use \
find_package(${CETMODULES_CURRENT_PROJECT_NAME}), or call \
cet_cmake_config() with the NO_CMAKE_CONFIG flag to prevent the generation \
of these configuration files\
")
      endif()
    elseif (origin STREQUAL "<initial-value>" AND
        NOT (${CETMODULES_CURRENT_PROJECT_NAME}_NOARCH OR
          IS_ABSOLUTE "${distdir}")) # Defaulted.
      # Is EXEC_PREFIX non-empty?
      if (${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX)
        string(FIND "${distdir}"
          "${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}"
          idx)
        if (NOT idx EQUAL 0)
          message(SEND_ERROR "refusing to install architecture-dependent \
CMake Config files in architecture-independent default location ${distdir}.
Set project variable NOARCH TRUE, or set project variable \
CONFIG_OUTPUT_ROOT_DIR to confirm intention\
")
        endif()
      else()
        message(WARNING "installing architecture-dependent CMake Config \
files in possibly architecture-independent default location ${distdir}.
Set project variable NOARCH TRUE, or set project variable \
CONFIG_OUTPUT_ROOT_DIR to suppress this message\
")
      endif()
    endif()
    if (NOT CCC_COMPATIBILITY)
      set(CCC_COMPATIBILITY AnyNewerVersion)
    endif()
    string(APPEND distdir "/${CETMODULES_CURRENT_PROJECT_NAME}/cmake")
    if (NOT CCC_WORKDIR)
      set(CCC_WORKDIR "genConfig")
    endif()
    if (NOT IS_ABSOLUTE "${CCC_WORKDIR}")
      string(PREPEND CCC_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/")
    endif()
    ####################################
    # Generate and install config files.
    _install_package_config_files()
  endif()
  ####################################
  # Packaging.
  _configure_cpack()
endfunction()

macro(_configure_cpack)
  if (CMAKE_CURRENT_SOURCE_DIR STREQUAL CETMODULES_CURRENT_PROJECT_SOURCE_DIR)
    if (CMAKE_PROJECT_NAME STREQUAL CETMODULES_CURRENT_PROJECT_NAME)
      if (CETMODULES_CONFIG_CPACK_MACRO)
        parse_version_string(${PROJECT_VERSION} CPACK_PACKAGE_VERSION SEP . NO_EXTRA EXTRA_VAR _cc_extra)
        # Make sure we include non-numeric version components, removing unwanted characters.
        string(REGEX REPLACE "[ -]" "_" _cc_extra "${_cc_extra}")
        string(APPEND CPACK_PACKAGE_VERSION "${_cc_extra}")
        unset(_cc_extra)
        # Configure everything else.
        cmake_language(CALL ${CETMODULES_CONFIG_CPACK_MACRO})
        # invoke CPack.
        include(CPack)
      else()
        message(WARNING "automatic configuration of CPack is supported only for WANT_UPS builds at this time")
      endif()
    else()
      message(VERBOSE "\
automatic configuration of CPack is not supported for subprojects at \
this time ($(CMAKE_PROJECT_NAME) -> ${CETMODULES_CURRENT_PROJECT_NAME}\
")
    endif()
  else()
    message(WARNING "configuration of CPack packaging is supported from top-level project CMakeLists.txt ONLY at this time")
  endif()
endmacro()

# Add a separator to STRINGVAR iff it already has content.
macro(_add_sep STRINGVAR)
  if (${STRINGVAR})
    string(APPEND ${STRINGVAR} "\n\n")
  endif()
endmacro()

function(_write_stage STAGE FRAG_LIST)
  set(stage_file
    "${CCC_WORKDIR}/${CETMODULES_CURRENT_PROJECT_NAME}-generated-config.cmake.${STAGE}.in")
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
  # Stage: deps
  ####################################
  _generate_transitive_deps(${FRAG_LIST})
  list(APPEND ${FRAG_LIST} ${CCC_CONFIG_POST_DEPS})
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
  # Propagate variables required upstream.
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
  set(${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIRS \"@PACKAGE_INCLUDE_DIR@\")
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
  set(${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIRS \"@PACKAGE_LIBRARY_DIR@\")
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
  foreach (VAR_NAME IN LISTS CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    get_property(VAL_DEFINED CACHE ${CETMODULES_CURRENT_PROJECT_NAME}_${VAR_NAME} PROPERTY VALUE SET)
    get_property(VAR_VAL CACHE ${CETMODULES_CURRENT_PROJECT_NAME}_${VAR_NAME} PROPERTY VALUE)
    # We can check for nullity and lack of CONFIG now; path
    # existence and directory content must be delayed to find_package()
    # time.
    cet_get_pv_property(${VAR_NAME} PROPERTY CONFIG)
    cet_get_pv_property(${VAR_NAME} PROPERTY OMIT_IF_NULL)
    if (NOT CONFIG OR (OMIT_IF_NULL AND (NOT VAL_DEFINED OR VAR_VAL
        STREQUAL "")))
      continue()
    endif()
    list(APPEND defs_list "# ${CETMODULES_CURRENT_PROJECT_NAME}_${VAR_NAME}")
    cet_get_pv_property(${VAR_NAME} PROPERTY OMIT_IF_MISSING)
    cet_get_pv_property(${VAR_NAME} PROPERTY OMIT_IF_EMPTY)
    # Add logic for conditional definitions.
    if (OMIT_IF_MISSING OR OMIT_IF_EMPTY)
      set(indent "  ")
      list(APPEND defs_list "if (EXISTS \"@PACKAGE_${VAR_NAME}@\")")
      if (OMIT_IF_EMPTY)
        list(APPEND defs_list "${indent}file(GLOB _${CETMODULES_CURRENT_PROJECT_NAME}_TMP_DIR_ENTRIES \"@PACKAGE_${VAR_NAME}@/*\")"
          "${indent}if (_${CETMODULES_CURRENT_PROJECT_NAME}_TMP_DIR_ENTRIES)")
        string(APPEND indent "  ")
      endif()
    else()
      set(indent)
    endif()
    # Logic for handling paths and path fragments.
    cet_get_pv_property(${VAR_NAME} PROPERTY IS_PATH)
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
      list(APPEND defs_list "${indent}${set_func}(${CETMODULES_CURRENT_PROJECT_NAME}_${VAR_NAME} \"@PACKAGE_${VAR_NAME}@\")")
    else()
      list(APPEND defs_list
        "${indent}set(${CETMODULES_CURRENT_PROJECT_NAME}_${VAR_NAME} \"${VAR_VAL}\")")
    endif()
    if (indent)
      if (OMIT_IF_EMPTY)
        list(APPEND defs_list "  endif()"
          "  unset(_${CETMODULES_CURRENT_PROJECT_NAME}_TMP_DIR_ENTRIES)")
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

function(_verify_cross_dependent_exports EXPORT_SET)
  if (NOT ARGN) # Nothing to do.
    return()
  endif()
  list(FIND CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
    "${EXPORT_SET}" idx)
  if (idx EQUAL -1)
    message(FATAL_ERROR "cetmodules internal consistency error: report to developers")
  endif()
  math(EXPR idx "${idx} + 1")
  list(LENGTH CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME} num_sets)
  if (idx EQUAL num_sets)
    return()
  endif()
  list(SUBLIST CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
    ${idx} -1 other_exports)
  set(other_targets)
  foreach (other_export IN LISTS other_exports)
    if (CETMODULES_NAMESPACE_EXPORT_SET_${other_export}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
      list(TRANSFORM CETMODULES_TARGET_EXPORT_NAMES_EXPORT_SET_${other_export}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
        PREPEND "${CETMODULES_NAMESPACE_EXPORT_SET_${other_export}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}}::"
        OUTPUT_VARIABLE tmp)
    endif()
    list(APPEND other_targets "${tmp}")
  endforeach()
  if (other_targets)
    cet_regex_escape(NUM 1 VAR escaped_targets ${other_targets})
    list(JOIN escaped_targets "|" escaped_targets)
    install(CODE "\
# Check for badly-ordered export sets.
  set(_targetFiles \"${ARGN}\")
  foreach (_targetFile IN LISTS _targetFiles)
    file(READ \"\${_targetFile}\" _targetFileData)
    string(REGEX MATCHALL \"\\\"(${escaped_targets})\\\"\" _targetMatches \"\${_targetFileData}\")
    if (_targetMatches)
      string(REPLACE \";\" \" \" \"\${_targetMatches}\" _targetMatches)
      message(FATAL_ERROR \"export set \\\"${EXPORT_SET}\\\" refers to targets from export sets read later by dependent packages. Verify dependencies, split export sets, and / or register sets explicitly (cet_register_export_set()) in the desired order.
Problematic dependencies: \${_targetMatches}\\
\")
    endif()
  endforeach()\
")
  endif()
endfunction()

function(_generate_target_imports FRAG_LIST)
  set(exports)
  if (CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME} OR
      CETMODULES_IMPORT_COMMANDS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(IGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES TYPE BOOL DOCSTRING
      "Permit all absolute paths in transitive dependencies in targets exported by project ${CETMODULES_CURRENT_PROJECT_NAME}")
    project_variable(IGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES_REGEX TYPE STRING DOCSTRING
      "Regex describing absolute paths in transitive dependencies permitted in targets exported by project ${CETMODULES_CURRENT_PROJECT_NAME}")
    set(exports "\
####################################
# Exported targets, and package components.
####################################\
")
    foreach (export_set IN LISTS CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
      if (CETMODULES_EXPORTED_TARGETS_EXPORT_SET_${export_set}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
        # Generate and install target definition files (included by
        # top-level configs as appropriate).
        cet_passthrough(KEYWORD NAMESPACE
          CETMODULES_NAMESPACE_EXPORT_SET_${export_set}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
          namespace)
        if (NOT export_set MATCHES "Targets\$")
          set(export_file "${export_set}Targets")
        else()
          set(export_file "${export_set}")
        endif()
        # Export targets for import from the build tree.
        export(EXPORT ${export_set}
          FILE "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${export_file}.cmake"
          ${namespace}::)
        # Verify transitive dependencies. Note that the instructions
        # inserted into cmake_install.cmake need to be executed *before*
        # the CMake-generated ones that actually install the file.
        _verify_transitive_dependencies("${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/CMakeFiles/Export/${distdir}/${export_file}.cmake")
        # Export targets for import from the installed package.
        install(EXPORT ${export_set}
          DESTINATION "${distdir}"
          FILE "${export_file}.cmake"
          ${namespace}::)
        _verify_cross_dependent_exports(${export_set}
          "\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${distdir}/${export_file}.cmake"
          )
        list(APPEND exports "\

##################
# Automatically-generated runtime targets: ${export_set}
##################
include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_file}.cmake\")
foreach (component IN LISTS ${CETMODULES_CURRENT_PROJECT_NAME}_FIND_COMPONENTS)
  include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_file}_\${component}.cmake\")
endforeach()\
")
      endif()
    endforeach()
    if (CETMODULES_IMPORT_COMMANDS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
      list(TRANSFORM CETMODULES_EXPORTED_MANUAL_TARGETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
        PREPEND "    " OUTPUT_VARIABLE tmp)
      list(APPEND exports "\

##################
# Manually-generated non-runtime targets.
##################
set(_targetsDefined)
set(_targetsNotDefined)
set(_expectedTargets)
foreach (_expectedTarget IN ITEMS\
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
      list(TRANSFORM CETMODULES_IMPORT_COMMANDS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
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

function(_verify_transitive_dependencies _cet_target_file)
  # Armor the user's regex against interpolation.
  string(REGEX REPLACE "(\\\\|\\\")" "\\\\\\1" _cet_iadt_regex
    "${${CETMODULES_CURRENT_PROJECT_NAME}_IGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES_REGEX}")
  if (${CETMODULES_CURRENT_PROJECT_NAME}_IGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES)
    # Needed to avoid policy warnings when conditional code is
    # inserted in cmake_install.cmake.
    set(_cet_iadt "x")
  else()
    set(_cet_iadt "")
  endif()
  install(CODE "\
# Handle placeholders in target definitions.
  file(READ \"${_cet_target_file}\" _targetFileData)
  string(REPLACE \"@CET_DOLLAR@\" \"\$\" _targetFileData_new \"\${_targetFileData}\")
  if (NOT _targetFileData_new STREQUAL _targetFileData)
    file(WRITE \"${_cet_target_file}\" \"\${_targetFileData_new}\")
  endif()
  if (NOT \"${_cet_iadt}\" STREQUAL \"x\")
    # Check for unwanted absolute transitive dependencies.
    include(\"${CMAKE_CURRENT_FUNCTION_LIST_DIR}/private/CetFindAbsoluteTransitiveDependencies.cmake\")
    _cet_find_absolute_transitive_dependencies(\"${_cet_target_file}\"
       \"\${_targetFileData_new}\"
       \"${_cet_iadt_regex}\")
  endif()\
")
endfunction()

# Generate old cetbuildtools-style variables for targets produced by
# this package.
function(_generate_target_vars FRAG_LIST)
  set(var_settings)
  cet_regex_escape("${CETMODULES_CURRENT_PROJECT_NAME}" e_proj)
  string(TOUPPER "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}" product_name_uc)
  cet_regex_escape("${product_name_uc}" e_pname_uc)
  list(TRANSFORM CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME} REPLACE
    "^(.+)$" "CETMODULES_EXPORTED_TARGETS_EXPORT_SET_\\1_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}"
    OUTPUT_VARIABLE target_lists)
  set(handled_targets)
  foreach (target_list IN ITEMS ${target_lists}
      CETMODULES_EXPORTED_MANUAL_TARGETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    if (target_list MATCHES "_EXPORT_SET_(.*)_PROJECT_${e_proj}\$")
      set(namespace ${CETMODULES_NAMESPACE_EXPORT_SET_${CMAKE_MATCH_1}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}})
    else()
      set(namespace "${${CETMODULES_CURRENT_PROJECT_NAME}_NAMESPACE}")
    endif()
    foreach (target IN LISTS "${target_list}")
      get_property(var_target TARGET ${target}
        PROPERTY ALIASED_TARGET)
      set(var)
      if (NOT (var_target AND var_target IN_LIST handled_targets))
        get_property(target_type TARGET ${target} PROPERTY TYPE)
        if (NOT var_target)
          set(var_target "${target}")
        endif()
        if (CCC_EXTRA_TARGET_VARS)
          string(REGEX REPLACE "^.*::(.*)$" "\\1" var "${var_target}")
          string(TOUPPER "${var}" var)
          if (var IN_LIST CCC_EXTRA_TARGET_VARS)
          elseif ("${product_name_uc}_${var}" IN_LIST CCC_EXTRA_TARGET_VARS)
            set(var "${product_name_uc}_${var}")
          else()
            unset(var)
          endif()
        endif()
        if (NOT var AND
            target_type MATCHES "^(MODULE|SHARED|STATIC)_LIBRARY\$")
          string(TOUPPER "${var_target}" var)
          if (NOT var MATCHES "^${e_pname_uc}(_|\$)")
            string(PREPEND var "${product_name_uc}_")
          endif()
        endif()
        if (var)
          get_property(val TARGET ${target} PROPERTY EXPORT_NAME)
          if (NOT val)
            set(val ${target})
          endif()
          if (NOT val MATCHES "::")
            string(PREPEND val "${namespace}::")
          endif()
          list(APPEND var_settings "  set(${var} ${val})")
          list(APPEND handled_targets "${var_target}")
        endif()
      endif()
    endforeach()
  endforeach()
  if (var_settings)
    list(JOIN var_settings "\n" tmp)
    set(var_settings "\
####################################
# Old cetbuildtools-style target variables.
####################################
if (\${CETMODULES_CURRENT_PROJECT_NAME}_OLD_STYLE_CONFIG_VARS OR # Per-dependent setting.
 cetbuildtools_UPS_VERSION OR # Backward-compatibility.
 cetbuildtools IN_LIST \${CETMODULES_CURRENT_PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES)
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
  if (CETMODULES_FIND_DEPS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    list(APPEND transitive_deps
      "${CETMODULES_FIND_DEPS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}}")
  endif()
  # Find component-specific dependencies.
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  cet_regex_escape("${CETMODULES_CURRENT_PROJECT_NAME}" e_proj)
  set(component_regex "^CETMODULES_FIND_DEPS_COMPONENT_(.*)_PROJECT_${eproj}$")
  list(FILTER cache_vars INCLUDE REGEX "${component_regex}")
  list(TRANSFORM cache_vars REPLACE "${component_regex}" "\\1")
  # Load dependencies iff component is requested.
  foreach (component IN LISTS cache_vars)
    string(REPLACE "\n(.)" "\n  \\1" tmp "${CETMODULES_FIND_DEPS_COMPONENT_${component}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}}")
    list(APPEND transitive_deps "\
if (\"${component}\" IN LISTS ${CETMODULES_CURRENT_PROJECT_NAME}_FIND_COMPONENTS)
  ${tmp}
endif()\
")
  endforeach()
  if (transitive_deps)
    # Remove duplicates.
    list(REMOVE_DUPLICATES transitive_deps)
    # Add to result.
    list(PREPEND transitive_deps "\
####################################
# Transitive dependencies.
####################################
set(_${CETMODULES_CURRENT_PROJECT_NAME}_PACKAGE_PREFIX_DIR \"\${PACKAGE_PREFIX_DIR}\")\
")
    list(APPEND transitive_deps "\
set(PACKAGE_PREFIX_DIR \"\${_${CETMODULES_CURRENT_PROJECT_NAME}_PACKAGE_PREFIX_DIR}\")
unset(_${CETMODULES_CURRENT_PROJECT_NAME}_PACKAGE_PREFIX_DIR)\
")
    list(JOIN transitive_deps "\n" tmp)
    set(transitive_deps "${tmp}")
  endif()
  _write_stage(deps ${FRAG_LIST} "${transitive_deps}")
  set(${FRAG_LIST} "${${FRAG_LIST}}" PARENT_SCOPE)
  string(REPLACE "\n" ";" transitive_deps "${transitive_deps}")
  set(CETMODULES_TRANSITIVE_DEPS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME} "${transitive_deps}"
    CACHE INTERNAL "CMake Config transitive dependencies section for project ${CETMODULES_CURRENT_PROJECT_NAME}")
endfunction()

function(_prepend_cmake_module_path RESULTS_VAR PATH_VARS_VAR)
  if (CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    set(_PCMP_${PATH_VARS_VAR})
    set(_PCMP_COUNT 0)
    foreach (dir IN LISTS
        CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
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
  set(configStem "${CETMODULES_CURRENT_PROJECT_NAME}Config")
  set(config "${configStem}.cmake")
  set(configVersion "${configStem}Version.cmake")
  file(MAKE_DIRECTORY "${CCC_WORKDIR}")

  cet_localize_pv(cetmodules CONFIG_DIR)
  if (${CETMODULES_CURRENT_PROJECT_NAME}_EXTENDED_VERSION_SEMANTICS)
    include(CetWritePackageVersionFile)
    set(WRITE_PACKAGE_VERSION_FILE cet_write_package_version_file)
    # Needed by our templates.
    set(CVF_VERSION_INFO "${${CETMODULES_CURRENT_PROJECT_NAME}_VERSION_INFO}")
    configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ParseVersionString.cmake"
      ParseVersionString.cmake COPYONLY)
    install(FILES "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ParseVersionString.cmake"
      DESTINATION "${distdir}")
  else()
    set(WRITE_PACKAGE_VERSION_FILE write_basic_package_version_file)
  endif()

  cmake_language(CALL ${WRITE_PACKAGE_VERSION_FILE}
    "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${configVersion}"
	  VERSION "${CETMODULES_CURRENT_PROJECT_VERSION}"
	  COMPATIBILITY "${CCC_COMPATIBILITY}"
    ${ARCH_INDEPENDENT})

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

  # Post-process manual target definitions in top-level Config file.
  _verify_transitive_dependencies("${CCC_WORKDIR}/${config}")

  # Install top level config files.
  install(FILES
    "${CCC_WORKDIR}/${config}"
    "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${configVersion}"
    DESTINATION "${distdir}")

  # Generate a top-level config file for the build tree directly at its
  # final location.
  configure_package_config_file(
    "${CCC_WORKDIR}/${config}.in"
    "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${config}"
    INSTALL_PREFIX "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}"
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
