########################################################################
# CetCMakeEnv
#
# Set up a characteristic cetmodules build environment for the current
# package.
#
# Options:
#
#   WANT_UPS
#     Activate the generation of UPS table and version files and Unified
#     UPS-compliant installation tarballs. If you don't know what this is,
#     you don't need it.
#
# Functions:
#
#   cet_cmake_env()
#     Set up the cetmodules build environment. Options:
#
#     ARCH_INCLUDEDIR (WANT_UPS=ON)
#       The include directory will be architecture-specific to avoid
#       issues with multiple builds of the same product being installed
#       with the same prefix. As with all following options also
#       annotated with (WANT_UPS=ON), this currently only affects
#       UPS-aware installations.
#
#     BUILDTYPE <buildtype> (WANT_UPS=ON)
#     NO_BUILDTYPE (WANT_UPS=ON)
#       Specify the build type (usually debug, prof or opt) to be used
#       when generating the UPS table file, installation directories and
#       tarball names. If not specified, it will be inferred from the
#       CMAKE_BUILD_TYPE.
#
#     NO_FLAVOR (WANT_UPS=ON)
#       Used to determine whether the platform is taken into account
#       when generating the UPS table file, installation directories and
#       tarball names or whether NULL or noarch should be used as
#       appropriate. See also the NO_FLAVOR option to cet_cmake_config()
#       in CetCMakeConfig.cmake.
#
#     PAD_{MAJOR,MINOR,PATCH,TWEAK} <ON|OFF|[0-9]+> (WANT_UPS=ON)
#       Used to determine the padding level for version components when
#       converting CMAKE_PROJECT_VERSION into UPS_PRODUCT_VERSION. If ON
#       is specified, the padding is set to 2 (e.g. 7 -> 07). If padding
#       is set >1 for one level, the default padding level for all lower
#       levels is set to 2.
#
#     UPS_PRODUCT_NAME <product_name> (WANT_UPS=ON)
#       Specific the UPS product name. The default is CMAKE_PROJECT_NAME
#       converted to lower case and with hyphens converted to
#       underscores.
#
#     UPS_QUALS <qual>... (WANT_UPS=ON)
#       Specify the list of applicable UPS qualifiers for this build of
#       the product.
#
#     WANT_COMPILER_QUAL (WANT_UPS=ON)
#       If specified, calculate and use the UPS qualifier used to
#       signify the compiler (e.g. e15 for GCC 6.4.0 or c2 for Clang
#       5.0.1).
########################################################################

# Options
option(WANT_UPS "Activate the generation of UPS table and version files and Unified UPS-compliant installation tarballs." OFF)

include(CetProjectVars)

set(_ARCH_DEP_DIRS BINDIR SBINDIR LIBDIR LIBEXECDIR ETC)

