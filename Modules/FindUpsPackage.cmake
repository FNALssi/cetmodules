#
# since variables are passed, this is implemented as a macro
macro( find_ups_product PRODUCTNAME )

  cmake_parse_arguments( FUP "" "" "" ${ARGN} )
  message ( STATUS "find_ups_product debug: unparsed arguments ${FUP_UNPARSED_ARGUMENTS}" )
  set( fup_version "" )
  if( FUP_UNPARSED_ARGUMENTS )
    list( GET FUP_UNPARSED_ARGUMENTS 0 fup_version )
  endif()
  message ( STATUS "find_ups_product debug: called with ${PRODUCTNAME} ${fup_version}" )

  # get upper and lower case versions of the name
  string(TOUPPER  ${PRODUCTNAME} ${PRODUCTNAME}_UC )
  string(TOLOWER  ${PRODUCTNAME} ${PRODUCTNAME}_LC )

  find_package( ${PRODUCTNAME} )

endmacro( find_ups_product )
