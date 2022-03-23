.. cmake-manual-description: build utility script for UPS-compatible builds.

buildtool(1)
************

.. program:: buildtool

Synopsis
========

:program:`buildtool`\  [:ref:`mode-option... <buildtool-mode-options>`\|\ :ref:`combo-option... <buildtool-combo-options>`\]
[:ref:`misc-options <buildtool-misc-options>`\]
[``--`` [:ref:`CMake build options <buildtool-cmake-build-options>`\]
[``--`` :ref:`generator options <buildtool-generator-options>`\]]

:program:`buildtool`\  :option:`--help`\|\ :option:`-h`

:program:`buildtool`\  :option:`--usage`

:ref:`Exclusive mode options <buildtool-mode-options>`:
   :option:`-C`\|\ :option:`--cmake-only`
   :option:`-A`\|\ :option:`--all`
   :option:`--info`

:ref:`Other mode options <buildtool-mode-options>`:
   :option:`-b`\|\ :option:`--build`
   :option:`-i`\|\ :option:`--install`
   :option:`-p`\|\ :option:`--package`
   :option:`--sc`\|\ :option:`--short-circuit`
   :option:`-t`\|\ :option:`--test`

:ref:`Combo mode options <buildtool-combo-options>`:
   :option:`-R`\|\ :option:`--release`
   :option:`-T`\|\ :option:`--test-all`

:ref:`Miscellaneous options <buildtool-misc-options>`:
   | :option:`-D\<CMake-definition>`\ ...
   | :option:`-E`\|\ :option:`--export-compile-commands`
   | :option:`-G\<CMake-generator-string>`\|\ :option:`--generator \<make|ninja>[:\<secondary-generator>] <--generator>`
   | :option:`-I`\|\ :option:`--install-prefix \<ups-top-dir> <--install-prefix>`
   | :option:`--L \<label-regex> <--L>`
   | :option:`--LE \<label-regex> <--LE>`
   | :option:`-c`\|\ :option:`--clean`
   | :option:`--clean-logs`
   | :option:`-X\<c|b|t|i|p> \<arg>[,\<arg>]... <-X<c|b|t|i|p>>`
   | :option:`--cmake-debug`
   | :option:`--cmake-trace`
   | :option:`--cmake-trace-expand`
   | :option:`--deleted-header[s] \<header>[,\<header>]... <--deleted-header[s]>`
   | :option:`-f`\|\ :option:`--force-top`
   | :option:`-g \<dot-file> <-g>`\|\ :option:`--graphviz=\<dot-file> <--graphviz>` [:option:`--gfilt[=\<gfilt-opt>[,\<gfilt-opt>]...] <--gfilt>`\]
   | :option:`-j` ``#``
   | :option:`-l`\|\ :option:`--log`\ [``=<log-file>``\]|\ :option:`--log-file`\[``=<log-file>``\]
   | :option:`--no-pc`\|\ :option:`--no-preset-configure`
   | :option:`--pc`\|\ :option:`--preset-configure` ``<preset-name>``
   | :option:`-q`\|\ :option:`--quiet`
   | :option:`-s`\|\ :option:`--subdir`
   | :option:`--tee`
   | :option:`--test-labels`\|\ :option:`--labels`\|\ :option:`--test-groups`\|\ :option:`--groups` ``<group>``\[``<;|,><group>``\]...
   | :option:`-v`\|\ :option:`--verbose`

Description
===========

Despite the bewildering array of available options, :program:`buildtool` is intended to simplify the task of building and debugging code, producing packages for use with `UPS <https://cdcvs.fnal.gov/redmine/projects/ups/wiki/Documentation>`_.

The process of producing a software package from its source consists of multiple steps:

* Configuration
* Build
* Test
* Installation
* Packaging

:program:`buildtool` assumes one is using `CMake <https://cmake.org>`_ and the macros and functions defined within cetmodules inside a :abbr:`UPS` environment to produce a :abbr:`UPS` package. This in turn implies the existence of files :file:`ups/{product}.table` :file:`ups/product_deps`, and file:`ups/setup_for_development`, the latter of which has already been sourced prior to invoking :program:`buildtool`.

