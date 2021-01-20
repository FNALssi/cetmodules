#[================================================================[.rst:
CetCMakeUtils
=============

General functions and macros.
#]================================================================]

include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetRegexEscape)

#[================================================================[.rst:
.. cmake:command:: cet_passthrough

   **Synopsis:**
     .. code-block:: cmake

       cet_passthrough([FLAG|ARMOR] [KEYWORD <keyword>] <in_var> IN_PLACE|<out-var>)
       cet_passthrough([FLAG|ARMOR] VALUES [<val>...] KEYWORD <keyword> <out-var>)

     Turn a flag or option value into something that can be passed on to
     another function or macro.

   **Options:**
     ``ARMOR``

       Apply an extra \`layer of armor' ("\\" -> "\\\\") to enable the
       result to be passed to another function without quoting in order
       to preserve empty-list semantics. See
       :cmake:command:`cet_armor_string` for details.

     ``FLAG``

       If ``<in-var>`` or ``VALUES`` evaluates to ``TRUE``, the result
       is ``<keyword>`` (or see ``KEYWORD``, below). Otherwise the
       result will be ``NULL``.

     ``IN_PLACE``

       If ``<in-var>`` is specified this option signifies that the
       result will be placed in ``<in-var>``. In this case ``<out-var>``
       must then *not* be present.

     ``KEYWORD <keyword>``

       If specified, the option keyword will be
       ``<keyword>``. Otherwise, if ``<in-var>`` is specified, then it
       will be the name "``<in-var>``" with any leading ``<word>_``
       stripped off the front. Failing that, the name "``<out-var>``"
       will be used as the default.

     ``VALUES <val>...``

       The values to be passed through to another function or macro may
       be specified as ``<val>...`` rather than as ``<in-var>``. In this
       case, :option:<out-var>` is required and ``IN_PLACE`` is not
       permitted.

   **Non-option arguments:**
     ``<in-var>``

       The name of a variable holding the values to be passed
       through. ``<in-var>`` must *not* be present if ``VALUES`` is
       specified.

     ``<out-var>``

       The name of a variable to hold the values in passthrough form. If
       ``IN_PLACE`` and ``<in-var>`` are both specified, than
       ``<out-var>`` must *not* be present.

   **Examples**
     .. code-block:: cmake

        cet_passthrough(FLAG IN_PLACE MYOPTS_VERBOSE)

     ``MYOPTS_VERBOSE`` will have the value "VERBOSE" in the calling
     function or macro.

     .. code-block:: cmake

        cet_passthrough(FLAG VALUES "NOTFOUND" USE_MYPACKAGE)

     ``USE_MYPACKAGE`` will be empty in the calling function or macro.

     .. code-block:: cmake

        cet_passthrough(FLAG VALUES "MYTEXT" USE_MYPACKAGE)

     ``USE_MYPACKAGE`` will have the value ``USE_MYPACKAGE`` in the
     calling function or macro.

     .. code-block:: cmake

        cet_passthrough(IN_PLACE VALUES
          "Mary had a little lamb; Its fleece was white as snow"
          KEYWORD RHYME MARY_LAMB)

     The list ``MARY_LAMB`` will have the values:

     .. code-block:: console

        "RHYME" "Mary had a little lamb" "Its fleece was white as snow"

     in the calling function or macro. Note the lack of whitespace at
     the beginning of the third element of the list.

     .. code-block:: cmake

        cet_passthrough(IN_PLACE VALUES
          "Mary had a little lamb\\\\; Its fleece was white as snow"
          KEYWORD RHYME MARY_LAMB)

     The list ``MARY_LAMB`` will have the values:

     .. code-block:: console

        "RHYME" "Mary had a little lamb; Its fleece was white as snow"

     in the calling function or macro.
