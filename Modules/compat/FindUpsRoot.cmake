cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(Compatibility)
include(CetFindPackage)

macro(find_ups_root)
  _parse_fup_arguments(root PROJECT ROOT ${ARGN})

  if (_FUP_DOT_VERSION)
    # Remove FNAL-specific version trailer.
    string(REGEX REPLACE [=[[a-z]+[0-9]*$]=] ""
      _FUP_DOT_VERSION "${_FUP_DOT_VERSION}")
  endif()

  cet_find_package(${_FUP_PROJECT} ${_FUP_DOT_VERSION} ${_FUP_UNPARSED_ARGUMENTS})

  # Convenience variables for backward compatibility.
  if (${_FUP_PROJECT}_FOUND AND NOT _FUP_INTERFACE)
    set(ROOTSYS $ENV{ROOTSYS})
    get_property(_fur_cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
    list(FILTER _fur_cache_vars INCLUDE REGEX "^ROOT_(.*)_LIBRARY$")
    list(TRANSFORM _fur_cache_vars REPLACE "^ROOT_(.*)_LIBRARY$" "\\1"
      OUTPUT_VARIABLE _fur_old_varnames)
    if (${_FUP_PROJECT}_VERSION VERSION_GREATER_EQUAL 6.10.04) # Use targets
      list(TRANSFORM _fur_old_varnames PREPEND ${_FUP_PROJECT}::
        OUTPUT_VARIABLE _fur_targets) # Use targets.
      set(val_list _fur_targets)
      set(val_string "\${_fur_var}")
    else() # Use cache variables instead
      set(val_list _fur_cache_vars)
      set(val_string "\$CACHE{\${_fur_var}}")
    endif()
    list(TRANSFORM _fur_old_varnames TOUPPER)
    foreach (_fur_old_varname _fur_var IN ZIP_LISTS _fur_old_varnames ${val_list})
      cmake_language(EVAL CODE "set(${_fur_old_varname} ${val_string})")
    endforeach()
    set(ROOT_GENREFLEX "$CACHE{ROOT_genreflex_CMD}")
    set(ROOTCLING "$CACHE{ROOT_rootcling_CMD}")
    set(ROOT_BASIC_LIB_LIST ${ROOT_CORE} ${ROOT_CINT} ${ROOT_RIO}
      ${ROOT_NET} ${ROOT_IMT} ${ROOT_HIST} ${ROOT_GRAF} ${ROOT_GRAF3D}
      ${ROOT_GPAD} ${ROOT_TREE} ${ROOT_RINT} ${ROOT_POSTSCRIPT}
      ${ROOT_MATRIX} ${ROOT_PHYSICS} ${ROOT_MATHCORE} ${ROOT_THREAD})
    set(ROOT_GUI_LIB_LIST ${ROOT_GUI} ${ROOT_BASIC_LIB_LIST})
    set(ROOT_EVE_LIB_LIST ${ROOT_EVE} ${ROOT_EG} ${ROOT_TREEPLAYER}
      ${ROOT_GEOM} ${ROOT_GED} ${ROOT_RGL} ${ROOT_GUI_LIB_LIST})
  endif()

  # Backward compatibility only.
  include_directories($ENV{ROOT_INC})
endmacro()

cmake_policy(POP)
