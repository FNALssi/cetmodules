########################################################################
# cet_set_compiler_flags( [extra flags] ) 
#
#    sets the default compiler flags
#
# Debug           -g -O0
# MinSizeRel      -Os
# Release         -O3 -g -DNDEBUG
# RelWithDebInfo  -O3 -g -DNDEBUG -fno-omit-frame-pointer
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
#      asserts for RelWithDebInfo and Release levels).
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
  if( ${BTYPE_UC} MATCHES "RELEASE" OR
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
  string(REGEX MATCH "(^| )-std=" CSCF_HAVE_STD ${CSCF_ARGS})
  if (CSCF_HAVE_STD)
    message(FATAL_ERROR "cet_add_compiler_flags() called with -std=...: use CMAKE_<LANG>_STANDARD and CMAKE_<LANG>_EXTENSIONS instead")
  endif()
  if(CSCF_C AND CSCF_CXX)
    add_compile_options(${CSCF_UNPARSED_ARGUMENTS}) # In bulk.
    list(REMOVE_ITEM CSCF_LANGUAGES C CXX)
  endif()
  # For each language specified if not already handled above.
  foreach(lang ${CSCF_LANGUAGES})
    foreach(opt ${CSCF_UNPARSED_ARGUMENTS})
      add_compile_options($<$<COMPILE_LANGUAGE:${lang}>:${opt}>)
    endforeach()
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

macro( cet_set_compiler_flags )
  CET_PARSE_ARGS(CSCF
    "DIAGS;DWARF_VER;EXTRA_FLAGS;EXTRA_C_FLAGS;EXTRA_CXX_FLAGS;EXTRA_DEFINITIONS"
    "ALLOW_DEPRECATIONS;DWARF_STRICT;ENABLE_ASSERTS;NO_UNDEFINED;WERROR"
    ${ARGN}
    )

  if (CSCF_DEFAULT_ARGS)
    message(FATAL_ERROR "Unexpected extra arguments: ${CSCF_DEFAULT_ARGS}.\nConsider EXTRA_FLAGS, EXTRA_C_FLAGS, EXTRA_CXX_FLAGS or EXTRA_DEFINITIONS")
  endif()

  # Set options based on diagnostic option.
  set(diags_vals CAVALIER CAUTIOUS VIGILANT PARANOID)
  string(TOUPPER "${CSCF_DIAGS}" CSCF_DIAGS)
  if (NOT CSCF_DIAGS)
    set(CSCF_DIAGS "CAUTIOUS")
  endif()
  list(FIND diags_vals ${CSCF_DIAGS} diag_idx)
  if (diag_idx GREATER -1)
    message(STATUS "Selected diagnostics option ${CSCF_DIAGS}")
    if (diag_idx GREATER 0) # At least CAUTIOUS
      add_compile_options(-Wall -Werror=return-type) # C & C++
      if (diag_idx GREATER 1) # At least VIGILANT
        add_compile_options(-Wextra -Wno-long-long -Winit-self)
        if (NOT CMAKE_COMPILER_ID STREQUAL "Intel")
          add_compile_options(-Wno-unused-local-typedefs)
        endif()
        foreach (opt -Woverloaded-virtual
            -Wnon-virtual-dtor
            -Wdelete-non-virtual-dtor)
          add_compile_options($<$<COMPILE_LANGUAGE:CXX>:${opt}>) # C++ only
        endforeach()
        if (diag_idx GREATER 2) # PARANOID
          add_compile_options(-pedantic
            -Wformat-y2k
            -Wswitch-default
            -Wsync-nand
            -Wtrampolines
            -Wlogical-op
            -Wshadow
            -Wcast-qual)
        endif(diag_idx GREATER 2)
      endif(diag_idx GREATER 1)
    endif(diag_idx GREATER 0)
    add_compile_options(${CSCF_EXTRA_FLAGS})
    foreach (opt ${CSCF_EXTRA_C_FLAGS})
      add_compile_options($<$<COMPILE_LANGUAGE:C>:${opt}>) # C only
    endforeach()
    foreach (opt ${CSCF_EXTRA_CXX_FLAGS})
      add_compile_options($<$<COMPILE_LANGUAGE:CXX>:${opt}>) # C++ only
    endforeach()
  else()
    message(FATAL_ERROR "Unrecognized DIAGS option ${CSCF_DIAGS}")
  endif()

  if (CSCF_WERROR)
    add_compile_options(-Werror)
    if (CSCF_ALLOW_DEPRECATIONS)
      add_compile_options(-Wno-error=deprecated-declarations)
    endif()
  elseif (CSCF_ALLOW_DEPRECATIONS)
    message(WARNING "ALLOW_DEPRECATIONS ignored when WERROR not specified")
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
  cet_remove_compiler_flags(C CXX -DNDEBUG)
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

  # Be more aggressive with optimization for RelWithDebInfo
  add_compile_options($<$<CONFIG:RELWITHDEBINFO>:-O3>)
  add_compile_options($<$<CONFIG:RELWITHDEBINFO>:-fno-omit-frame-pointer>)

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
