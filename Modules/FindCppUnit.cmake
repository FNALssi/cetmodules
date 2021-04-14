#[================================================================[.rst:
FindCppUnit
-----------
#]================================================================]

include(CetFindPkgConfigPackage)
include(FindPackageHandleStandardArgs)

if ("$ENV{CPPUNIT_FQ_DIR}")
  if(EXISTS "$ENV{CPPUNIT_FQ_DIR}/lib/pkgconfig/cppunit.pc")
    # Older cppunit UPS table files added the wrong directory to PKG_CONFIG_PATH.
    set(ENV{PKG_CONFIG_PATH} "$ENV{CPPUNIT_FQ_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
  endif()
endif()
set(_cet_findcppunit_required ${${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED})
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
set(_cet_findcppunit_quietly ${${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY})
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY TRUE)
cet_find_pkg_config_package(cppunit)
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY TRUE ${_cet_findcppunit_quietly})
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED ${_cet_findcppunit_required})
unset(_cet_findcppunit_required)
if (NOT ${CMAKE_FIND_PACKAGE_NAME}_FOUND)
  # Some even older cppunit UPS table files didn't install working
  # pkgconfig files at all.
  if (DEFINED ENV{CPPUNIT_INC} AND DEFINED ENV{CPPUNIT_LIB})
    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)
    set(${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR $ENV{CPPUNIT_INC})
    set(${CMAKE_FIND_PACKAGE_NAME}_LIBRARY "$ENV{CPPUNIT_LIB}/libccpunit.so")
    string(REGEX REPLACE "^v(.*)$" "\\1" ${CMAKE_FIND_PACKAGE_NAME}_VERSION
      "$ENV{CPPUNIT_VERSION}")
    string(REPLACE "_" "." ${CMAKE_FIND_PACKAGE_NAME}_VERSION
      "${${CMAKE_FIND_PACKAGE_NAME}_VERSION}")
    if (NOT TARGET ${CMAKE_FIND_PACKAGE_NAME}::${CMAKE_FIND_PACKAGE_NAME})
      add_library(${CMAKE_FIND_PACKAGE_NAME}::${CMAKE_FIND_PACKAGE_NAME} SHARED IMPORTED)
      set_target_properties(${CMAKE_FIND_PACKAGE_NAME}::${CMAKE_FIND_PACKAGE_NAME}
        PROPERTIES
        IMPORTED_INTERFACE_INCLUDE_DIRECTORIES "${${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR}"
        IMPORTED_LOCATION "${${CMAKE_FIND_PACKAGE_NAME}_LIBRARY}"
        )
    endif()
    set(CPPUNIT ${CMAKE_FIND_PACKAGE_NAME}::${CMAKE_FIND_PACKAGE_NAME})
  endif()
  find_package_handle_standard_args(${CMAKE_FIND_PACKAGE_NAME}
    VERSION_VAR ${CMAKE_FIND_PACKAGE_NAME}_VERSION
    REQUIRED_VARS CPPUNIT
    ${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR
    ${CMAKE_FIND_PACKAGE_NAME}_LIBRARY
    )
endif()
