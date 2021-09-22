# Mitigate a possible FFTW3 packaging error if built with autotools
# instead of CMake.

# Attempt to load the normal way without fatal error on failure.
set(_cet_findfftw3_required ${${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED})
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
set(_cet_findfftw3_quietly ${${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY})
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY TRUE)

# Broken builds of FFTW3 install a Config.cmake file, but not the
# corresponding targets file. We take advantage of the fact that we are
# already overriding include() for other purposes to make this include
# optional, and check success by looking for the target(s) that should
# have been defined.
set(CETMODULES_OPTIONAL_INCLUDE_MODULE_FFTW3LibraryDepends TRUE)
find_package(${CMAKE_FIND_PACKAGE_NAME} NO_MODULE)
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY ${_cet_findfftw3_quietly})
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED ${_cet_findfftw3_required})

if (NOT (${CMAKE_FIND_PACKAGE_NAME}_FOUND AND TARGET FFTW3::${CMAKE_FIND_PACKAGE_NAME}))
  unset(${CMAKE_FIND_PACKAGE_NAME}_FOUND)
  unset(${CMAKE_FIND_PACKAGE_NAME}_FOUND CACHE)
  # Alternative attempt to find FFTW3* using pkg-config.
  include(CetFindPkgConfigPackage)
  string(TOLOWER "${CMAKE_FIND_PACKAGE_NAME}" _cet_findfftw3_package_name)
  cet_find_pkg_config_package(NAMESPACE FFTW3 ${_cet_findfftw3_package_name})
  unset(_cet_findfftw3_package_name)
endif()

unset(_cet_findfftw3_quietly)
unset(_cet_findfftw3_required)
