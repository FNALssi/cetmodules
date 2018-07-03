include(CetProjectVars)

# Project variables.
cet_project_var(inc_dir include
  MISSING_OK
  DOCSTRING "Directory below prefix to install headers")
cet_project_var(lib_dir lib
  MISSING_OK
  DOCSTRING "Directory below prefix to install libraries")
cet_project_var(bin_dir bin
  MISSING_OK
  DOCSTRING "Directory below prefix to install executables")
cet_project_var(modules_dir Modules
  MISSING_OK
  DOCSTRING "Directory below prefix to install CMake modules")
cet_project_var(test_dir test
  MISSING_OK
  DOCSTRING "Directory below prefix to install test scripts")

macro(cet_cmake_env)
  # project() must have been called before us.
  if(NOT CMAKE_PROJECT_NAME)
    message (FATAL_ERROR
      "CMake project() command must have been invoked prior to cet_cmake_env()."
      "\nIt must be invoked at the top level, not in an included .cmake file.")
  endif()
  string(TOLOWER ${CMAKE_PROJECT_NAME} ${CMAKE_PROJECT_NAME}_LC )
  set(product ${${CMAKE_PROJECT_NAME}_LC})
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

  # do not embed full path in shared libraries or executables
  # because the binaries might be relocated
  #  set(CMAKE_SKIP_RPATH)

  #message(STATUS "Product is ${product} ${version} ${${product}_full_qualifier}")
  #message(STATUS "Module path is ${CMAKE_MODULE_PATH}")

  set_install_root()
  enable_testing()

  # Useful includes.
  include(CetCMakeConfig)
  include(CetCMakeUtils)
  include(CetMake)
  include(InstallFw)
  include(InstallFhicl)
  include(InstallHeaders)
  include(InstallLicense)
  include(InstallPerllib)
  include(InstallScripts)
  include(InstallSource)
  include(SetCompilerFlags)

  # initialize cmake config file fragments
  _cet_init_config_var()

  # add to the include path
  include_directories("${PROJECT_BINARY_DIR}")
  include_directories("${PROJECT_SOURCE_DIR}" )
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

macro(process_ups_files)
  message(STATUS "Obsolete function process_ups_files() called.")
endmacro()
