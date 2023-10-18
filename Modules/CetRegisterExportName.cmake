#[================================================================[.rst:
CetRegisterExportName
---------------------

Defines the deprecated function :command:`cet_register_export_name`.

#]================================================================]

include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(CetRegisterExportSet)

#[================================================================[.rst:
.. command:: cet_register_export_name

   Register an export name.

   .. deprecated:: 2.10.00 use :command:`cet_register_export_set`.

   .. code-block:: cmake

      cet_register_export_name(<name> <namespace>)

   Non-option arguments
   ^^^^^^^^^^^^^^^^^^^^

   ``<name>``
     The desired export name.

   ``<namespace>``
     The desired namespace.

   Details
   ^^^^^^^

   Requests ``<name>`` as an export name associated with the specified
   namespace ``<namespace>``.

   The _actual_ registered export name—which may have
   :variable:`CETMODULES_CURRENT_PROJECT_NAME` prepended to it,
   separated by ``_``—shall be returned as the variable ``<name>`` for
   future use by the caller.

#]================================================================]

function (cet_register_export_name EXPORT_NAME)
  warn_deprecated("cet_register_export_name()" NEW "cet_register_export_set()")
  cet_register_export_set(SET_NAME ${${EXPORT_NAME}}
    SET_VAR ${EXPORT_NAME}
    NAMESPACE ${ARGV1})
  set(${EXPORT_NAME} ${${EXPORT_NAME}} PARENT_SCOPE)
endfunction()
