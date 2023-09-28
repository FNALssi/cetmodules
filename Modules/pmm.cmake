#[================================================================[.rst:
X
=
#]================================================================]

include(${CMAKE_CURRENT_LIST_DIR}/private/pmm.cmake)
if (CETMODULES_CURRENT_PROJECT_NAME
    AND NOT CETMODULES_PMM_MODULE_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
  set(CETMODULES_PMM_MODULE_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
    ${PMM_MODULE} CACHE FILEPATH
    "path to pmm.cmake used by project ${CETMODULES_CURRENT_PROJECT_NAME}")
  mark_as_advanced(CETMODULES_PMM_MODULE_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
endif()
