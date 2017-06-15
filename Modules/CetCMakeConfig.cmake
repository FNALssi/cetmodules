# create the cmake configure files for this package
#
# cet_cmake_config( [NO_FLAVOR] )
#   build and install PackageConfig.cmake and PackageConfigVersion.cmake
#   these files are installed in ${flavorqual_dir}/lib/PACKAGE/cmake
#   if NO_FLAVOR is specified, the files are installed under ${product}/${version}/include

# this requires cmake 2.8.8 or later
include(CMakePackageConfigHelpers)

include(CetParseArgs)

function(_config_package_config_file)
  # Set variables (scope within this function only) with simpler names
  # for use inside package config files as e.g. @PACKAGE_bin_dir@
  foreach(path_type bin lib inc fcl gdml)
    set(${path_type}_dir ${${product}_${path_type}_dir})
  endforeach()
  configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/product-config.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/${product}Config.cmake
	  INSTALL_DESTINATION ${distdir}
    # Use known list of path vars for installation locations so these
    # can be found relative to the location of the productConfig.cmake
    # file
    PATH_VARS
    bin_dir
    lib_dir
    inc_dir
    fcl_dir
    gdml_dir
    )
endfunction()

macro( cet_write_version_file _filename )

  cet_parse_args( CWV "VERSION;COMPATIBILITY" "" ${ARGN})

  find_file( versionTemplateFile
             NAMES CetBasicConfigVersion-${CWV_COMPATIBILITY}.cmake.in
             PATHS ${CMAKE_MODULE_PATH} )
  if(NOT EXISTS "${versionTemplateFile}")
    message(FATAL_ERROR "Bad COMPATIBILITY value used for cet_write_version_file(): \"${CWV_COMPATIBILITY}\"")
  endif()

  if("${CWV_VERSION}" STREQUAL "")
    message(FATAL_ERROR "No VERSION specified for cet_write_version_file()")
  endif()

  configure_file("${versionTemplateFile}" "${_filename}" @ONLY)
endmacro( cet_write_version_file )

