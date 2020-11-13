########################################################################
# UseCPack.cmake
#
# Configure CPack to produce an appropriate installation archive for the
# selected build type.
########################################################################

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

if (CMAKE_CURRENT_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
  # Avoid double-dipping with older project CMakeLists.txt files.
  if (WANT_UPS)
    install(CODE "\
# Detect misplaced installs from older, cetbuildtools-using packages.
  if (product AND version AND IS_DIRECTORY \"\${CMAKE_INSTALL_PREFIX}/\${product}/\${version}\")
    message(WARNING \"Fixing faulty install: remove \${product}/\${version}/ \
from install paths.\")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar c -- .
                    COMMAND ${CMAKE_COMMAND} -E tar xv -C ../..
                    WORKING_DIRECTORY \"\${CMAKE_INSTALL_PREFIX}\"
                    COMMAND_ERROR_IS_FATAL)
  endif()

  # We need to reset CMAKE_INSTALL_PREFIX to its original value at this
  # time.
  get_filename_component(CMAKE_INSTALL_PREFIX \"\${CMAKE_INSTALL_PREFIX}\" DIRECTORY)
  get_filename_component(CMAKE_INSTALL_PREFIX \"\${CMAKE_INSTALL_PREFIX}\" DIRECTORY)\
")
  endif()
  if (CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    if (CETMODULES_CONFIG_CPACK_MACRO)
      cmake_language(CALL ${CETMODULES_CONFIG_CPACK_MACRO})
      include(CPack)
    else()
      message(WARNING "automatic configuration of CPack is supported only for WANT_UPS builds at this time")
    endif()
  else()
    message(VERBOSE "\
automatic configuration of CPack is not supported for subprojects at \
this time ($(CMAKE_PROJECT_NAME) -> ${PROJECT_NAME}\
")
  endif()
else()
  message(WARNING "Invocation of UseCPack.cmake is supported from top-level project CMakeLists.txt ONLY")
endif()
cmake_policy(POP)
