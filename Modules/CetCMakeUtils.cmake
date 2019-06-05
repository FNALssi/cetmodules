# cet_cmake_utils
#
# cet_find_library()
#   Call cet_find_library instead of find_library
#   This macro will pass the arguments on to find_library
#   Using this macro ensures that there will be an appropriate
#     cet_find_library command in the cmake config file for this product
#
# cet_find_simple_package()
#   Operate like find_package() for packages that don't have a
#   FindXXX.cmake module or CMake config files.
#
#   Options:
#     HEADERS <header>...
#       Look for <header>... to ascertain the include path. If not
#       specified, use NAME.{h,hh,H,hxx,hpp}
#     INCPATH_SUFFIXES <suffix>...
#       Add <suffix>... to paths when searching for HEADERS (defaults to
#       "include")
#     INCPATH_VAR <var>
#       Store the found include path in INCPATH_VAR. If not specified,
#       we invoke include_directories() with the found include path.
#     LIB_VAR <var>
#       Store the found library as LIB_VAR. If not specified, use
#       NAME as converted to an upper case identifier.
#     LIBNAMES <libname>...
#       Look for <libname>... as a library in addition to NAME.
#     LIBPATH_SUFFIXES <suffix>...
#       Add <suffix>... to paths when searching for LIBNAMES.
#
# _cet_init_config_var()
#    For internal use only
#
# cet_add_to_library_list()
#    Used internally and by art cmake modules

macro(_cet_init_config_var)
  # initialize cmake config file fragments
  set(CONFIG_FIND_LIBRARY_COMMAND_LIST "## find_library directives"
    CACHE INTERNAL "find_library directives for config"
    )
  set(CONFIG_LIBRARY_LIST "" CACHE INTERNAL "libraries created by this package" )
  set(cet_find_library_list "" CACHE INTERNAL "list of calls to cet_find_library")
endmacro(_cet_init_config_var)

macro(cet_add_to_library_list libname)
     # add to library list for package configure file
     set(CONFIG_LIBRARY_LIST ${CONFIG_LIBRARY_LIST} ${libname}
	 CACHE INTERNAL "libraries created by this package" )
endmacro(cet_add_to_library_list)

function(cet_find_library)
  STRING( REGEX REPLACE ";" " " find_library_commands "${ARGN}" )
  #message(STATUS "cet_find_library debug: find_library_commands ${find_library_commands}" )

  #message(STATUS "cet_find_library debug: cet_find_library_list ${cet_find_library_list}")
  if (ARGV2 STREQUAL "NAMES")
    set(lib_label ${ARGV3})
  else()
    set(lib_label ${ARGV2})
  endif()
  list(FIND cet_find_library_list ${lib_label} found_library_match)
  if( ${found_library_match} LESS 0 )
    set(cet_find_library_list ${lib_label} ${cet_find_library_list}
      CACHE INTERNAL "list of calls to cet_find_library")
    # add to library list for package configure file
    set(CONFIG_FIND_LIBRARY_COMMAND_LIST ${CONFIG_FIND_LIBRARY_COMMAND_LIST}
      "find_library( ${find_library_commands} )"
      CACHE INTERNAL "find_library directives for config"
      )
  endif()

  # call find_library
  find_library( ${ARGN} )
endfunction(cet_find_library)

function(cet_find_simple_package NAME)
  cmake_parse_arguments(CFSP
    ""
    "INCPATH_VAR;LIB_VAR"
    "HEADERS;LIBNAMES;LIBPATH_SUFFIXES;INCPATH_SUFFIXES"
    ${ARGN})
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
    set(WANT_INCLUDE_DIRECTORIES ON)
  else()
    set(${CFSP_INCPATH_VAR} ${CFSP_LIB_VAR}_INC)
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
