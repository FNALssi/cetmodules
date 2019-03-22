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
include (CetCopy)
include (CetExclude)
include (CetProjectVars)

function(install_fhicl)
  set(fhicl_install_dir "${CMAKE_INSTALL_PREFIX}/fcl")
  if (IFCL_LIST)
    if (IFCL_SUBDIRS)
      message(FATAL_ERROR "ERROR: LIST and SUBDIRS are mutually exclusive in install_fhicl()")
    endif()
    cet_copy(${IFCL_LIST} DESTINATION  ${fhicl_install_dir})
    install(FILES ${IFCL_LIST} DESTINATION ${fhicl_install_dir})
  else()
    if (IFCL_EXTRAS)
      cet_copy(${IFCL_EXTRAS} DESTINATION ${fhicl_install_dir})
      install(FILES ${IFCL_EXTRAS} DESTINATION ${fhicl_install_dir})
    endif()
    file(GLOB fhicl [^.]*.fcl)
    if (fhicl)
      cet_copy(${fhicl} DESTINATION ${fhicl_install_dir})
      install(FILES ${fhicl} DESTINATION ${fhicl_install_dir})
      if (IFCL_SUBDIRS)
        foreach(sub ${IFCL_SUBDIRS})
	        file(GLOB subdir_fhicl ${sub}/[^.]*.fcl)
          if (IFCL_EXCLUDES)
            _cet_exlude_from_list(subdir_fhicl EXCLUDES ${IFCL_EXCLUDES} LIST ${subdir_fhicl})
          endif()
          if (subdir_fhicl)
            cet_copy(${subdir_fhicl} DESTINATION ${fhicl_install_dir})
            install(FILES ${subdir_fhicl} DESTINATION ${fhicl_install_dir})
          endif()
        endforeach()
      endif()
    endif()
  endif()
endfunction()
