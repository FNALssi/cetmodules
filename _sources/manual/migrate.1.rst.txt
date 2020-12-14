.. cmake-manual-description: cetbuildtools -> cetmodules migration utility script

.. role:: inline-cmake(code)
   :language: cmake

migrate(1)
**********

.. program:: migrate

Synopsis
========

:program:`migrate`\  [:ref:`option... <migrate-options>`] [``--``] :option:`<pkg-top>`...

:program:`migrate`\  :option:`--clean-info` [``--``] :option:`<pkg-top>`...

:program:`migrate`\  :option:`--help`\|\ :option:`-h`\|\ :option:`-?`

:ref:`Options <migrate-options>`:
   | :option:`-n`\|\ :option:`--dry-run`
   | :option:`-q`\|\ :option:`--quiet`
   | :option:`-v`\|\ :option:`--verbose`

Description
===========

:program:`migrate` will convert a Cetbuildtools package to use
Cetmodules |version|, or refresh and annotate an existing cetmodules
package.

Many changes to the CMake code and various configuration files of the
specified packages will be made automatically. Other necessary or
recommended changes will be flagged by means of inline comments
:inline-cmake:`### MIGRATE-ACTION...`.

Arguments
=========

.. option:: <pkg-top>

   Path to the top-level directory of a package using Cetbuildtools or
   Cetmodules.

.. _migrate-options:

Options
=======

.. option:: --help, -h, -?

   Long-form help.

.. option:: --clean-info

   If specified, a "normal" migration will *not* be performed; instead,
   CMake files will be cleaned of any existing non-"ACTION" tags.

.. option:: --flags-only

   During a migration, only "ACTION" tags will be added to CMake files.

.. option:: -n, --dry-run

   Do not change, replace or remove files under :option:`<pkg-top>`. Any
   proposed changes or annotations to a file will be written to a new
   file with ``.new`` appended to the name of the original.

.. option:: -q, --quiet

   Show fewer messages of type ``INFO``.

.. option:: -v, --verbose

   Show messages of type ``VERBOSE``.

Notes
=====

*  Any files to be removed or altered will be backed-up to
   :file:`{<pkgtop>}/migrate-backup-{timestamp}`. New files will be
   created with a ".new" extension before being moved to replace their
   original unless B<-n> has been specified.

*  Any line which has been flagged for action (:inline-cmake:`###
   MIGRATE-ACTION-...`) may be ignored on future invocations of
   :program:`migrate` by replacing the annotation with,
   :inline-cmake:`### MIGRATE-NO-ACTION`.

* In spite of the backup, it is recommended that the current state of
  the package be checked in to a repository or otherwise saved prior to
  invoking :program:`migrate` for easy restoration in case of suboptimal
  results.

