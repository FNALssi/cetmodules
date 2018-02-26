##
##message(STATUS "cetmodules_BINDIR = ${cetmodules_BINDIR}")

include(CetGetProductInfo)

# Verify that the compiler is set as desired, and is consistent with our
# current known use of qualifiers.

##function(_verify_cc COMPILER)
function(_verify_cc )
  # no-op for now
  return()
  if(NOT CMAKE_C_COMPILER) # Languages disabled.
    return()
  endif()
  if(COMPILER STREQUAL "cc")
    set(compiler_ref "^/usr/bin/cc$")
  elseif(COMPILER MATCHES "^(gcc.*)$")
    cet_regex_escape("$ENV{GCC_FQ_DIR}/bin/${CMAKE_MATCH_0}" escaped_path)
    set(compiler_ref "^${escaped_path}$")
  elseif(COMPILER STREQUAL icc)
    cet_regex_escape("$ENV{ICC_FQ_DIR}/bin/intel64/${COMPILER}" escaped_path)
    set(compiler_ref "^${escaped_path}$")
  #elseif(COMPILER STREQUAL clang)
  #  message(FATAL_ERROR "Clang not yet supported.")
  elseif(COMPILER MATCHES "^(clang.*)$")
    cet_regex_escape("$ENV{APPLE_CLANG_FQ_DIR}/bin/${CMAKE_MATCH_0}" escaped_path)
    set(compiler_ref "^${escaped_path}$")
  elseif(COMPILER MATCHES "[-_]gcc\\$")
    message(FATAL_ERROR "Cross-compiling not yet supported")
  else()
    message(FATAL_ERROR "Unrecognized C compiler \"${COMPILER}\": use cc, gcc(-XXX)?, icc, or clang.")
  endif()
  get_filename_component(cr_dir "${compiler_ref}" DIRECTORY)
  _cet_real_dir("${cr_dir}" cr_dir)
  get_filename_component(cr_name "${compiler_ref}" NAME)
  set(compiler_ref "${cr_dir}/${cr_name}")
  if(NOT (CMAKE_C_COMPILER MATCHES "${compiler_ref}"))
    message(FATAL_ERROR "CMAKE_C_COMPILER set to ${CMAKE_C_COMPILER}: expected match to \"${compiler_ref}\".\n"
      "Use buildtool or preface cmake invocation with \"env CC=${CETPKG_CC}.\" Use buildtool -c if changing qualifier.")
  endif()
endfunction()

##function(_verify_cxx COMPILER)
function(_verify_cxx )
  # no-op for now
  return()
  if(NOT CMAKE_CXX_COMPILER) # Languages disabled.
    return()
  endif()
  if(COMPILER STREQUAL "c++")
    set(compiler_ref "^/usr/bin/c\\+\\+$")
  elseif(COMPILER MATCHES "^(g\\+\\+.*)$")
    cet_regex_escape("$ENV{GCC_FQ_DIR}/bin/${CMAKE_MATCH_0}" escaped_path)
    set(compiler_ref "^${escaped_path}$")
  elseif(COMPILER STREQUAL icpc)
    set(compiler_ref "$ENV{ICC_FQ_DIR}/bin/intel64/${COMPILER}")
  ##elseif(COMPILER STREQUAL clang++)
  ##  message(FATAL_ERROR "Clang not yet supported.")
  elseif(COMPILER MATCHES "^(clang\\+\\+.*)$")
    cet_regex_escape("$ENV{APPLE_CLANG_FQ_DIR}/bin/${CMAKE_MATCH_0}" escaped_path)
    set(compiler_ref "^${escaped_path}$")
  elseif(COMPILER MATCHES "[-_]g\\+\\+$")
    message(FATAL_ERROR "Cross-compiling not yet supported")
  else()
    message(FATAL_ERROR "Unrecognized C++ compiler \"${COMPILER}\": use c++, g++(-XXX)?, icpc, or clang++.")
  endif()
  get_filename_component(cr_dir "${compiler_ref}" DIRECTORY)
  _cet_real_dir("${cr_dir}" cr_dir)
  get_filename_component(cr_name "${compiler_ref}" NAME)
  set(compiler_ref "${cr_dir}/${cr_name}")
  if(NOT (CMAKE_CXX_COMPILER MATCHES "${compiler_ref}"))
    message(FATAL_ERROR "CMAKE_CXX_COMPILER set to ${CMAKE_CXX_COMPILER}: expected match to \"${compiler_ref}\".\n"
      "Use buildtool or preface cmake invocation with \"env CXX=${CETPKG_CXX}.\" Use buildtool -c if changing qualifier.")
  endif()
endfunction()

