########################################################################
# cet_set_compiler_flags( [extra flags] ) 
#
#    sets the default compiler flags
#
# default gcc/g++ flags:
# DEBUG           -g
# RELEASE         -O3 -DNDEBUG
# MINSIZEREL      -Os -DNDEBUG
# RELWITHDEBINFO  -O2 -g
#
# CET flags
# (debug)   DEBUG           -g -O0
# (prof)    PROF            -O3 -g -DNDEBUG -fno-omit-frame-pointer
# (opt)     OPT             -O3 -g -DNDEBUG
# (prof)    MINSIZEREL      -O3 -g -DNDEBUG -fno-omit-frame-pointer
# (opt)     RELEASE         -O3 -g -DNDEBUG
# (default) RELWITHDEBINFO  unchanged
#
# Plus the diagnostic option set indicated by the DIAG option.
#
# Optional arguments
#    DIAGS <diag-level>
#      This option may be CAVALIER, CAUTIOUS, VIGILANT or PARANOID.
#      Default is CAUTIOUS.
#    DWARF_STRICT
#      Instruct the compiler not to emit any debugging information more
#      advanced than that selected. This will prevent possible errors in
#      older debuggers, but may prevent certain C++11 constructs from
#      being debuggable in modern debuggers.
#    DWARF_VER <#>
#      Version of the DWARF standard to use for generating debugging
#      information. Default depends upon the compiler: GCC v4.8.0 and
#      above emit DWARF4 by default; earlier compilers emit DWARF2.
#    ENABLE_ASSERTS
#      Enable asserts regardless of debug level (default is to disable
#      asserts for PROF and OPT levels).
#    EXTRA_FLAGS (applied to both C and CXX) <flags>
#    EXTRA_C_FLAGS <flags>
#    EXTRA_CXX_FLAGS <flags>
#    EXTRA_DEFINITIONS <flags>
#      This list parameters will append tbe appropriate items.
#    NO_UNDEFINED
#      Unresolved symbols will cause an error when making a shared
#      library.
#    WERROR
#      All warnings are flagged as errors.
#
####################################
# cet_enable_asserts()
#
#   Enable use of assserts (ie remove -DNDEBUG) regardless of
#   optimization level.
#
####################################
# cet_disable_asserts()
#
#   Disable use of assserts (ie ensure -DNDEBUG) regardless of
#   optimization level.
#
####################################
# cet_maybe_disable_asserts()
#
#   Possibly disable use of assserts (ie ensure -DNDEBUG) based on
#   optimization level.
#
####################################
# cet_add_compiler_flags(<options> <flags>...)
#
#   Add the specified compiler flags.
#
# Options:
#
#   C
#     Add <flags> to CMAKE_C_FLAGS.
#
#   CXX
#    Add <flags> to CMAKE_CXX_FLAGS.
#
#   LANGUAGES <X>
#    Add <flags> to CMAKE_<X>_FLAGS.
#
# Using any or all options is permissible. Using none is equivalent to
# using C CXX.
#
# Duplicates are not removed.
#
####################################
# cet_remove_compiler_flags(<options> <flags>...)
#
#   Remove the specified compiler flags.
#
# Options:
#
#   C
#     Remove <flags> from CMAKE_C_FLAGS.
#
#   CXX <flags>
#     Remove <flags> from CMAKE_CXX_FLAGS.
#
#  LANGUAGES <X>
#     Remove <flags> from CMAKE_<X>_FLAGS.
#
# Using any or all options is permissible. Using none is equivalent to
# using C CXX.
#
####################################
# cet_report_compiler_flags()
#
#   Print the compiler flags currently in use.
#
####################################
# cet_query_system()
#
#   List the values of various variables
#
########################################################################
include(CMakeParseArguments)
include(CetGetProductInfo)
#include(CetHaveQual)
include(CetRegexEscape)

macro( cet_report_compiler_flags )
  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
  message( STATUS "compiler flags for directory " ${CURRENT_SUBDIR} " and below")
  message( STATUS "   C++     FLAGS: ${CMAKE_CXX_FLAGS_${BTYPE_UC}}")
  message( STATUS "   C       FLAGS: ${CMAKE_C_FLAGS_${BTYPE_UC}}")
  if (CMAKE_Fortran_COMPILER)
    message( STATUS "   Fortran FLAGS: ${CMAKE_Fortran_FLAGS_${BTYPE_UC}}")
  endif()
endmacro( cet_report_compiler_flags )

