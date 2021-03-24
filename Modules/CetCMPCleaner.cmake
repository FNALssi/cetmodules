include_guard(GLOBAL)
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2...3.20 FATAL_ERROR)

set(_cet_cmp_ourselves "${CMAKE_CURRENT_LIST_FILE}")
set(_cet_cmp_compat_dir "${CMAKE_CURRENT_LIST_DIR}/compat/art")
set(_cet_cmp_compat_art_version 3.08.01)
set(_cet_cmp_compat_canvas_root_io_version 1.09.00)

function(_cet_cmp_cleaner WATCHED_VAR ACCESS VALUE CURRENT_LIST_FILE INCLUDE_STACK)
  set(need_compat)
  if (NOT ACCESS STREQUAL "MODIFIED_ACCESS" OR
      CURRENT_LIST_FILE STREQUAL _cet_cmp_ourselves)
    return() # Not relevant.
  endif()
  list(POP_FRONT VALUE _cet_cmp_first)
  if (_cet_cmp_first STREQUAL _cet_cmp_compat_dir)
    return() # Our preferred first value is first: nothing to do.
  elseif (canvas_root_io_VERSION)
    if (canvas_root_io_VERSION VERSION_LESS _cet_cmp_compat_canvas_root_io_version)
      set(need_compat TRUE)
    else()
      return() # We're sure: no need to check by hand.
    endif()
  elseif (art_VERSION)
    if (art_VERSION VERSION_LESS _cet_cmp_compat_art_version)
      set(need_compat TRUE)
    else()
      return() # We're sure: no need to check by hand.
    endif()
  endif()
  # We need to check for anti-pattern use of CMAKE_MODULE_PATH instead
  # of (cet_)?find_package().
  if (NOT need_compat)
    foreach (_cet_cmp_put IN LISTS _cet_cmp_first VALUE)
      # Check each path entry.
      if (_cet_cmp_put STREQUAL _cet_cmp_compat_dir)
        return() # We're good - no need to continue checking.
      endif()
      if (EXISTS "${_cet_cmp_put}/ArtMake.cmake")
        message(WARNING "anti-pattern use of CMAKE_MODULE_PATH for art: use cet_find_package() instead.")
      elseif (EXISTS "${_cet_cmp_put}/ArtDictionary.cmake")
        message(WARNING "anti-pattern use of CMAKE_MODULE_PATH for canvas_root_io: use cet_find_package() instead.")
      else()
        continue()
      endif()
      set(need_compat TRUE)
      break()
    endforeach()
  endif()
  if (need_compat)
    list(REMOVE_ITEM VALUE "${_cet_cmp_compat_dir}")
    list(PREPEND VALUE "${_cet_cmp_compat_dir}" "${_cet_cmp_first}")
    set(CMAKE_MODULE_PATH "${VALUE}" PARENT_SCOPE)
  endif()
endfunction()

# Watch for changes to CMAKE_MODULE_PATH that could break
# forward/backward compatibility.
variable_watch(CMAKE_MODULE_PATH _cet_cmp_cleaner)

cmake_policy(POP)
