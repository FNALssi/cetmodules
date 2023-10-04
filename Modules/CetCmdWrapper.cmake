#[================================================================[.rst:
X
-
#]================================================================]
cmake_minimum_required(VERSION 3.20...3.27 FATAL_ERROR)

set(idx 1)
if (NOT CMD)
  message(FATAL_ERROR "vacuous command")
endif()
string(REPLACE " " ";" CMD_ARGS "${CMD_ARGS}")
execute_process(COMMAND ${CMD} ${CMD_ARGS}
  RESULT_VARIABLE cmd_status
  COMMAND_ECHO STDERR)

if (cmd_status EQUAL 0)
  if (CMD_DONE_STAMP)
    file(TOUCH "${CMD_DONE_STAMP}")
  endif()
else() # Failure.
  if (CMD_DONE_STAMP)
    file(REMOVE "${CMD_DONE_STAMP}")
  endif()
  if (CMD_DELETE_ON_FAILURE)
    file(REMOVE_RECURSE "${CMD_DELETE_ON_FAILURE}")
  endif()
  set(err_msg "command failed: ${CMD}")
  if (cmd_status MATCHES "^-?[0-9]+$")
    string(APPEND err_msg " with status ${cmd_status}")
  else()
    string(APPEND err_msg "${cmd_status}")
  endif()
  message(FATAL_ERROR "${err_msg}")
endif()
