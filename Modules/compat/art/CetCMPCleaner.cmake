#[================================================================[.rst:
X
=
#]================================================================]
include_guard(GLOBAL)
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2...3.21 FATAL_ERROR)

set(_cet_cmp_compat_dir "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "art suite compatibility modules location")
set(_cet_cmp_compat_art_version 3.09.04 CACHE INTERNAL "art suite compatibility modules version")
set(_cet_cmp_compat_canvas_root_io_version 1.09.00 CACHE INTERNAL "canvas_root_io compatibility modules version")
set(_cet_cmp_compat_messagefacility_version 2.08.03 CACHE INTERNAL "messagefacility compatibility modules version")

if (COMMAND _include)
  message(WARNING "include() has already been overridden: compatibility with art suites < ${_cet_cmp_compat_art_version} cannot be assured")
endif()

include(ParseVersionString)

macro(include _cmp_FILE)
  if (NOT IS_ABSOLUTE "${_cmp_FILE}" AND
      "${_cmp_FILE}" MATCHES "(^|/)(Art(Dictionary|Make)|BuildPlugins|(mf|mfStats|module|plugin|service|source|tool)Plugin)(.cmake)?$" AND
      NOT "${CMAKE_MODULE_PATH}" STREQUAL "")
    set(_cmp_art_module "${CMAKE_MATCH_2}")
    list(GET CMAKE_MODULE_PATH 0 _cet_cmp_first)
    set(_cmp_need_compat)
    if (NOT _cet_cmp_first STREQUAL _cet_cmp_compat_dir)
      if (_cmp_art_module STREQUAL "ArtDictionary")
        set(_cmp_art_pkg canvas_root_io)
      elseif (_cmp_art_module MATCHES "^mf(Stats)?Plugin$" )
        set(_cmp_art_pkg messagefacility)
      else()
        set(_cmp_art_pkg art)
      endif()
      if (${_cmp_art_pkg}_FOUND)
        cet_compare_versions(_cmp_need_compat "${${_cmp_art_pkg}_VERSION}" VERSION_LESS
          "${_cet_cmp_compat_${_cmp_art_pkg}_version}")
      elseif (NOT ${_cmp_art_pkg}_IN_TREE)
        set(_cmp_need_compat TRUE)
        message(AUTHOR_WARNING "anti-pattern use of CMAKE_MODULE_PATH for package ${_cmp_art_pkg}: use find_package() instead.")
      endif()
      if (_cmp_need_compat)
        list(REMOVE_ITEM CMAKE_MODULE_PATH "${_cet_cmp_compat_dir}")
        list(PREPEND CMAKE_MODULE_PATH "${_cet_cmp_compat_dir}")
      endif()
    endif()
  endif()
  _include(${ARGV})
  unset(_cmp_need_compat)
  unset(_cmp_art_module)
  unset(_cmp_art_pkg)
endmacro()

cmake_policy(POP)
