########################################################################
# install_x()
#
# Install files of category x in the appropriate place in the build and
# installation areas.
#
# Usage: install_x([PROGRAMS] [SUBDIRNAME <subdir>] LIST ...)
#        install_x([PROGRAMS] [SUBDIRNAME <subdir>] 
#                  [BASENAME_EXCLUDES ...] [EXCLUDES ...]
#                  [EXTRAS ...] [SUBDIRS ...])
#
# The first form installs the items specified by LIST under (usually)
# ${${PROJECT_NAME}_X}/<subdir> with respect to the top level
# build and install directories. If ${PROJECT_NAME}_X is
# vacuous, a FATAL_ERROR will be generated.
#
# The second form, where available, looks for generally-recognized files
# of category x, subject to the exclusion options. Any specified EXTRAS
# are also installed in the appropriate places. Any specified SUBDIRS
# are also searched. Depending on what is appropriate for files of
# category x: the build area may be searched for generated files of that
# category, the current package subdirectory may be appended to
# ${${PROJECT_NAME}_X}/<subdir>, and/or any SUBDIRs may be honored or
# removed. Non-absolute paths for EXCLUDES, EXTRAS, LISTS and SUBDIRS
# are resolved relative to ${CMAKE_CURRENT_SOURCE_DIR} or
# ${CMAKE_CURRENT_BINARY_DIR} as appropriate.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include (CetCopy)
include (CetExclude)
include (ProjectVariable)

# Copy all files (or PROGRAMS) found matching provided glob expressions
# to location indicated by DEST_VAR. Optionally (as indicated by
# _SEARCH_BUILD) use ${CMAKE_CURRENT_BINARY_DIR} as a relative base in
# addition to ${CMAKE_CURRENT_SOURCE_DIR}.
#
# If _SQUASH_SUBDIRS is not specified, any matching items found in
# SUBDIRS will be copied to a corresponding directory under the
# destination.
#
# Any non-absolute EXCLUDES are anchored to ${CMAKE_CURRENT_SOURCE_DIR},
# while EXCLUDE_BASENAMES apply anywhere.
#
# Specified EXTRAS will be copied to the location indicatd by DEST_VAR
# without being checked for exclusion.
function(_cet_install CATEGORY)
  # Parse an option to tell us how to parse options.
  cmake_parse_arguments(PARSE_ARGV 1 _I "_LIST_ONLY;_NO_LIST" "" "")
  set(_USAGE_FLAGS)
  if (_I__LIST_ONLY)
    list(_USAGE_FLAGS _LIST_ONLY)
  elseif(_I__NO_LIST)
    list(APPEND _USAGE_FLAGS _NO_LIST)
  endif()
  # Set up main parsing operation.
  set(options PROGRAMS _INSTALL_ONLY)
  set(one_arg_options DEST_VAR DESTINATION SUBDIRNAME _INSTALLED_FILES_VAR)
  set(multi_arg_options)
  if (NOT _I__NO_LIST)
    list(APPEND multi_arg_options LIST)
  endif()
  if (NOT _I__LIST_ONLY)
    list(APPEND options _SEARCH_BUILD _SQUASH_SUBDIRS)
    list(APPEND multi_arg_options
      _EXTRA_BASENAME_EXCLUDES _EXTRA_EXCLUDES _EXTRA_EXTRAS
      BASENAME_EXCLUDES EXCLUDES EXTRAS _GLOBS SUBDIRS)
  endif()
  cmake_parse_arguments(_I "${options}" "${one_arg_options}"
    "${multi_arg_options}" "${_I_UNPARSED_ARGUMENTS}")
  cet_passthrough(FLAG _I_PROGRAMS PROGRAMS)
  cet_passthrough(FLAG _I__INSTALL_ONLY _INSTALL_ONLY)
  # Act on options and arguments.
  if (NOT _I_DEST_VAR)
    if (_I_DESTINATION)
      set(CUSTOM_DESTINATION "${_I_DESTINATION}")
      set(_I_DEST_VAR CUSTOM_DESTINATION)
    else()
      list(POP_FRONT _I_UNPARSED_ARGUMENTS _I_DEST_VAR)
    endif()
  endif()
  # Sanity check.
  if (NOT (_I_DEST_VAR AND ${_I_DEST_VAR}))
    _cet_install_error(${CATEGORY} ${_USAGE_FLAGS}
      "vacuous destination ${_I_DEST_VAR}")
  endif()
  set(DEST_DIR "${${_I_DEST_VAR}}")

  if ((_I__SEARCH_BUILD OR _I_BASENAME_EXCLUDES OR
        _I_EXCLUDES OR _I_EXTRAS OR _I_SUBDIRS) AND _I_LIST)
    _cet_install_error(${CATEGORY} ${_USAGE_FLAGS}
      "mutually exclusive options detected")
  elseif (_I_UNPARSED_ARGUMENTS)
    if (_I_LIST)
      _cet_install_error(${CATEGORY} ${_USAGE_FLAGS}
        "unwanted extra arguments ${_I_UNPARSED_ARGUMENTS}")
    else()
      warn_deprecated("<file>... as non-option arguments to install_${CATEGORY}()"
        NEW "install_${CATEGORY}(LIST ...)")
      set(_I_LIST "${_I_UNPARSED_ARGUMENTS}")
    endif()
  elseif (NOT_I_LIST)
    # Deal with hidden extras.
    if (_I__EXTRA_EXTRAS)
      list(APPEND _I_EXTRAS ${_I__EXTRA_EXTRAS})
    endif()
    # Loop over subdirs.
    if (_I_GLOBS)
      foreach(SUBDIR IN ITEMS "" LISTS _I_SUBDIRS)
        set(GLOBS ${_I__GLOBS})
        if (SUBDIR)
          list(TRANSFORM GLOBS PREPEND "${SUBDIR}/")
        endif()
        file(GLOB FILES LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS ${GLOBS})
        if (_I__SEARCH_BUILD)
          # Search build area for files.
          list(TRANSFORM GLOBS PREPEND "${CMAKE_CURRENT_BINARY_DIR}/")
          file(GLOB TMP LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS ${GLOBS})
          list(APPEND FILES ${TMP})
        endif()
        if (FILES)
          # Process exclusions.
          _cet_exclude_from_list(FILES
            LIST ${FILES}
            EXCLUDES ${_I_EXCLUDES} ${_I__EXTRA_EXCLUDES}
            BASENAME_EXCLUDES ${_I_BASENAME_EXCLUDES}
            ${_I__EXTRA_BASENAME_EXCLUDES})
          if (_I__SQUASH_SUBDIRS)
            # We can deal with everything in one operation.
            list(APPEND _I_EXTRAS ${FILES})
          else()
            if (_I_SUBDIRNAME)
              string(JOIN "/" tmp_subdir "${_I_SUBDIRNAME}" "${SUBDIR}")
            endif()
            # One subdirectory at a time.
            _cet_install_list(${CATEGORY} ${_I_DEST_VAR}
              ${PROGRAMS} ${_INSTALL_ONLY} _USAGE_FLAGS ${_USAGE_FLAGS}
              SUBDIRNAME "${tmp_subdir}"
              LIST ${FILES})
            list(APPEND INSTALLED_FILES ${FILES})
          endif()
        endif()
      endforeach()
    endif()
  endif()
  # Deal with specified extras.
  _cet_install_list(${CATEGORY} ${_I_DEST_VAR}
    ${PROGRAMS} ${_INSTALL_ONLY} _USAGE_FLAGS ${_USAGE_FLAGS}
    SUBDIRNAME ${_I_SUBDIRNAME}
    LIST ${_I_LIST} ${_I_EXTRAS} ${_I__EXTRA_EXTRAS})
  list(APPEND INSTALLED_FILES ${_I_LIST} ${_I_EXTRAS} ${_I__EXTRA_EXTRAS})
  if (_I__INSTALLED_FILES_VAR)
    set(${_I__INSTALLED_FILES_VAR} ${INSTALLED_FILES} PARENT_SCOPE)
  endif()