macro( cet_cmake_config  )

  cet_parse_args( CCC "" "NO_FLAVOR" ${ARGN})

  if( CCC_NO_FLAVOR )
    set( distdir "${product}/${version}/cmake" )
  else()
    set( distdir "${flavorqual_dir}/lib/${product}/cmake" )
  endif()

  #message(STATUS "cet_cmake_config debug: will install cmake configure files in ${distdir}")
  #message(STATUS "cet_cmake_config debug: ${CONFIG_FIND_UPS_COMMANDS}")
  #message(STATUS "cet_cmake_config debug: ${CONFIG_FIND_LIBRARY_COMMANDS}")
  #message(STATUS "cet_cmake_config debug: ${CONFIG_LIBRARY_LIST}")

  string(TOUPPER  ${product} ${product}_UC )
  # add to library list for package configure file
  foreach( my_library ${CONFIG_LIBRARY_LIST} )
    string(TOUPPER  ${my_library} ${my_library}_UC )
    string(TOUPPER  ${product} ${product}_UC )
    set(CONFIG_FIND_LIBRARY_COMMANDS "${CONFIG_FIND_LIBRARY_COMMANDS}
      set( ${${my_library}_UC}  \$ENV{${${product}_UC}_LIB}/lib${my_library}${CMAKE_SHARED_LIBRARY_SUFFIX} )" )
    #cet_find_library( ${${my_library}_UC} NAMES ${my_library} PATHS ENV ${${product}_UC}_LIB NO_DEFAULT_PATH )" )
    ##message(STATUS "cet_cmake_config: cet_find_library( ${${my_library}_UC} NAMES ${my_library} PATHS ENV ${${product}_UC}_LIB NO_DEFAULT_PATH )" )
    ##message(STATUS "cet_cmake_config: set( ${${my_library}_UC}  \$ENV{${${product}_UC}_LIB}/lib${my_library}${CMAKE_SHARED_LIBRARY_SUFFIX} )" )
  endforeach(my_library)
  #message(STATUS "cet_cmake_config debug: ${CONFIG_FIND_LIBRARY_COMMANDS}")

  # add include path to CONFIG_FIND_LIBRARY_COMMANDS
  ##message(STATUS "cet_cmake_config: ${product}_inc_dir is ${${product}_inc_dir}")
  if( NOT ${${product}_inc_dir} MATCHES "NONE" )
    set(CONFIG_FIND_LIBRARY_COMMANDS "${CONFIG_FIND_LIBRARY_COMMANDS}
      include_directories ( \$ENV{${${product}_UC}_INC} )" )
  endif()
  ##message(STATUS "cet_cmake_config: CONFIG_INCLUDE_DIRECTORY is ${CONFIG_INCLUDE_DIRECTORY}")

  # get perl library directory
  #message( STATUS "config_pm: ${product}_perllib is ${${product}_perllib}")
  #message( STATUS "config_pm: ${product}_ups_perllib is ${${product}_ups_perllib}")
  #message( STATUS "config_pm: ${product}_perllib_subdir is ${${product}_perllib_subdir}")
  STRING( REGEX REPLACE "flavorqual_dir" "\$ENV{${${product}_UC}_FQ_DIR}" mypmdir "${REPORT_PERLLIB_MSG}" )
  #message( STATUS "config_pm: mypmdir ${mypmdir}")
  STRING( REGEX REPLACE "product_dir" "\$ENV{${${product}_UC}_DIR}" mypmdir "${REPORT_PERLLIB_MSG}" )
  #message( STATUS "config_pm: mypmdir ${mypmdir}")
  # PluginVersionInfo is a special case
  if( CONFIG_PM_VERSION )
    message(STATUS "CONFIG_PM_VERSION is ${CONFIG_PM_VERSION}" )
    string(REGEX REPLACE "\\." "_" my_pm_ver "${CONFIG_PM_VERSION}" )
    string(TOUPPER  ${my_pm_ver} PluginVersionInfo_UC )
    set(CONFIG_FIND_LIBRARY_COMMANDS "${CONFIG_FIND_LIBRARY_COMMANDS}
      set( ${${product}_UC}_${PluginVersionInfo_UC} ${mypmdir}/CetSkelPlugins/${product}/${CONFIG_PM_VERSION} )" )
    message(STATUS "${${product}_UC}_${PluginVersionInfo_UC} ${mypmdir}/CetSkelPlugins/${product}/${CONFIG_PM_VERSION} " )
  endif()
  # add to pm list for package configure file
  foreach( my_pm ${CONFIG_PERL_PLUGIN_LIST} )
    #message( STATUS "config_pm: my_pm ${my_pm}")
    get_filename_component( my_pm_name ${my_pm} NAME )
    string(REGEX REPLACE "\\." "_" my_pm_dash "${my_pm_name}" )
    #message( STATUS "config_pm: my_pm_dash ${my_pm_dash}")
    string(TOUPPER  ${my_pm_dash} ${my_pm_name}_UC )
    set(CONFIG_FIND_LIBRARY_COMMANDS "${CONFIG_FIND_LIBRARY_COMMANDS}
      set( ${${my_pm_name}_UC} ${mypmdir}${my_pm} )" )
    message(STATUS "${${my_pm_name}_UC}  ${mypmdir}${my_pm} " )
  endforeach(my_pm)
  foreach( my_pm ${CONFIG_PM_LIST} )
    #message( STATUS "config_pm: my_pm ${my_pm}")
    get_filename_component( my_pm_name ${my_pm} NAME )
    string(REGEX REPLACE "\\." "_" my_pm_dash "${my_pm}" )
    #message( STATUS "config_pm: my_pm_dash ${my_pm_dash}")
    string(REGEX REPLACE "/" "_" my_pm_slash "${my_pm_dash}" )
    #message( STATUS "config_pm: my_pm_slash ${my_pm_slash}")
    string(TOUPPER  ${my_pm_slash} ${my_pm_name}_UC )
    set(CONFIG_FIND_LIBRARY_COMMANDS "${CONFIG_FIND_LIBRARY_COMMANDS}
      set( ${${product}_UC}${${my_pm_name}_UC} ${mypmdir}${my_pm} )" )
    message(STATUS "${${product}_UC}${${my_pm_name}_UC}  ${mypmdir}${my_pm} " )
  endforeach(my_pm)

  _config_package_config_file()

  # allowed COMPATIBILITY values are:
  # AnyNewerVersion ExactVersion SameMajorVersion
  if( CCC_NO_FLAVOR )
    cet_write_version_file(
               ${CMAKE_CURRENT_BINARY_DIR}/${product}ConfigVersion.cmake
	       VERSION ${cet_dot_version}
	       COMPATIBILITY AnyNewerVersion )
  else()
    write_basic_package_version_file(
               ${CMAKE_CURRENT_BINARY_DIR}/${product}ConfigVersion.cmake
	       VERSION ${cet_dot_version}
	       COMPATIBILITY AnyNewerVersion )
  endif()

  install( FILES ${CMAKE_CURRENT_BINARY_DIR}/${product}Config.cmake
        	 ${CMAKE_CURRENT_BINARY_DIR}/${product}ConfigVersion.cmake
           DESTINATION ${distdir} )

endmacro( cet_cmake_config )
