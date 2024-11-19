########################
Cetmodules Documentation
########################

Overview
========

`Cetmodules <https://github.com/FNALssi/cetmodules>`_ is, at its core, a
wrapper around low-level `CMake <https://cmake.org>`_ functionality
intended to fulfill the following goals:

#. Reduce the number of CMake commands necessary to accomplish common
   tasks, including for "modern" (v3+) CMake functionality such as
   `pseudo-targets <https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html#pseudo-targets>`_.
#. Generate CMake config files automatically, taking care of the
   bookkeeping necessary to handle transitive dependencies with minimum
   user intervention.
#. Provide domain-specific build tools useful to scientists utilizing
   the `Art <https://art.fnal.gov/>`_ :abbr:`HEP (High Energy Physics)`
   analysis framwork to process data from (mainly) neutrino experiments.

Target user base
----------------

Cetmodules was developed as a backward-compatible replacement for an
earlier tool ("cetbuildtools") satisfying the latter goal mentioned
above. This was intimately tied to a `domain-specific package management
system
<https://s3.cern.ch/inspire-prod-files-8/8cee9fd8c06a92ebb9d627a5e88a874b>`_
called |UPS|. Notwithstanding its origins, Cetmodules is intended to be
a general build tool—although someone from outside the original target
community might encounter some puzzling terminology, vestigial
functionality, or other endearing quirks.

Documentation notes
-------------------

Information specific to domain-specific features will be marked with an
appropriate admonition:

.. admonition:: :abbr:`HEP`
   :class: admonition-domain

   This information is specific to HEP.

... or:

.. admonition:: ROOT
   :class: admonition-app

   This is a feature that supports building code using ROOT.

Compatibility
-------------

* Cetmodules requires CMake >= |CMAKE_MIN_VERSION|.
* All cetbuildtools compatibility has been removed from Cetmodules
  4.00.00.
