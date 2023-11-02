CETMODULES_CURRENT_PROJECT_VARIABLE_PREFIX
------------------------------------------

.. admonition:: cetbuildtools
   .. rst-class:: admonition-legacy

   A variable whose value is generated from the SHA256-hashed value of
   the full physical path to the current project's top level
   :filename:`CMakeLists.txt`.

   Used by ``buildtool`` and other cetbuildtools-compatibility functions
   to set initial values for :manual:`project variables
   <cetmodules-project-variables(7)>` before the project's name (as
   defined to CMake via :command:`project()
   <cmake-ref-current:command:project>`) is known.

   It is not necessary for users of Cetmodules (even those requiring
   compatibility with cetbuildtools and UPS) either to use this
   variable, or to know its contents at any time. However, it is useful
   to know of its existence to understand the precedence rules governing
   the initial value of a project variable as defined by
   :command:`project_variable`.
