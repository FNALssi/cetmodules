########################################################################
# install_fw([SUBDIRNAME dir] LIST files...)
#   Install FW data in ${${CMAKE_PROJECT_NAME}_fw_dir}/${SUBDIRNAME}
#
########################################################################
include(CetProjectVars)

function(install_fw)
  cet_project_var(fw_dir
    DOCSTRING "Directory below prefix to install FW files")
  cmake_parse_arguments(IFW "" "SUBDIRNAME" "LIST" ${ARGN})
  if (NOT ${CMAKE_PROJECT_NAME}_fw_dir)
    message(FATAL_ERROR "ERROR: install_fw() called without ${CMAKE_PROJECT_NAME}_fw_dir being configured.")
  endif()
  if (IFW_LIST)
    cet_copy(${IFW_LIST}
      DESTINATION "${PROJECT_BINARY_DIR}/${${CMAKE_PROJECT_NAME}_fw_dir}/${IFW_SUBDIRNAME}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    install(FILES ${IFW_LIST} DESTINATION ${${CMAKE_PROJECT_NAME}_fw_dir}/${IFW_SUBDIRNAME})
  else()
    message(FATAL_ERROR "ERROR: install_fw(): LIST is mandatory.")
  endif()
endfunction()
