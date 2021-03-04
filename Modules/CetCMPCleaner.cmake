include_guard(GLOBAL)
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2...3.20 FATAL_ERROR)

set(_cet_cmp_ourselves "${CMAKE_CURRENT_LIST_FILE}")
set(_cet_cmp_compat_dir "${CMAKE_CURRENT_LIST_DIR}/compat/art")

function(_cet_cmp_cleaner WATCHED_VAR ACCESS VALUE CURRENT_LIST_FILE INCLUDE_STACK)
  if (ACCESS STREQUAL "MODIFIED_ACCESS" AND NOT CURRENT_LIST_FILE STREQUAL _cet_cmp_ourselves)
    if (CURRENT_LIST_FILE MATCHES "(^|/)(art|canvas_root_io)Config\.cmake\$" AND
        ((CMAKE_MATCH_2 STREQUAL "art" AND art_VERSION VERSION_LESS 3.08.00) OR
          canvas_root_io_VERSION VERSION_LESS 1.09.00))
      message(VERBOSE "activate/refresh compatibility for art suite < 3.08.00")
      list(PREPEND CMAKE_MODULE_PATH "${_cet_cmp_compat_dir}")
      list(REMOVE_DUPLICATES CMAKE_MODULE_PATH)
      set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
    else()
      foreach (_cet_cmp_put IN LISTS CMAKE_MODULE_PATH)
        if (_cet_cmp_put STREQUAL _cet_cmp_compat_dir)
          break()
        endif()
        if ((EXISTS "${_cet_cmp_put}/ArtMake.cmake" AND
              NOT EXISTS "${_cet_cmp_put}/pluginPlugin.cmake") OR
            (EXISTS "${_cet_cmp_put}/ArtDictionary.cmake" AND
              (IS_DIRECTORY "${_cet_cmp_put}/../include" OR
                EXISTS "${_cet_cmp_put}/../ups/product-config.cmake.in")))
          if (NOT _cet_cmp_put MATCHES "/(art|canvas_root_io)/Modules/*$")
            message(WARNING "anti-pattern use of CMAKE_MODULE_PATH: use cet_find_package() instead.")
          else()
            message(VERBOSE "activate/refresh compatibility for art suite < 3.08.00")
          endif()
          list(PREPEND CMAKE_MODULE_PATH "${_cet_cmp_compat_dir}")
          list(REMOVE_DUPLICATES CMAKE_MODULE_PATH)
          set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
          break()
        endif()
      endforeach()
    endif()
  endif()
endfunction()

# Watch for changes to CMAKE_MODULE_PATH that could break
# forward/backward compatibility.
variable_watch(CMAKE_MODULE_PATH _cet_cmp_cleaner)

cmake_policy(POP)