#]================================================================]
function(cet_passthrough)
  cmake_parse_arguments(PARSE_ARGV 0 CP
    "APPEND;FLAG;IN_PLACE" "KEYWORD" "VALUES")
  if (NOT (CP_VALUES OR "VALUES" IN_LIST CP_KEYWORDS_MISSING_VALUES))
    list(POP_FRONT CP_UNPARSED_ARGUMENTS CP_IN_VAR)
    if (CP_IN_VAR MATCHES
        "^CP_(IN_PLACE|IN_VAR|KEYWORD|KEYWORDS_MISSING_VALUES|OUT_VAR|UNPARSED_ARGUMENTS|VALUES)$")
      message(FATAL_ERROR "value of IN_VAR non-option argument (\"${CP_IN_VAR}\") is \
not permitted - specify values with VALUES instead\
")
    elseif (NOT CP_IN_VAR)
      message(FATAL_ERROR "vacuous IN_VAR non-option argument - missing VALUES?")
    elseif (NOT CP_KEYWORD)
      string(REGEX REPLACE "^_*[^_]+_(.*)$" "\\1" CP_KEYWORD "${CP_IN_VAR}")
    endif()
    if (CP_IN_PLACE)
      if (CP_APPEND)
        message(FATAL_ERROR "options IN_PLACE and APPEND are mutually exclusive")
      endif()
      set(CP_OUT_VAR "${CP_IN_VAR}")
    endif()
  elseif (CP_IN_PLACE)
    message(FATAL_ERROR "options IN_PLACE and VALUES are mutually exclusive")
  else()
    set(CP_IN_VAR CP_VALUES)
  endif()
  if (NOT CP_OUT_VAR)
    list(POP_FRONT CP_UNPARSED_ARGUMENTS CP_OUT_VAR)
    if (NOT CP_OUT_VAR)
      message(FATAL_ERROR "vacuous OUT_VAR non-option argument")
    endif()
  endif()
  if (NOT CP_KEYWORD)
    set(CP_KEYWORD  "${CP_OUT_VAR}")
  endif()
  if (CP_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "unexpected non-option arguments ${CP_UNPARSED_ARGUMENTS}")
  endif()
  if (CP_FLAG AND ${CP_IN_VAR})
    if (CP_APPEND)
      list(APPEND ${CP_OUT_VAR} ${CP_KEYWORD})
      set(${CP_OUT_VAR} "${${CP_OUT_VAR}}" PARENT_SCOPE)
    else()
      set(${CP_OUT_VAR} ${CP_KEYWORD} PARENT_SCOPE)
    endif()
  elseif (${CP_IN_VAR})
    if (CP_APPEND)
      list(APPEND ${CP_OUT_VAR} ${CP_KEYWORD} ${${CP_IN_VAR}})
      set(${CP_OUT_VAR} "${${CP_OUT_VAR}}" PARENT_SCOPE)
    else()
      set(${CP_OUT_VAR} ${CP_KEYWORD} "${${CP_IN_VAR}}" PARENT_SCOPE)
    endif()
  elseif (CP_FLAG AND NOT CP_APPEND)
    unset(${CP_OUT_VAR} PARENT_SCOPE)
  endif()
endfunction()

#[================================================================[.rst:
.. cmake:command:: cet_source_file_extensions

   Produce an ordered list of source file extensions for enabled
   languages.

   **Synopsis:**
     .. code-block:: cmake

        cet_source_file_extensions(<out-var>)

   **Non-option arguments:**

   .. note::

      Prescribed order of enabled languages: ``CUDA`` ``CXX`` ``C``
      ``Fortran`` ``<lang>...`` ``ASM``
