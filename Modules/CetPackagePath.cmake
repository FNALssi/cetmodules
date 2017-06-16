########################################################################
# cet_package_path(VAR [SUBDIR <subdir>])
#
# Calculate the path to SUBDIR (default ${CMAKE_CURRENT_SOURCE_DIR})
# relative to ${PACKAGE_TOP_DIRECTORY} (if set, otherwise
# ${CMAKE_SOURCE_DIR}) and save the result in VAR.
#
# If SUBDIR is specifed and relative, it is assumed to be relative to
# ${CMAKE_CURRENT_SOURCE_DIR}
########################################################################
include(CMakeParseArguments)

function(cet_package_path VAR)
  cmake_parse_arguments(CPP "" "SUBDIR" "" ${ARGN})
  if (CPP_SUBDIR)
    if (NOT IS_ABSOLUTE ${CPP_SUBDIR})
      get_filename_component(CPP_SUBDIR ${CPP_SUBDIR} ABSOLUTE)
    endif()
  else()
    set(CPP_SUBDIR ${CMAKE_CURRENT_SOURCE_DIR})
  endif()
  if (PACKAGE_TOP_DIRECTORY)
    STRING( REGEX REPLACE "^${PACKAGE_TOP_DIRECTORY}/(.*)" "\\1" CURRENT_SUBDIR "${CPP_SUBDIR}" )
  else()
    STRING( REGEX REPLACE "^${CMAKE_SOURCE_DIR}/(.*)" "\\1" CURRENT_SUBDIR "${CPP_SUBDIR}" )
  endif()
  set(${VAR} ${CURRENT_SUBDIR} PARENT_SCOPE)
endfunction()
