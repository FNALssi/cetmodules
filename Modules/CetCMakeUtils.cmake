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
  set(CONFIG_FIND_UPS_COMMANDS "
## find_ups_product directives
## remember that these are minimum required versions" 
      CACHE STRING "UPS product directives for config" FORCE)
  set(CONFIG_FIND_LIBRARY_COMMANDS "
## find_library directives" 
      CACHE STRING "find_library directives for config" FORCE)
  set(CONFIG_LIBRARY_LIST "" CACHE INTERNAL "libraries created by this package" )
  set(CONFIG_PM_LIST "" CACHE INTERNAL "perl libraries created by this package" )
  set(CONFIG_PERL_PLUGIN_LIST "" CACHE INTERNAL "perl plugin libraries created by this package" )
  set(CONFIG_PM_VERSION "" CACHE INTERNAL "just for PluginVersionInfo.pm" )
  # we use cet_product_list to make sure there is only one find_ups_product call
  set(cet_product_list "" CACHE STRING "list of ups products" FORCE)
  set(cet_find_library_list "" CACHE STRING "list of calls to cet_find_library" FORCE)
endmacro(_cet_init_config_var)

macro(cet_add_to_library_list libname)
     # add to library list for package configure file
     set(CONFIG_LIBRARY_LIST ${CONFIG_LIBRARY_LIST} ${libname}
	 CACHE INTERNAL "libraries created by this package" )
endmacro(cet_add_to_library_list)

macro(cet_find_library)
  STRING( REGEX REPLACE ";" " " find_library_commands "${ARGN}" )
  #message(STATUS "cet_find_library debug: find_library_commands ${find_library_commands}" )

  #message(STATUS "cet_find_library debug: cet_find_library_list ${cet_find_library_list}")
  list(FIND cet_find_library_list ${ARGV2} found_library_match)
  if( ${found_library_match} LESS 0 )
    set(cet_find_library_list ${ARGV2} ${cet_find_library_list} )
    # add to library list for package configure file
    set(CONFIG_FIND_LIBRARY_COMMANDS "${CONFIG_FIND_LIBRARY_COMMANDS}
    if( NOT ${ARGV0} )
      cet_find_library( ${find_library_commands} )
    endif()" )
  endif()

  # call find_library
  find_library( ${ARGN} )
endmacro(cet_find_library)
