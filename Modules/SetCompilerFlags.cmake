########################################################################
# cet_set_compiler_flags( [extra flags] ) 
#
#    sets the default compiler flags
#

macro( cet_report_compiler_flags )
  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
  message( STATUS "compiler flags for directory " ${CURRENT_SUBDIR} " and below")
  message( STATUS "   C++     FLAGS: ${CMAKE_CXX_FLAGS_${BTYPE_UC}}")
  message( STATUS "   C       FLAGS: ${CMAKE_C_FLAGS_${BTYPE_UC}}")
  if (CMAKE_Fortran_COMPILER)
    message( STATUS "   Fortran FLAGS: ${CMAKE_Fortran_FLAGS_${BTYPE_UC}}")
  endif()
endmacro( cet_report_compiler_flags )

macro( cet_enable_asserts )
  remove_definitions(-DNDEBUG)
endmacro( cet_enable_asserts )

macro( cet_set_compiler_flags )

  set( CMAKE_C_FLAGS_DEBUG "-g  -O0 ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${CSCF_EXTRA_C_FLAGS} ${DFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_CXX_FLAGS_DEBUG "-std=c++98 -g  -O0 ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${QUAL_STD_FLAG} ${CSCF_EXTRA_CXX_FLAGS} ${DFLAGS_${CSCF_DIAGS}} ${DXXFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_C_FLAGS_MINSIZEREL "-O3 -g  -fno-omit-frame-pointer ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${CSCF_EXTRA_C_FLAGS} ${DFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_CXX_FLAGS_MINSIZEREL "-std=c++98 -O3 -g  -fno-omit-frame-pointer ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${QUAL_STD_FLAG} ${CSCF_EXTRA_CXX_FLAGS} ${DFLAGS_${CSCF_DIAGS}} ${DXXFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_C_FLAGS_RELEASE "-O3 -g  ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${CSCF_EXTRA_C_FLAGS} ${DFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_CXX_FLAGS_RELEASE "-std=c++98 -O3 -g  ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${QUAL_STD_FLAG} ${CSCF_EXTRA_CXX_FLAGS} ${DFLAGS_${CSCF_DIAGS}} ${DXXFLAGS_${CSCF_DIAGS}}" )

  message(STATUS "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "" FORCE)
  endif()
  message(STATUS "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")

  if( PACKAGE_TOP_DIRECTORY )
     STRING( REGEX REPLACE "^${PACKAGE_TOP_DIRECTORY}/(.*)" "\\1" CURRENT_SUBDIR "${CMAKE_CURRENT_SOURCE_DIR}" )
     if( CURRENT_SUBDIR STREQUAL PACKAGE_TOP_DIRECTORY)
       SET ( CURRENT_SUBDIR "<top>" )
     endif()
  else()
     STRING( REGEX REPLACE "^${CMAKE_SOURCE_DIR}/(.*)" "\\1" CURRENT_SUBDIR "${CMAKE_CURRENT_SOURCE_DIR}" )
     if( CURRENT_SUBDIR STREQUAL CMAKE_SOURCE_DIR )
       SET ( CURRENT_SUBDIR "<top>" )
     endif()
  endif()

  if( NOT ${CURRENT_SUBDIR} MATCHES "<top>" )
    message(STATUS "cmake build type set to ${CMAKE_BUILD_TYPE} in directory " ${CURRENT_SUBDIR} " and below")
  endif()

endmacro( cet_set_compiler_flags )
