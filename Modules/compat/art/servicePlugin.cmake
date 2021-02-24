include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

function(service_plugin NAME)
  set(deps art_plugin_support::service_macros)
  if (NOT TARGET ${deps})
    set(deps
      art_Framework_Services_Registry
      art_Persistency_Common
      art_Utilities
      canvas
      fhiclcpp
      cetlib
      cetlib_except
      Boost::filesystem)
  endif()
  basic_plugin(${NAME} "service" NOP ${ARGN}
    LIBRARIES PLUGIN "${deps}")
endfunction()

cmake_policy(POP)