.. note:: :abbr:`UPS` is **deprecated**, in addition to being practically unknown outside certain areas of experimental particle physics. If your package is not already reliant on :abbr:`UPS`, you are *strongly* encouraged not to start: the macros and functions provided by cetmodules to aid building and packaging your code do not need :abbr:`UPS`, or any of its accoutrements.

   If your package *does* rely on :abbr:`UPS`, you are encouraged to investigate :program:`migrate` to facilitate evolving your package to no longer rely on UPS,becoming buildable via more general means such as `Spack <https://spack.readthedocs.io/>`_, *while still being buildable with and for the* :abbr:`UPS` *environment*.

Options
=======

.. _buildtool-mode-options:

Modes
-----

If any of :option:`--info`, :option:`--cmake-only`, or :option:`--all` are set, they override all other mode options.

If any of the other options are selected, they will be executed in their natural order *after* the CMake stage (which is always executed
in the :envvar:`CETPKG_BUILD` directory) unless :option:`--short-circuit` is used.

Exclusive mode options
^^^^^^^^^^^^^^^^^^^^^^

.. option:: -A, --all

   Execute all stages.

.. option:: -C, --cmake-only

   Execute *only* the CMake stage.

.. option:: --info

  If already configured (CMake has been run at least once since the last clean), give some basic information about the package, then exit.

Other mode options
^^^^^^^^^^^^^^^^^^

.. option:: -b, --build

   Execute the build stage from the current directory. This is default if no other mode option is specified.

   .. note:: implies execution of the configuration step unless combined with :option:``--short-circuit``.

.. option:: -i, --install

   Execute the install stage from :envvar:`CETPKG_BUILD`. CMake's generated build procedure will ensure that all build targets are up to date, so an accompanying explicit :option:`--build` option is unnecessary.

.. option:: -p, --package

  Execute the package stage from CETPKG_BUILD to create a binary installation archive. As for :option:`--install`, CMake's generated build procedure will ensure that all build targets are up to date so an accompanying explicit :option:`--build` option is unnecessary. Note that :option:`--package` does *not* imply :option:`--install`: the two operations are independent.

.. option:: -t, --test

   Execute configured tests with :program:`ctest` from the current directory. Implies :option:`--build`.

.. _buildtool-combo-options:

Combo options
-------------

.. option:: -R, --release

   Equivalent to :option:`-t` :option:`--test-labels=RELEASE <--test-labels>`.

.. option:: -T, --test-all

   Equivalent to :option:`-t` :option:`--test-labels=ALL <--test-labels>`.

.. _buildtool-misc-options:

Miscellaneous options
---------------------

.. option:: -D<CMake-definition>

   Pass definitions to the invocation of the CMake stage. A warning shall be issued if this option is specified but the CMake stage is not to be executed.

.. option:: -E, --export-compile-commands

   Equivalent to :option:`-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON <-D<CMake-definition>>`. Useful for (e.g.) :program:`clang-tidy`.

.. option:: -G<CMake-generator-string>

   Pass the specified CMake generator string through to CMake. Note that, at this time, only the "Unix Makefiles" and "Ninja" generators are supported by buildtool. Any secondary generator specification is passed through unexamined.

.. option:: -I <ups-top-dir>, --install-prefix <ups-top-dir>

   Specify the location of the private (or public) UPS products area into  which to install the package if install is requested. Overrides the :envvar:`CETPKG_INSTALL` environment variable and anything already known to CMake.

.. option:: --L <label-regex>, --LE <label-regex>

   Per :program:`ctest`, include (:option:`--L`) or exclude (:option:`--LE`) labels by CMake regular expression. Both options are mutually exclusive with :option:`--test-labels`, :option:`-T`, and :option:`-R`, but not with each other. Specifying one of these options implies :option:`-t`.

