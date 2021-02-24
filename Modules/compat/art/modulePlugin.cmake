include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

function(module_plugin NAME)
  set(deps art_plugin_support::module_macros art::Framework_Core)
  if (NOT TARGET art_plugin_support::module_macros)
    set(deps
      art_Framework_Core
      art_Framework_Principal
      art_Framework_Services_Registry
      art_Persistency_Common
      art_Persistency_Provenance
      art_Utilities
      canvas
      fhiclcpp
      cetlib
      cetlib_except
      Boost::filesystem)
  endif()
  basic_plugin(${NAME} "module" NOP ${ARGN}
    LIBRARIES PLUGIN "${deps}")
endfunction()

cmake_policy(POP)
