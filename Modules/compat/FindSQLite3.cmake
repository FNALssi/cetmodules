set(_cet_sqlite_sqlite_var_names
  FIND_COMPONENTS FOUND VERSION INCLUDE_DIR INCLUDE_DIRS LIBRARIES LIBRARY)

if (NOT CMAKE_FIND_PACKAGE_NAME STREQUAL SQLite3)
  set(_cet_sqlite_pkg_prefix ${CMAKE_FIND_PACKAGE_NAME})
  set(SQLite3_FIND_COMPONENTS ${${_cet_sqlite_pkg_prefix}_FIND_COMPONENTS})
  foreach (_cet_sqlite_component IN LISTS SQLite3_FIND_COMPONENTS)
    set(SQLite3_FIND_REQUIRED_${_cet_sqlite_component}
      ${${_cet_sqlite_pkg_prefix}_FIND_REQUIRED_${_cet_sqlite_component}})
  endforeach()
else()
  unset(_cet_sqlite_pkg_prefix)
endif()

# In B4 the official search to find our special library first. We do NOT
# want to use NAMES_PER_DIR here.
find_library(SQLite3_LIBRARY NAMES sqlite3_ups sqlite3 sqlite)
set(_cet_sqlite_cmake_module_path "${CMAKE_MODULE_PATH}")
set(CMAKE_MODULE_PATH) # Don't want to find ourselves and loop.
find_package(SQLite3)
set(CMAKE_MODULE_PATH "${_cet_sqlite_cmake_module_path}")
unset(_cet_sqlite_cmake_module_path)

# Set a variable for backward compatibility.
if (SQLite3_FOUND AND ${PROJECT_NAME}_OLD_STYLE_CONFIG_VARS)
  if (TARGET SQLite::SQLite3)
    set(SQLITE3 SQLite::SQLite3 CACHE FILEPATH
      "Location of the SQLite3 library (old-style CET compatibility)")
    mark_as_advanced(SQLITE3)
  else()
    unset(SQLITE3 CACHE)
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SQLite3 NAME_MISMATCHED
  REQUIRED_VARS SQLite3_INCLUDE_DIRS SQLite3_LIBRARIES)
if (_cet_sqlite_pkg_prefix)
  foreach (_cet_sqlite_var IN LISTS _cet_sqlite_sqlite_var_names)
    set(${_cet_sqlite_pkg_prefix}_${_cet_sqlite_var} ${SQLite3_${_cet_sqlite_var}})
  endforeach()
  foreach (_cet_sqlite_component IN LISTS ${_cet_sqlite_pkg_prefix_}_FIND_COMPONENTS)
    set(${_cet_sqlite_pkg_prefix}_FIND_REQUIRED_${_cet_sqlite_component} ${SQLite3_FIND_REQUIRED_${_cet_sqlite_component}})
    set(${_cet_sqlite_pkg_prefix}_${_cet_sqlite_component}_FOUND ${SQLite3_${_cet_sqlite_component}_FOUND})
  endforeach()
  set(CMAKE_FIND_PACKAGE_NAME ${_cet_sqlite_pkg_prefix})
endif()

unset(_cet_sqlite_component)
unset(_cet_sqlite_pkg_prefix)
