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

Information specific to legacy compatibility and domain-specific
features will be marked with appropriate admonitions:

.. admonition:: cetbuildtools
   :class: admonition-legacy

   You will only care about this information if you are porting code
   from cetbuidltools.

... or:

.. admonition:: :abbr:`HEP`
   :class: admonition-domain

   This is a Find module specific to HEP.

... or:

.. admonition:: ROOT
   :class: admonition-app

   This is a feature that supports building code using ROOT.

Compatibility
-------------

* Cetmodules requires CMake >= |CMAKE_MIN_VERSION|.

.. admonition:: cetbuildtools
   :class: admonition-legacy

   * Cetmodules >= 2.10.00 is backward-compatible with cetbuildtools >=
     7.00.00.

   Unported cetbuildtools code will generate many deprecation and other
   warnings. To temporarily disable these warnings, add
   ``-DCET_WARN_DEPRECATED:BOOL=NO`` to your CMake configuration
   command-line options.

   Some cetbuildtools-style behavior is different or disabled in
   Cetmodules by default either because it is inefficient, inflexible or
   against modern best practice. Examples include use of |UPS|-specific
   variables or terminology, or library-path variables instead of
   targets in dependency lists. These can be enabled on a per-package
   basis by adding ``-D{project}_OLD_STYLE_CONFIG_VARS:BOOL=YES`` to
   your CMake configuration command-line options.
