include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

function(source_plugin NAME)
  set(deps art::Framework_IO_Sources art::Framework_Core)
  if (NOT TARGET art::Framework_IO_Sources)
    set(deps
      art_Framework_IO_Sources
      art_Framework_Core
      art_Framework_Principal
      art_Persistency_Common
      art_Persistency_Provenance
      art_Utilities
      canvas
      fhiclcpp
      cetlib
      cetlib_except
      Boost::filesystem)
  endif()
  basic_plugin(${NAME} "source" NOP ${ARGN}
    LIBRARIES PLUGIN "${deps}")
endfunction()

cmake_policy(POP)
