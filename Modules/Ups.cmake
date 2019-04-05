########################################################################
# Ups.cmake
#
# Two functions are provided for public external use: ups_version() and
# set_ups_variables().
#
# This CMake file should *not* be included directly by anyone wishing to
# make use of the above functions: the CMake variable WANT_UPS should be
# set and the cet_cmake_env() function called in order to make these
# functions available.
########################################################################
cmake_minimum_required(VERSION 3.11) # For STRING(JOIN...)

set(_known_compiler_quals e10 e14 e15 e16 e17 e19 c2 c5 c7)

if (_PRINT_KNOWN_COMPILER_QUALS)
  message("Known UPS compiler qualifiers: ${_known_compiler_quals}")
  return()
elseif (NOT WANT_UPS)
  message(FATAL_ERROR "Set the CMake variable WANT_UPS prior to including CetCMakeEnv.cmake and call cet_cmake_env() to activate UPS table file and tarball generation. Ups.cmake should not be included directly.")
endif()

set(CETMODULES_MODULES_DIR ${CMAKE_CURRENT_LIST_DIR})

function(_set_compiler_qual CQUALVAR)
  if (CMAKE_CXX_COMPILER_ID STREQUAL GNU)
    if (CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 4.9.3)
      set(CQUAL e10)
    elseif (CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 6.3.0)
      set(CQUAL e14)
    elseif (CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 6.4.0)
      set(CQUAL e15)
    elseif (CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 7.2.0)
      set(CQUAL e16)
    elseif (CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 7.3.0)
      set(CQUAL e17)
    elseif (CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 8.2.0)
      set(CQUAL e19)
    else()
      message(FATAL_ERROR "WANT_UPS is incompatible with ${CMAKE_CXX_COMPILER_ID} version ${CMAKE_CXX_COMPILER_VERSION}. Known compiler qualifers: ${_known_compiler_quals}")
    endif()
  elseif (CMAKE_CXX_COMPILER_ID STREQUAL Clang)
    if (CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 5.0.1)
      set(CQUAL c2)
    elseif(CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 6.0.1)
      set(CQUAL c5)
    elseif(CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 7.0.0)
      set(CQUAL c7)
    else()
      message(FATAL_ERROR "WANT_UPS is incompatible with ${CMAKE_CXX_COMPILER_ID} version ${CMAKE_CXX_COMPILER_VERSION}. Known compiler qualifers: ${_known_compiler_quals}")
    endif()
  else()
    message(FATAL_ERROR "WANT_UPS is incompatible with ${CMAKE_CXX_COMPILER_ID} compilers. Known compiler qualifers: ${_known_compiler_quals}")
  endif()
  set(${CQUALVAR} ${CQUAL} PARENT_SCOPE)
endfunction()

function(_set_ostype)
  cmake_parse_arguments(_SO "NO_FLAVOR" "" "" ${ARGN})
  if (_SO_NO_FLAVOR)
    set(OSTYPE noarch PARENT_SCOPE)
  elseif(APPLE)
    set(OSTYPE "d${CMAKE_SYSTEM_VERSION_MAJOR}" PARENT_SCOPE)
  else()
    execute_process(COMMAND ups flavor -5
      OUTPUT_VARIABLE tmp OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REGEX MATCH "^.*-(.*)$" tmp "${tmp}")
    set(OSTYPE "${CMAKE_MATCH_1}")
    if (OSTYPE MATCHES "(sl)([56])")
      set(OSTYPE "${CMAKE_MATCH_1}f${CMAKE_MATCH_2}")
    endif()
    set(OSTYPE "${OSTYPE}" PARENT_SCOPE)
  endif()
endfunction()

function(_pad_num PADDING VAR NUMBER)
  if (PADDING GREATER 0 AND NUMBER MATCHES "^([^0-9]*)([0-9]+)(.*)$")
    set(NUMBER_PRE ${CMAKE_MATCH_1})
    set(NUMBER ${CMAKE_MATCH_2})
    set(NUMBER_POST ${CMAKE_MATCH_3})
    string(LENGTH "${NUMBER}" len)
    math(EXPR PADDING "${PADDING} - 1")
    if (NOT len GREATER PADDING)
      foreach(NZ RANGE ${len} ${PADDING})
        string(PREPEND NUMBER 0)
      endforeach()
    endif()
  endif()
  set(${VAR} "${NUMBER_PRE}${NUMBER}${NUMBER_POST}" PARENT_SCOPE)
