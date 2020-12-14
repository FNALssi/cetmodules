.. cmake-manual-description: Code-dep-graph Command-Line Reference

code-dep-graph(1)
*****************

Usage
=====

.. parsed-literal::

     code-dep-graph [<options>] [-d <topdir>] [-o <outfile>]

Options
-------

  -D
     Show external dependencies also. Specify twice to include external
     dependencies that would usually be ignored (like sys/).

  -h
     This help.

  -v
     Verbose output.

Post-processing
---------------

Output is in the graphviz, "dot" format. Examples of post-processing:

* Basic graph (could be complicated).

  dot -Tpng -o out.png in.dot

* Apply transitive reduction to graph prior to main processing.

  tred in.dot | dot -Tpng -o out.dot

