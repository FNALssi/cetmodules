##
message(STATUS "cetmods_BINDIR = ${cetmods_BINDIR}")

include(CetGetProductInfo)

# Verify that the compiler is set as desired, and is consistent with our
# current known use of qualifiers.

function(_verify_cc COMPILER)
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

function(_study_compiler CTYPE)
  # CTYPE = CC, CXX or FC
  if (NOT CTYPE STREQUAL "CC" AND
      NOT CTYPE STREQUAL "CXX" AND
      NOT CTYPE STREQUAL "FC")
    message(FATAL_ERROR "INTERNAL ERROR: unrecognized CTYPE ${CTYPE} to _study_compiler")
  endif()
  cet_get_product_info_item(${CTYPE} rcompiler ec_compiler)
  if (NOT rcompiler)
    message(FATAL_ERROR "Unable to obtain compiler suite setting: re-source setup_for_development?")
  endif()
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

  message(STATUS "Product is ${product} ${version} ${${product}_full_qualifier}")
  message(STATUS "Module path is ${CMAKE_MODULE_PATH}")

  # Useful includes.
  include(FindUpsPackage)
  include(SetCompilerFlags)
  include(InstallLicense)
  include(InstallHeaders)
  include(InstallSource)
  #include(InstallFiles)
  #include(InstallPerllib)
  include(CetCMakeUtils)

  # install license and readme if found
  install_license()

  # initialize cmake config file fragments
  _cet_init_config_var()

  # Make sure compiler is set as the configuration requires.
  if( "${arch}" MATCHES "noarch" )
  message(STATUS "${product} is null flavored")
  else()
  _verify_compiler_quals()
  endif()

  # install directories 
  set( ${product}_bin_dir bin CACHE STRING "Package bin directory" FORCE )
  set( ${product}_inc_dir include CACHE STRING "Package include directory" FORCE )
  set( ${product}_lib_dir lib CACHE STRING "Package lib directory" FORCE )

endmacro(cet_cmake_env)