macro( _cet_process_flags PTYPE_UC )
   # turn a space separated string into a colon separated list
  STRING( REGEX REPLACE " " ";" tmp_cxx_flags "${CMAKE_CXX_FLAGS_${PTYPE_UC}}")
  STRING( REGEX REPLACE " " ";" tmp_c_flags "${CMAKE_C_FLAGS_${PTYPE_UC}}")
  ##message( STATUS "tmp_cxx_flags: ${tmp_cxx_flags}")
  ##message( STATUS "tmp_c_flags: ${tmp_c_flags}")
  foreach( flag ${tmp_cxx_flags} )
     if( ${flag} MATCHES "^-W(.*)" )
        ##message( STATUS "Warning: ${flag}" )
     elseif( ${flag} MATCHES "-pedantic" )
        ##message( STATUS "Ignoring: ${flag}" )
     elseif( ${flag} MATCHES "-std[=]c[+][+]98" )
        ##message( STATUS "Ignoring: ${flag}" )
     else()
        ##message( STATUS "keep ${flag}" )
        list(APPEND TMP_CXX_FLAGS_${PTYPE_UC} ${flag} )
     endif()
  endforeach( flag )
  foreach( flag ${tmp_c_flags} )
     if( ${flag} MATCHES "^-W(.*)" )
        ##message( STATUS "Warning: ${flag}" )
     elseif( ${flag} MATCHES "-pedantic" )
        ##message( STATUS "Ignoring: ${flag}" )
     else()
        ##message( STATUS "keep ${flag}" )
        list(APPEND TMP_C_FLAGS_${PTYPE_UC} ${flag} )
     endif()
  endforeach( flag )
  ##message( STATUS "TMP_CXX_FLAGS_${PTYPE_UC}: ${TMP_CXX_FLAGS_${PTYPE_UC}}")
  ##message( STATUS "TMP_C_FLAGS_${PTYPE_UC}: ${TMP_C_FLAGS_${PTYPE_UC}}")

endmacro( _cet_process_flags )

macro( cet_base_flags )
  foreach( mytype DEBUG;OPT;PROF )
     ##message( STATUS "checking ${mytype}" )
     _cet_process_flags( ${mytype} )
     ##message( STATUS "${mytype} C   flags: ${TMP_C_FLAGS_${mytype}}")
     ##message( STATUS "${mytype} CXX flags: ${TMP_CXX_FLAGS_${mytype}}")
     set( CET_BASE_CXX_FLAG_${mytype} ${TMP_CXX_FLAGS_${mytype}}
          CACHE STRING "base CXX ${mytype} flags for ups table"
	  FORCE)
     set( CET_BASE_C_FLAG_${mytype} ${TMP_C_FLAGS_${mytype}}
          CACHE STRING "base C ${mytype} flags for ups table"
	  FORCE)
  endforeach( mytype )
  ##message( STATUS "CET_BASE_CXX_FLAG_DEBUG: ${CET_BASE_CXX_FLAG_DEBUG}")
  ##message( STATUS "CET_BASE_CXX_FLAG_OPT:   ${CET_BASE_CXX_FLAG_OPT}")
  ##message( STATUS "CET_BASE_CXX_FLAG_PROF:  ${CET_BASE_CXX_FLAG_PROF}")
endmacro( cet_base_flags )

macro( _cet_add_build_types )
  SET( CMAKE_CXX_FLAGS_OPT "${CMAKE_CXX_FLAGS_RELEASE}" CACHE STRING
    "Flags used by the C++ compiler for optimized builds."
    FORCE )
  SET( CMAKE_C_FLAGS_OPT "${CMAKE_C_FLAGS_RELEASE}" CACHE STRING
    "Flags used by the C compiler for optimized builds."
    FORCE )
  SET( CMAKE_EXE_LINKER_FLAGS_OPT "${CMAKE_EXE_LINKER_FLAGS_RELEASE}"
    CACHE STRING
    "Flags used for linking binaries for optimized builds."
    FORCE )
  SET( CMAKE_SHARED_LINKER_FLAGS_OPT "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}"
    CACHE STRING
    "Flags used by the shared libraries linker for optimized builds."
    FORCE )
  MARK_AS_ADVANCED(
    CMAKE_CXX_FLAGS_OPT
    CMAKE_C_FLAGS_OPT
    CMAKE_EXE_LINKER_FLAGS_OPT
    CMAKE_SHARED_LINKER_FLAGS_OPT )

  SET( CMAKE_CXX_FLAGS_PROF "${CMAKE_CXX_FLAGS_MINSIZEREL}" CACHE STRING
    "Flags used by the C++ compiler for optimized builds."
    FORCE )
  SET( CMAKE_C_FLAGS_PROF "${CMAKE_C_FLAGS_MINSIZEREL}" CACHE STRING
    "Flags used by the C compiler for optimized builds."
    FORCE )
  SET( CMAKE_EXE_LINKER_FLAGS_PROF "${CMAKE_EXE_LINKER_FLAGS_MINSIZEREL}"
    CACHE STRING
    "Flags used for linking binaries for optimized builds."
    FORCE )
  SET( CMAKE_SHARED_LINKER_FLAGS_PROF "${CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL}"
    CACHE STRING
    "Flags used by the shared libraries linker for optimized builds."
    FORCE )

  MARK_AS_ADVANCED(
    CMAKE_CXX_FLAGS_PROF
    CMAKE_C_FLAGS_PROF
    CMAKE_EXE_LINKER_FLAGS_PROF
    CMAKE_SHARED_LINKER_FLAGS_PROF )

