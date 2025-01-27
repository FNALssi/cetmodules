#[================================================================[.rst:
X
-
#]================================================================]
include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.20...3.27 FATAL_ERROR)

set(_cet_cmp_compat_dir "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "art suite compatibility modules location")
set(_cet_cmp_compat_art_version 3.14.05 CACHE INTERNAL "art suite compatibility modules version")
set(_cet_cmp_compat_canvas_root_io_version 1.11.00-alpha CACHE INTERNAL "canvas_root_io compatibility modules version")
set(_cet_cmp_compat_messagefacility_version 2.10.00-alpha CACHE INTERNAL "messagefacility compatibility modules version")

if (COMMAND _include)
  message(WARNING "include() has already been overridden: compatibility with art suites < ${_cet_cmp_compat_art_version} cannot be assured")
endif()

include(ParseVersionString)

macro(include _cmp_FILE)
  get_filename_component(_cmp_module "${_cmp_FILE}" NAME_WE)
  if (_cmp_module STREQUAL "${_cmp_FILE}" AND
      EXISTS "${_cet_cmp_compat_dir}/${_cmp_module}.cmake")
    # We've asked for a module provided in our art_suite compatibility
    # area. Are we going to find it with include()?
    if (NOT CMAKE_MODULE_PATH STREQUAL "")
      list(GET CMAKE_MODULE_PATH 0 _cmp_first)
    else()
      set(_cmp_first)
    endif()
    set(_cmp_need_compat)
    if (NOT _cmp_first STREQUAL _cet_cmp_compat_dir)
      if (_cmp_module STREQUAL "ArtDictionary")
        set(_cmp_art_pkg canvas_root_io)
      elseif (_cmp_module MATCHES
          "^(MessagefacilityPlugins|mf(Stats)?Plugin)$")
        set(_cmp_art_pkg messagefacility)
      else()
        set(_cmp_art_pkg art)
      endif()
      if (DEFINED CETMODULES_NEED_COMPAT_${_cmp_art_pkg})
        # Avoid an expensive version check if we already know the
        # answer for this scope.
        set(_cmp_need_compat ${CETMODULES_NEED_COMPAT_${_cmp_art_pkg}})
      elseif (${_cmp_art_pkg}_FOUND OR ${_cmp_art_pkg}_IN_TREE)
        cet_compare_versions(_cmp_need_compat "${${_cmp_art_pkg}_VERSION}" VERSION_LESS
          "${_cet_cmp_compat_${_cmp_art_pkg}_version}")
      else()
        set(_cmp_need_compat TRUE)
        message(AUTHOR_WARNING "anti-pattern use of CMAKE_MODULE_PATH for package ${_cmp_art_pkg}: use find_package() instead.")
      endif()
      set(CETMODULES_NEED_COMPAT_${_cmp_art_pkg} ${_cmp_need_compat})
      if (_cmp_need_compat)
        list(REMOVE_ITEM CMAKE_MODULE_PATH "${_cet_cmp_compat_dir}")
        list(PREPEND CMAKE_MODULE_PATH "${_cet_cmp_compat_dir}")
      endif()
      unset(_cmp_art_pkg)
    endif()
    unset(_cmp_need_compat)
    unset(_cmp_first)
  endif()
  # Have we been asked to make this module optional, overriding call
  # options?
  if (CETMODULES_OPTIONAL_INCLUDE_MODULE_${_cmp_module} AND
      NOT "${ARGV}" MATCHES "(^|[; 	])OPTIONAL([; 	]|$)")
    unset(_cmp_module)
    _include(${ARGV} OPTIONAL)
  else()
    unset(_cmp_module)
    _include(${ARGV})
  endif()
endmacro()
