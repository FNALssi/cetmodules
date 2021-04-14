#[================================================================[.rst:
X
=
#]================================================================]
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetRegisterExportSet)

function (cet_register_export_name EXPORT_NAME)
  warn_deprecated("cet_register_export_name()" NEW "cet_register_export_set()")
  cet_register_export_set(SET_NAME ${${EXPORT_NAME}}
    SET_VAR ${EXPORT_NAME}
    NAMESPACE ${ARGV1})
  set(${EXPORT_NAME} ${${EXPORT_NAME}} PARENT_SCOPE)
endfunction()

cmake_policy(POP)