endmacro( _cet_add_build_types )

function(_verify_cxx_std_flag FLAGS FLAG_VAR)
  _find_std_flag(FLAGS FOUND_STD_FLAG)
  _std_flag_from_qual(QUAL_STD_FLAG)

  if (FOUND_STD_FLAG AND QUAL_STD_FLAG AND NOT FOUND_STD_FLAG STREQUAL QUAL_STD_FLAG)
    message(FATAL_ERROR "Qualifier specifies ${QUAL_STD_FLAG}, but user specifies ${FOUND_STD_FLAG}.\nPlease change qualifier or (preferably) remove user setting of ${FOUND_STD_FLAG}")
  endif()
  set(${FLAG_VAR} ${QUAL_STD_FLAG} PARENT_SCOPE)
endfunction()

macro( cet_enable_asserts )
  remove_definitions(-DNDEBUG)
endmacro( cet_enable_asserts )

macro( cet_disable_asserts )
  remove_definitions(-DNDEBUG)
  add_definitions(-DNDEBUG)
endmacro( cet_disable_asserts )

macro( cet_maybe_disable_asserts )
  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
  cet_enable_asserts() # Starting point
  if( ${BTYPE_UC} MATCHES "OPT" OR
      ${BTYPE_UC} MATCHES "PROF" OR
      ${BTYPE_UC} MATCHES "RELEASE" OR
      ${BTYPE_UC} MATCHES "MINSIZEREL" )
    cet_disable_asserts()
  endif()
endmacro( cet_maybe_disable_asserts )

macro (_parse_flags_options)
  cmake_parse_arguments(CSCF "C;CXX" "" "LANGUAGES" ${ARGN})
  if (CSCF_C)
    list(APPEND CSCF_LANGUAGES "C")
  endif()
  if (CSCF_CXX)
    list(APPEND CSCF_LANGUAGES "CXX")
  endif()
  if (NOT CSCF_LANGUAGES)
    SET(CSCF_LANGUAGES C CXX)
  endif()
endmacro()

macro( cet_add_compiler_flags )
  _parse_flags_options(${ARGN})
  string(REGEX REPLACE ";" " " CSCF_ARGS "${CSCF_UNPARSED_ARGUMENTS}")
  string(REGEX MATCH "(^| )-std=" CSCF_HAVE_STD ${CSCF_ARGS})
  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
  # temporary hack while we wait for the real fix
  #_verify_cxx_std_flag(${CSCF_CXX})
  _verify_cxx_std_flag(CSCF_CXX QUAL_STD_FLAG)
  foreach(acf_lang ${CSCF_LANGUAGES})
    if (CSCF_HAVE_STD)
      cet_remove_compiler_flags(LANGUAGES ${acf_lang} REGEX "-std=[^ ]*")
    endif()
    set(CMAKE_${acf_lang}_FLAGS_${BTYPE_UC} "${CMAKE_${acf_lang}_FLAGS_${BTYPE_UC}} ${CSCF_ARGS}")
  endforeach()
endmacro( cet_add_compiler_flags )

function(_rm_flag_trim_whitespace VAR FLAG)
  if (NOT ("X${FLAG}" STREQUAL "X"))
    string(REGEX REPLACE "(^| )${FLAG}( |$)" " " ${VAR} "${${VAR}}" )
  endif()
  string(REGEX REPLACE "^ +" "" ${VAR} "${${VAR}}")
  string(REGEX REPLACE " +$" "" ${VAR} "${${VAR}}")
  string(REGEX REPLACE " +" " " ${VAR} "${${VAR}}")
  # Push (local) value of ${${VAR}} up to parent scope.
  set(${VAR} "${${VAR}}" PARENT_SCOPE)
