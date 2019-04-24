# parse an underscored version string and set the cmake project versions
#
# set_dot_version ( PRODUCTNAME _VERSION )
# set_version_from_underscored( _VERSION )
# parse_underscored_version( _VERSION )
#  PRODUCTNAME - product name
#  _VERSION - ups version of the form vx_y_z

macro( parse_underscored_version _VERSION )

  STRING(REGEX MATCHALL "_" ulist ${_VERSION} ) 
  list( LENGTH ulist nunder )
  ##message(STATUS "parse_underscored_version: ${_VERSION} has ${nunder} underscores" )
  if ( ${nunder} STREQUAL 0 )
    STRING( REGEX REPLACE "^[v](.*)$" "\\1" VMAJ "${_VERSION}" )
  elseif( ${nunder} STREQUAL 1 )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)$" "\\1" VMAJ "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)$" "\\2" VMIN "${_VERSION}" )
  elseif( ${nunder} STREQUAL 2 )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)$" "\\1" VMAJ "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)$" "\\2" VMIN "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)$" "\\3" VPRJ "${_VERSION}" )
  elseif( ${nunder} STREQUAL 3 )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\1" VMAJ "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\2" VMIN "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\3" VPRJ "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\4" VPT "${_VERSION}" )
  else()
    message(STATUS "NOTE: ups version ${_VERSION} has extra underscores")
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\1" VMAJ "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\2" VMIN "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\3" VPRJ "${_VERSION}" )
    STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)[_](.*)$" "\\4" VPT "${_VERSION}" )
  endif()
  ##message(STATUS "parse_underscored_version: version parses to ${VMAJ}.${VMIN}.${VPRJ}.${VPT}" )

endmacro( parse_underscored_version )

macro( set_version_from_underscored _VERSION )

  parse_underscored_version( ${_VERSION} )

  set( VERSION_MAJOR ${VMAJ} CACHE STRING "Package major version" FORCE)
  set( VERSION_MINOR ${VMIN} CACHE STRING "Package minor version" FORCE )
  set( VERSION_PATCH ${VPRJ} CACHE STRING "Package patch version" FORCE )
  set( VERSION_TWEAK ${VPT} CACHE STRING "Package tweak version" FORCE )
  ##message(STATUS "set_version_from_underscored: project version is ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}.${VERSION_TWEAK}" )

endmacro( set_version_from_underscored )

macro( set_dot_version PRODUCTNAME _VERSION )

  string(TOUPPER  ${PRODUCTNAME} PRODUCTNAME_UC )
  STRING( REGEX REPLACE "_" "." VDOT "${_VERSION}" )
  ##message(STATUS "temp version is ${VDOT}" )
  STRING( REGEX REPLACE "^[v]" "" ${PRODUCTNAME_UC}_DOT_VERSION "${VDOT}" )
  ##message(STATUS "set_dot_version: ${PRODUCTNAME_UC}_DOT_VERSION version is ${${PRODUCTNAME_UC}_DOT_VERSION}" )

endmacro( set_dot_version )
