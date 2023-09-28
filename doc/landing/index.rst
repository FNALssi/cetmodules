##########################################
Documentation
##########################################


.. meta::
   :google-site-verification: mWu4AzUH2LiVvIlufi6W4Goyu4kKB0pKde6qTj8XYoU

.. <--include-top-start-->

Overview
========

Cetmodules is, at its core, a wrapper around low-level CMake functionality
intended to fulfill the following goals:

#. Reduce the number of CMake commands necessary to accomplish common
   tasks, including for "modern" (v3+) CMake functionality such as
   `pseudo-targets <https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html#pseudo-targets>`_.
#. Generate CMake config files automatically, taking care of the
   bookkeeping necessary to handle transitive dependencies with minimum
   user intervention.
#. Provide domain-specific build tools useful to scientists utilizing
   the "Art"\ :abbr:`HEP (High Energy Physics)` analysis framwork to
   process data from (mainly) neutrino experiments.

Target user base
----------------

Cetmodules was developed as a backward-compatible replacement for an
earlier tool satisfying the latter goal above called "cetbuildtools,"
which was intimately tied to a `domain-specific package management
system
<https://cdcvs.fnal.gov/redmine/projects/ups/wiki/Documentation>`_
called |UPS|. Notwithstanding its origins, Cetmodules is intended to be
a general build tool—although someone from outside the original target
community might encounter some puzzling terminology, vestigial
functionality, or other endearing quirks.

Compatibility
-------------

.. <--include-top-end-->

Reference Documentation
=======================

.. button-link:: latest/
   :expand:
   :outline:
   :color: primary

   Latest reference documentation (with links to other versions)

.. <--include-bottom-start-->

.. only:: html or text

   Release Notes
   =============

   .. toctree::
      :maxdepth: 1

.. /release_notes/v3/index.rst

License
=======

Support
=======

Contributing
============

.. <--include-bottom-end-->
