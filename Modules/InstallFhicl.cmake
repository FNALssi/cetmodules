########################################################################
#
# install_fhicl()
#   Install fhicl scripts in a top level fcl subdirectory
#   Default extensions:
#     .fcl
#
# The SUBDIRS option allows you to search subdirectories (e.g. a detail subdirectory)
#
# The EXTRAS option is intended to allow you to pick up extra files not otherwise found.
# They should be specified by relative path (eg f1, subdir1/f2, etc.).
#
# The EXCLUDES option will exclude the specified files from the installation list.
#
# The LIST option allows you to install from a list. When LIST is used,
# we do not search for other files to install. Note that the LIST and
# SUBDIRS options are mutually exclusive.
#
####################################
# Recommended use:
#
# install_fhicl( [SUBDIRS subdirectory_list]
#                [EXTRAS extra_files]
#                [EXCLUDES exclusions] )
# install_fhicl( LIST file_list )
#
########################################################################

include(CMakeParseArguments)
#include(CetCurrentSubdir)
include (CetCopy)
include (CetExclude)


macro( _cet_copy_fcl )
  set( mrb_build_dir $ENV{MRB_BUILDDIR} )
  get_filename_component( fclpathname ${fhicl_install_dir} NAME )
  #message(STATUS "_cet_copy_fcl: copying to mrb ${mrb_build_dir}/${product}/${fclpathname} or cet ${CETPKG_BUILD}/${fclpathname}")
  if( mrb_build_dir )
    set( fclbuildpath ${mrb_build_dir}/${product}/${fclpathname} )
  else()
    set( fclbuildpath ${CETPKG_BUILD}/${fclpathname} )
  endif()
  #message(STATUS "_cet_copy_fcl: copying to ${fclbuildpath}")
  cet_copy(${ARGN} DESTINATION "${fclbuildpath}")
endmacro( _cet_copy_fcl )

macro( _cet_install_fhicl_without_list   )
  #message( STATUS "fhicl scripts will be installed in ${fhicl_install_dir}" )
  FILE(GLOB fcl_files [^.]*.fcl )
  if( IFCL_EXCLUDES )
    #message( STATUS "initial fhicl files ${fcl_files}")
    _cet_exclude_from_list( fcl_files EXCLUDES ${IFCL_EXCLUDES} LIST ${fcl_files} )
    #message( STATUS "install_fhicl: fhicl files after exlucde ${fcl_files}")
  endif()
  if( fcl_files )
    #message( STATUS "installing fhicl files ${fcl_files} in ${fhicl_install_dir}")
    _cet_copy_fcl( ${fcl_files} )
    INSTALL ( FILES ${fcl_files}
              DESTINATION ${fhicl_install_dir} )
  endif( fcl_files )
  # now check subdirectories
  if( IFCL_SUBDIRS )
    foreach( sub ${IFCL_SUBDIRS} )
      FILE(GLOB subdir_fcl_files
                ${sub}/[^.]*.fcl )
      if( IFCL_EXCLUDES )
        _cet_exclude_from_list( subdir_fcl_files EXCLUDES ${IFCL_EXCLUDES} LIST ${subdir_fcl_files} )
      endif()
      if( subdir_fcl_files )
        _cet_copy_fcl( ${subdir_fcl_files} )
        INSTALL ( FILES ${subdir_fcl_files}
                  DESTINATION ${fhicl_install_dir} )
      endif( subdir_fcl_files )
    endforeach(sub)
  endif( IFCL_SUBDIRS )
endmacro( _cet_install_fhicl_without_list )

macro( install_fhicl   )
  cmake_parse_arguments( IFCL "" "" "SUBDIRS;LIST;EXTRAS;EXCLUDES" ${ARGN})
  set(fhicl_install_dir ${${product}_fcl_dir} )
  #message( STATUS "install_fhicl: fhicl scripts will be installed in ${fhicl_install_dir}" )
  if( IFCL_LIST )
    if( IFCL_SUBDIRS )
      message( FATAL_ERROR
               "ERROR: call install_fhicl with EITHER LIST or SUBDIRS but not both")
    endif( IFCL_SUBDIRS )
    _cet_copy_fcl( ${IFCL_LIST} WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    INSTALL ( FILES  ${IFCL_LIST}
              DESTINATION ${fhicl_install_dir} )
  else()
    if( IFCL_EXTRAS )
      _cet_copy_fcl( ${IFCL_EXTRAS} )
      INSTALL ( FILES  ${IFCL_EXTRAS}
                DESTINATION ${fhicl_install_dir} )
    endif( IFCL_EXTRAS )
    _cet_install_fhicl_without_list()
  endif()
endmacro( install_fhicl )

