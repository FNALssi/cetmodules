#[================================================================[.rst:
FindTBB / Findtbb
-----------------

Find module bridging UPS SciSoft and TBB-native config files.

Imported Targets
^^^^^^^^^^^^^^^^

This module ensures import of at least the following targets, if applicable:

.. hlist::
   :columns: 1

   * ``TBB::tbb``
   * ``TBB::tbbmalloc``
   * ``TBB::tbbmalloc_proxy``

Result Variables
^^^^^^^^^^^^^^^^

The following variables will be defined:

.. hlist::
   :columns: 1

   * ``TBB_FOUND``
   * ``TBB_VERSION``
   * ``TBB_INCLUDE_DIRS``
   * ``TBB_LIBRARIES``

Cache Variables
^^^^^^^^^^^^^^^

The following cache variables may also be set:

.. hlist::
   :columns: 1

   * ``TBB_INCLUDE_DIR``
   * ``TBB_LIBRARY``
   * ``TBB``
#]================================================================]

set(_cet_tbb_var_names
  FIND_COMPONENTS FOUND VERSION INCLUDE_DIR INCLUDE_DIRS LIBRARIES LIBRARY)

if (NOT CMAKE_FIND_PACKAGE_NAME STREQUAL TBB)
  set(_cet_tbb_pkg_prefix ${CMAKE_FIND_PACKAGE_NAME})
  set(TBB_FIND_COMPONENTS ${${_cet_tbb_pkg_prefix}_FIND_COMPONENTS})
  foreach (_cet_tbb_component IN LISTS TBB_FIND_COMPONENTS)
    set(TBB_FIND_REQUIRED_${_cet_tbb_component}
      ${${_cet_tbb_pkg_prefix}_FIND_REQUIRED_${_cet_tbb_component}})
  endforeach()
else()
  unset(_cet_tbb_pkg_prefix)
endif()

# Find a TBB (or tbb) config file.
find_package(TBB CONFIG QUIET)

# Add some information depending on whether we have the UPS/SciSoft or
# TBB-official config file.
if (TBB_FOUND)
  if (TBB_DIR AND EXISTS "${TBB_DIR}/../../../../ups/tbb.table" AND
      2021.1.1 VERSION_GREATER ${TBB_VERSION})
    set(_cet_tbb_fnal_config TRUE)
    if (NOT TBB_FIND_COMPONENTS)
      set(TBB_FIND_COMPONENTS "tbb;tbbmalloc;tbbmalloc_proxy")
      foreach (_cet_tbb_component IN LISTS TBB_FIND_COMPONENTS)
        set(TBB_FIND_REQUIRED_${_cet_tbb_component} TRUE)
      endforeach()
    endif()
    set(TBB_INCLUDE_DIR "$ENV{TBB_INC}" CACHE PATH "Path to TBB Headers")
    mark_as_advanced(FORCE TBB_INCLUDE_DIR)
  endif()
  foreach(_cet_tbb_component IN LISTS TBB_FIND_COMPONENTS)
    if (_cet_tbb_fnal_config)
      if (TBB_${_cet_tbb_component}_FOUND)
        continue()
      elseif (TARGET TBB::${_cet_tbb_component})
        set(TBB_${_cet_tbb_component}_FOUND TRUE)
        continue()
      endif()
      add_library(TBB::${_cet_tbb_component} SHARED IMPORTED)
      if (EXISTS "$ENV{TBB_LIB}/${CMAKE_SHARED_LIBRARY_PREFIX}${_cet_tbb_component}_debug${CMAKE_SHARED_LIBRARY_SUFFIX}")
        set(_cet_tbb_config DEBUG)
        set(_cet_tbb_lib "$ENV{TBB_LIB}/${CMAKE_SHARED_LIBRARY_PREFIX}${_cet_tbb_component}_debug${CMAKE_SHARED_LIBRARY_SUFFIX}")
      else()
        set(_cet_tbb_config RELEASE)
        set(_cet_tbb_lib "$ENV{TBB_LIB}/${CMAKE_SHARED_LIBRARY_PREFIX}${_cet_tbb_component}${CMAKE_SHARED_LIBRARY_SUFFIX}")
      endif()
      set_target_properties(TBB::${_cet_tbb_component} PROPERTIES
        IMPORTED_CONFIGURATIONS "${_cet_tbb_config}"
        IMPORTED_LOCATION_${_cet_tbb_config} "${_cet_tbb_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "$ENV{TBB_INC}")
      if (_cet_tbb_component STREQUAL tbbmalloc_proxy)
        set_target_properties(TBB::tbbmalloc_proxy PROPERTIES INTERFACE_LINK_LIBRARIES TBB::tbbmalloc)
      endif()
      set(TBB_${_cet_tbb_component}_FOUND 1)
    endif()
    if (TARGET TBB::${_cet_tbb_component})
      string(TOUPPER "${_cet_tbb_component}" _cet_tbb_var_name)
      set(${_cet_tbb_var_name} TBB::${_cet_tbb_component})
    endif()
  endforeach()
endif()
unset(_cet_tbb_fnal_config)

##################
# FNAL config file provided two functions—we should at least stub
# them out:
set(_cet_tbb_err_msg " is obsolete: use \
check_cxx_compiler_flag() (include(CheckCXXCompilerFlag)), \
target_compile_options(), and target_link_libraries() to achieve the \
same effect")
# Need to leave _cet_tbb_err_msg lying around to be available for these
# macros.
if (NOT COMMAND tbb_offload)
  macro(tbb_offload)
    message(SEND_ERROR "tbb_offload()${_cet_tbb_err_msg}")
  endmacro()
endif()
if (NOT COMMAND find_tbb_offloads)
  macro(find_tbb_offloads)
    message(SEND_ERROR "find_tbb_offloads()${_cet_tbb_err_msg}")
  endmacro()
endif()
##################

# Bookkeeping.
include(FindPackageHandleStandardArgs)
string(TOUPPER "${TBB_FIND_COMPONENTS}" _cet_tbb_req_vars)
find_package_handle_standard_args(TBB CONFIG_MODE NAME_MISMATCHED
  HANDLE_COMPONENTS REQUIRED_VARS ${_cet_tbb_req_vars})

if (_cet_tbb_pkg_prefix)
  foreach (_cet_tbb_var IN LISTS _cet_tbb_var_names)
    set(${_cet_tbb_pkg_prefix}_${_cet_tbb_var} "${TBB_${_cet_tbb_var}}")
  endforeach()
  foreach (_cet_tbb_component IN LISTS ${_cet_tbb_pkg_prefix_}_FIND_COMPONENTS)
    set(${_cet_tbb_pkg_prefix}_FIND_REQUIRED_${_cet_tbb_component} ${TBB_FIND_REQUIRED_${_cet_tbb_component}})
    set(${_cet_tbb_pkg_prefix}_${_cet_tbb_component}_FOUND ${TBB_${_cet_tbb_component}_FOUND})
  endforeach()
  set(CMAKE_FIND_PACKAGE_NAME ${_cet_tbb_pkg_prefix})
endif()

unset(_cet_tbb_component)
unset(_cet_tbb_config)
unset(_cet_tbb_lib)
unset(_cet_tbb_pkg_prefix)
unset(_cet_tbb_req_vars)
unset(_cet_tbb_var_name)
unset(_cet_tbb_var_names)
