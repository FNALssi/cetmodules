########################################################################
# ProjectVariable.cmake
#
#   Utilities for defining and manipulating project-specific cache
#   variables, with optional propagation to dependent packages via
#   find_package().
#
####################################
# FUNCTION OVERVIEW
##################
#
# project_variable(<var-name> [<options>] [<initial-value>...])
#
#   Define a cached project variable ${PROJECT_NAME}_<var-name>,
#   extending the functionality of set(... CACHE...). Optionally ensure
#   that the variable is appropriately defined for dependents via
#   find_package().
#
# set_project_variable_property([<project-name>] <var-name>
#                               [APPEND|APPEND_STRING]
#                               PROPERTY <property> [<value>...])
#
#   Set (or add to) the property <property> for project variable
#   <project-name>_<var-name>. If <project-name> is not specified,
#   ${PROJECT_NAME} will be used.
#
# get_project_variable_property([<output-variable>] [PROJECT <project-name>]
#                               <var-name> PROPERTY <property>)
#
#   Get the value of the specified <property> for
#   <project_name>_<var-name>, storing in <output-variable>.
#
####################################
# FEATURES
##################
#
# * Any project variable may be propagated to dependent packages via the
#   non-default CONFIG option (see OPTIONS for project_variable(),
#   below).
#
# * The attributes of any project variable are stored in cache also, and
#   may be interrogated or changed via get_project_variable_property()
#   and set_project_variable_property() respectively.
#
# * In addition to the CMake variable types (see
#   https://cmake.org/cmake/help/latest/prop_cache/TYPE.html or
#   https://cmake.org/cmake/help/latest/command/set.html#set-cache-entry),
#   special types PATH_FRAGMENT and FILEPATH_FRAGMENT are available
#   indicating that they should be considered relative to
#   ${CMAKE_INSTALL_PREFIX} for the project.
#
# * Project variables representing path types will have
#   ${${PROJECT_NAME}_EXEC_PREFIX} prepended to their value if:
#
#     1. ${PROJECT_NAME}_EXEC_PREFIX is set; AND
#
#     2. <var-name> is defined as architecture-specific, as defined by
#        CetModules' defaults and modified by project variables
#        ${PROJECT_NAME}_ADD_ARCH_DIRS and
#        ${PROJECT_NAME}_ADD_NOARCH_DIRS; AND
#
#     3. The path is relative.
#
# * Order of precedence for the initial value of
#   ${PROJECT_NAME}_<var-name>:
#
#     1. The value of a CMake variable ${PROJECT_NAME}_<var-name> if it
#        is defined in the scope in which project_variable() is called
#        prior to the definition of the project variable. In this case,
#        the CMake variable is unset as a natural consequence of calling
#        set(... CACHE...).
#
#     2. The value of a CMake variable <var-name> if it is defined in
#        the current scope prior to the definition of the project
#        variable.
#
#     3. The value of a CMake or cached variable
#        ${PROJECT_NAME}_<var-name>_INIT.
#
#     4. The value of an existing cached variable
#        ${PROJECT_NAME}_<var-name>.
#
#     5. <initial-value>.
#
#     6. <backup-default> (if specified - see OPTIONS for
#        project_variable()) and <initial-value>... evaluates to FALSE).
#
# * All CONFIG project variables whose type matches
#   (FILE)?PATH(_FRAGMENT)? will be defined in
#   ${PROJECT_NAME}Config.cmake in such a way as to be correct
#   regardless of the package's installation location provided they
#   exist under the project's installation prefix. See
#   https://cmake.org/cmake/help/latest/module/CMakePackageConfigHelpers.html#command:configure_package_config_file
#   for details.
#
####################################
# project_variable(<var-name> [<options>] [<initial-value>...])
#
##################
# OPTIONS
##################
#
#   PUBLIC
#
#     Project variables will generally be marked "advanced"—not visible
#     by default in CMake configuration GUIs or to cmake -N -L in the
#     absence of the -A option. Specifying the PUBLIC option will negate
#     this.
#
#   BACKUP_DEFAULT <value>...
#
#     If provided, and in the event that IF (<initial-value>) evaluates
#     to FALSE, then this will be the default value of the cached
#     variable.
#
#   CONFIG
#
#     This variable will be propagated to dependent packages via
#     find_package() - in a location-independent way if appropriate to
#     the variable's TYPE - and as modified by any OMIT... options as
#     described below.
#
#   DOCSTRING <string>
#
#     A string describing the variable (defaults to a generic
#     description).
#
#   MISSING_OK
#
#     A variable whose TYPE matches (FILE)?PATH(_FRAGMENT)? but whose
#     value does not represent a valid path in the installation area
#     will cause an error at find_package() time unless this option is
#     specified.
#
#   NO_WARN_REDUNDANT
#
#     Do not warn about redundant options (e.g. if CONFIG is not
#     specified).
#
#   OMIT_IF_EMPTY
#
#     If specified, a project variable representing a directory (i.e. whose
#     TYPE matches PATH(_FRAGMENT)?) will be omitted from
#     ${PROJECT_NAME}Config.cmake if it contains no entries other than
#     `.' and ".."
#
#   OMIT_IF_MISSING
#
#     If specified, a project variable whose TYPE matches
#     (FILE)?PATH(_FRAGMENT)?  but whose value does not represent an
#     existing file or directory in the installation area will be
#     omitted from ${PROJECT_NAME}Config.cmake.
#
#   OMIT_IF_NULL
#
#     If specified, the definition of a vacuous project variable will be
#     omitted from ${PROJECT_NAME}Config.cmake.
#
#   TYPE
#
#     The type of the cached variable. Custom types PATH_FRAGMENT and
#     FILEPATH_FRAGMENT are accepted in addition to the values defined
#     and explained at
#     
#
#     PATH_FRAGMENT and FILEPATH_FRAGMENT are related to their official
#     partial namesakes in that they are treated as path-style values
#     for the purposes of handling in the CMake config file, but are
#     defined as STRING in CMake's cache in order to avoid unwanted
#     relative-to-absolute conversion for values specified on the
#     command line.
#
#     The default value of TYPE is PATH_FRAGMENT.
#
####################################
# PROPERTIES
##################
#
# These are not properties in the formal CMake sense, but are
# semantically similar.
#
# * CONFIG
# * MISSING_OK
# * OMIT_IF_EMPTY
# * OMIT_IF_MISSING
# * OMIT_IF_NULL
#
#   These boolean flags reflect the settings of the corresponding
#   options to project_variable().
#
# * IS_PATH
#
#   This boolean flag indicates whether the variable should be treated
#   as the location of a file or directory in the filesystem.
#
# * ORIGIN
#
#   This option indicates the origin of the initial value of the project
#   variable.
#
# * TYPE
#
#   This option indicates the type of the project variable as indicated
#   by the TYPE option to the project_variable() call.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