endfunction()

set(_pad_default 2)
function (ups_version VERSION VAR)
  cmake_parse_arguments(UV "" "DOTVAR;PAD_MAJOR;PAD_MINOR;PAD_PATCH;PAD_TWEAK" "" ${ARGN})
  if (UV_PAD_MAJOR)
    if (NOT UV_PAD_MAJOR GREATER 0)
      set(PAD_MAJOR ${_pad_default})
    else()
      set(PAD_MAJOR ${UV_PAD_MAJOR})
    endif()
    if (PAD_MAJOR GREATER 1)
      set(PAD_MINOR ON)
    endif()
  endif()
  if (UV_PAD_MINOR OR PAD_MINOR)
    if (NOT UV_PAD_MINOR GREATER 0)
      set(PAD_MINOR ${_pad_default})
    else()
      set(PAD_MINOR ${UV_PAD_MINOR})
    endif()
    if (PAD_MINOR GREATER 1)
      set(PAD_PATCH ON)
    endif()
  elseif(DEFINED UV_PAD_MINOR)
    unset(PAD_MINOR)
  endif()
  if (UV_PAD_PATCH OR PAD_PATCH)
    if (NOT UV_PAD_PATCH GREATER 0)
      set(PAD_PATCH ${_pad_default})
    else()
      set(PAD_PATCH ${UV_PAD_PATCH})
    endif()
    if (PAD_PATCH GREATER 1)
      set(PAD_TWEAK ${_pad_default})
    endif()
  elseif(DEFINED UV_PAD_PATCH)
    unset(PAD_PATCH)
  endif()
  if (UV_PAD_TWEAK)
    if (UV_PAD_TWEAK GREATER 0)
      set(PAD_TWEAK ${UV_PAD_TWEAK})
    else()
      set(PAD_TWEAK ${_pad_default})
    endif()
  elseif(DEFINED UV_PAD_TWEAK)
    unset(PAD_TWEAK)
  endif()
  if (VERSION MATCHES "^([^_.]+)[_.]?(.*)$")
    set(major ${CMAKE_MATCH_1})
    if ("${CMAKE_MATCH_2}" MATCHES "^([^_.]+)[_.]?(.*)$")
      set(minor ${CMAKE_MATCH_1})
      if ("${CMAKE_MATCH_2}" MATCHES "^([^_.]+)[_.]?(.*)$")
        set(patch ${CMAKE_MATCH_1})
        if ("${CMAKE_MATCH_2}")
          set(tweak "_${CMAKE_MATCH_2}")
        elseif (patch MATCHES "^([0-9]+)(.*)$")
          set(patch ${CMAKE_MATCH_1})
          set(tweak ${CMAKE_MATCH_2})
        endif()
        if (PAD_TWEAK)
          _pad_num(${PAD_TWEAK} tweak "${tweak}")
        endif()
        if (PAD_PATCH)
          _pad_num(${PAD_PATCH} patch "${patch}")
        endif()
      endif()
      if (PAD_MINOR)
        _pad_num(${PAD_MINOR} minor "${minor}")
      endif()
    endif()
    if (PAD_MAJOR)
      _pad_num(${PAD_MAJOR} major "${major}")
    endif()
  endif()
  string(JOIN "_" tmp ${major} ${minor} ${patch})
  set(${VAR} "v${tmp}${tweak}" PARENT_SCOPE)
  string(JOIN "." dottmp ${major} ${minor} ${patch})
  if (UV_DOTVAR)
    set(${UV_DOTVAR} "${dottmp}${tweak}" PARENT_SCOPE)
  endif()
endfunction()

