.. cmake-manual-description: generate a bash-completion script from a program's help output.

make_bash_completions(1)
************************

.. program:: make_bash_completions

Synopsis
========

:program:`make_bash_completions` \ :option:`out-file` \ :option:`program` [:option:`user-completions-file`\]

Description
===========

:program:`make_bash_completions` generates a bash-completion script :option:`out-file` for :option:`program`. assuming its help text is formatted according to Boost's program options library, with program options like:

.. parsed-literal::

   --opt1             Non-argument option
   --opt2 arg         Option with argument
   -O [ --opt3 ] arg  Long and short options with argument

Arguments
=========

.. option:: out-file

   Name of the ``bash-completions`` script to be generated.

.. option:: program

   Name of the program (to be found in :envvar:`!PATH`) or its absolute path for which to generate the completions script.

.. option:: user-completions-file

   Path to a file containing explicit completions to add to :option:`out-file`.