endfunction()

macro( cet_remove_compiler_flags )
  _parse_flags_options(${ARGN})
  cmake_parse_arguments(CSCF "REGEX" "" "" ${CSCF_UNPARSED_ARGUMENTS})
  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
  foreach (arg ${CSCF_UNPARSED_ARGUMENTS})
    if (NOT CSCF_REGEX)
      cet_regex_escape("${arg}" arg)
    endif()
    foreach (rcf_lang ${CSCF_LANGUAGES})
      _rm_flag_trim_whitespace(CMAKE_${rcf_lang}_FLAGS_${BTYPE_UC} ${arg})
    endforeach()
  endforeach()
endmacro()

# Find the first -std flag in the incoming list and put it in the
# outgoing var.
function(_find_std_flag IN_VAR OUT_VAR)
  string(REGEX MATCH "(^| )-std=[^ ]*" found_std_flag "${${IN_VAR}}")
  set(${OUT_VAR} "${found_std_flag}" PARENT_SCOPE)
endfunction()

function(_find_extra_std_flags IN_VAR OUT_VAR)
  string(REGEX MATCHALL "(^| )-std=[^ ]*" found_std_flags "${${IN_VAR}}")
  list(LENGTH found_std_flags fsf_len)
  if (fsf_len GREATER 1)
    list(GET found_std_flags 0 tmp)
    set(${OUT_VAR} "${tmp}" PARENT_SCOPE)
  else()
    unset(${OUT_VAR} PARENT_SCOPE)
  endif()
endfunction()

function(_std_flag_from_qual OUT_VAR)
# complete hack
      set(${OUT_VAR} "-std=c++14" PARENT_SCOPE)
endfunction()

macro(_remove_extra_std_flags VAR)
  string(REGEX MATCHALL "(^| )-std=[^ ]*" found_std_flags "${${VAR}}")
  list(LENGTH found_std_flags fsf_len)
  if (fsf_len GREATER 1)
    list(REMOVE_AT found_std_flags -1)
    foreach (flag ${found_std_flags})
      cet_regex_escape("${flag}" flag)
      _rm_flag_trim_whitespace(${VAR} "${flag}")
    endforeach()
  endif()
endmacro()

