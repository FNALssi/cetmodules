########################################################################
# install_scripts()
#   Install executable scripts in a top level fcl subdirectory
#   Default extensions:
#     .sh .py .pl .rb [.cfg when AS_TEST is specified]
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
# install_scripts([SUBDIRS subdirectory_list]
#                 [EXTRAS extra_files]
#                 [EXCLUDES exclusions]
#                 [AS_TEST])
# install_scripts(LIST file_list)
#
########################################################################
include (CetExclude)

function(install_scripts)
  cmake_parse_arguments(IS "AS_TEST" "" "SUBDIRS;LIST;EXTRAS;EXCLUDES" ${ARGN})
  if (IS_AS_TEST)
    set(script_install_dir ${${CMAKE_PROJECT_NAME}_test_dir})
  else()
    set(script_install_dir ${${CMAKE_PROJECT_NAME}_bin_dir})
  endif()
  if (IS_LIST)
    if (IS_SUBDIRS)
      message(FATAL_ERROR "ERROR: LIST and SUBDIRS are mutually exclusive in install_scripts()")
    endif()
    install(PROGRAMS ${IS_LIST} DESTINATION ${script_install_dir})
  else()
    if (IS_EXTRAS)
      install(PROGRAMS ${IS_EXTRAS} DESTINATION ${script_install_dir})
    endif()
    if (IS_AS_TEST)
      file(GLOB scripts [^.]*.sh [^.]*.py [^.]*.pl [^.]*.rb [^.]*.cfg)
    else()
      file(GLOB scripts [^.]*.sh [^.]*.py [^.]*.pl [^.]*.rb)
    endif()
    if (scripts)
      install(PROGRAMS ${scripts} DESTINATION ${script_install_dir})
      if (IS_SUBDIRS)
        foreach(sub ${IS_SUBDIRS})
          if (IS_AS_TEST)
	          file(GLOB subdir_scripts
              ${sub}/[^.]*.sh ${sub}/[^.]*.py ${sub}/[^.]*.pl ${sub}/[^.]*.rb ${sub}/[^.]*.cfg)
          else()
	          file(GLOB subdir_scripts
              ${sub}/[^.]*.sh ${sub}/[^.]*.py ${sub}/[^.]*.pl ${sub}/[^.]*.rb)
          endif()
          if (IS_EXCLUDES)
            _cet_exlude_from_list(subdir_scripts EXCLUDES ${IS_EXCLUDES} LIST ${subdir_scripts})
          endif()
          if (subdir_scripts)
            install(PROGRAMS ${subdir_scripts} DESTINATION ${script_install_dir})
          endif()
        endforeach()
      endif()
  endif()
endfunction()
