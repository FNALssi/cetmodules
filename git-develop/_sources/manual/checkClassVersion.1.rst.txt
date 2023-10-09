.. cmake-manual-description: Check ROOT dictionary versions and checksums

checkClassVersion(1)
********************

.. program:: checkClassVersion

Synopsis
========

:program:`checkClassVersion` [:option:`-l`\|\ :option:`--lib` ``<library>``]
  | [:option:`-x`\|\ :option:`--xml_file` ``<xml-file>``]
  | [:option:`-g`\|\ :option:`--generate_new`]|[:option:`-G`\|\ :option:`--generate-in-place`]
  | [:option:`--[no-]recursive`]
  | [:option:`-t`\|\ :option:`--timestamp`]

Description
===========

\ :program:`checkClassVersion` is a helper script used by
:command:`check_class_version` to invoke `pyROOT
<https://root.cern/manual/python/>`_ to check ROOT dictionary object
versions and checksums. It should not be necessary to invoke
:program:`checkClassVersion` manually.

Options
=======

.. option:: -l <library>, --lib <library>

   Specify the library to load. If not set, classes will be found by the
   ROOT plugin manager.

.. option:: -x <xml-file>, --xml_file <xml-file>

   Specify the selection XML file describing the classes to be checked
   (default :file:`./classes_def.xml`).
   
.. option:: -g, --generate_new

   Generate a new selection XML file instead of flagging checksum errors
   or changed versions.

.. option:: -G, --generate-in-place

   Update the selection XML file in place and exit with non-zero status.

.. option:: --[no-]recursive

   Enable/disable recursive dictionary checks (default: disable).

.. option:: -t <file>, --timestamp <file>

   Touch ``<file>`` upon sucess.