macro(cet_cmake_env)
  # project() must have been called before us.
  if(NOT CMAKE_PROJECT_NAME)
    message (FATAL_ERROR
      "CMake project() command must have been invoked prior to cet_cmake_env()."
      "\nIt must be invoked at the top level, not in an included .cmake file.")
  endif()
  cmake_parse_arguments(CCE "ARCH_INCLUDEDIR" "" "" ${ARGN})

  if (CCE_ARCH_INCLUDEDIR)
    list(APPEND _ARCH_DEP_DIRS INCLUDE)
  endif()

  string(TOLOWER ${CMAKE_PROJECT_NAME} ${CMAKE_PROJECT_NAME}_LC)
  if (CCE_UPS_PRODUCT_NAME)
    set(product ${CCE_UPS_PRODUCT_NAME})
  else()
    set(product ${${CMAKE_PROJECT_NAME}_LC})
  endif()

  string(TOUPPER ${CMAKE_PROJECT_NAME} ${CMAKE_PROJECT_NAME}_UC)
  ##message(STATUS "CMAKE_PROJECT_NAME: ${CMAKE_PROJECT_NAME}")
  ##message(STATUS "CMAKE_PROJECT_NAME: ${CMAKE_PROJECT_NAME}")
  ##message(STATUS "PROJECT_SOURCE_DIR: ${PROJECT_SOURCE_DIR}")
  ##message(STATUS "PROJECT_BINARY_DIR: ${PROJECT_BINARY_DIR}")
  
  # Acknowledge new RPATH behavior on OS X.
  cmake_policy(SET CMP0042 NEW)
  if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin" )
    set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
  endif()

  set_install_root()
  enable_testing()

  # If we're dealing with UPS.
  if (WANT_UPS)
    include(Ups)
    set_ups_variables(${CCE_UNPARSED_ARGUMENTS})
    if (CMAKE_INSTALL_PREFIX)
      string(APPEND CMAKE_INSTALL_PREFIX "/${UPS_PRODUCT_SUBDIR}")
      _ups_init_cpack()
    endif()
  endif()

  set(CMAKE_INSTALL_LIBDIR lib) # Don't use lib64.

  # Set up installation directories (must follow UPS clause above)
  include(GNUInstallDirs)

  if (WANT_UPS AND UPS_PRODUCT_FQ)
    foreach(dirtype ${_ARCH_DEP_DIRS})
      string(PREPEND CMAKE_INSTALL_${dirtype} "${UPS_PRODUCT_FQ}/")
    endforeach()
    include(GNUInstallDirs) # Reinitialize.
  endif()

  # Project variables.
  cet_project_var(inc_dir ${CMAKE_INSTALL_INCLUDEDIR}
    MISSING_OK
    DOCSTRING "Directory below prefix to install headers")
  cet_project_var(lib_dir ${CMAKE_INSTALL_LIBDIR}
    MISSING_OK
    DOCSTRING "Directory below prefix to install libraries")
  cet_project_var(bin_dir ${CMAKE_INSTALL_BINDIR}
    MISSING_OK
    DOCSTRING "Directory below prefix to install executables")
  cet_project_var(modules_dir Modules
    MISSING_OK
    DOCSTRING "Directory below prefix to install CMake modules")
  cet_project_var(test_dir test
    MISSING_OK
    DOCSTRING "Directory below prefix to install test scripts")

  # Useful includes.
  include(CetCMakeConfig)
  include(CetCMakeUtils)
  include(CetMake)
  include(InstallFW)
  include(InstallFhicl)
  include(InstallGdml)
  include(InstallHeaders)
  include(InstallLicense)
  include(InstallPerllib)
  include(InstallScripts)
  include(InstallSource)
  include(InstallWP)
  include(SetCompilerFlags)

  # initialize cmake config file fragments
  _cet_init_config_var()

  # add to the include path
  include_directories("${PROJECT_BINARY_DIR}")
  include_directories("${PROJECT_SOURCE_DIR}")
  # make sure all libraries are in one directory
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${${CMAKE_PROJECT_NAME}_lib_dir})
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${${CMAKE_PROJECT_NAME}_lib_dir})
  # make sure all executables are in one directory
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${${CMAKE_PROJECT_NAME}_bin_dir})

  # install license and readme if found
  install_license()
endmacro(cet_cmake_env)

macro(_cet_debug_message)
  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
  if( ${BTYPE_UC} MATCHES "DEBUG" )
    message( STATUS "${ARGN}")
  endif()
endmacro(_cet_debug_message)

macro( set_install_root )
  set( PACKAGE_TOP_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  #message( STATUS "set_install_root: PACKAGE_TOP_DIRECTORY is ${PACKAGE_TOP_DIRECTORY}")
endmacro( set_install_root )

if (NOT WANT_UPS)
  macro(process_ups_files)
    message(FATAL_ERROR "Set the CMake variable WANT_UPS prior to including CetCMakeEnv.cmake to activate UPS table file and tarball generation.")
  endmacro()
endif()