.. option:: -X<c|b|t|i|p> <arg>[,<arg>]+[,--,<non-option-arg>[,<non-option-arg>]+]

   E\ ``X``\ tra arguments to be passed to the ``C``\ onfigure, ``b``\ uild, ``t``\ est, ``i``\ nstall, or ``p``\ ackage stages. ``<arg>``\ s will be added at the end of option arguments, while ``<non-option-arg>``\ s will be added at the end of non-option arguments.

.. option:: -c, --clean

   Remove CMake-generated files and caches and other build products.

.. option:: --clean-logs

   Remove ``.log`` files in the :envvar:``CETPKG_BUILD`` top directory.

.. option:: --cmake-debug, --cmake-trace, --cmake-trace-expand

   Add the corresponding CMake debug option (:ref:`--debug-output, --trace, --trace-expand <cmake-ref-current:cmake options>`, respectively)  to the command-line options for the configure stage.

   .. seealso:: :option:`-Xc <-X<c|b|t|i|p>>`.

.. option:: --deleted-header[s] <header>[,<header>]+

   Indicate that named headers have been removed from the source, to allow removal and regeneration of dependency files containing references to same.

.. option:: -f, --force-top

  Force build and test stages (if applicable) to be executed from the top level :envvar:`CETPKG_BUILD` area. Otherwise these stages will execute  within the context of the user's current directory at invocation if it is below :envvar:`CETPKG_BUILD`. :option:`--force-top` is incompatible with :option:`--subdir`. In any event, any relative or unqualified log file will be output relative to the user's current directory at the time buildtool was
  invoked.

.. option:: -g <dot-file>, --graphviz=<dot-file>

  Ask CMake to produce a code dependency graph in graphviz (.dot) format.

  Note that CMake can only tell you about the dependencies about which
  it knows. Libraries must have their dependencies resolved at library
  production time (NO_UNDEFINED) in order for the information to be
  complete.

.. option:: --gfilt[=<gfilt-opt>[,<gfilt-opt>]...]

   Filter the graphviz output from CMake through :program:cmake-graphviz-filt, with the following options:

   .. option:: [no-]exes
      :noindex:

      With or without executables shown (default without).

   .. option:: [no-]dicts
      :noindex:

      With or without dictionary and map libraries (default without).

   .. option:: [no-]extlibs
      :noindex:

      With or without extlibs shown (default without).

   .. option:: [no-]short-libnames
      :noindex:

      Any fully-specified library pathnames are shortened to their basenames (default long).

   .. option:: [no-]test-tree
      :noindex:

      With or without libraries and execs from the test directory hierarchy (default without).

   .. option:: [no-]tred
      :noindex:

      With or without transitive dependency reduction (default with).

   Multiple options should be comma-separated. Note that all of these options may be specified in :file:`~/.cgfrc` for the same effect (command-line overrides).

.. option:: --generator <generator>[:<secondary-generator>]

   User-friendly way to specify the generator. Currently supported values are "make" and "ninja" (default make). If <secondary-generator> (e.g. CodeBlocks) is specified it will be passed through as-is.

.. option:: -h, --help

   Long-form help.

.. option:: -j <#>

   Specify the level of parallelism for stages for which it is appropriate (overrides :envvar:`CETPKG_J` if specified).

.. option:: -l, --log[=<log-dir-or-filepath>], --log-file[=<log-dir-or-filepath>]

   All build output is redirected to the specified log-file, or one with a default name if no other is specified. Unless :option:`--quiet` is also specified, stage information will still be printed to the screen---though see :option:`--tee` below. Note that the short variant does not accept an argument: a log filename will be generated. The long forms should use ``=`` to separate the option from their argument.

.. option:: --no-pc, --no-preset-configure

   Do not use a predefined CMake configure preset.

   .. seealso:: :option:`--pc`

.. option:: --pc <preset-name>, --preset-configure <preset-name>

   Use the named `CMake configure preset <https://cmake.org/cmake/help/v3.22/manual/cmake-presets.7.html#configure-preset>`_ instead of CMake definitions genereated from :file:`ups/product_deps`. Absent this option or :option:`--no-pc`, the preset ``for_UPS`` will be used if defined in :envvar:`CETPKG_SOURCE`\ /:file:`CMakePresets.json`.

