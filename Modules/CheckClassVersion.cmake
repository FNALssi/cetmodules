cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

set(CCV_DEFAULT_RECURSIVE FALSE
  CACHE BOOL "Default setting for recursive checks by checkClassVersion (may be time-consuming)."
  )

function(_verify_pyroot)
  if (NOT DEFINED CACHE{_CheckClassVersion_ENABLED})
    set(_CheckClassVersion_ENABLED FALSE CACHE INTERNAL
      "Activation status of ROOT ClassVersion checking via PYROOT")
    execute_process(COMMAND root-config --features
      RESULT_VARIABLE CCV_ROOT_CONFIG_OK
      OUTPUT_VARIABLE CCV_ROOT_CONFIG_OUT
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    if(NOT CCV_ROOT_CONFIG_OK EQUAL 0)
      message(FATAL_ERROR "Could not execute root-config successfully to interrogate configuration: exit code ${CCV_ROOT_CONFIG_OK}")
    endif()
    string(REPLACE " " ";" CCV_ROOT_FEATURES "${CCV_ROOT_CONFIG_OUT}")
    if("pyroot" IN_LIST CCV_ROOT_FEATURES OR "python" IN_LIST CCV_ROOT_FEATURES)
      set_property(CACHE _CheckClassVersion_ENABLED PROPERTY VALUE TRUE)
    else()
      message("WARNING: The version of root against which we are building currently has not been built "
        "with python support: ClassVersion checking is disabled.")
    endif()
  endif()
endfunction()

function(check_class_version)
  _verify_pyroot()
  if (NOT $CACHE{_CheckClassVersion_ENABLED})
    return()
  endif()
  cmake_parse_arguments(PARSE_ARGV 0 CCV
    "UPDATE_IN_PLACE;RECURSIVE;NO_RECURSIVE"
    "CLASSES_DEF_XML"
    "ENVIRONMENT;LIBRARIES;REQUIRED_DICTIONARIES")
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
  if (NOT CCV_CLASSES_DEF_XML)
    set(CCV_CLASSES_DEF_XML ${CMAKE_CURRENT_SOURCE_DIR}/classes_def.xml)
  endif()
  IF(CCV_ENABLED)
    set(ASAN_OPTIONS "detect_leaks=0:new_delete_type_mismatch=0")
    if ("$ENV{ASAN_OPTIONS}")
      string(PREPEND ASAN_OPTIONS "$ENV{ASAN_OPTIONS}:")
    endif()
    set(CMD_ENV "ASAN_OPTIONS=${ASAN_OPTIONS}")
    if (CETB_SANITIZER_PRELOADS)
      list(APPEND CMD_ENV "LD_PRELOAD=$ENV{LD_PRELOAD} ${CETB_SANITIZER_PRELOADS}")
    endif()
    foreach(ev IN ITEMS LSAN_OPTIONS MSAN_OPTIONS TSAN_OPTIONS UBSAN_OPTIONS)
      if (DEFINED ENV{${ev}})
        list(APPEND CMD_ENV "${ev}=$ENV{${ev}}")
      endif()
    endforeach()
    # Add the check to the end of the dictionary building step.
    add_custom_command(OUTPUT ${dictname}_dict_checked
      COMMAND ${CMAKE_COMMAND} -E env ${CMD_ENV} ${CCV_ENVIRONMENT}
      $<TARGET_FILE:cetmodules::checkClassVersion> ${CCV_EXTRA_ARGS}
      -l "$<TARGET_LINKER_FILE:${dictname}_dict>"
      -x ${CCV_CLASSES_DEF_XML}
      -t ${dictname}_dict_checked
      COMMENT "Checking class versions for ROOT dictionary ${dictname}"
      DEPENDS ${dictname}_dict cetmodules::checkClassVersion
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

cmake_policy(POP)