macro( cet_set_compiler_flags )
  CET_PARSE_ARGS(CSCF
    "DIAGS;DWARF_VER;EXTRA_FLAGS;EXTRA_C_FLAGS;EXTRA_CXX_FLAGS;EXTRA_DEFINITIONS"
    "ALLOW_DEPRECATIONS;DWARF_STRICT;ENABLE_ASSERTS;NO_UNDEFINED;WERROR"
    ${ARGN}
    )

  if (CSCF_DEFAULT_ARGS)
    message(FATAL_ERROR "Unexpected extra arguments: ${CSCF_DEFAULT_ARGS}.\nConsider EXTRA_FLAGS, EXTRA_C_FLAGS, EXTRA_CXX_FLAGS or EXTRA_DEFINITIONS")
  endif()

  _verify_cxx_std_flag(CSCF_EXTRA_CXX_FLAGS QUAL_STD_FLAG)

  # turn a colon separated list into a space separated string
  STRING( REGEX REPLACE ";" " " CSCF_EXTRA_CXX_FLAGS "${CSCF_EXTRA_CXX_FLAGS}")
  STRING( REGEX REPLACE ";" " " CSCF_EXTRA_C_FLAGS "${CSCF_EXTRA_C_FLAGS}")
  STRING( REGEX REPLACE ";" " " CSCF_EXTRA_FLAGS "${CSCF_EXTRA_FLAGS}")

  set( DFLAGS_CAVALIER "" )
  set( DXXFLAGS_CAVALIER "" )
  set( DFLAGS_CAUTIOUS "${DFLAGS_CAVALIER} -Wall -Werror=return-type" )
  set( DXXFLAGS_CAUTIOUS "${DXXFLAGS_CAVALIER}" )
  set( DFLAGS_VIGILANT "${DFLAGS_CAUTIOUS} -Wextra -Wno-long-long -Winit-self" )
  if (NOT CMAKE_C_COMPILER MATCHES "/?icc$") # Not understood by ICC
    set( DFLAGS_VIGILANT "${DFLAGS_VIGILANT} -Wno-unused-local-typedefs" )
  endif()
  set( DXXFLAGS_VIGILANT "${DXXFLAGS_CAUTIOUS} -Woverloaded-virtual" )
  set( DFLAGS_PARANOID "${DFLAGS_VIGILANT} -pedantic -Wformat-y2k -Wswitch-default -Wsync-nand -Wtrampolines -Wlogical-op -Wshadow -Wcast-qual" )
  set( DXXFLAGS_PARANOID "${DXXFLAGS_VIGILANT}" )

  if (NOT CSCF_DIAGS)
    SET(CSCF_DIAGS "CAUTIOUS")
  endif()

  if (CSCF_NO_UNDEFINED)
    if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
      set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-undefined,error")
    else()
      set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")
    endif()
  elseif (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    # Make OS X match default SLF6 behavior.
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-undefined,dynamic_lookup")
  endif()

  if (CSCF_WERROR)
    set(CSCF_WERROR "-Werror")
    if (CSCF_ALLOW_DEPRECATIONS)
      set(CSCF_WERROR "${CSCF_WERROR} -Wno-error=deprecated-declarations")
    endif()
  else()
    set(CSCF_WERROR "")
    if (CSCF_ALLOW_DEPRECATIONS)
      message(WARNING "ALLOW_DEPRECATIONS ignored when WERROR not specified")
    endif()
  endif()

  string(TOUPPER "${CSCF_DIAGS}" CSCF_DIAGS)
  if (CSCF_DIAGS STREQUAL "CAVALIER" OR
      CSCF_DIAGS STREQUAL "CAUTIOUS" OR
      CSCF_DIAGS STREQUAL "VIGILANT" OR
      CSCF_DIAGS STREQUAL "PARANOID")
    message(STATUS "Selected diagnostics option ${CSCF_DIAGS}")
  else()
    message(FATAL_ERROR "Unrecognized DIAGS option ${CSCF_DIAGS}")
  endif()

  set( CMAKE_C_FLAGS_DEBUG "-g -O0 ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${CSCF_EXTRA_C_FLAGS} ${DFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_CXX_FLAGS_DEBUG "-std=c++98 -g -O0 ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${QUAL_STD_FLAG} ${CSCF_EXTRA_CXX_FLAGS} ${DFLAGS_${CSCF_DIAGS}} ${DXXFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_C_FLAGS_MINSIZEREL "-O3 -g -fno-omit-frame-pointer ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${CSCF_EXTRA_C_FLAGS} ${DFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_CXX_FLAGS_MINSIZEREL "-std=c++98 -O3 -g -fno-omit-frame-pointer ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${QUAL_STD_FLAG} ${CSCF_EXTRA_CXX_FLAGS} ${DFLAGS_${CSCF_DIAGS}} ${DXXFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_C_FLAGS_RELEASE "-O3 -g ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${CSCF_EXTRA_C_FLAGS} ${DFLAGS_${CSCF_DIAGS}}" )
  set( CMAKE_CXX_FLAGS_RELEASE "-std=c++98 -O3 -g ${CSCF_WERROR} ${CSCF_EXTRA_FLAGS} ${QUAL_STD_FLAG} ${CSCF_EXTRA_CXX_FLAGS} ${DFLAGS_${CSCF_DIAGS}} ${DXXFLAGS_${CSCF_DIAGS}}" )

 _cet_add_build_types() 

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

  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
  remove_definitions(-DNDEBUG)
  if ( CSCF_ENABLE_ASSERTS )
    cet_enable_asserts()
  else()
    cet_maybe_disable_asserts()
  endif()
  add_definitions(${CSCF_EXTRA_DEFINITIONS})
  
  get_directory_property( CSCF_CD COMPILE_DEFINITIONS )
  if( CSCF_CD )
    message( STATUS "   DEFINE (-D): ${CSCF_CD}")
  endif()
 
  _remove_extra_std_flags(CMAKE_C_FLAGS_${BTYPE_UC})
  _remove_extra_std_flags(CMAKE_CXX_FLAGS_${BTYPE_UC})
  _remove_extra_std_flags(CMAKE_Fortran_FLAGS_${BTYPE_UC})
  ##message(STATUS "cet_set_compiler_flags debug: CMAKE_CXX_FLAGS_MINSIZEREL ${CMAKE_CXX_FLAGS_MINSIZEREL}")
  ##message(STATUS "cet_set_compiler_flags debug: CMAKE_CXX_FLAGS_DEBUG ${CMAKE_CXX_FLAGS_DEBUG}")
  ##message(STATUS "cet_set_compiler_flags debug: CMAKE_CXX_FLAGS_RELEASE ${CMAKE_CXX_FLAGS_RELEASE}")

endmacro( cet_set_compiler_flags )

macro( cet_query_system )
  ### This macro is useful if you need to check a variable
  ## http://cmake.org/Wiki/CMake_Useful_Variables#Compilers_and_Tools
  ## also see http://cmake.org/Wiki/CMake_Useful_Variables/Logging_Useful_Variables
  message( STATUS "cet_query_system: begin compiler report")
  message( STATUS "CMAKE_SYSTEM_NAME is ${CMAKE_SYSTEM_NAME}" )
  message( STATUS "CMAKE_BASE_NAME is ${CMAKE_BASE_NAME}" )
  message( STATUS "CMAKE_BUILD_TYPE is ${CMAKE_BUILD_TYPE}")
  message( STATUS "CMAKE_CONFIGURATION_TYPES is ${CMAKE_CONFIGURATION_TYPES}" )
  message( STATUS "BUILD_SHARED_LIBS  is ${BUILD_SHARED_LIBS}")
  message( STATUS "CMAKE_CXX_COMPILER_ID is ${CMAKE_CXX_COMPILER_ID}" )
  message( STATUS "CMAKE_COMPILER_IS_GNUCXX is ${CMAKE_COMPILER_IS_GNUCXX}" )
  message( STATUS "CMAKE_COMPILER_IS_MINGW is ${CMAKE_COMPILER_IS_MINGW}" )
  message( STATUS "CMAKE_COMPILER_IS_CYGWIN is ${CMAKE_COMPILER_IS_CYGWIN}" )
  message( STATUS "CMAKE_AR is ${CMAKE_AR}" )
  message( STATUS "CMAKE_RANLIB is ${CMAKE_RANLIB}" )
  message( STATUS "CMAKE_CXX_COMPILER is ${CMAKE_CXX_COMPILER}")
  message( STATUS "CMAKE_CXX_OUTPUT_EXTENSION is ${CMAKE_CXX_OUTPUT_EXTENSION}" )
  message( STATUS "CMAKE_CXX_FLAGS_DEBUG is ${CMAKE_CXX_FLAGS_DEBUG}" )
  message( STATUS "CMAKE_CXX_FLAGS_RELEASE is ${CMAKE_CXX_FLAGS_RELEASE}" )
  message( STATUS "CMAKE_CXX_FLAGS_MINSIZEREL is ${CMAKE_CXX_FLAGS_MINSIZEREL}" )
  message( STATUS "CMAKE_CXX_FLAGS_RELWITHDEBINFO is ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}" )
  message( STATUS "CMAKE_CXX_STANDARD_LIBRARIES is ${CMAKE_CXX_STANDARD_LIBRARIES}" )
  message( STATUS "CMAKE_CXX_LINK_FLAGS is ${CMAKE_CXX_LINK_FLAGS}" )
  message( STATUS "CMAKE_C_COMPILER is ${CMAKE_C_COMPILER}")
  message( STATUS "CMAKE_C_FLAGS is ${CMAKE_C_FLAGS}")
  message( STATUS "CMAKE_C_FLAGS_DEBUG is ${CMAKE_C_FLAGS_DEBUG}" )
  message( STATUS "CMAKE_C_FLAGS_RELEASE is ${CMAKE_C_FLAGS_RELEASE}" )
  message( STATUS "CMAKE_C_FLAGS_MINSIZEREL is ${CMAKE_C_FLAGS_MINSIZEREL}" )
  message( STATUS "CMAKE_C_FLAGS_RELWITHDEBINFO is ${CMAKE_C_FLAGS_RELWITHDEBINFO}" )
  message( STATUS "CMAKE_C_OUTPUT_EXTENSION is ${CMAKE_C_OUTPUT_EXTENSION}")
  message( STATUS "CMAKE_SHARED_LIBRARY_CXX_FLAGS is ${CMAKE_SHARED_LIBRARY_CXX_FLAGS}" )
  message( STATUS "CMAKE_SHARED_MODULE_CXX_FLAGS is ${CMAKE_SHARED_MODULE_CXX_FLAGS}" )
  message( STATUS "CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS is ${CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS}" )
  message( STATUS "CMAKE_SHARED_LINKER_FLAGS  is ${CMAKE_SHARED_LINKER_FLAGS}")
  message( STATUS "cet_query_system: end compiler report")
endmacro( cet_query_system )
