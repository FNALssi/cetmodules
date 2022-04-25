if (NOT Eigen3_FOUND)
  set(_cet_findEigen3_quietly ${Eigen3_FIND_QUIETLY})
  find_package(Eigen3 CONFIG QUIET)
  set(Eigen3_FIND_QUIETLY ${_cet_findEigen3_quietly})
  unset(_cet_findEigen3_quietly)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Eigen3
  CONFIG_MODE
  HANDLE_VERSION_RANGE
  REQUIRED_VARS EIGEN3_INCLUDE_DIRS
)

if (Eigen3_FOUND
    AND NOT TARGET Eigen3::Eigen3
    AND EIGEN3_INCLUDE_DIRS)
  add_library(Eigen3::Eigen3 INTERFACE IMPORTED)
  set_target_properties(Eigen3::Eigen3 PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${EIGEN3_INCLUDE_DIRS}"
    INTERFACE_COMPILE_DEFINITIONS "${EIGEN3_DEFINITIONS}"
  )
endif()
