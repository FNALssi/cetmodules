include(CMakeParseArguments)

##INCLUDE(CheckUpsVersion)

set(CCV_DEFAULT_RECURSIVE FALSE
  CACHE BOOL "Default setting for recursive checks by checkClassVersion (may be time-consuming)."
  )

EXECUTE_PROCESS(COMMAND root-config --has-python
  RESULT_VARIABLE CCV_ROOT_CONFIG_OK
  OUTPUT_VARIABLE CCV_ENABLED
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

IF(NOT CCV_ROOT_CONFIG_OK EQUAL 0)
  MESSAGE(FATAL_ERROR "Could not execute root-config successfully to interrogate configuration: exit code ${CCV_ROOT_CONFIG_OK}")
ENDIF()

IF(NOT CCV_ENABLED)
  MESSAGE("WARNING: The version of root against which we are building currently has not been built "
    "with python support: ClassVersion checking is disabled."
    )
ENDIF()

function(check_class_version)
  cmake_parse_arguments(CCV
    "UPDATE_IN_PLACE;RECURSIVE;NO_RECURSIVE"
    ""
    "LIBRARIES;REQUIRED_DICTIONARIES"
    ${ARGN}
    )
  IF(CCV_LIBRARIES)
    MESSAGE(FATAL_ERROR "LIBRARIES option not supported at this time: "
      "ensure your library is linked to any necessary libraries not already pulled in by ART.")
  ENDIF()
  if (CCV_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unparsed arguments: ${CCV_UNPARSED_ARGUMENTS}")
  endif()
  IF(CCV_UPDATE_IN_PLACE)
    SET(CCV_EXTRA_ARGS ${CCV_EXTRA_ARGS} "-G")
  ENDIF()
  if(CCV_RECURSIVE)
    set(CCV_EXTRA_ARGS ${CCV_EXTRA_ARGS} "--recursive")
  elsif (CCV_NO_RECURSIVE)
    set(CCV_EXTRA_ARGS ${CCV_EXTRA_ARGS} "--no-recursive")
  elseif (CCV_DEFAULT_RECURSIVE)
    set(CCV_EXTRA_ARGS ${CCV_EXTRA_ARGS} "--recursive")
  else()
    set(CCV_EXTRA_ARGS ${CCV_EXTRA_ARGS} "--no-recursive")
  endif()
  IF(NOT dictname)
    MESSAGE(FATAL_ERROR "CHECK_CLASS_VERSION must be called after BUILD_DICTIONARY.")
  ENDIF()
  IF(CCV_ENABLED)
    # Add the check to the end of the dictionary building step.
    add_custom_command(OUTPUT ${dictname}_dict_checked
      COMMAND checkClassVersion ${CCV_EXTRA_ARGS}
      -l ${LIBRARY_OUTPUT_PATH}/lib${dictname}_dict
      -x ${CMAKE_CURRENT_SOURCE_DIR}/classes_def.xml
      -t ${dictname}_dict_checked
      COMMENT "Checking class versions for ROOT dictionary ${dictname}"
      DEPENDS ${LIBRARY_OUTPUT_PATH}/${CMAKE_SHARED_LIBRARY_PREFIX}${dictname}_dict${CMAKE_SHARED_LIBRARY_SUFFIX}
      )
    add_custom_target(checkClassVersion_${dictname} ALL
      DEPENDS ${dictname}_dict_checked)
    # All checkClassVersion invocations must wait until after *all*
    # dictionaries have been built.
    add_dependencies(checkClassVersion_${dictname} BuildDictionary_AllDicts)
    if (CCV_REQUIRED_DICTIONARIES)
      add_dependencies(${dictname}_dict ${CCV_REQUIRED_DICTIONARIES})
    endif()
  ENDIF()
endfunction()
