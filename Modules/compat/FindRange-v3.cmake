#[================================================================[.rst:
X
=
#]================================================================]

include(private/CetAddTransitiveDependency)
include(ParseVersionString)
if (NOT ${CMAKE_FIND_PACKAGE_NAME}_FOUND) # we have work to do
  if (CMAKE_FIND_PACKAGE_NAME STREQUAL "Range") # compatibility
    set(_cet_Range_fphsa_package range-v3)
    unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
    if (_fp_Range_transitive_args)
      # We will need cetmodules in order to find Range transitively (but
      # see deprecation warning).
      _cet_add_transitive_dependency(find_package cetmodules 2.29.11 REQUIRED)
    endif()
  else()
    set(_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package ${CMAKE_FIND_PACKAGE_NAME})
    set(_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED ${${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED})
    unset(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
  endif()
  # Try to find an official CMake config.
  find_package(${_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package} CONFIG QUIET)
  if (_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
    set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED ${_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED})
    unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
  endif()
  if (${_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package}_FOUND)
    set(_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode CONFIG_MODE)
    if (NOT CMAKE_FIND_PACKAGE_NAME STREQUAL _cet_${CMAKE_FIND_PACKAGE_NAME}_fhpsa_package)
      set(${CMAKE_FIND_PACKAGE_NAME}_FOUND ${_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package}_FOUND)
      set(_cet_${CMAKE_FIND_PACKAGE_NAME}_name_mismatched NAME_MISMATCHED)
    else()
      unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_name_mismatched)
    endif()
  elseif (CMAKE_DISABLE_FIND_PACKAGE_${_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package})
    # If we're not supposed to be looking for range-v3, we shouldn't be
    # trying to find Range either.
  else()
    # Look for a UPS Range package configured in the environment.
    set(_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package
      ${CMAKE_FIND_PACKAGE_NAME})
    unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode)
    if (DEFINED ENV{RANGE_INC}) # UPS package?
      find_file(_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp
        NAMES range_fwd.hpp HINTS ENV RANGE_INC
        PATH_SUFFIXES range/v3 NO_DEFAULT_PATH)
      mark_as_advanced(_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp)
      if (_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp)
        set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)
        set(${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR $ENV{RANGE_INC} CACHE INTERNAL
          "Header include directory for ${CMAKE_FIND_PACKAGE_NAME}")
        set(${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIRS $ENV{RANGE_INC})
        string(REGEX REPLACE "^v3_([0-9]+)_([0-9]+)_([0-9]+).*$"
          "\\1.\\2.\\3"
          ${CMAKE_FIND_PACKAGE_NAME}_VERSION
          "$ENV{RANGE_VERSION}")
        if (CMAKE_FIND_PACKAGE_NAME STREQUAL Range)
          set(${CMAKE_FIND_PACKAGE_NAME}_VERSION
            "3.${${CMAKE_FIND_PACKAGE_NAME}_VERSION}")
        endif()
      endif()
    endif()
  endif()
endif()

if (${_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package}_FOUND)
  if (_cet_${CMAKE_FIND_PACKAGE_NAME}_hpp AND NOT TARGET range-v3::range-v3)
    # CMake config files are missing from some UPS installations: try to
    # make up for it.
    cet_compare_versions(_cet_UPS_Range_targets_supported
      $ENV{RANGE_VERSION} VERSION_GREATER_EQUAL 3.0.10.0)
    if (_cet_UPS_Range_targets_supported)
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
    elseif (NOT CMAKE_FIND_PACKAGE_NAME STREQUAL Range)
      message(FATAL_ERROR "find_package(${CMAKE_FIND_PACKAGE_NAME}) for UPS \"range\" packages is not supported below v3_0_10_0
Use either find_package(Range) with target Range::Range, non-UPS Range-v3, or UPS \"range\" >= v3_0_10_0\
")
    endif()
  endif()
  if (CMAKE_FIND_PACKAGE_NAME STREQUAL Range AND NOT TARGET Range::Range)
    message(DEPRECATION "find_package(Range) is deprecated: please use find_package(Range-v3) and target range-v3::range-v3")
    add_library(Range::Range INTERFACE IMPORTED)
    if (TARGET range-v3::range-v3)
      if(CMAKE_VERSION VERSION_LESS 3.11)
        set_target_properties(Range::Range PROPERTIES
          INTERFACE_LINK_LIBRARIES "range-v3::range-v3")
      else()
        target_link_libraries(Range::Range INTERFACE range-v3::range-v3)
      endif()
    else() # we're using UPS \"range\" without packaged CMake config files
      set_target_properties(Range::Range PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "$ENV{RANGE_INC}")
    endif()
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(${_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package}
  REQUIRED_VARS
  ${CMAKE_FIND_PACKAGE_NAME}_FOUND
  ${CMAKE_FIND_PACKAGE_NAME}_VERSION
  HANDLE_VERSION_RANGE
  HANDLE_COMPONENTS
  ${_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode}
  ${_cet_${CMAKE_FIND_PACKAGE_NAME}_name_mismatched}
  VERSION_VAR ${CMAKE_FIND_PACKAGE_NAME}_VERSION
  )

unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_config_mode)
unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_fphsa_package)
unset(_cet_${CMAKE_FIND_PACKAGE_NAME}_name_mismatched)