#]================================================================]
function(cet_source_file_extensions RESULTS_VAR)
  set(source_glob)
  get_property(enabled_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
  # Specific order.
  list(REMOVE_ITEM enabled_languages ASM Fortran C CXX CUDA)
  list(PREPEND enabled_languages CUDA CXX C Fortran)
  list(APPEND enabled_languages ASM)
  foreach (lang IN LISTS enabled_languages)
    if (CMAKE_${lang}_COMPILER_LOADED)
      list(APPEND source_glob ${CMAKE_${lang}_SOURCE_FILE_EXTENSIONS})
    endif()
  endforeach()
  set(${RESULTS_VAR} "${source_glob}" PARENT_SCOPE)
endfunction()

#[================================================================[.rst:
.. cmake:command:: cet_exclude_files_from

   Remove duplicates and other files from a list, specifically or by
   regular expression.

   **Synopsis:**
     .. code-block:: cmake

        cet_exclude_files_from(<list> [REGEX <regex>...]
          [NOP] <file>...)

   **Options:**

     ``NOP``

       Optional separator between a list option and non-option
       arguments; no other effect.

     ``REGEX``

       Entries in ``<list>`` matching ``<regex>...`` will be removed.

   **Non-option arguments:**

     ``<list>``

       The name of a list of files to be pruned

     ``<file>...``

       Files to be removed from ``<list>`` (exact matches only).

   .. note::

      Relative paths are interpreted relative to
      ``${CMAKE_CURRENT_SOURCE_DIR}``.
#]================================================================]
function(cet_exclude_files_from SOURCES)
  if (NOT ${SOURCES} OR NOT ARGN) # Nothing to do.
    return()
  endif()
  # Remove known plugin sources and anything else the user specifies.
  cmake_parse_arguments(PARSE_ARGV 1 CEFF "NOP" "" "REGEX")
  if (CEFF_REGEX)
    list(JOIN CEFF_REGEX "|" regex)
    list(FILTER ${SOURCES} EXCLUDE REGEX "(${regex})")
  endif()
  if (CEFF_UNPARSED_ARGUMENTS)
    # Transform relative paths with respect to the current source
    # directory.
    list(TRANSFORM CEFF_UNPARSED_ARGUMENTS
      PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/"
      REGEX [=[^[^/]]=])
    # Remove exact matches only.
    list(REMOVE_ITEM ${SOURCES} ${CEFF_UNPARSED_ARGUMENTS})
  endif()
  list(REMOVE_DUPLICATES ${SOURCES})
  set(${SOURCES} "${${SOURCES}}" PARENT_SCOPE)
endfunction()

#[================================================================[.rst:
.. cmake:command:: cet_timestamp

   Generate a current timestamp.

   **Synopsis:**
     .. code-block:: cmake

        cet_timestamp(<out-var> [<fmt>])

   **Non-option arguments:**

     ``<out-var>``

       Variable in which to store the formatted timestamp.

     ``<fmt>``

       The desired format of the timestamp, using ``%`` placeholders
       according to :ref:`string(TIMESTAMP)
       <cmake.org:TIMESTAMP>`. In addition, timezone
       placeholders ``%Z`` and ``%z`` are interpreted according to your
       system's :command:`date` command.

   **Examples:**
     * .. code-block:: cmake

          cet_timestamp(RESULT)
          message(STATUS "${RESULT}")

       ``-- Sun Jan 01 23:59:59 CST 1970``

     * .. code-block:: cmake

          cet_timestamp(RESULT "%Y-%m-%d %H:%M:%S %z")
          message(STATUS "${RESULT}")

       ``-- 1970-01-01 23:59:59 -0600``

   .. versionchanged:: 2.07.00

      Prior to version 2.07.00, "%Y" was missing from the default
      format.

   .. seealso:: :cmake:command:`string(TIMESTAMP) <cmake:command:string(TIMESTAMP)>`, :command:`date`
#]================================================================]
function(cet_timestamp VAR)
  list(POP_FRONT ARGN fmt)
  if (NOT fmt)
    set(fmt "%a %b %d %H:%M:%S %Z %Y")
  endif()

  # Get local timezone.
  if (NOT CET_TZ)
    _cet_init_tz()
    set(CET_TZ ${CET_TZ} PARENT_SCOPE)
    set(CET_tz ${CET_tz} PARENT_SCOPE)
  endif()

  # Use standard U**X date formats for timezone info.
  string(REPLACE "%Z" "${CET_TZ}" fmt "${fmt}")
  string(REPLACE "%z" "${CET_tz}" fmt "${fmt}")

  # Timestamp.
  string(TIMESTAMP result "${fmt}")
  string(STRIP "${result}" result)
  set(${VAR} ${result} PARENT_SCOPE)
endfunction()

#[================================================================[.rst:
.. cmake:command:: cet_find_simple_package

   :cmake:command:`find_package() <cmake:command:find_package>` for
   packages without generated CMake config files or a ``Find<name>.cmake``
   module.

   **Synopsis:**
     .. code-block:: cmake

        find_simple_package([HEADERS <header>...]
          [INCPATH_SUFFIXES <dir>...] [INCPATH_VAR <var>]
          [LIB_VAR <var>] [LIBNAMES <libname>...]
          [LIBPATH_SUFFIXES <dir>...]
          <name>)

   **Options:**

     ``HEADERS <header>...``

       Look for ``<header>...`` to ascertain the include path. If not
       specified, use ``<name>.{h,hh,H,hxx,hpp}``

     ``INCPATH_SUFFIXES <dir>...``

       Add ``<suffix>...`` to paths when searching for headers (defaults
       to "include").

     ``INCPATH_VAR <var>``

       Store the found include path in ``<var>``. If not specified, we
       invoke :cmake:command:`include_directories()
       <cmake:command:include_directories>` with the found include path.

     ``LIB_VAR <var>``

       Store the found library as ``<var>``. If not specified, use
       ``<name>`` as converted to an upper case identifier.

     ``LIBNAMES <libname>...``

       Look for ``<libname>...`` as a library in addition to ``name``.

     ``LIBPATH_SUFFIXES <dir>...``

       Add ``<dir>...`` to paths when searching for libraries.

   **Non-option arguments:**

     ``<name>``

       The primary name of the library (without prefix or suffix) or
       headers to be found.

   **Variables controlling behavior:**

     :cmake:variable:`WANT_INCLUDE_DIRECTORIES`

   .. :deprecated:: 2.0

      If no ``FindXXX.cmake`` module or CMake config file is available
      for ``<name>``, write your own find module or request one from the
      SciSoft team.
#]================================================================]
function(cet_find_simple_package NAME)
  cmake_parse_arguments(PARSE_ARGV 1 CFSP
    ""
    "INCPATH_VAR;LIB_VAR"
    "HEADERS;LIBNAMES;LIBPATH_SUFFIXES;INCPATH_SUFFIXES")
  if (NOT CFSP_LIB_VAR)
    string(TOUPPER "${NAME}" CFSP_LIB_VAR)
    string(MAKE_C_IDENTIFIER "${CFSP_LIB_VAR}" CFSP_LIB_VAR)
  endif()
  if (CFSB_PATH_SUFFIXES)
    list(INSERT CFSB_PATH_SUFFIXES 0 PATH_SUFFIXES)
  endif()
  cet_find_library(${CFSP_LIB_VAR} NAMES ${NAME} ${CFSP_LIBNAMES}
    ${CFSP_LIBPATH_SUFFIXES}
    NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH
    )
  set(${CFSP_LIB_VAR} ${${CFSP_LIB_VAR}} PARENT_SCOPE)
  if (NOT CFSP_HEADERS)
    set(CFSP_HEADERS ${NAME}.h ${NAME}.hh ${NAME}.H ${NAME}.hxx ${NAME}.hpp)
  endif()
  if (NOT CFSP_INCPATH_VAR)
    set(CFSP_INCPATH_VAR ${CFSP_LIB_VAR}_INCLUDE)
    set(WANT_INCLUDE_DIRECTORIES ON)
  endif()
  find_path(${CFSP_INCPATH_VAR}
    NAMES ${CFSP_HEADERS}
    PATH_SUFFIXES ${CFSP_INCPATH_SUFFIXES}
    NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH
    )
  if (WANT_INCLUDE_DIRECTORIES)
    include_directories(${${CFSP_INCPATH_VAR}})
  endif()
endfunction()

#[================================================================[.rst:
.. cmake:command:: cet_localize_pv

   Ensure that all fragment-type :cmake:manual:`project variables
   <cetmodules-project-variables.7>` are absolute in the current
   directory scope for in-tree project ``<project>``.

   **Synopsis:**
     .. code-block:: cmake

        cet_localize_pv(<project>)

   **Non-option arguments:**
     ``<project>``

       The name of a CMake project in the current source tree.
#]================================================================]
function(cet_localize_pv PROJECT)
  if (NOT ${PROJECT}_IN_TREE)
    message(SEND_ERROR "cannot localize project variables: project ${PROJECT} is not local or missing find_package()")
  endif()
  if (ARGN STREQUAL "ALL")
    set(var_list "CETMODULES_VARS_PROJECT_${PROJECT}")
    set(check_pv_validity)
  else()
    set(var_list ARGN)
    set(check_pv_validity TRUE)
  endif()
  foreach (var IN LISTS ${var_list})
    if (check_pv_validity AND NOT
        var IN_LIST "CETMODULES_VARS_PROJECT_${PROJECT}")
      message(SEND_ERROR "cannot localize unknown project variable ${var} for project ${PROJECT}")
    elseif (NOT ${PROJECT}_${var} OR IS_ABSOLUTE "${${PROJECT}_${var}}")
      continue() # Nothing to do.
    endif()
    set(result)
    set(generated)
    get_project_variable_property(type PROJECT ${PROJECT} ${var} PROPERTY TYPE)
    if (type MATCHES ^FILEPATH)
      get_filename_component(result "${${PROJECT}_${var}}" ABSOLUTE BASE_DIR "${${PROJECT}_BINARY_DIR}")
      get_property(generated SOURCE "${result}" PROPERTY GENERATED)
    endif()
    if (type MATCHES ^PATH OR (result AND NOT (generated OR EXISTS "${result}")))
      get_filename_component(result "${${PROJECT}_${var}}" ABSOLUTE BASE_DIR "${${PROJECT}_SOURCE_DIR}")
    endif()
    if (result)
      set(${PROJECT}_${var} "${result}" PARENT_SCOPE)
    elseif (check_pv_validity)
      message(SEND_ERROR "cannot localize non-path project variable ${var} for project ${PROJECT}")
    endif()
  endforeach()
endfunction()

#[================================================================[.rst:
.. cmake:command:: cet_localize_pv_all

   **Synopsis:**
     .. code-block:: cmake

        cet_localize_pv_all(<project>)

     Equivalent to :cmake:command:`cet_localize_pv(<project> ALL)`.
#]================================================================]
function(cet_localize_pv_all PROJECT)
  cet_localize_pv(PROJECT ALL)
endfunction()

#[================================================================[.rst:
.. cmake:command:: cet_cmake_module_directories

   **Synopsis:**
     .. code-block:: cmake

        cet_cmake_module_directories([NO_CONFIG] [NO_LOCAL] [PROJECT <project>]
          <dir>...)

   **Options:**
     ``NO_CONFIG``

       Do not add these directories to
       :cmake:variable:`CMAKE_MODULE_PATH <cmake:variable:CMAKE_MODULE_PATH>`
       in the CMake config file for ``<project>``.

     ``NO_CONFIG``

       Do not add these directories to 
       :cmake:variable:`CMAKE_MODULE_PATH <cmake:variable:CMAKE_MODULE_PATH>`
       in the current scope. Implied if ``<project>`` is not equal to
       :cmake:variable:`PROJECT_NAME <cmake:variable:PROJECT_NAME>`

      ``PROJECT <project>``

        Specify the project to which these module directories belong. If
        not specifed, ``<project>`` defaults to
        :cmake:variable:`PROJECT_NAME <cmake:variable:PROJECT_NAME>`.

   **Non-option arguments:**
     ``<dir>...``

     Directories containing CMake modules.
#]================================================================]
function(cet_cmake_module_directories)
  cmake_parse_arguments(PARSE_ARGV 0 CMD "NO_LOCAL;NO_CONFIG" "PROJECT" "")
  if (CMD_PROJECT)
    if (NOT CMD_PROJECT STREQUAL PROJECT_NAME)
      set(NO_LOCAL TRUE)
    endif()
  else()
    set(CMD_PROJECT "${PROJECT_NAME}")
  endif()
  if (NOT CMD_NO_LOCAL)
    list(TRANSFORM CMD_UNPARSED_ARGUMENTS PREPEND "${PROJECT_SOURCE_DIR}/"
      REGEX "^[^/]+" OUTPUT_VARIABLE tmp)
    list(PREPEND CMAKE_MODULE_PATH "${tmp}")
    set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
  endif()
  if (NOT CMD_NO_CONFIG)
    if (NOT DEFINED CACHE{CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${CMD_PROJECT}})
      set(CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${CMD_PROJECT} ${CMD_UNPARSED_ARGUMENTS}
        CACHE INTERNAL "CMAKE_MODULE_PATH additions for ${CMD_PROJECT}Config.cmake")
    else()
      set_property(CACHE
        CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${CMD_PROJECT}
        APPEND PROPERTY VALUE ${CMD_UNPARSED_ARGUMENTS})
    endif()
  endif()
endfunction()

if (CMAKE_SCRIPT_MODE_FILE) # Smoke test.
  cet_passthrough(KEYWORD RHYME MARY_LAMB "Mary had a little lamb\\; Its fleece was white as snow")
  list(LENGTH MARY_LAMB len)
  if (NOT len EQUAL 2)
    message(FATAL_ERROR "MARY_LAMB has ${len} elements - expected 2")
  endif()
endif()

function(_cet_init_tz)
  # We have to get timezone externally because CMake won't tell us what
  # it is.
  set(tz_cmd date +%Z)
  execute_process(COMMAND ${tz_cmd}
    OUTPUT_VARIABLE TZ
    ERROR_VARIABLE tz_error
    RESULT_VARIABLE tz_status)
  if (tz_error OR NOT (${tz_status} EQUAL 0 AND TZ))
    message(WARNING "attempt to obtain local timezone code with \"${tz_cmd}\" \
returned status code ${tz_status} and error output \"${tz_error}\" in addition to output \"${TZ}\"\
")
  endif()
  set(CET_TZ ${TZ} PARENT_SCOPE)
endfunction()

function(_cet_export_import_cmd)
  cmake_parse_arguments(PARSE_ARGV 0 _cc "" "" "COMMANDS;TARGETS")
  if (NOT _cc_COMMANDS)
    set(_cc_COMMANDS "${_cc_UNPARSED_ARGUMENTS}")
  endif()
  string(REPLACE "\n" ";" _cc_COMMANDS "${_cc_COMMANDS}")
  if (DEFINED CACHE{CETMODULES_IMPORT_COMMANDS_PROJECT_${PROJECT_NAME}})
    set_property(CACHE CETMODULES_IMPORT_COMMANDS_PROJECT_${PROJECT_NAME}
      APPEND PROPERTY VALUE "${_cc_COMMANDS}")
  else()
    set(CETMODULES_IMPORT_COMMANDS_PROJECT_${PROJECT_NAME}
      "${_cc_COMMANDS}" CACHE INTERNAL
      "Convenience aliases for exported non-runtime targets for project ${PROJECT_NAME}")
  endif()
  _add_to_exported_targets(TARGETS ${_cc_TARGETS})
endfunction()

function(_add_to_exported_targets)
  cmake_parse_arguments(PARSE_ARGV 0 _add "" "EXPORT" "TARGETS")
  if (NOT _add_TARGETS OR (NOT _add_EXPORT AND "EXPORT" IN_LIST _add_KEYWORDS_MISSING_VALUES))
    return()
  endif()
  if (_add_EXPORT)
    list(TRANSFORM _add_TARGETS PREPEND "${${PROJECT_NAME}_${_add_EXPORT}_NAMESPACE}::")
    set(cache_var CETMODULES_EXPORTED_TARGETS_EXPORT_${_add_EXPORT}_PROJECT_${PROJECT_NAME})
  else()
    set(_add_EXPORT manual)
    set(cache_var CETMODULES_EXPORTED_MANUAL_TARGETS_PROJECT_${PROJECT_NAME})
  endif()
  if (DEFINED CACHE{${cache_var}})
    set_property(CACHE ${cache_var} APPEND PROPERTY VALUE ${_add_TARGETS})
  else()
    set(${cache_var} ${_add_TARGETS} CACHE INTERNAL
      "List of exported ${_add_EXPORT} targets for project ${PROJECT_NAME}")
  endif()
endfunction()

function(_calc_namespace VAR)
  cmake_parse_arguments(PARSE_ARGV 0 _cn "" "EXPORT" "")
  if (NOT _cn_EXPORT)
    list(POP_FRONT _cn_UNPARSED_ARGUMENTS _cn_EXPORT)
  endif()
  if (_cn_EXPORT AND ${PROJECT_NAME}_${_cn_EXPORT}_NAMESPACE)
    set(ns "${${PROJECT_NAME}_${_cn_EXPORT}_NAMESPACE}")
  elseif (${PROJECT_NAME}_NAMESPACE)
    set(ns "${${PROJECT_NAME}_NAMESPACE}")
  else()
    set(ns "${PROJECT_NAME}")
  endif()
  set(${VAR} ${ns} PARENT_SCOPE)
endfunction()

cmake_policy(POP)
