#[================================================================[.rst:
X
=
#]================================================================]
include_guard(GLOBAL)
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2...3.20 FATAL_ERROR)

include(ParseVersionString)

set(_cet_cmp_ourselves "${CMAKE_CURRENT_LIST_FILE}")
set(_cet_cmp_compat_dir "${CMAKE_CURRENT_LIST_DIR}/compat/art")
set(_cet_cmp_compat_art_version 3.08.01)
set(_cet_cmp_compat_canvas_root_io_version 1.09.00)

function(_cet_cmp_cleaner WATCHED_VAR ACCESS VALUE CURRENT_LIST_FILE INCLUDE_STACK)
  if (NOT ACCESS STREQUAL "MODIFIED_ACCESS" OR CURRENT_LIST_FILE STREQUAL _cet_cmp_ourselves)
    return() # Not relevant.
  endif()
  list(POP_FRONT VALUE _cet_cmp_first)
  if (_cet_cmp_first STREQUAL _cet_cmp_compat_dir)
    return() # Our preferred first value is first: nothing to do.
  elseif (canvas_root_io_VERSION)
    cet_compare_versions(maybe_need_compat "${canvas_root_io_VERSION}" VERSION_LESS
      "${_cet_cmp_compat_canvas_root_io_version}")
  elseif (art_VERSION)
    cet_compare_versions(maybe_need_compat "${art_VERSION}" VERSION_LESS
      "${_cet_cmp_compat_art_version}")
  endif()
  if (NOT maybe_need_compat)
    return()
  endif()
  # We need to check for anti-pattern use of CMAKE_MODULE_PATH instead
  # of (cet_)?find_package().
  foreach (_cet_cmp_put IN LISTS _cet_cmp_first VALUE)
    # Check each path entry.
    if (_cet_cmp_put STREQUAL _cet_cmp_compat_dir)
      set(maybe_need_compat) # We know we don't need it.
    elseif (EXISTS "${_cet_cmp_put}/ArtMake.cmake")
      message(WARNING "anti-pattern use of CMAKE_MODULE_PATH for art: use find_package() instead.")
    elseif (EXISTS "${_cet_cmp_put}/ArtDictionary.cmake")
      message(WARNING "anti-pattern use of CMAKE_MODULE_PATH for canvas_root_io: use find_package() instead.")
    else()
      continue() # Keep checking.
    endif()
    break() # We have our answer, one way or the other
  endforeach()
  if (maybe_need_compat)
    list(REMOVE_ITEM VALUE "${_cet_cmp_compat_dir}")
    list(PREPEND VALUE "${_cet_cmp_compat_dir}" "${_cet_cmp_first}")
    set(CMAKE_MODULE_PATH "${VALUE}" PARENT_SCOPE)
  endif()
endfunction()

# Watch for changes to CMAKE_MODULE_PATH that could break
# forward/backward compatibility.
variable_watch(CMAKE_MODULE_PATH _cet_cmp_cleaner)

cmake_policy(POP)
