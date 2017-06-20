#
# since variables are passed, this is implemented as a macro
macro( find_ups_product PRODUCTNAME )

  cmake_parse_arguments( FUP "" "" "" ${ARGN} )
  ##message ( STATUS "find_ups_product debug: unparsed arguments ${FUP_UNPARSED_ARGUMENTS}" )
  set( fup_version "" )
  if( FUP_UNPARSED_ARGUMENTS )
    list( GET FUP_UNPARSED_ARGUMENTS 0 fup_version )
  endif()
  ##message ( STATUS "find_ups_product debug: called with ${PRODUCTNAME} ${fup_version}" )
  ##message ( STATUS "find_ups_product debug: CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH}" )

  # get upper and lower case versions of the name
  string(TOUPPER  ${PRODUCTNAME} ${PRODUCTNAME}_UC )
  string(TOLOWER  ${PRODUCTNAME} ${PRODUCTNAME}_LC )
  ##message ( STATUS "find_ups_product debug: ${${PRODUCTNAME}_UC}_FQ_DIR $ENV{${${PRODUCTNAME}_UC}_FQ_DIR}" )

  # define the cmake search path
  set( ${${PRODUCTNAME}_UC}_SEARCH_PATH $ENV{${${PRODUCTNAME}_UC}_FQ_DIR} )
  if( NOT ${${PRODUCTNAME}_UC}_SEARCH_PATH )
    set( ${${PRODUCTNAME}_UC}_SEARCH_PATH $ENV{${${PRODUCTNAME}_UC}_DIR} )
  endif()
  if( NOT ${${PRODUCTNAME}_UC}_SEARCH_PATH )
    #message(STATUS "calling find_package ${PRODUCTNAME} " )
    find_package( ${PRODUCTNAME} )
  else()
    set( ${PRODUCTNAME}_DIR ${${${PRODUCTNAME}_UC}_SEARCH_PATH} )
    #message(STATUS "calling find_package ${PRODUCTNAME} PATHS ${${PRODUCTNAME}_DIR}" )
    find_package( ${PRODUCTNAME} PATHS ${${PRODUCTNAME}_DIR} NO_DEFAULT_PATH )
  endif()
  #message(STATUS "find_ups_product debug: ${PRODUCTNAME}_DIR ${${PRODUCTNAME}_DIR}")
  #message(STATUS "find_ups_product debug: ${PRODUCTNAME}_LIBDIR ${${PRODUCTNAME}_LIBDIR}")

endmacro( find_ups_product )