##function(_verify_fc COMPILER)
function(_verify_fc )
  # no-op for now
  return()
  if(NOT CMAKE_Fortran_COMPILER) # Languages disabled.
    return()
  endif()
  if(COMPILER MATCHES "^(gfortran.*)$")
    cet_regex_escape("$ENV{GCC_FQ_DIR}/bin/${CMAKE_MATCH_0}" escaped_path)
    set(compiler_ref "^${escaped_path}$")
  elseif(COMPILER STREQUAL ifort)
    set(compiler_ref "$ENV{ICC_FQ_DIR}/bin/intel64/${COMPILER}")
  elseif(COMPILER STREQUAL clang)
    message(FATAL_ERROR "Clang not yet supported.")
  elseif(COMPILER MATCHES "[-_]gfortran$")
    message(FATAL_ERROR "Cross-compiling not yet supported")
  else()
    message(FATAL_ERROR "Unrecognized Fortran compiler \"${COMPILER}\": use , gfortran(-XXX)? or ifort.")
  endif()
  get_filename_component(cr_dir "${compiler_ref}" DIRECTORY)
  _cet_real_dir("${cr_dir}" cr_dir)
  get_filename_component(cr_name "${compiler_ref}" NAME)
  set(compiler_ref "${cr_dir}/${cr_name}")
  if(NOT (CMAKE_Fortran_COMPILER MATCHES "${compiler_ref}"))
    message(FATAL_ERROR "CMAKE_Fortran_COMPILER set to ${CMAKE_Fortran_COMPILER}: expected match to \"${compiler_ref}\".\n"
      "Use buildtool or preface cmake invocation with \"env FC=${CETPKG_FC}.\" Use buildtool -c if changing qualifier.")
  endif()
endfunction()

function(_study_compiler CTYPE)
  # CTYPE = CC, CXX or FC
  if (NOT CTYPE STREQUAL "CC" AND
      NOT CTYPE STREQUAL "CXX" AND
      NOT CTYPE STREQUAL "FC")
    message(FATAL_ERROR "INTERNAL ERROR: unrecognized CTYPE ${CTYPE} to _study_compiler")
  endif()
  ##cet_get_product_info_item(${CTYPE} rcompiler ec_compiler)
  ##if (NOT rcompiler)
  ##  message(FATAL_ERROR "Unable to obtain compiler suite setting: re-source setup_for_development?")
  ##endif()
  if (CTYPE STREQUAL "CC")
    _verify_cc(${rcompiler})
  elseif(CTYPE STREQUAL "CXX")
    _verify_cxx(${rcompiler})
  elseif(CTYPE STREQUAL "FC")
    _verify_fc(${rcompiler})
  else()
    message(FATAL_ERROR "INTERNAL ERROR: case missing for CTYPE ${CTYPE} in _study_compiler")
  endif()
endfunction()

function(_verify_compiler_quals)
  _study_compiler(CC)
  _study_compiler(FC)
  _study_compiler(CXX)
endfunction()

macro(cet_cmake_env)

  # project() must have been called before us.
  if(NOT PROJECT_NAME)
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
  
  # temporarily set this policy
  # silently ignore non-existent dependencies
  cmake_policy(SET CMP0046 OLD)

  # Silently ignore the lack of an RPATH setting on OS X.
  cmake_policy(SET CMP0042 OLD)

  # do not embed full path in shared libraries or executables
  # because the binaries might be relocated
  set(CMAKE_SKIP_RPATH)

  #message(STATUS "Product is ${product} ${version} ${${product}_full_qualifier}")
  #message(STATUS "Module path is ${CMAKE_MODULE_PATH}")

  set_install_root()

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

  # Make sure compiler is set as the configuration requires.
  if( "${arch}" MATCHES "noarch" )
  message(STATUS "${product} is null flavored")
  else()
  _verify_compiler_quals()
  endif()

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
  set(LIBRARY_OUTPUT_PATH    ${PROJECT_BINARY_DIR}/lib)
  # make sure all executables are in one directory
  set(EXECUTABLE_OUTPUT_PATH ${PROJECT_BINARY_DIR}/bin)
  # install license and readme if found
  install_license()

  # Update the documentation string of CMAKE_BUILD_TYPE for GUIs
  SET( CMAKE_BUILD_TYPE "${CMAKE_BUILD_TYPE}" CACHE STRING
    "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel Opt Prof."
    FORCE )
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE MinSizeRel CACHE STRING "" FORCE)
  endif()
  #message(STATUS "cet_cmake_env debug: CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}" )

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
  if( ${CMAKE_BUILD_TYPE} )
  string(TOUPPER ${CMAKE_BUILD_TYPE} BTYPE_UC )
    if( ${BTYPE_UC} MATCHES "DEBUG" )
      message( STATUS "${ARGN}")
    endif()
  endif( ${CMAKE_BUILD_TYPE} )
endmacro(_cet_debug_message)

macro( set_install_root )
  set( PACKAGE_TOP_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  #message( STATUS "set_install_root: PACKAGE_TOP_DIRECTORY is ${PACKAGE_TOP_DIRECTORY}")
endmacro( set_install_root )
