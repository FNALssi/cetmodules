########################################################################
# cet_cmake_config([NO_FLAVOR] [CONFIG_FRAGMENTS <config-fragment>...])
#
# Build and install PackageConfig.cmake and PackageConfigVersion.cmake.
#
# These files are installed in lib/${CMAKE_PROJECT_NAME}/cmake unless
# NO_FLAVOR is specified, in which case the files are installed in the
# top directory.
#
# If CONFIG_FRAGMENTS is given, the specified fragments are incorporated
# into the CMakeConfig.cmake file, and @-variables are expanded with
# their values at the time.
########################################################################

# this requires cmake 2.8.8 or later
include(CMakePackageConfigHelpers)

include(CetParseArgs)

function(_config_package_config_file)
  string(REPLACE ";" "\n"
    CONFIG_FIND_LIBRARY_COMMANDS
    "${CONFIG_FIND_LIBRARY_COMMAND_LIST}")
  string(REPLACE ";" "\n"
    PROJECT_VARIABLE_DEFINITIONS
    "${${CMAKE_PROJECT_NAME}_DEFINITIONS_LIST}")
  # Set path variables (scope within this function only) with names for
  # use inside package config files as e.g. @PACKAGE_bin_dir@ (converted
  # to absolute paths in the installation area by
  # configure_package_config_file).
  set(path_vars)
  foreach(project_var ${${CMAKE_PROJECT_NAME}_VARS})
    get_property(var_type CACHE ${CMAKE_PROJECT_NAME}_${project_var} PROPERTY TYPE)
    if (${CMAKE_PROJECT_NAME}_${project_var} AND
        (var_type STREQUAL PATH OR var_type STREQUAL FILEPATH))
      set(${project_var} "${${CMAKE_PROJECT_NAME}_${project_var}}")
      list(APPEND path_vars ${project_var})
    endif()
  endforeach()
  # Top of CMakeConfig.cmake.in file.
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}Config.cmake.in"
    "@PACKAGE_INIT@\n\n${PROJECT_VARIABLE_DEFINITIONS}\n\n"
    )
  # Middle.
  file(READ "${cetmodules_config_dir}/product-config.cmake.in.middle" FILE_IN)
  file(APPEND
    "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}Config.cmake.in"
    "${FILE_IN}"
    )
  # Package-specific extra sections.
  foreach (frag ${ARGN})
    get_filename_component(config_fragment "${frag}" ABSOLUTE)
    get_filename_component(frag_name "${frag}" NAME)
    if (EXISTS "${config_fragment}")
      file(READ "${config_fragment}" FILE_IN)
      file(APPEND
        "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}Config.cmake.in"
        "########################################################################\n# ${frag_name}\n${FILE_IN}########################################################################\n\n"
        )
    else()
      set(msg "cet_cmake_config() could not find specified fragment ${config_fragment}")
      if (NOT frag STREQUAL config_fragment)
        set(msg "${msg} -- need absolute path rather than relative to \${CMAKE_CURRENT_SOURCE_DIR}?")
      endif()
      message(FATAL_ERROR ${msg})
    endif()
  endforeach()
  # Bottom.
  file(READ "${cetmodules_config_dir}/product-config.cmake.in.bottom" FILE_IN)
  file(APPEND
    "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}Config.cmake.in"
    "${FILE_IN}"
    )
  # Configure the CMakeConfig.cmake file.
  configure_package_config_file(
    ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}Config.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}Config.cmake
	  INSTALL_DESTINATION ${distdir}
    PATH_VARS ${path_vars}
    )
endfunction()