endfunction()

function(_cet_install_error CATEGORY)
  cmake_parse_arguments(PARSE_ARGV 1 _CIE "_LIST_ONLY;_NO_LIST" "" "")
  set(PREAMBLE "Usage: ")
  string(REGEX REPLACE "." " " EMPTY "${PREAMBLE}")
  set(USAGE_MSG)
  if (NOT NO_LIST)
    string(APPEND USAGE_MSG
      "${PREAMBLE}${install_${CATEGORY}}([PROGRAMS] [SUBDIRNAME <subdir>] LIST ...)")
    set(PREAMBLE "${EMPTY}")
  endif()
  if (NOT LIST_ONLY)
    string(APPEND USAGE_MSG
      "${PREAMBLE}install_${CATEGORY}([PROGRAMS] [SUBDIRNAME <subdir>]\n"
      "${EMPTY}   [BASENAME_EXCLUDES ...] [EXCLUDES ...]\n"
      "${EMPTY}   [EXTRAS ...] [SUBDIRS ...])")
  endif()
  message(FATAL_ERROR "install_${CATEGORY}(): "
    ${_CIE_UNPARSED_ARGUMENTS} "\n\n${USAGE_MSG}")
endfunction()

# Copy listed files (or PROGRAMS) to location indicated by DEST_VAR
# (optionally under subdirectory SUBDIRNAME) in build tree and install
# tree.
#
# Relative paths for ${${DEST_VAR}} are with respect to
# ${PROJECT_BINARY_DIR} or ${CMAKE_INSTALL_PREFIX} as appropriate, the
# optional subdirectory is relative to the resolved ${${DEST_VAR}}, and
# listed files are relative to ${CMAKE_CURRENT_SOURCE_DIR}.
function(_cet_install_list CATEGORY DEST_VAR)
  cmake_parse_arguments(PARSE_ARGV 2 _IL "_INSTALL_ONLY;PROGRAMS"
    "SUBDIRNAME" "_USAGE_FLAGS;LIST")
  if (NOT ${DEST_VAR})
    _cet_install_error(${CATEGORY} ${_IL__USAGE_FLAGS}
      "vacuous destination ${DEST_VAR}")
  endif()
  if (_IL_PROGRAMS)
    set(IMODE PROGRAMS)
    set(CMODE PROGRAMS)
  else()
    set(IMODE FILES)
  endif()
  set(DEST_DIR "${${DEST_VAR}}")
  if (_IL_SUBDIRNAME)
    string(JOIN "/" DEST_DIR "${DEST_DIR}" "${_IL_SUBDIRNAME}")
  endif()
  if (NOT _IL__INSTALL_ONLY)
    cet_copy(${CMODE}
      DESTINATION "${PROJECT_BINARY_DIR}/${DEST_DIR}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      ${_IL_LIST})
  endif()
  install(${IMODE}
    ${_IL_LIST}
    DESTINATION "${DEST_DIR}")
endfunction()

cmake_policy(POP)
