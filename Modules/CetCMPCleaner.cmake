include_guard(GLOBAL)
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2...3.20 FATAL_ERROR)

set(_cet_cmp_ourselves "${CMAKE_CURRENT_LIST_FILE}")
set(_cet_cmp_compat_dir "${CMAKE_CURRENT_LIST_DIR}/compat/art")
set(_cet_cmp_compat_art_version 3.08.01)
set(_cet_cmp_compat_canvas_root_io_version 1.09.00)

function(_cet_cmp_cleaner WATCHED_VAR ACCESS VALUE CURRENT_LIST_FILE INCLUDE_STACK)
  set(need_compat)
  if (ACCESS STREQUAL "MODIFIED_ACCESS" AND NOT CURRENT_LIST_FILE STREQUAL _cet_cmp_ourselves)
    if (canvas_root_io_VERSION)
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
  endif()
  # We need to check for anti-pattern use of CMAKE_MODULE_PATH instead
  # of (cet_)?find_package().
  if (NOT need_compat)
    foreach (_cet_cmp_put IN LISTS CMAKE_MODULE_PATH)
      # Check each path entry.
      if (_cet_cmp_put STREQUAL _cet_cmp_compat_dir)
        break() # We're good - no need to continue checking.
      endif()
      if ((EXISTS "${_cet_cmp_put}/ArtMake.cmake" AND
            NOT EXISTS "${_cet_cmp_put}/pluginPlugin.cmake") OR
          (EXISTS "${_cet_cmp_put}/ArtDictionary.cmake" AND
            (IS_DIRECTORY "${_cet_cmp_put}/../include" OR
              EXISTS "${_cet_cmp_put}/../ups/product-config.cmake.in")))
        if (NOT _cet_cmp_put MATCHES "/(art|canvas_root_io)/Modules/*$")
          message(WARNING "anti-pattern use of CMAKE_MODULE_PATH for art and/or canvas_root_io: use cet_find_package() instead.")
        elseif ()
          message(VERBOSE "activate/refresh compatibility for art suite < ${_cet_cmp_compat_art_version}")
        endif()
        set(need_compat TRUE)
        break()
      endif()
    endforeach()
  endif()
  if (need_compat)
    list(PREPEND CMAKE_MODULE_PATH "${_cet_cmp_compat_dir}")
    list(REMOVE_DUPLICATES CMAKE_MODULE_PATH)
    set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
  endif()
endfunction()

# Watch for changes to CMAKE_MODULE_PATH that could break
# forward/backward compatibility.
variable_watch(CMAKE_MODULE_PATH _cet_cmp_cleaner)

cmake_policy(POP)