# Non-disruptive CMake version requirements.
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetRegexEscape)

# Default architecture-specific install directory types.
set(CETMODULES_DEFAULT_ARCH_DIRS BIN_DIR LIBEXEC_DIR LIBRARY_DIR)

# Type classifiers, including two special ones of our own that CMake
# doesn't know about.
set(_CPV_SPECIAL_PATH_TYPES PATH_FRAGMENT FILEPATH_FRAGMENT)
set(_CPV_PATH_TYPES PATH FILEPATH ${_CPV_SPECIAL_PATH_TYPES})

# Names that will clash with CMake's predefined variables.
set(_CPV_RESERVED_NAMES BINARY_DIR DESCRIPTION HOMEPAGE_URL SOURCE_DIR
  VERSION VERSION_MAJOR VERSION_MINOR VERSION_PATCH VERSION_TWEAK )

# Flag properties.
set(_CPV_FLAGS CONFIG IS_PATH MISSING_OK OMIT_IF_EMPTY OMIT_IF_MISSING
  OMIT_IF_NULL)

# Option properties.
set(_CPV_OPTIONS ORIGIN TYPE)

function(project_variable VAR_NAME)
  # Audit requested variable name for collisions with CMake.
  if (VAR_NAME IN_LIST _CPV_RESERVED_NAMES)
    message(SEND_ERROR "project variable name ${VAR_NAME} would clash with a variable defined by CMake")
  else()
    message(VERBOSE "defining project variable ${VAR_NAME} for ${PROJECT_NAME}")
  endif()
  cmake_parse_arguments(PARSE_ARGV 1 CPV
    "CONFIG;MISSING_OK;NO_WARN_REDUNDANT;OMIT_IF_EMPTY;OMIT_IF_MISSING;OMIT_IF_NULL;PUBLIC"
    "DOCSTRING;TYPE" "BACKUP_DEFAULT")
  if (NOT DEFINED CACHE{CETMODULES_VARS_PROJECT_${PROJECT_NAME}})
    # Cache variable listing all the project variables for the current project.
    set(CETMODULES_VARS_PROJECT_${PROJECT_NAME} CACHE INTERNAL
      "Valid project variables")
  endif()
  if (VAR_NAME IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    message(WARNING
      "duplicate definition of project variable ${PROJECT_NAME}_${VAR_NAME} ignored")
    return()
  endif()
  if (NOT (CPV_CONFIG OR CPV_NO_WARN_REDUNDANT))
    foreach (var IN ITEMS MISSING_OK OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL)
      if (CPV_${var})
        list(APPEND redundant_vars ${var})
      endif()
    endforeach()
    if (redundant_vars)
      message(WARNING "project_variable(${VAR_NAME}...): these options are redundant if CONFIG not specified: ${redundant_vars}")
    endif()
  endif()
  set_property(CACHE CETMODULES_VARS_PROJECT_${PROJECT_NAME} APPEND
    PROPERTY VALUE "${VAR_NAME}")
  if (NOT CPV_DOCSTRING)
    set(CPV_DOCSTRING "Project's setting for ${VAR_NAME}")
  endif()
  if (NOT CPV_TYPE)
    set(CPV_TYPE "PATH_FRAGMENT")
  endif()
  if (CPV_TYPE IN_LIST _CPV_SPECIAL_PATH_TYPES)
    # Need to avoid automatic absolute path conversion for command-line
    # values.
    set(VAR_TYPE "STRING")
  else()
    set(VAR_TYPE "${CPV_TYPE}")
  endif()
  set(ORIGIN)
  # Enforce precedence rules as described above:
  cet_regex_escape("${PROJECT_NAME}" e_proj)
  cet_regex_escape("${VAR_NAME}" e_var)
  get_property(cmake_vars DIRECTORY PROPERTY VARIABLES)
  list(FILTER cmake_vars INCLUDE REGEX "^(${e_proj}_${e_var}(_INIT)?|${e_var})$")
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  list(FILTER cache_vars INCLUDE REGEX "^(${e_proj}_${e_var}(_INIT)?|${e_var})$")
  if ("${PROJECT_NAME}_${VAR_NAME}" IN_LIST cmake_vars AND
      NOT (DEFINED CACHE{${PROJECT_NAME}_${VAR_NAME}} AND
        "$CACHE{${PROJECT_NAME}_${VAR_NAME}}" STREQUAL
        ${PROJECT_NAME}_${VAR_NAME}))
    # 1.
    set(DEFAULT_VAL "${${PROJECT_NAME}_${VAR_NAME}}")
    set(FORCE FORCE)
    set(ORIGIN "${PROJECT_NAME}_${VAR_NAME}")
  elseif (DEFINED ${VAR_NAME})
    # 2.
    set(DEFAULT_VAL "${${VAR_NAME}}")
    set(FORCE FORCE)
    set(ORIGIN "${VAR_NAME}")
  elseif (DEFINED ${PROJECT_NAME}_${VAR_NAME}_INIT)
    # 3.
    set(DEFAULT_VAL "${${PROJECT_NAME}_${VAR_NAME}_INIT}")
    set(FORCE FORCE)
    set(ORIGIN "${PROJECT_NAME}_${VAR_NAME}_INIT")
    unset(${PROJECT_NAME}_${VAR_NAME}_INIT)
  else()
    unset(FORCE)
    set(DEFAULT_VAL "${CPV_UNPARSED_ARGUMENTS}")
    # 5.
    set(DEFAULT_ORIGIN "<initial-value>")
    if (NOT DEFAULT_VAL AND CPV_BACKUP_DEFAULT)
      set(DEFAULT_VAL "${CPV_BACKUP_DEFAULT}")
      # 6.
      set(DEFAULT_ORIGIN "<backup-default>")
    endif()
    if (NOT DEFINED CACHE{${PROJECT_NAME}_${VAR_NAME}})
      set(ORIGIN "${DEFAULT_ORIGIN}")
    endif()
  endif()
  ##################
  # Avoid hysteresis.
  unset(${PROJECT_NAME}_${VAR_NAME}_INIT CACHE)
  ##################
  # Make the project variable known to the CMake cache.
  message(DEBUG "set(${PROJECT_NAME}_${VAR_NAME} ${DEFAULT_VAL} CACHE ${VAR_TYPE} ${CPV_DOCSTRING} ${FORCE})")
  set(${PROJECT_NAME}_${VAR_NAME} "${DEFAULT_VAL}"
    CACHE ${VAR_TYPE} "${CPV_DOCSTRING}" ${FORCE})
  # Defining cached variable automatically erases the eponymous CMake
  # variable in the current scope only.
  unset(${PROJECT_NAME}_${VAR_NAME} PARENT_SCOPE)
  if (CPV_PUBLIC)
    set(advanced CLEAR)
  else()
    set(advanced FORCE)
    mark_as_advanced(${advanced} ${PROJECT_NAME}_${VAR_NAME})
  endif()
  get_property(current_val CACHE ${PROJECT_NAME}_${VAR_NAME} PROPERTY VALUE)
  if (NOT ORIGIN)
    # 4.
    set(ORIGIN "<pre-cached_value>")
  elseif (CPV_TYPE IN_LIST _CPV_SPECIAL_PATH_TYPES AND
      ${PROJECT_NAME}_EXEC_PREFIX AND current_val AND
      (VAR_NAME IN_LIST CETMODULES_DEFAULT_ARCH_DIRS OR
        VAR_NAME IN_LIST ${PROJECT_NAME}_ADD_ARCH_DIRS) AND
      NOT VAR_NAME IN_LIST ${PROJECT_NAME}_ADD_NOARCH_DIRS)
    list(TRANSFORM current_val
      REPLACE [[^([^/].*)$]] "${${PROJECT_NAME}_EXEC_PREFIX}/\\1")
    set_property(CACHE ${PROJECT_NAME}_${VAR_NAME} PROPERTY VALUE ${current_val})
  endif()
  ##################
  # Set "properties" of each project variable that we can interrogate
  # later.
  set(CETMODULES_${VAR_NAME}_PROPERTIES_PROJECT_${PROJECT_NAME} CACHE INTERNAL
    "Properties for project variable ${PROJECT_NAME}_${VAR_NAME}")
  set_project_variable_property(${VAR_NAME} PROPERTY ORIGIN "${ORIGIN}")
  set_project_variable_property(${VAR_NAME} PROPERTY TYPE "${CPV_TYPE}")
  foreach(var IN ITEMS CONFIG OMIT_IF_NULL)
    if (CPV_${var})
      set_project_variable_property(${VAR_NAME} PROPERTY ${var})
    endif()
  endforeach()
  if (CPV_TYPE IN_LIST _CPV_PATH_TYPES)
    set_project_variable_property(${VAR_NAME} PROPERTY IS_PATH)
    foreach (var IN ITEMS MISSING_OK OMIT_IF_MISSING)
      if (CPV_${var})
        set_project_variable_property(${VAR_NAME} PROPERTY ${var})
      endif()
    endforeach()
  else()
    foreach(var IN ITEMS OMIT_IF_MISSING MISSING_OK)
      if (CPV_${var})
        message(WARNING "${var} not valid for project variable ${PROJECT_NAME}_${VAR_NAME} of TYPE ${CPV_TYPE}")
      endif()
    endforeach()
  endif()
  if (CPV_OMIT_IF_EMPTY)
    if (CPV_TYPE MATCHES [[^PATH(_FRAGMENT)?$]])
      set_project_variable_property(${VAR_NAME} PROPERTY OMIT_IF_EMPTY)
    else()
      message(WARNING "${var} not valid for project variable ${PROJECT_NAME}_${VAR_NAME} of TYPE ${CPV_TYPE}")
    endif()
  endif()
endfunction()

# Set the specified CMake or project variable property.
function(set_project_variable_property)
  list(FIND ARGV "PROPERTY" PROP_IDX)
  list(SUBLIST ARGV ${PROP_IDX} -1 VALS)
  list(POP_FRONT VALS PROP_KW PROP)
  list(SUBLIST ARGV 0 ${PROP_IDX} ARGS)
  cmake_parse_arguments(SPVP "APPEND;APPEND_STRING" "" "" ${ARGS})
  list(POP_BACK SPVP_UNPARSED_ARGUMENTS PVAR PROJ)
  if (NOT PROJ)
    set(PROJ "${PROJECT_NAME}")
  endif()
  if (SPVP_UNPARSED_ARGUMENTS OR NOT (PROJ AND PVAR AND PROP_KW STREQUAL "PROPERTY" AND PROP))
    message(FATAL_ERROR "set_project_variable_property(): bad arguments ${ARGV}"
      "\nUSAGE: set_project_variable_property([<project-name>] <var-name> [APPEND|APPEND_STRING] PROPERTY <property> [<value>...])")
  endif()
  if (NOT PVAR IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    # Don't know this project variable.
    message(FATAL_ERROR "set_project_variable_property(): project variable ${PROJ}_${PVAR} has not been defined")
  endif()
  get_property(cached_properties
    CACHE CETMODULES_${PVAR}_PROPERTIES_PROJECT_${PROJ} PROPERTY VALUE)
  if (PROP IN_LIST _CPV_FLAGS)
    # Flag.
    if (SPVP_APPEND OR SPVP_APPEND_STRING)
      message(FATAL_ERROR "set_project_variable_property(): APPEND/APPEND_STRING invalid for flag ${PROP}"
        "\nSet flag without <VALUE>, or reset with non-empty <VALUE> evaluating to FALSE.")
    endif()
    list(REMOVE_ITEM cached_properties "${PROP}")
    if (VALS OR VALS STREQUAL "") # Flag should be set.
      list(APPEND cached_properties "${PROP}")
    endif()
  elseif (PROP IN_LIST _CPV_OPTIONS)
    # Valued property.
    set(PVAL)
    list(FIND cached_properties "${PROP}" PROP_IDX)
    if (PROP_IDX GREATER -1)
      # Save.
      list(SUBLIST cached_properties ${PROP_IDX} 2 PVAL)
      # Remove for manipulation.
      list(REMOVE_AT cached_properties ${PROP_IDX})
      list(REMOVE_AT cached_properties ${PROP_IDX})
      # Don't need property name any more.
      list(POP_FRONT PVAL)
    endif()
    if (SPVP_APPEND_STRING)
      # Treat as a string append.
      string(APPEND PVAL "${VALS}")
    elseif (SPVP_APPEND)
      # Treat as a list append.
      list(APPEND PVAL ${VALS})
    else()
      # Set.
      set(PVAL ${VALS})
    endif()
    list(APPEND cached_properties ${PROP} "${PVAL}")
  else()
    message(FATAL_ERROR
      "set_project_variable_property(): unrecognized property ${PROP}"
      "\nKnown flags: ${_CPV_FLAGS}"
      "\nKnown options: ${_CPV_OPTIONS}")
  endif()
  set_property(CACHE CETMODULES_${PVAR}_PROPERTIES_PROJECT_${PROJ}
    PROPERTY VALUE ${cached_properties})
endfunction()

function(get_project_variable_property)
  cmake_parse_arguments(PARSE_ARGV 0 GPVP "" "PROJECT" "")
  # Read backwards.
  list(POP_BACK GPVP_UNPARSED_ARGUMENTS PROP PROP_KW PVAR)
  if (GPVP_PROJECT)
    set(PROJ "${GPVP_PROJECT}")
    list(POP_FRONT GPVP_UNPARSED_ARGUMENTS OUT_VAR)
  else()
    list(POP_FRONT GPVP_UNPARSED_ARGUMENTS OUT_VAR PROJ)
    if (NOT PROJ)
      set(PROJ "${PROJECT_NAME}")
    endif()
  endif()
  if (NOT OUT_VAR)
    set(OUT_VAR "${PROP}")
  endif()
  if (GPVP_UNPARSED_ARGUMENTS OR
      NOT (PROJ AND PVAR AND OUT_VAR AND PROP_KW STREQUAL "PROPERTY" AND PROP))
    message(FATAL_ERROR [=[
get_project_variable_property bad arguments ${ARGV}
USAGE: get_project_variable_property([<output-variable>] [PROJECT <project-name>] <var-name> PROPERTY <property>)
       If <output-variable> and <project-variable> are both specified, the PROJECT keyword is optional]=])
  endif()
  if (NOT PVAR IN_LIST CETMODULES_VARS_PROJECT_${PROJ})
    # Don't know this project variable.
    message(FATAL_ERROR "get_project_variable_property(): project variable ${PROJ}_${PVAR} has not been defined")
  endif()
  get_property(cached_properties CACHE
    CETMODULES_${PVAR}_PROPERTIES_PROJECT_${PROJ} PROPERTY VALUE)
  if (PROP IN_LIST _CPV_FLAGS)
    # Flag.
    if (PROP IN_LIST cached_properties)
      set(RESULT TRUE)
    else()
      set(RESULT FALSE)
    endif()
  elseif (PROP IN_LIST _CPV_OPTIONS)
    # Valued property.
    set(RESULT)
    list(FIND cached_properties "${PROP}" PROP_IDX)
    if (PROP_IDX GREATER -1)
      # Save.
      list(SUBLIST cached_properties ${PROP_IDX} 2 PVAL)
      # Don't need property name.
      list(POP_FRONT PVAL)
      set(RESULT ${PVAL})
    endif()
  else()
    message(FATAL_ERROR
      "get_project_variable_property(): unrecognized property ${PROP}"
      "\nKnown flags: ${_CPV_FLAGS}"
      "\nKnown options: ${_CPV_OPTIONS}")
  endif()
  set(${OUT_VAR} ${RESULT} PARENT_SCOPE)
endfunction()

cmake_policy(POP)
