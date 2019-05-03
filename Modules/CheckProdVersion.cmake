########################################################################
# Utility macros and functions, mostly for private use by other
# cetbuildtools CMake utilities.
#
# Also provides the public function check_prod_version.
#
####################################
# check_prod_version(product version minimum
#                    [PRODUCT_OLDER_VAR <var>]
#                    [PRODUCT_MATCHES_VAR <var>])
#
# Options and arguments:
#
# product
#   The name of the UPS product whose version is to be tested.
#
# version
#   The version of the product (eg from $ENV{<product>_VERSION}).
#
# minimum
#   The minimum required version of the product.
#
# PRODUCT_OLDER_VAR
#   If the product's version is does not satisfy the required minimum,
#   the variable specified herein is set to TRUE. Otherwise it is set to
#   FALSE.
#
# PRODUCT_MATCHES_VAR
#   If the product's version is at least the requiremd minimum, the
#   variable specified herein is set to TRUE. Otherwise it is set to
#   FALSE.
#
# NOTES.
#
# * At least one of PRODUCT_OLDER_VAR or PRODUCT_MATCHES_VAR must be
# supplied.
#
# * Version precedence is as follows (a strict superset of the "old"
#   ROOT versioning system):
#
#   * v1_0_0 is SAME as v1_0_0_0.
#
#   * v1_0_0 is NEWER than v1_0_0pre.
#
#   * v1_0_0pre is SAME as v1_0_0rc.
#
#   * v1_0_0pre0 is SAME as v1_0_0pre.
#
#   * v1_0_0alphaN is SAME as v1_0_0_alphaN.
#
#   * v1_0_0alphaN is OLDER than v1_0_0betaM.
#
#   * v1_0_0betaN is OLDER than v1_0_0rcM.
#
#   * v1_0_0patch is SAME is v1_0_0p0.
#
#   * v1_0_0a is NEWER than v1_0_0pN.
#
#   * v1_0_0p[<letters>] is NEWER than v1_0_0q[<letters>].
#
#   * v1_0_0q[<letters>] is NEWER than v1_0_0p[<letters>].
#
#   * <non-numeric-version> is NEWER than <any-numeric-version>.
#
#   * <non-numeric-version> is SAME as <non-numeric-version>.
#
########################################################################
cmake_policy(VERSION 3.3.2)

include(CMakeParseArguments)

#internal macro
macro(_get_dotver myversion )
   # replace all underscores with dots
   STRING( REGEX REPLACE "_" "." dotver1 "${myversion}" )
   STRING( REGEX REPLACE "v(.*)" "\\1" dotver "${dotver1}" )
endmacro(_get_dotver myversion )

#internal macro
function(_parse_version version )
   # standard case
   # convert vx_y_z to x.y.z
   # special cases
   # convert va_b_c_d to a.b.c.d
   # convert vx_y to x.y

   string(REGEX MATCH "^v([0-9]*)(_([0-9]*)(_([0-9]*)(.*))?)?" smatch ${version})
#   message(STATUS "CMAKE_MATCH_COUNT = ${CMAKE_MATCH_COUNT}")
   if (NOT CMAKE_MATCH_COUNT)
     string(REGEX MATCH "^([0-9]*)(\\.([0-9]*)(\\.([0-9]*)(.*))?)?" smatch ${version})
   endif()
   if (CMAKE_MATCH_COUNT GREATER 4)
     set(basicdotver ${CMAKE_MATCH_1} ${CMAKE_MATCH_3} ${CMAKE_MATCH_5})
     set(extra ${CMAKE_MATCH_6})
   elseif(CMAKE_MATCH_COUNT GREATER 2)
     set(basicdotver ${CMAKE_MATCH_1} ${CMAKE_MATCH_3} 0)
   elseif(CMAKE_MATCH_COUNT EQUAL 1)
     set(basicdotver ${CMAKE_MATCH_1} 0 0)
   else()
     set(basicdotver 0 0 0)
   endif()
   string(REPLACE ";" "."  basicdotver "${basicdotver}")
#   message(STATUS "version: ${version}; basicdotver: ${basicdotver}; extra: ${extra}")
   if (extra)
     string(TOUPPER "${extra}" EXTRA)
     string(REGEX MATCH "^[._]?([A-Z]+)?([0-9]+)?" smatch "${EXTRA}")
     if (CMAKE_MATCH_COUNT)
       set(patchchars ${CMAKE_MATCH_1})
       set(micro ${CMAKE_MATCH_2})
     endif()
   endif()
