########################################################################
# install_perllib()
#   Install perl libs for inclusion by other packages.
#   Default extensions: .pm
#
# The SUBDIRS option allows you to search subdirectories (e.g. a detail
# subdirectory)
#
# The EXTRAS option is intended to allow you to pick up extra files not
# otherwise found.  They should be specified by relative path (eg f1,
# subdir1/f2, etc.).
#
# The EXCLUDES option will exclude the specified files from the
# installation list.
#
# The LIST option allows you to install from a list. When LIST is used,
# we do not search for other files to install. Note that the LIST and
# SUBDIRS options are mutually exclusive.
#
####################################
# Recommended use:
#
# install_perllib( [SUBDIRS subdirectory_list]
#                  [EXTRAS extra_files]
#                  [EXCLUDES exclusions] )
# install_perllib( LIST file_list )
#

include(CetCopy)
include(CetCurrentSubdir)
include(CetExclude)
include(CetProjectVars)

# Project variable.
macro( _cet_perl_plugin_version )
  find_package(cetlib REQUIRED)
  configure_file(${cetlib_PLUGINVERSIONINFO_PM_IN}
    ${CMAKE_CURRENT_BINARY_DIR}/${product}/PluginVersionInfo.pm
    @ONLY)
    set(CONFIG_PM_VERSION "PluginVersionInfo.pm"
	   CACHE INTERNAL "just for PluginVersionInfo.pm" )
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${product}/PluginVersionInfo.pm
    DESTINATION ${perllib_install_dir}/${product}/)
endmacro( _cet_perl_plugin_version )

macro( _cet_copy_perllib )
  cmake_parse_arguments( CPPRL "" "SUBDIR;WORKING_DIRECTORY" "LIST" ${ARGN})
  set( mrb_build_dir $ENV{MRB_BUILDDIR} )
  #message(STATUS "_cet_copy_perllib: copying to mrb ${mrb_build_dir}/${product}/${prlpathname} or cet ${CMAKE_BINARY_DIR}/${prlpathname}")
  if( mrb_build_dir )
    set( perllibbuildpath ${mrb_build_dir}/${product}/${prlpathname} )
  else()
    set( perllibbuildpath ${CMAKE_BINARY_DIR}/${prlpathname} )
  endif()
  #message(STATUS "_cet_copy_perllib: copying to ${perllibbuildpath}")
  if( CPPRL_SUBDIR )
    set( perllibbuildpath "${perllibbuildpath}/${CPPRL_SUBDIR}" )
  endif( CPPRL_SUBDIR )
  if (CPPRL_WORKING_DIRECTORY)
    cet_copy(${CPPRL_LIST} DESTINATION "${perllibbuildpath}" WORKING_DIRECTORY "${CPPRL_WORKING_DIRECTORY}")
  else()
    cet_copy(${CPPRL_LIST} DESTINATION "${perllibbuildpath}")
  endif()
  #message(STATUS "_cet_copy_perllib: copying to ${perllibbuildpath}")
endmacro( _cet_copy_perllib )

macro(_cet_add_to_pm_list libname)
     # add to perl library list for package configure file
     set(CONFIG_PM_LIST ${CONFIG_PM_LIST} ${libname}
	 CACHE INTERNAL "perl libraries installed by this package" )
endmacro(_cet_add_to_pm_list)

macro(_cet_add_to_perl_plugin_list libname)
     # add to perl library list for package configure file
     set(CONFIG_PERL_PLUGIN_LIST ${CONFIG_PERL_PLUGIN_LIST} ${libname}
	 CACHE INTERNAL "perl plugin libraries installed by this package" )
endmacro(_cet_add_to_perl_plugin_list)

macro( _cet_perllib_config_setup  )
  if( ${CURRENT_SUBDIR_NAME} MATCHES "CetSkelPlugins" )
    foreach( pmfile ${ARGN} )
      get_filename_component( pmfilename "${pmfile}" NAME )
      _cet_add_to_perl_plugin_list( ${CURRENT_SUBDIR}/${pmfilename} )
    endforeach( pmfile )
  else()
    foreach( pmfile ${ARGN} )
      get_filename_component( pmfilename "${pmfile}" NAME )
      _cet_add_to_pm_list( ${CURRENT_SUBDIR}/${pmfilename} )
    endforeach( pmfile )
  endif()
endmacro( _cet_perllib_config_setup )