function(set_ups_variables)
  cmake_parse_arguments(suv
    "NO_BUILDTYPE;WANT_COMPILER_QUAL"
    "BUILDTYPE;UPS_PRODUCT_NAME"
    "UPS_QUALS"
    ${ARGN})

  # Argument consistency.
  if (suv_BUILDTYPE AND suv_NO_BUILDTYPE)
    message(FATAL_ERROR "set_ups_variables(): BUILDTYPE and NO_BUILDTYPE are mutually-exclusive options.")
  endif()

  # UPS product name.
  if (suv_UPS_PRODUCT_NAME)
    set(UPS_PRODUCT_NAME ${suv_UPS_PRODUCT_NAME})
  else()
    set(UPS_PRODUCT_NAME ${CMAKE_PROJECT_NAME})
  endif()

  # UPS product version.
  list(REMOVE_ITEM suv_UNPARSED_ARGUMENTS DOTVAR)
  ups_version(${CMAKE_PROJECT_VERSION} UPS_PRODUCT_VERSION ${suv_UNPARSED_ARGUMENTS}
    DOTVAR UPS_PRODUCT_DOTVERSION)

  # OSTYPE.
  _set_ostype(${suv_UNPARSED_ARGUMENTS})

  # Compiler qualifier (e17, c2, etc.).
  if (suv_WANT_COMPILER_QUAL)
    _set_compiler_qual(CQUAL)
  endif()

  # Flavor and qualifier.
  if (OSTYPE STREQUAL "noarch")
    set(UPS_FLAVOR "NULL")
  else()
    if (APPLE)
      set(FLVRLVL 2)
    else()
      set(FLVRLVL 4)
    endif()
    execute_process(COMMAND ups flavor -${FLVRLVL}
      OUTPUT_VARIABLE UPS_FLAVOR OUTPUT_STRIP_TRAILING_WHITESPACE)
    if (suv_BUILDTYPE)
      set(btype ${suv_BUILDTYPE})
    elseif(NOT suv_NO_BUILDTYPE)
      string(TOUPPER "${CMAKE_BUILD_TYPE}" BTYPE_UC)
      if (BTYPE_UC STREQUAL "DEBUG")
        set(btype "debug")
      elseif(BTYPE_UC STREQUAL "RELWITHDEBINFO")
        set(btype "prof")
      elseif(BTYPE_UC STREQUAL "RELEASE")
        set(btype "opt")
      else()
        message(FATAL_ERROR
          "set_ups_variables() unable to deduce buildtype from CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
      endif()
    endif()
  endif()

  if (suv_UPS_QUALS)
    list(SORT suv_UPS_QUALS)
  endif()
  set(UPS_QUALS ${CQUAL} ${suv_UPS_QUALS} ${btype})

  string(JOIN ":" UPS_QUALIFIER_STRING ${UPS_QUALS})

  # UPS product directory.
  set(UPS_PRODUCT_SUBDIR "${UPS_PRODUCT_NAME}/${UPS_PRODUCT_VERSION}")
  set(UPS_PRODUCT_FQ_SUBDIR "${UPS_PRODUCT_SUBDIR}")
  set(UPS_PRODUCT_UPS_DIR ups)
  if (NOT OSTYPE STREQUAL "noarch")
    string(JOIN "." UPS_PRODUCT_FQ
      "${OSTYPE}"
      "${CMAKE_SYSTEM_PROCESSOR}"
      ${UPS_QUALS}
      )
    string(APPEND UPS_PRODUCT_FQ_SUBDIR "/${UPS_PRODUCT_FQ}")
    string(PREPEND UPS_PRODUCT_UPS_DIR "${UPS_PRODUCT_FQ}/")
  endif()

  string(JOIN "_" UPS_PRODUCT_VERSION_FILE "${UPS_FLAVOR}" ${UPS_QUALS})
  if (NOT UPS_QUALS)
    string(APPEND UPS_PRODUCT_VERSION_FILE "_")
  endif()

  # Set variables in parent scope.
  set(OSTYPE "${OSTYPE}" PARENT_SCOPE)
  set(UPS_TOP_DIR "${CMAKE_INSTALL_PREFIX}" PARENT_SCOPE)
  set(UPS_PRODUCT_NAME "${UPS_PRODUCT_NAME}" PARENT_SCOPE)
  set(UPS_PRODUCT_VERSION "${UPS_PRODUCT_VERSION}" PARENT_SCOPE)
  set(UPS_PRODUCT_DOTVERSION "${UPS_PRODUCT_DOTVERSION}" PARENT_SCOPE)
  set(UPS_FLAVOR "${UPS_FLAVOR}" PARENT_SCOPE)
  set(UPS_QUALS ${UPS_QUALS} PARENT_SCOPE)
  set(UPS_QUALIFIER_STRING "${UPS_QUALIFIER_STRING}" PARENT_SCOPE)
  set(UPS_PRODUCT_SUBDIR "${UPS_PRODUCT_SUBDIR}" PARENT_SCOPE)
  set(UPS_PRODUCT_FQ "${UPS_PRODUCT_FQ}" PARENT_SCOPE)
  set(UPS_PRODUCT_FQ_SUBDIR "${UPS_PRODUCT_FQ_SUBDIR}" PARENT_SCOPE)
  set(UPS_PRODUCT_UPS_DIR "${UPS_PRODUCT_UPS_DIR}" PARENT_SCOPE)
  set(UPS_PRODUCT_VERSION_DIRNAME "${UPS_PRODUCT_VERSION}.version" PARENT_SCOPE)
  set(UPS_PRODUCT_VERSION_SUBDIR "../${UPS_PRODUCT_VERSION}.version" PARENT_SCOPE)
  set(UPS_PRODUCT_VERSION_FILE "${UPS_PRODUCT_VERSION_FILE}" PARENT_SCOPE)
  set(UPS_TAR_DIR "${CMAKE_BINARY_DIR}" PARENT_SCOPE)
endfunction()

function(process_ups_files)
  if (NOT UPS_TOP_DIR)
    message(FATAL_ERROR "Set the CMake variable WANT_UPS prior to including CetCMakeEnv.cmake to activate UPS table file and tarball generation. Ups.cmake should not be included directly.")
  endif()
  # Generate the UPS table file.
  configure_file(${UPS_PRODUCT_NAME}.table.in
    ${CMAKE_CURRENT_BINARY_DIR}/${UPS_PRODUCT_NAME}.table
    @ONLY)

  # Use UTC because CMake won't tell us the current timezone code.
  string(TIMESTAMP UPS_DECLARE_DATE "%a %b %d %H:%M:%S UTC" UTC)

  # Generate the UPS version file.
  configure_file(${CETMODULES_MODULES_DIR}/../config/UPS_PRODUCT_VERSION_FILE.in
    ${CMAKE_CURRENT_BINARY_DIR}/${UPS_PRODUCT_VERSION_FILE}
    @ONLY)

  # Install generated files.
  install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/${UPS_PRODUCT_NAME}.table
    DESTINATION ${UPS_PRODUCT_UPS_DIR})

  install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/${UPS_PRODUCT_VERSION_FILE}
    DESTINATION ${UPS_PRODUCT_VERSION_SUBDIR})
