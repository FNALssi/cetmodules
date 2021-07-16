include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

macro(mfPlugin NAME)
  basic_plugin(${NAME} mfPlugin ${ARGN}
    LIBRARIES REG art_plugin_types::mfPlugin)
endmacro()

cmake_policy(POP)
