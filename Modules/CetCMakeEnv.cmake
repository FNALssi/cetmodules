##
##message(STATUS "cetmodules_BINDIR = ${cetmodules_BINDIR}")

macro(cet_cmake_env)

  # project() must have been called before us.
  if(NOT CMAKE_PROJECT_NAME)
    message (FATAL_ERROR
      "CMake project() command must have been invoked prior to cet_cmake_env()."
      "\nIt must be invoked at the top level, not in an included .cmake file.")
  endif()
  string(TOLOWER  ${PROJECT_NAME} ${PRODUCTNAME}_LC )
  set( product ${${PRODUCTNAME}_LC} )
  ##message(STATUS "CMAKE_PROJECT_NAME: ${CMAKE_PROJECT_NAME}")
  ##message(STATUS "PROJECT_NAME: ${PROJECT_NAME}")
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
  include(FindUpsPackage)
  include(FindUpsBoost)
  include(FindUpsRoot)
  include(SetCompilerFlags)
  include(InstallSource)
  include(InstallFhicl)
  include(InstallLicense)
  include(InstallHeaders)
  include(InstallPerllib)
  include(CetCMakeUtils)
  include(CetMake)
  include(CetCMakeConfig)
  include(ProcessUpsFiles)

  # initialize cmake config file fragments
  _cet_init_config_var()

  # we use ups/product_deps
  set( cet_ups_dir ${CMAKE_CURRENT_SOURCE_DIR}/ups CACHE STRING "Package UPS directory" FORCE )
  # find $CETMODULES_DIR/bin/cet_report
  set(CET_REPORT ${cetmodules_BINDIR}/cet_report)
  #message(STATUS "CET_REPORT: ${CET_REPORT}")
  # some definitions
  cet_set_lib_directory()
  cet_set_bin_directory()
  cet_set_inc_directory()
  cet_set_fcl_directory()
  cet_set_fw_directory()
  cet_set_gdml_directory()
  cet_set_perllib_directory()
  cet_set_test_directory()

  # install directories 
  set( ${product}_bin_dir bin CACHE STRING "Package bin directory" FORCE )
  set( ${product}_inc_dir include CACHE STRING "Package include directory" FORCE )
  set( ${product}_lib_dir lib CACHE STRING "Package lib directory" FORCE )
  ##message( STATUS "cet_cmake_env debug: ${product}_bin_dir ${${product}_bin_dir}")
  ##message( STATUS "cet_cmake_env debug: ${product}_lib_dir ${${product}_lib_dir}")

  # add to the include path
  include_directories ("${PROJECT_BINARY_DIR}")
  include_directories("${PROJECT_SOURCE_DIR}" )
  # make sure all libraries are in one directory
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
  # make sure all executables are in one directory
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
  # install license and readme if found
  install_license()

endmacro(cet_cmake_env)


macro( cet_set_lib_directory )
  set( ${product}_lib_dir lib CACHE STRING "Package lib directory" FORCE )
  #message( STATUS "cet_set_lib_directory: ${product}_lib_dir is ${${product}_lib_dir}")
endmacro( cet_set_lib_directory )

macro( cet_set_bin_directory )
  set( ${product}_bin_dir bin CACHE STRING "Package bin directory" FORCE )
  #message( STATUS "cet_set_bin_directory: ${product}_bin_dir is ${${product}_bin_dir}")
endmacro( cet_set_bin_directory )

macro( cet_set_fcl_directory )
  set( ${product}_fcl_dir fcl CACHE STRING "Package fcl directory" FORCE )
  #message( STATUS "cet_set_fcl_directory: ${product}_fcl_dir is ${${product}_fcl_dir}")
endmacro( cet_set_fcl_directory )