endfunction()

macro(_ups_init_cpack)
  set(CPACK_PACKAGE_VERSION "${UPS_PRODUCT_DOTVERSION}")
  # Necessary to allow the correct structure in the archive file.
  set(CPACK_GENERATOR External)
  set(CPACK_EXTERNAL_ENABLE_STAGING ON)
  set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CETMODULES_MODULES_DIR}/UpsTar.cmake")
  set(CPACK_PACKAGE_NAME ${UPS_PRODUCT_NAME})
  set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY ON)
  if (OSTYPE STREQUAL "noarch")
    set(PACKAGE_BASENAME ${OSTYPE})
  else()
    set(PACKAGE_BASENAME ${OSTYPE}-${CMAKE_SYSTEM_PROCESSOR})
  endif()
  string(JOIN "-" CPACK_SYSTEM_NAME ${PACKAGE_BASENAME} ${UPS_QUALS})
  message(STATUS "CPACK_PACKAGE_NAME = ${CPACK_PACKAGE_NAME}, CPACK_SYSTEM_NAME = ${CPACK_SYSTEM_NAME}")
  include(CPack)
  # Ensure we see these variables inside CPack.
  set(CPackConfigExtra "\n# UPS variables for use by external generator script.\n")
  foreach (VAR
      UPS_TOP_DIR UPS_PRODUCT_NAME UPS_PRODUCT_VERSION UPS_FLAVOR UPS_QUALS
      UPS_QUALIFIER_STRING UPS_PRODUCT_SUBDIR UPS_PRODUCT_FQ
      UPS_PRODUCT_FQ_SUBDIR UPS_PRODUCT_UPS_DIR UPS_PRODUCT_VERSION_DIRNAME
      UPS_PRODUCT_VERSION_SUBDIR UPS_PRODUCT_VERSION_FILE UPS_TAR_DIR)
    string(APPEND CPackConfigExtra "set(${VAR} \"${${VAR}}\")\n")
  endforeach()
  file(APPEND "${CMAKE_CURRENT_BINARY_DIR}/CPackConfig.cmake" "${CPackConfigExtra}")
endmacro()
