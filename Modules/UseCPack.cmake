########################################################################
# UseCPack.cmake
#
# Configure CPack to produce an appropriate installation archive for the
# selected build type.
########################################################################

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

if (CETMODULES_CONFIG_CPACK_MACRO)
  cmake_language(CALL ${CETMODULES_CONFIG_CPACK_MACRO})
  include(CPack)
else()
  message(WARNING "automatic configuration of CPack is supported only for WANT_UPS builds at this time")
endif()

cmake_policy(POP)