.. option:: -q, --quiet

   Suppress all non-error output to the screen (but see :option:`--tee` below). A log file will still be written as normal if so specified.

.. option:: -s <subdir>, --subdir <subdir>

   Execute build and install stages from the context of ``<subdir>``, which will be interpreted relative to :envvar:`CETPKG_BUILD`. Incompatible with :option:`--force-top`. ``<subdir>`` will be used in preference to the current user directory, even if the latter is a subdirectory of :envvar:`CETPKG_BUILD`.

.. option:: --tee

   Write to a log file (either as specified by :option:`--log` or the default), but copy output to the screen also: :option:`--quiet` is overridden by this option.

.. option:: --test-labels=<group>[<;|,><group>]..., --labels=<group>[<;|,><group>]..., --test-groups=<group>[<;|,><group>]..., --groups=<group>[<;|,><group>]+

   Specify optional CMake test labels to execute. Test selection is done at :program:`ctest` invocation time. If this option is activated but tests are not to be run, a warning shall be issued. If no labels are selected, then ``DEFAULT`` is selected. A value of ``ALL`` is substituted with all known test labels. A leading ``-`` for a label will lead to its explicit exclusion. See also :option:`--test-all`, and :option:`--release`. Mutually-exclusive with :option:`--L` and :option:`--LE`.

.. option:: --usage

   Short help.

.. option:: -v, --verbose

   Extra information about the commands being executed at each step.

.. option:: --short-circuit, --sc

   Execute only the specified stages and not those that might be implied.

.. _buildtool-cmake-build-options:

CMake build options
--------------------

Any options or arguments specified after a single instance of ``--``\ ---or between two instances of same---will be passed to all stages invoked with ``cmake --build``: the build, install and package stages.

.. _buildtool-generator-options:

Generator options
-----------------

Any options or arguments specified after a second instance of ``--`` will be passed to the configured generator (*e.g.* "UNIX Makefiles" or "Ninja") for the build stage only.

Examples
========

Build, test, install and create a package tarball from scratch with
output to a default-named log file, using parallelism:

 .. code-block:: console

    buildtool -A -c -l -I <install-dir> -j16

As above, but copying output to screen:

 .. code-block:: console

    buildtool -A -c -l --tee -I <install-dir> -j16

The need for the :option:`-I` option may be obviated by defining :envvar:`CETPKG_INSTALL`;
the need for the explicit parallelism may be similarly voided by
defining (*e.g.*) :envvar:`CETPKG_J=16 <CETPKG_J>`.

To build only a particular target within a subdirectory:

 .. code-block:: console

    buildtool --subdir art/Framework/IO/Root -- RootOutput_source.o

To build and test only:

 .. code-block:: console

    buildtool -t -j16

To install and package only:

 .. code-block:: console

    buildtool -i -p -j16

Environment
===========

Required
--------

.. envvar:: CETPKG_BUILD

   The path to the build area. Set by sourcing :manual:`ups/setup_for_development <setup_for_development(7)>`.

.. envvar:: CETPKG_SOURCE

   The path to the source (*i.e.* the top-level :file:`CMakeLists.txt`). Set by sourcing :manual:`ups/setup_for_development <setup_for_development(7)>`.

Optional
--------

.. envvar:: CETPKG_INSTALL

   The installation area (must be a properly-initialized unified-UPS top level directory for the installed products to be usable by UPS). May be overridden by :option:`-I`, but takes precedence over :variable:`CMAKE_INSTALL_PREFIX <cmake-ref-current:variable:CMAKE_INSTALL_PREFIX>`.

.. envvar:: CETPKG_J

   The default level of parallelism for all appropriate steps; may be overridden by ::option::`-j`. If not specified, the default level of parallelism is controlled by the generator (*e.g.* ``UNIX Makefiles`` *vs* ``Ninja``).
