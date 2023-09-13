#[================================================================[.rst:
X
=
#]================================================================]

# Avoid unnecessary repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(Compatibility)
include(FindUpsPackage)

macro(find_ups_root)
  if (NOT _FUR_INCLUDED)
    find_ups_product(root PROJECT ROOT ${ARGN})

    # Convenience variables for backward compatibility.
    if (${_FUP_PROJECT}_FOUND)
      set(ROOTSYS $ENV{ROOTSYS})
      _set_root_lib_vars()
      set(ROOT_GENREFLEX "$CACHE{ROOT_genreflex_CMD}")
      set(ROOTCLING "$CACHE{ROOT_rootcling_CMD}")
      set(ROOT_BASIC_LIB_LIST ${ROOT_CORE} ${ROOT_CINT} ${ROOT_RIO}
        ${ROOT_NET} ${ROOT_IMT} ${ROOT_HIST} ${ROOT_GRAF} ${ROOT_GRAF3D}
        ${ROOT_GPAD} ${ROOT_TREE} ${ROOT_RINT} ${ROOT_POSTSCRIPT}
        ${ROOT_MATRIX} ${ROOT_PHYSICS} ${ROOT_MATHCORE} ${ROOT_THREAD})
      set(ROOT_GUI_LIB_LIST ${ROOT_GUI} ${ROOT_BASIC_LIB_LIST})
      set(ROOT_EVE_LIB_LIST ${ROOT_EVE} ${ROOT_EG} ${ROOT_TREEPLAYER}
        ${ROOT_GEOM} ${ROOT_GED} ${ROOT_RGL} ${ROOT_GUI_LIB_LIST})
      include_directories($ENV{ROOT_INC})
      set(_FUR_INCLUDED TRUE)
    endif()
  endif()
endmacro()

function(_set_root_lib_vars)
  file(GLOB libs LIST_DIRECTORIES FALSE
    ${ROOTSYS}/lib/lib*.so ${ROOTSYS}/lib/lib*.so)
  list(FILTER libs EXCLUDE REGEX "Dict\\.(so|a)$")
  list(TRANSFORM libs REPLACE "^.*/lib(.*)\.so$" "\\1" OUTPUT_VARIABLE libnames)
  list(TRANSFORM libnames TOUPPER OUTPUT_VARIABLE old_varnames)
  if (${_FUP_PROJECT}_VERSION VERSION_GREATER_EQUAL 6.10.04) # Use targets
    list(TRANSFORM libnames PREPEND ${_FUP_PROJECT}::
      OUTPUT_VARIABLE targets) # Use targets.
    set(val_list targets)
  else() # Use full library locations.
    set(val_list libs)
  endif()
  foreach (old_varname var IN ZIP_LISTS old_varnames ${val_list})
    set(ROOT_${old_varname} "${var}" PARENT_SCOPE)
  endforeach()
endfunction()
