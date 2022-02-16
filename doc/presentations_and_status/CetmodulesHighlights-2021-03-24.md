---
title: "Cetmodules 2.X Status and Highlights"
author: "Chris Green, FNAL"
date: "2021-03-24"
theme: MFP
aspectratio: 1610
---

## Recap ##

* Progressing towards total replacement of UPS by Spack in experimental software ecosystem.
* cetmodules 1.X: UPS-free CMake-based build system based on cetbuildtools.
* Testing and improving Spack-related operations is difficult because (_e.g._) experimental code must be forked to remove reliance on UPS for both building and use.

## cetmodules 2.X ##

* Remove the need for forking experimental software for building with Spack: retain the ability to build with / for UPS while also being build-able with Spack.
* Improve cetmodules to embrace "modern" (_c._ 2014) CMake paradigms:  

	* Targets vs CMake variables with library filenames.
	* `INTERFACE` and `OBJECT` libraries and `PUBLIC` vs `PRIVATE` vs `INTERFACE` dependencies.
    * Components.
    * Handling of transitive dependencies.
    * Automatic generation of CMake configuration files.
    * Automatic generation of package checksums.

* Spack / UPS build compatibility relies on "Project variables," managed by cetmodules, with configuration translated from `product_deps` to CMake by `setup_for_development` and `buildtool`---use of `buildtool` is now **required** for at least the CMake stage.
* cetmodules-using packages can use cetbuildtools-using dependencies via mrb or UPS.

## Upgrading from cetbuildtools -> cetmodules ##

* Initially: upgrading to cetmodules is _not necessary_---simply changing the specified version of cetbuildtools in `product_deps` to 8.X should be all that is required to use cetmodules-built UPS packages (or build the package(s) within an mrb 5.X development set).
* Via mrb 5.X, one can develop simultaneously an arbitrary mix of cetbuildtools / cetmodules-using packages with _no change_ to package source code.
* Migration script provides a wide range of automatic changes to use cetmodules efficiently, including translating cetbuildtools variables to "uniform" cetmodules style, and adjusting to the improved installation and packaging structure. Annotations detailing requirements and recommendations for less easily-script-able changes are added as comments.
* Incremental best practice improvements to use modern CMake features via cetmodules will reduce library size and dependencies and improve maintainability.

## Upgrading packages to build with Spack ##
* Build-ability with Spack will require:
  * Spack recipes.
  * Use of cetmodules 2.X.
  * Migration of configuration from `product_deps` to project variables set in the project's top-level `CMakeLists.txt` file or in JSON "preset" files (recent CMake feature), retaining a single point of maintenance for package build configuration.
  * Removal of use of UPS-set environment variables for package headers and libraries.
* As changes are made to accommodate and ease building for Spack, the ability to build for UPS and use UPS-packaged dependencies id _not_ affected.

## Status ##

* art suite 3.08.00 is out, featuring "best practice" use of cetmodules and modern CMake facilities.
* Experience with downstream and older packages (Nutools, ifdh\_art, LArSoft and MicroBooNE experimental code) has improved backward compatibility: success building MicroBooNE production (based on art suite 3.01.02, LArSoft 08.05.00.17) in an mrb 5.X development set with no change to packages (source, CMake or `product_deps`).
* Production of new release of LArSoft and friends based on art suite 3.08 is in process.
* Documentation in process (couple of weeks).

## Rollout ##

* Discussion of new and technical aspects with external projects / experiments where necessary.
* Technical help available for corner cases, issues, making best use of modern CMake paradigms, _etc._
* Completion of documentation.
* artdaq-core, TRACE, nutools, LArSoft, experiment packages.
* Shift emphasis to Spack build and verification of art suite and downstream packages.
