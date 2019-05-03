########################################################################
# install_wp([SUBDIRNAME dir] LIST files...)
#   Install WP data in ${${CMAKE_PROJECT_NAME}_wp_dir}/${SUBDIRNAME}
#
# N.B. fp_dir must be set prior to calling install_wp(),, otherwise
# install_wp() will generate a FATAL_ERROR.
########################################################################
include(CetProjectVars)

function(install_wp)
  cet_project_var(wp_dir
    DOCSTRING "Directory below prefix to install WP files")
  cmake_parse_arguments(IWP "" "SUBDIRNAME" "LIST" ${ARGN})
  if (NOT ${CMAKE_PROJECT_NAME}_wp_dir)
    message(FATAL_ERROR "ERROR: install_wp() called without ${CMAKE_PROJECT_NAME}_wp_dir being configured.")
  endif()
  if (IWP_LIST)
    cet_copy(${IWP_LIST}
      DESTINATION "${PROJECT_BINARY_DIR}/${${CMAKE_PROJECT_NAME}_wp_dir}/${IWP_SUBDIRNAME}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    install(FILES ${IWP_LIST} DESTINATION ${${CMAKE_PROJECT_NAME}_wp_dir}/${IWP_SUBDIRNAME})
  else()
    message(FATAL_ERROR "ERROR: install_wp(): LIST is mandatory.")
  endif()
endfunction()
