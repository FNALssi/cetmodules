#[============================================================[.rst:
FindGeant4
==========
#]============================================================]

set(_fg4_libs G4FR G4GMocren G4OpenGL G4RayTracer G4Tree G4VRML
  G4analysis G4digits_hits G4error_propagation G4event G4geometry
  G4gl2ps G4global G4graphics_reps G4intercoms G4interfaces
  G4materials G4modeling G4parmodels G4particles G4persistency
  G4physicslists G4processes G4readout G4run G4track G4tracking
  G4visHepRep G4visXXX G4vis_management G4zlib)

if (NOT ${CMAKE_FIND_PACKAGE_NAME}_FOUND)
  find_package(${CMAKE_FIND_PACKAGE_NAME} CONFIG)
  if (${CMAKE_FIND_PACKAGE_NAME}_FOUND)
    set(_fg4_need_tweaks TRUE)
  endif()
endif()

if (${CMAKE_FIND_PACKAGE_NAME}_FOUND)
  set(_cet_find${CMAKE_FIND_PACKAGE_NAME}_required ${${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED})
  set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
  set(_cet_find${CMAKE_FIND_PACKAGE_NAME}_quietly ${${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY})
  set(${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY TRUE)
  foreach (_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep XercesC)
    get_property(_cet_find${CMAKE_FIND_PACKAGE_NAME}_${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep}_alreadyTransitive GLOBAL PROPERTY
      _CMAKE_${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep}_TRANSITIVE_DEPENDENCY)
    find_package(${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep} QUIET)
    if (NOT DEFINED cet_${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep}_alreadyTransitive OR cet_${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep}_alreadyTransitive)
      set_property(GLOBAL PROPERTY _CMAKE_${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep}_TRANSITIVE_DEPENDENCY TRUE)
    endif()
    unset(_cet_find${CMAKE_FIND_PACKAGE_NAME}_${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep}_alreadyTransitive)
    if (NOT ${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep}_FOUND)
      set(${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE "${CMAKE_FIND_PACKAGE_NAME} could not be found because dependency ${_cet_find${CMAKE_FIND_PACKAGE_NAME}_dep} could not be found.")
      set(${CMAKE_FIND_PACKAGE_NAME}_FOUND False)
      break()
    endif()
  endforeach()
endif()

set(${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED ${_cet_find${CMAKE_FIND_PACKAGE_NAME}_required})
set(${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY ${_cet_find${CMAKE_FIND_PACKAGE_NAME}_required})
unset(_cet_find${CMAKE_FIND_PACKAGE_NAME}_required)
unset(_cet_find${CMAKE_FIND_PACKAGE_NAME}_quietly)

if (${CMAKE_FIND_PACKAGE_NAME}_FOUND AND _fg4_need_tweaks)
  foreach (_fg4_lib ${_fg4_libs})
    if (TARGET ${CMAKE_FIND_PACKAGE_NAME}::${_fg4_lib})
      set_property(TARGET ${CMAKE_FIND_PACKAGE_NAME}::${_fg4_lib}
        APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES
        "${${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR}/..")
      if (_fg4_lib STREQUAL G4persistency)
        set_property(TARGET ${CMAKE_FIND_PACKAGE_NAME}::${_fg4_lib}
          APPEND PROPERTY INTERFACE_LINK_LIBRARIES XercesC::XercesC)
      endif()
    endif()
  endforeach()
  unset(_fg4_need_tweaks)
  unset(_fg4_lib)
endif()

unset(_fg4_libs)
