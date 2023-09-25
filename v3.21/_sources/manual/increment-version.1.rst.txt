.. cmake-manual-description: increment the current version of a cetmodules-using package.

increment-version(1)
********************

.. program:: increment-version

Synopsis
========

:program:`increment-version`\  :ref:`mode <increment-version-modes>` [:ref:`options <increment-version-options>`\] [``--``\] [:option:`package-loc`\]

:program:`increment-version`\  :option:`--help`\|\ :option:`-h`\|\ :option:`-?`

Description
===========

:program:`increment-version` will increment the current version of a cetmodules-using package. Optionally find all other packages where said package is listed as a dependency and update the required version.

.. deprecated:: 2.0

   This script is deprecated, as it operates only on unmigrated sources where the version has *not* been migrated to the :command:`project() <cmake-ref-current:command:project>` call in the top-level :file:`CMakeLists.txt`\ .

Arguments
=========

.. option:: package-loc

   Path to top directory of package whose version should be bumped.

Options
=======

.. _increment-version-modes:

Modes
-----

Precisely one mode type should be specified (although :option:`-U` may be specified multiple times).

.. option:: -M, --major

   Increment the major version number, zeroing all used subordinate version designators.

.. option:: -m, --minor

   Increment the minor version number, zeroing all used subordinate version designators.

.. option:: -u, --micro

   Increment the micro version number, resetting any patch number.

.. option:: -p, --patch

   Increment the patch number.

.. option:: --update-only <package>,<version>, -U <package>,<version>

   Do not increment any version numbers; simply navigate the directories specified with the :option:`increment-version --client-dir` option (or ``./`` if not specified) to update any references to the named package(s) to use the specified version(s) thereof.

.. _increment-version-options:

Other Options
-------------

.. option:: --client-dir <package-client-search-path>, -c <package-client-search-path>

   Specify a directory to search for :file:`ups/product_deps` in which to update the set-up versions of the updated product(s); or those of products specified with :option:`-U`.

.. option:: --debug, -d

   Debug mode: leave temporary files available.

.. option:: --dry-run, -n

   Do not actually update anything: just say what would be done.

   .. note:: currently unimplemented.

.. option:: --help, -h, -?

   Help and usage information.

.. option:: --tag

   Commit changes to product_deps and tag all updated packages with their new versions.

.. option:: --verbose, -v
