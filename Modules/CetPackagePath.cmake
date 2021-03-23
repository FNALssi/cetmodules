########################################################################
# cet_package_path(VAR [PATH <path>] [BASE_SUBDIR <base_subdir>]
#                  [MUST_EXIST] [SOURCE] [BINARY])
#
# Calculate the path to PATH relative to
# ${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}/${BASE_SUBDIR} (SOURCE) or
# ${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/${BASE_SUBDIR} (BINARY) and save the result in
# VAR.
#
# BASE_SUBDIR (if specified) must not be *relative*, not absolute.
#
# If PATH is not specified, we default to ${CMAKE_CURRENT_SOURCE_DIR}
# (SOURCE) or ${CMAKE_CURRENT_BINARY_DIR} (BINARY). If <path> is
# relative, we treat it as relative to these defaults as appropriate.
#
# If neither SOURCE nor BINARY is specified or both are specified, we
# check relative to ${CETMODULES_CURRENT_PROJECT_SOURCE_DIR} first, and then to
# ${CETMODULES_CURRENT_PROJECT_BINARY_DIR}. If we cannot calculate a valid relative path,
# VAR will be empty. If MUST_EXIST is specified and the calculated path
# does not exist in the filesystem, VAR will be set to NOTFOUND.
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_package_path RESULT_VAR)
  cmake_parse_arguments(PARSE_ARGV 1 CPP "BINARY;HUMAN_READABLE;MUST_EXIST;SOURCE;TOP_PROJECT"
    "BASE_SUBDIR;FOUND_VAR;SUBDIR;PATH" "")
  if (CPP_TOP_PROJECT)
    set(var_prefix CMAKE)
  else()
    set(var_prefix PROJECT)
  endif()
  if (CPP_SUBDIR) # Backward compatibility.
    if (NOT ARGC EQUAL 3)
      message(FATAL_ERROR "cet_package_path(): SUBDIR option is for backward compatibility ONLY: use PATH instead")
    else()
      set(CPP_PATH "${CPP_SUBDIR}")
      set(CPP_SOURCE TRUE)
    endif()
  endif()
  if (NOT (CPP_SOURCE OR CPP_BINARY))
    set(CPP_SOURCE TRUE)
    set(CPP_BINARY TRUE)
  endif()
  if (CPP_SOURCE)
    _cpp_package_path(RESULT "${${var_prefix}_SOURCE_DIR}")
    if (RESULT)
      set(found SOURCE)
    endif()
  endif()
  if (CPP_BINARY AND NOT RESULT)
    _cpp_package_path(RESULT "${${var_prefix}_BINARY_DIR}"
      PATH_BASE "${CMAKE_CURRENT_BINARY_DIR}")
    if (RESULT)
      set(found BINARY)
    else()
      set(found NOTFOUND)
    endif()
  endif()
  if (CPP_HUMAN_READABLE)
    if (RESULT STREQUAL .)
      if (BASE_SUBDIR)
        set(RESULT "<base>")
      else()
        set(RESULT "<top>")
      endif()
    endif()
  endif()
  set(${RESULT_VAR} "${RESULT}" PARENT_SCOPE)
  if (CPP_FOUND_VAR)
    set(${CPP_FOUND_VAR} ${found} PARENT_SCOPE)
  endif()
endfunction()

# Internal function to be called from cet_package_path ONLY.
function(_cpp_package_path VAR PROJ_BASE)
  cmake_parse_arguments(PARSE_ARGV 2 _cpp "" "PATH_BASE" "")
  get_filename_component(PUT "${CPP_PATH}" ABSOLUTE BASE_DIR ${_cpp_PATH_BASE})
  file(RELATIVE_PATH RESULT "${PROJ_BASE}/${CPP_BASE_SUBDIR}" "${PUT}")
  if (NOT RESULT) # Exact match.
    set(RESULT .)
  elseif (RESULT MATCHES [[^\.\./]]) # Not under expected base.
    set(RESULT)
  elseif (CPP_MUST_EXIST AND NOT EXISTS "${PUT}")
    set(RESULT NOTFOUND)
  endif()
  set(${VAR} "${RESULT}" PARENT_SCOPE)
endfunction()

cmake_policy(POP)