macro( cet_set_fw_directory )
  execute_process(COMMAND ${CET_REPORT} fwdir ${cet_ups_dir}
    OUTPUT_VARIABLE REPORT_FW_DIR_MSG
		OUTPUT_STRIP_TRAILING_WHITESPACE
		)
  #message( STATUS "${CET_REPORT} fwdir returned ${REPORT_FW_DIR_MSG}")
   if( ${REPORT_FW_DIR_MSG} MATCHES "DEFAULT" )
     set( ${product}_fw_dir "NONE" CACHE STRING "Package fw directory" FORCE )
  elseif( ${REPORT_FW_DIR_MSG} MATCHES "NONE" )
     set( ${product}_fw_dir ${REPORT_FW_DIR_MSG} CACHE STRING "Package fw directory" FORCE )
  elseif( ${REPORT_FW_DIR_MSG} MATCHES "ERROR" )
     set( ${product}_fw_dir ${REPORT_FW_DIR_MSG} CACHE STRING "Package fw directory" FORCE )
  else()
    STRING( REGEX REPLACE "flavorqual_dir" "${flavorqual_dir}" fdir1 "${REPORT_FW_DIR_MSG}" )
    STRING( REGEX REPLACE "product_dir" "${product}/${version}" fdir2 "${fdir1}" )
    set( ${product}_fw_dir ${fdir2}  CACHE STRING "Package fw directory" FORCE )
  endif()
  #message( STATUS "cet_set_fw_directory: ${product}_fw_dir is ${${product}_fw_dir}")
endmacro( cet_set_fw_directory )

macro( cet_set_gdml_directory )
  execute_process(COMMAND ${CET_REPORT} gdmldir ${cet_ups_dir}
    OUTPUT_VARIABLE REPORT_GDML_DIR_MSG
		OUTPUT_STRIP_TRAILING_WHITESPACE
		)
  #message( STATUS "${CET_REPORT} gdmldir returned ${REPORT_GDML_DIR_MSG}")
  if( ${REPORT_GDML_DIR_MSG} MATCHES "DEFAULT" )
     set( ${product}_gdml_dir "NONE" CACHE STRING "Package gdml directory" FORCE )
  elseif( ${REPORT_GDML_DIR_MSG} MATCHES "NONE" )
     set( ${product}_gdml_dir ${REPORT_GDML_DIR_MSG} CACHE STRING "Package gdml directory" FORCE )
  elseif( ${REPORT_GDML_DIR_MSG} MATCHES "ERROR" )
     set( ${product}_gdml_dir ${REPORT_GDML_DIR_MSG} CACHE STRING "Package gdml directory" FORCE )
  else()
    STRING( REGEX REPLACE "flavorqual_dir" "${flavorqual_dir}" fdir1 "${REPORT_GDML_DIR_MSG}" )
    STRING( REGEX REPLACE "product_dir" "${product}/${version}" fdir2 "${fdir1}" )
    set( ${product}_gdml_dir ${fdir2}  CACHE STRING "Package gdml directory" FORCE )
  endif()
  #message( STATUS "cet_set_gdml_directory: ${product}_gdml_dir is ${${product}_gdml_dir}")
endmacro( cet_set_gdml_directory )

macro( cet_set_perllib_directory )
  set( ${product}_perllib "" CACHE STRING "Package perllib directory" FORCE )
  #message( STATUS "cet_set_perllib_directory: ${product}_perllib is ${${product}_perllib}")
  #message( STATUS "cet_set_perllib_directory: ${product}_perllib_subdir is ${${product}_perllib_subdir}")
endmacro( cet_set_perllib_directory )

macro( cet_set_inc_directory )
  set( ${product}_inc_dir "include" CACHE STRING "Package include directory" FORCE )
  #message( STATUS "cet_set_inc_directory: ${product}_inc_dir is ${${product}_inc_dir}")
endmacro( cet_set_inc_directory )

macro( cet_set_test_directory )
  # The default is product_dir/test
  set( ${product}_test_dir test CACHE STRING "Package test directory" FORCE )
  #message( STATUS "cet_set_test_directory: ${product}_test_dir is ${${product}_test_dir}")
endmacro( cet_set_test_directory )

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
