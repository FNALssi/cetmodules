# cet_cmake_utils
#
# cet_find_library( )
#   Call cet_find_library instead of find_library
#   This macro will pass the arguments on to find_library
#   Using this macro ensures that there will be an appropriate
#     cet_find_library command in the cmake config file for this product
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
    list(APPEND CONFIG_FIND_LIBRARY_COMMAND_LIST
    "find_library( ${find_library_commands} )" )
  endif()

  # call find_library
  find_library( ${ARGN} )
endfunction(cet_find_library)
