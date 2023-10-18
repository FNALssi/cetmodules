.. cmake-manual-description: output filter for test reference comparisons

filter-output(1)
****************

.. program:: filter-output

Synopsis
========

.. parsed-literal::

   ``<my-test-program>`` ``[<arg> ...]`` | :program:`filter-output`

Description
===========

\ :program:`filter-output` is a filter, receiving input on ``STDIN`` and
producing output on ``STDOUT``.

\ :program:`filter-output` is usually invoked as part of a test
configured using the :command:`cet_test` command in order to sanitize
the test-output to improve its suitability for comparison with a
reference to (e.g.) detect regressions. It may also be used in order to
produce such references for later comparison.

Details
=======

The following transformations are performed on
:program:`filter-output`'s input:

* Recognizable date/time formats -> ``<date-time>``.

* Variable length separator/filler strings of at least 15 consecutive
  occurrences of the same symbol (``-``, ``=``, ``.``, ``*``, ``~`` or
  ``/``) -> ``<separator (<char>)>``.

* Platform identifiers starting with ``Darwin`` or ``Linux`` ->
  ``<platform>``.

.. admonition:: `art <https://art.fnal.gov/>`_
   :class: admonition-app

   * Absolute paths to source files ending in
     ``_(plugin|module|service|tool).cc`` are truncated to ``<path>/``.

   * ``TimeReport`` values -> ``<duration>``

   * ``MemReport`` sections are elided.

Examples
========

* .. code-block:: console

     $ my-test | filter-output >my-test-ref.out 2>my-test-ref.err

* .. parsed-literal::

     :command:`cet_test <cet_test(HANDBUILT)>`\ (my-test HANDBUILT TEST_EXEC my-test REF my-test-ref.out my-test-ref.err)
