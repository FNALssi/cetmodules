#[================================================================[.rst:
X
=
#]================================================================]
if (NOT ${CMAKE_FIND_PACKAGE_NAME}_FOUND)
  if (${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
    set(_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED ${${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED})
    unset(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
  else()
    unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
  endif()
  find_package(${CMAKE_FIND_PACKAGE_NAME} CONFIG QUIET)
  if (_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
    set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED ${_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED})
    unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
  endif()
  if (${CMAKE_FIND_PACKAGE_NAME}_FOUND)
    set(_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode CONFIG_MODE)
  else()
    unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode)
  endif()
endif()
if (NOT ${CMAKE_FIND_PACKAGE_NAME}_FOUND)
  find_file(_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp NAMES range_fwd.hpp HINTS ENV RANGE_INC
    PATH_SUFFIXES range/v3 NO_DEFAULT_PATHS)
  if (_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp)
    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)
    set(RANGE-V3_FOUND TRUE)
  endif()
  string(REGEX REPLACE "^v3_([0-9]+)_([0-9]+)_([0-9]+).*$"
    "\\1.\\2.\\3"
    ${CMAKE_FIND_PACKAGE_NAME}_VERSION
    $ENV{RANGE_VERSION})
  mark_as_advanced(_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp)
endif()
if (${CMAKE_FIND_PACKAGE_NAME}_FOUND)
  if (_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp AND NOT TARGET range-v3::range-v3)
    # CMake config files are missing from some UPS installations: try to
    # make up for it.
    if (${CMAKE_FIND_PACKAGE_NAME}_VERSION VERSION_GREATER_EQUAL 0.10.0)
      add_library(range-v3-meta INTERFACE IMPORTED)
      set_target_properties(range-v3-meta PROPERTIES
        INTERFACE_COMPILE_OPTIONS "\$<\$<CXX_COMPILER_ID:MSVC>:/permissive->"
        INTERFACE_INCLUDE_DIRECTORIES "$ENV{RANGE_INC}"
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "$ENV{RANGE_INC}"
        )
      add_library(range-v3-concepts INTERFACE IMPORTED)
      set_target_properties(range-v3-concepts PROPERTIES
        INTERFACE_COMPILE_OPTIONS "\$<\$<CXX_COMPILER_ID:MSVC>:/permissive->"
        INTERFACE_INCLUDE_DIRECTORIES "$ENV{RANGE_INC}"
        INTERFACE_LINK_LIBRARIES "range-v3-meta"
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "$ENV{RANGE_INC}"
        )
      add_library(range-v3 INTERFACE IMPORTED)
      set_target_properties(range-v3 PROPERTIES
        INTERFACE_COMPILE_OPTIONS "\$<\$<CXX_COMPILER_ID:MSVC>:/permissive->"
        INTERFACE_INCLUDE_DIRECTORIES "$ENV{RANGE_INC}"
        INTERFACE_LINK_LIBRARIES "range-v3-concepts;range-v3-meta"
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "$ENV{RANGE_INC}"
        )
      add_library(range-v3::meta INTERFACE IMPORTED)
      add_library(range-v3::concepts INTERFACE IMPORTED)
      add_library(range-v3::range-v3 INTERFACE IMPORTED)
      if (CMAKE_VERSION VERSION_LESS 3.11)
        set_target_properties(range-v3::meta PROPERTIES INTERFACE_LINK_LIBRARIES "range-v3-meta")
        set_target_properties(range-v3::concepts PROPERTIES INTERFACE_LINK_LIBRARIES "range-v3-concepts")
        set_target_properties(range-v3::range-v3 PROPERTIES INTERFACE_LINK_LIBRARIES "range-v3")
      else()
        target_link_libraries(range-v3::meta INTERFACE range-v3-meta)
        target_link_libraries(range-v3::concepts INTERFACE range-v3-concepts)
        target_link_libraries(range-v3::range-v3 INTERFACE range-v3)
      endif()
    else()
      message(FATAL_ERROR "UPS ${CMAKE_FIND_PACKAGE_NAME} packages not supported below v3_0_10_0")
    endif()
    if (CMAKE_FIND_PACKAGE_NAME STREQUAL Range AND NOT TARGET Range::Range)
      message(DEPRECATION "find_package(Range) is deprecated: please use find_package(Range-v3) and target range-v3::range-v3")
      add_library(Range::Range INTERFACE IMPORTED)
      if(CMAKE_VERSION VERSION_LESS 3.11)
        set_target_properties(Range::Range PROPERTIES INTERFACE_LINK_LIBRARIES "range-v3::range-v3")
      else()
        target_link_libraries(Range::Range INTERFACE range-v3::range-v3)
      endif()
    endif()
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(${CMAKE_FIND_PACKAGE_NAME} ${_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode}
  REQUIRED_VARS ${CMAKE_FIND_PACKAGE_NAME}_FOUND ${CMAKE_FIND_PACKAGE_NAME}_VERSION)
unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode)