macro( cet_cmake_config  )

  cmake_parse_arguments( CCC "NO_FLAVOR" "" "CONFIG_FRAGMENTS" ${ARGN})

  if( CCC_NO_FLAVOR )
    set( distdir "." )
  else()
    set( distdir "lib/${CMAKE_PROJECT_NAME}/cmake" )
  endif()

  #message(STATUS "cet_cmake_config debug: will install cmake configure files in ${distdir}")
  #message(STATUS "cet_cmake_config debug: ${CONFIG_FIND_LIBRARY_COMMAND_LIST}")
  #message(STATUS "cet_cmake_config debug: ${CONFIG_LIBRARY_LIST}")

  string(TOUPPER  ${CMAKE_PROJECT_NAME} ${CMAKE_PROJECT_NAME}_UC )
  # add to library list for package configure file
  foreach( my_library ${CONFIG_LIBRARY_LIST} )
    string(TOUPPER  ${my_library} ${my_library}_UC )
    string(TOUPPER  ${CMAKE_PROJECT_NAME} ${CMAKE_PROJECT_NAME}_UC )
    get_target_property(lib_type ${my_library} TYPE)
    get_target_property(lib_basename ${my_library} LIBRARY_OUTPUT_NAME)
    if (NOT lib_basename)
      get_target_property(prefix ${my_library} PREFIX)
      get_target_property(suffix ${my_library} SUFFIX)
      if (lib_type STREQUAL "STATIC_LIBRARY")
        if (prefix STREQUAL "prefix-NOTFOUND")
          set(prefix ${CMAKE_STATIC_LIBRARY_PREFIX})
        endif()
        if (suffix STREQUAL "suffix-NOTFOUND")
          set(suffix ${CMAKE_STATIC_LIBRARY_SUFFIX})
        endif()
      elseif(lib_type STREQUAL "SHARED_LIBRARY")
        if (prefix STREQUAL "prefix-NOTFOUND")
          set(prefix ${CMAKE_SHARED_LIBRARY_PREFIX})
        endif()
        if (suffix STREQUAL "suffix-NOTFOUND")
          set(suffix ${CMAKE_SHARED_LIBRARY_SUFFIX})
        endif()
      else()
        message(FATAL_ERROR "cet_make_config(): Unrecognized lib_type ${lib_type} for target ${my_library}")
      endif()
      set(lib_basename ${prefix}${my_library}${suffix})
    endif()
    list(APPEND CONFIG_FIND_LIBRARY_COMMAND_LIST
      "set_and_check(${${my_library}_UC} \"\${${CMAKE_PROJECT_NAME}_lib_dir}/${lib_basename}\")"
      )
  endforeach(my_library)
  #message(STATUS "cet_cmake_config debug: ${CONFIG_FIND_LIBRARY_COMMAND_LIST}")

  # get perl library directory
  # PluginVersionInfo is a special case
  if( CONFIG_PM_VERSION )
    #message(STATUS "CONFIG_PM_VERSION is ${CONFIG_PM_VERSION}" )
    string(REGEX REPLACE "\\." "_" my_pm_ver "${CONFIG_PM_VERSION}" )
    string(TOUPPER  ${my_pm_ver} PluginVersionInfo_UC )
    list(APPEND CONFIG_FIND_LIBRARY_COMMAND_LIST
      "set( ${${CMAKE_PROJECT_NAME}_UC}_${PluginVersionInfo_UC} @PACKAGE_perllib_dir@/CetSkelPlugins/${CMAKE_PROJECT_NAME}/${CONFIG_PM_VERSION} )" )
    #message(STATUS "${${CMAKE_PROJECT_NAME}_UC}_${PluginVersionInfo_UC} @PACKAGE_perllib_dir@//CetSkelPlugins/${CMAKE_PROJECT_NAME}/${CONFIG_PM_VERSION} " )
  endif()
  # add to pm list for package configure file
  foreach( my_pm ${CONFIG_PERL_PLUGIN_LIST} )
    #message( STATUS "config_pm: my_pm ${my_pm}")
    get_filename_component( my_pm_name ${my_pm} NAME )
    string(REGEX REPLACE "\\." "_" my_pm_dash "${my_pm_name}" )
    #message( STATUS "config_pm: my_pm_dash ${my_pm_dash}")
    string(TOUPPER  ${my_pm_dash} ${my_pm_name}_UC )
    list(APPEND CONFIG_FIND_LIBRARY_COMMAND_LIST
      "set( ${${my_pm_name}_UC}@PACKAGE_perllib_dir@/${my_pm} )" )
    #message(STATUS "${${my_pm_name}_UC}  @PACKAGE_perllib_dir@/${my_pm} " )
  endforeach(my_pm)
  foreach( my_pm ${CONFIG_PM_LIST} )
    #message( STATUS "config_pm: my_pm ${my_pm}")
    get_filename_component( my_pm_name ${my_pm} NAME )
    string(REGEX REPLACE "\\." "_" my_pm_dash "${my_pm}" )
    #message( STATUS "config_pm: my_pm_dash ${my_pm_dash}")
    string(REGEX REPLACE "/" "_" my_pm_slash "${my_pm_dash}" )
    #message( STATUS "config_pm: my_pm_slash ${my_pm_slash}")
    string(TOUPPER  ${my_pm_slash} ${my_pm_name}_UC )
    list(APPEND CONFIG_FIND_LIBRARY_COMMAND_LIST
      "set(${${CMAKE_PROJECT_NAME}_UC}${${my_pm_name}_UC} @PACKAGE_perllib_dir@/${my_pm})" )
    #message(STATUS "${${CMAKE_PROJECT_NAME}_UC}${${my_pm_name}_UC}  @PACKAGE_perllib_dir@/${my_pm} " )
  endforeach(my_pm)

  _config_package_config_file(${CCC_CONFIG_FRAGMENTS})

  # allowed COMPATIBILITY values are:
  # AnyNewerVersion ExactVersion SameMajorVersion
  #message(STATUS "cet_cmake_config: CMAKE_PROJECT_NAME ${CMAKE_PROJECT_NAME}")
  #message(STATUS "cet_cmake_config: CMAKE_PROJECT_VERSION ${CMAKE_PROJECT_VERSION}")
  write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}ConfigVersion.cmake
	  VERSION ${CMAKE_PROJECT_VERSION}
	  COMPATIBILITY AnyNewerVersion )

  install( FILES ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}Config.cmake
        	 ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}ConfigVersion.cmake
           DESTINATION ${distdir} )

endmacro( cet_cmake_config )
