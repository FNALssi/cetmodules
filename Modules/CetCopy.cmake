#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# cet_copy
#
# Simple internal copy target to avoid triggering a CMake when files
# have changed.
#
# Usage: cet_copy(<sources>... DESTINATION <dir> [options])
#
####################################
# Options:
#
# DEPENDENCIES <deps>...
#
#   If any <deps> change, the file shall be re-copied (the source file
#   itself is always a dependency).
#
# NAME
#
#   New name for the file in its final destination.
#
# NAME_AS_TARGET
#
#   Use the basename of the file as the target for the copy operation,
#   in order to facilitate dependency references. This non-default
#   option has the caveat that it is left to the package author to
#   ensure that there are no name collisions.
#
# PROGRAMS
#
#   Copied files should be made executable.
#
# WORKING_DIRECTORY <dir>
#
#   Paths are relative to the specified directory (default
#   CMAKE_CURRENT_BINARY_DIR).
#
####################################
# Notes
#
# For PROGRAMS, custom commands using them will be updated when the
# program changes if one lists the script in the DEPENDS list of the
# custom command.
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(CetPackagePath)

function (cet_copy)
  cmake_parse_arguments(PARSE_ARGV 0 CETC "PROGRAMS;NAME_AS_TARGET"
    "DESTINATION;NAME;WORKING_DIRECTORY"
    "DEPENDENCIES")
  if (NOT CETC_DESTINATION)
    message(FATAL_ERROR "Missing required option argument DESTINATION")
  endif()
  get_filename_component(real_dest "${CETC_DESTINATION}" REALPATH)
  if (NOT CETC_WORKING_DIRECTORY)
    set(CETC_WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
  endif()
  foreach (source IN LISTS CETC_UNPARSED_ARGUMENTS)
    if (CETC_NAME)
      set(dest_path "${real_dest}/${CETC_NAME}")
    else()
      get_filename_component(source_base "${source}" NAME)
      set(dest_path "${real_dest}/${source_base}")
    endif()
    if (CETC_NAME_AS_TARGET)
      get_filename_component(target ${dest_path} NAME)
    else()
      cet_package_path(dest_path_target PATH "${dest_path}" TOP_PROJECT BINARY)
      if (dest_path_target)
        string(REPLACE "/" "+" target "${dest_path_target}")
      else()
        string(REPLACE "/" "+" target "${dest_path}")
      endif()
    endif()
    string(REGEX REPLACE "[: ]" "+" target "${target}")
    if (CETC_PROGRAMS)
      set(chmod_cmd COMMAND chmod +x "${dest_path}")
    endif()
    add_custom_command(OUTPUT "${dest_path}"
      WORKING_DIRECTORY "${CETC_WORKING_DIRECTORY}"
      COMMAND ${CMAKE_COMMAND} -E make_directory "${real_dest}"
      COMMAND ${CMAKE_COMMAND} -E copy "${source}" "${dest_path}"
      ${chmod_cmd}
      COMMENT "Copying ${source} to ${dest_path}"
      VERBATIM COMMAND_EXPAND_LISTS
      DEPENDS "${source}" ${CETC_DEPENDENCIES})
    add_custom_target(${target} ALL DEPENDS "${dest_path}")
    set_property(TARGET ${target} PROPERTY CET_EXEC_LOCATION "${dest_path}")
  endforeach()
endfunction()
