set(_cet_catch_var_names
  FIND_COMPONENTS FOUND VERSION INCLUDE_DIR INCLUDE_DIRS LIBRARIES LIBRARY)

if (NOT CMAKE_FIND_PACKAGE_NAME STREQUAL Catch2)
  set(_cet_catch_pkg_prefix ${CMAKE_FIND_PACKAGE_NAME})
  set(Catch2_FIND_COMPONENTS ${${_cet_catch_pkg_prefix}_FIND_COMPONENTS})
  foreach (_cet_catch_component IN LISTS Catch2_FIND_COMPONENTS)
    set(Catch2_FIND_REQUIRED_${_cet_catch_component}
      ${${_cet_catch_pkg_prefix}_FIND_REQUIRED_${_cet_catch_component}})
  endforeach()
else()
  unset(_cet_catch_pkg_prefix)
endif()

find_package(Catch2)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Catch2 NAME_MISMATCHED
  REQUIRED_VARS Catch2_FOUND)

if (_cet_catch_pkg_prefix)
  foreach (_cet_catch_var IN LISTS _cet_catch_var_names)
    set(${_cet_catch_pkg_prefix}_${_cet_catch_var} "${Catch2_${_cet_catch_var}}")
  endforeach()
  foreach (_cet_catch_component IN LISTS ${_cet_catch_pkg_prefix_}_FIND_COMPONENTS)
    set(${_cet_catch_pkg_prefix}_FIND_REQUIRED_${_cet_catch_component} ${Catch2_FIND_REQUIRED_${_cet_catch_component}})
    set(${_cet_catch_pkg_prefix}_${_cet_catch_component}_FOUND ${Catch2_${_cet_catch_component}_FOUND})
  endforeach()
  set(CMAKE_FIND_PACKAGE_NAME ${_cet_catch_pkg_prefix})
endif()

unset(_cet_catch_component)
unset(_cet_catch_pkg_prefix)
unset(_cet_catch_var)
unset(_cet_catch_var_names)