#   message(STATUS "version: ${version}; basicdotver: ${basicdotver}; extra: ${extra}; patchchars: ${patchchars}; micro: ${micro}")
   if (NOT patchchars)
     set(patchtype 0)
     set(patchchars "")
   elseif ((patchchars STREQUAL "PATCH") OR (patchchars STREQUAL "P" AND DEFINED micro))
     set(patchtype 1)
   elseif(patchchars STREQUAL "RC" OR patchchars STREQUAL "PRE")
     set(patchchars "RC")
     set(patchtype -1)
   elseif(patchchars STREQUAL "BETA")
     set(patchtype -2)
   elseif(patchchars STREQUAL "ALPHA")
     set(patchtype -3)
   else()
     set(patchtype 2)
   endif()
   if (NOT micro)
     set(micro 0)
   endif()
#   message(STATUS "version: ${version}; basicdotver: ${basicdotver}; extra: ${extra}; patchtype: ${patchtype}; patchchars: ${patchchars}; micro: ${micro}")
   # Expose variables to parent scope.
   foreach(var basicdotver patchtype patchchars micro)
     string(TOUPPER ${var} var_uc)
     set(${var_uc} ${${var}} PARENT_SCOPE)
   endforeach()
endfunction(_parse_version)

macro( _check_version product version  )
  cmake_parse_arguments( CVP "" "" "" ${ARGN} )
  if( CVP_UNPARSED_ARGUMENTS )
    list( GET CVP_UNPARSED_ARGUMENTS 0 minimum )
    _check_if_version_greater( ${product} ${version} ${minimum} )
    if( product_version_less )
      message( FATAL_ERROR "Bad Version: ${product} ${THISVER} is less than minimum required version ${MINVER}")
    endif()
  endif()
  #message( STATUS "${product} ${THISVER} meets minimum required version ${MINVER}")
endmacro( _check_version product version minimum )

function( check_prod_version product version minimum )
  cmake_parse_arguments(CV "" "PRODUCT_OLDER_VAR;PRODUCT_MATCHES_VAR" "" ${ARGN})
  if ((NOT CV_PRODUCT_OLDER_VAR) AND (NOT CV_PRODUCT_MATCHES_VAR))
    message(FATAL_ERROR "check_prod_version requires at least one of PRODUCT_OLDER_VAR or PRODUCT_MATCHES_VAR")
  endif()
  _parse_version( ${minimum}  )
  set( MINCVER ${BASICDOTVER} )
  set( MINPATCHTYPE ${PATCHTYPE} )
  set( MINCHAR ${PATCHCHARS} )
  set( MINMICRO ${MICRO} )
  _parse_version( ${version}  )
  set( THISCVER ${BASICDOTVER} )
  set( THISPATCHTYPE ${PATCHTYPE} )
  set( THISCHAR ${PATCHCHARS} )
  set( THISMICRO ${MICRO} )
  # initialize product_older
  set( product_older FALSE )
  if(${THISCVER} VERSION_LESS ${MINCVER} )
    set( product_older TRUE )
  elseif(${THISCVER} VERSION_EQUAL ${MINCVER})
    # Need to look at patchtype.
    if (${THISPATCHTYPE} LESS ${MINPATCHTYPE})
      set(product_older TRUE)
    elseif(${THISPATCHTYPE} EQUAL 2 AND
        ${MINPATCHTYPE} EQUAL 2 AND
        "${THISCHAR}" STRLESS "${MINCHAR}")
	    set( product_older TRUE )
    elseif(${THISPATCHTYPE} EQUAL ${MINPATCHTYPE} AND
	      "${THISCHAR}" STREQUAL "${MINCHAR}" AND
	      ${THISMICRO} LESS ${MINMICRO})
	    set( product_older TRUE )
    endif()
  endif()
  # check for special cases such as "nightly"
  if (NOT version MATCHES "[0-9]+")
#    message(STATUS "check_prod_version: ${product} ${version} is not numeric, therefore it matches all\nminimum versions")
    set( product_older FALSE )
  elseif (NOT minimum MATCHES "[0-9]+")
#    message(STATUS "check_prod_version: ${product} minimum version ${minimum} is not numeric, therefore it is older\nthan all numeric versions.")
    set( product_older TRUE )
  endif()
  if (CV_PRODUCT_OLDER_VAR)
    set(${CV_PRODUCT_OLDER_VAR} ${product_older} PARENT_SCOPE)
  endif()
  if (CV_PRODUCT_MATCHES_VAR)
    if (product_older)
      set(${CV_PRODUCT_MATCHES_VAR} FALSE PARENT_SCOPE)
    else()
      set(${CV_PRODUCT_MATCHES_VAR} TRUE PARENT_SCOPE)
    endif()
  endif()
  #message( STATUS "check_prod_version: ${product} ${THISVER} check if greater returns ${product_older}")
endfunction( check_prod_version product version minimum )

# For backward compatibility.
macro(_check_if_version_greater product version minimum)
  check_prod_version(${product} ${version} ${minimum}
    PRODUCT_OLDER_VAR product_version_less)
endmacro(_check_if_version_greater product version minimum)
