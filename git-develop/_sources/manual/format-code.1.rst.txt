.. cmake-manual-description: run clang-format on a directory within a package.

format-code(1)
**************

.. program:: format-code

Synopsis
========

:program:`format-code` \ :option:`-d`\|\ :option:`--directory` ``<directory>`` [:option:`-n`] [:option:`-v`] [:option:`--use-available`]

Description
===========

:program:`format-code` will run :program:`format-code` recursively on a directory of a git repository's working tree, optionally committing the result.

Options
-------

.. option:: -d <directory>, --directory <directory>

   Top-level directory to which to apply formatting.

.. option:: -n, --dry-run

   No changes will be made to source code.

.. option:: -v, --verbose

.. option:: --use-available

   Use the version of :program:`clang-format` already set up for use.