macro( _cet_install_perllib_without_list   )
  #message( STATUS "_cet_install_perllib_without_list: perl lib scripts will be installed in ${perllib_install_dir}" )
  FILE(GLOB prl_files [^.]*.pm )
  FILE(GLOB prl_files2 [^.]*.pm README )
  if( IPRL_EXCLUDES )
    _cet_exclude_from_list( prl_files EXCLUDES ${IPRL_EXCLUDES} LIST ${prl_files} )
  endif()
  if( prl_files )
    #message( STATUS "_cet_install_perllib_without_list: installing perl lib files ${prl_files} in ${perllib_install_dir}")
    _cet_copy_perllib( LIST ${prl_files} )
    _cet_perllib_config_setup( ${prl_files} )
    INSTALL ( FILES ${prl_files2}
              DESTINATION ${perllib_install_dir} )
  endif( prl_files )
  # now check subdirectories
  if( IPRL_SUBDIRS )
    foreach( sub ${IPRL_SUBDIRS} )
      FILE(GLOB subdir_prl_files2
                ${sub}/[^.]*.pm  
		${sub}/README
		)
      FILE(GLOB subdir_prl_files ${sub}/[^.]*.pm )
      #message( STATUS "found ${sub} files ${subdir_prl_files}")
      if( IPRL_EXCLUDES )
        _cet_exclude_from_list( subdir_prl_files EXCLUDES ${IPRL_EXCLUDES} LIST ${subdir_prl_files} )
        _cet_exclude_from_list( subdir_prl_files2 EXCLUDES ${IPRL_EXCLUDES} LIST ${subdir_prl_files2} )
      endif()
      if( subdir_prl_files )
        _cet_copy_perllib( LIST ${subdir_prl_files} SUBDIR ${sub} )
        _cet_perllib_config_setup( ${subdir_prl_files} )
        INSTALL ( FILES ${subdir_prl_files2}
                  DESTINATION ${perllib_install_dir}/${sub} )
      endif( subdir_prl_files )
    endforeach(sub)
  endif( IPRL_SUBDIRS )
endmacro( _cet_install_perllib_without_list )

macro( install_perllib   )
  cet_project_var(perllib_dir perllib
    DOCSTRING "Directory below prefix to install perl files")
  cmake_parse_arguments( IPRL "" "" "SUBDIRS;LIST;EXTRAS;EXCLUDES" ${ARGN})
  _cet_current_subdir( TEST_SUBDIR )
  STRING( REGEX REPLACE "^/${${CMAKE_PROJECT_NAME}_perllib_dir}(.*)" "\\1" CURRENT_SUBDIR "${TEST_SUBDIR}" )
  set(perllib_install_dir "${${CMAKE_PROJECT_NAME}_perllib_dir}${CURRENT_SUBDIR}")
  set(prlpathname "${${CMAKE_PROJECT_NAME}_perllib_dir}${CURRENT_SUBDIR}")
  #message( STATUS "install_perllib: perllib scripts will be installed in ${perllib_install_dir}" )
  #message( STATUS "install_perllib: IPRL_SUBDIRS is ${IPRL_SUBDIRS}")
  get_filename_component( CURRENT_SUBDIR_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME )
  #message( STATUS "install_perllib: CURRENT_SUBDIR_NAME is ${CURRENT_SUBDIR_NAME}" )
  if( ${CURRENT_SUBDIR_NAME} MATCHES "CetSkelPlugins" )
    _cet_perl_plugin_version()
  endif()

  if( IPRL_LIST )
    if( IPRL_SUBDIRS )
      message( FATAL_ERROR
               "ERROR: call install_perllib with EITHER LIST or SUBDIRS but not both")
    endif( IPRL_SUBDIRS )
    _cet_copy_perllib( LIST ${IPRL_LIST} WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    _cet_perllib_config_setup( ${IPRL_LIST} )
    INSTALL ( FILES  ${IPRL_LIST}
              DESTINATION ${perllib_install_dir} )
  else()
    if( IPRL_EXTRAS )
      _cet_copy_perllib( LIST ${IPRL_EXTRAS} )
      _cet_perllib_config_setup( ${IPRL_EXTRAS} )
      INSTALL ( FILES  ${IPRL_EXTRAS}
                DESTINATION ${perllib_install_dir} )
    endif( IPRL_EXTRAS )
    _cet_install_perllib_without_list()
  endif()
endmacro( install_perllib )
