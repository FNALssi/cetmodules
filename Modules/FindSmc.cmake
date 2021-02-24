set(_cet_smc_var_names
  FIND_COMPONENTS FOUND VERSION INCLUDE_DIR INCLUDE_DIRS LIBRARIES LIBRARY)

if (NOT CMAKE_FIND_PACKAGE_NAME STREQUAL Smc)
  set(_cet_smc_pkg_prefix ${CMAKE_FIND_PACKAGE_NAME})
  set(Smc_FIND_COMPONENTS ${${_cet_smc_pkg_prefix}_FIND_COMPONENTS})
  foreach (_cet_smc_component IN LISTS Smc_FIND_COMPONENTS)
    set(Smc_FIND_REQUIRED_${_cet_smc_component}
      ${${_cet_smc_pkg_prefix}_FIND_REQUIRED_${_cet_smc_component}})
  endforeach()
  foreach (_cet_smc_var IN ITEMS
      FIND_VERSION FIND_VERSION_MAJOR FIND_VERSION_MINOR FIND_VERSION_MICRO FIND_VERSION_TWEAK)
    set(Smc_${_cet_smc_var} "${_cet_smc_pkg_prefix}_${_cet_smc_var}")
  endforeach()
else()
  unset(_cet_smc_pkg_prefix)
endif()

set(_cet_smc_cmake_module_path "${CMAKE_MODULE_PATH}")
set(CMAKE_MODULE_PATH) # Don't want to find ourselves and loop.
find_package(Smc QUIET)
set(CMAKE_MODULE_PATH "${_cet_smc_cmake_module_path}")
unset(_cet_smc_cmake_module_path)

if (NOT Smc_FOUND)
  cet_find_package(Java REQUIRED PRIVATE)
  include(UseJava)
  set(_cet_smc_search_paths)
  if (DEFINED SMC_HOME)
    list(APPEND _cet_smc_search_paths "${SMC_HOME}/bin")
  elseif (DEFINED ENV{SMC_HOME})
    list(APPEND _cet_smc_search_paths "$ENV{SMC_HOME}/bin")
  endif()
  find_jar(Smc_JAR NAMES Smc
    PATHS ${_cet_smc_search_paths}
    DOC "Location of the State Machine Chart JAR file.")
  unset(_cet_smc_search_paths)
  mark_as_advanced(Smc_JAR)
  if (Smc_JAR)
    set(Smc_FOUND 1)
    if (NOT SMC_HOME)
      get_filename_component(SMC_HOME "${Smc_JAR}" DIRECTORY)
      get_filename_component(SMC_HOME "${SMC_HOME}" DIRECTORY)
    endif()
  endif()
endif()

if (Smc_FOUND)
  if (NOT "$CACHE{Smc_statemap_h}")
    find_file(Smc_statemap_h NAMES statemap.h HINTS ENV SMC_HOME ${SMC_HOME}
      PATH_SUFFIXES lib/C++)
    mark_as_advanced(Smc_statemap_h)
  endif()
  if (Smc_statemap_h)
    get_filename_component(Smc_INCLUDE_DIR "${Smc_statemap_h}" DIRECTORY)
    if (NOT TARGET Smc::Smc)
      add_library(Smc::Smc UNKNOWN IMPORTED)
      set_target_properties(Smc::Smc PROPERTIES
        IMPORTED_LOCATION ${Smc_JAR}
        INTERFACE_INCLUDE_DIRECTORIES "${Smc_INCLUDE_DIR}")
    endif()
  else()
    unset(Smc_FOUND)
  endif()
endif()

if (Smc_JAR)
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf "${Smc_JAR}"
    --format=7zip -- "META-INF/MANIFEST.MF"
    OUTPUT_QUIET ERROR_QUIET
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
  execute_process(COMMAND sed -Ene
    "s&^Implementation-Version:[[:space:]]+(.*)\$&\\1&p" --
    "META-INF/MANIFEST.MF"
    OUTPUT_VARIABLE Smc_VERSION OUTPUT_STRIP_TRAILING_WHITESPACE
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
endif()
message(STATUS "Found Smc.jar version ${Smc_VERSION}")
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Smc NAME_MISMATCHED
  VERSION_VAR Smc_VERSION
  REQUIRED_VARS Smc_JAR Smc_FOUND Smc_statemap_h)

if (_cet_smc_pkg_prefix)
  foreach (_cet_smc_var IN LISTS _cet_smc_var_names)
    set(${_cet_smc_pkg_prefix}_${_cet_smc_var} "${Smc_${_cet_smc_var}}")
  endforeach()
  foreach (_cet_smc_component IN LISTS ${_cet_smc_pkg_prefix_}_FIND_COMPONENTS)
    set(${_cet_smc_pkg_prefix}_FIND_REQUIRED_${_cet_smc_component} ${Smc_FIND_REQUIRED_${_cet_smc_component}})
    set(${_cet_smc_pkg_prefix}_${_cet_smc_component}_FOUND ${Smc_${_cet_smc_component}_FOUND})
  endforeach()
  set(CMAKE_FIND_PACKAGE_NAME ${_cet_smc_pkg_prefix})
endif()

if (smc_FOUND AND ${PROJECT_NAME}_OLD_STYLE_CONFIG_VARS)
  set(SMC Smc::Smc)
endif()

unset(_cet_smc_component)
unset(_cet_smc_pkg_prefix)
unset(_cet_smc_var)
unset(_cet_smc_var_names)
