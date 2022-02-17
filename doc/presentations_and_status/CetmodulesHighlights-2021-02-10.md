---
title: "Cetmodules 2.X Status and Highlights"
author: "Chris Green, FNAL"
date: "2021-02-10"
theme: MFP
aspectratio: 1610
---

## Recap ##

* Progressing towards total replacement of UPS by Spack in experimental software ecosystem.
* cetmodules 1.X: UPS-free CMake-based build system based on cetbuildtools.
* Testing and improving Spack-related operations is difficult because (_e.g._) experimental code must be forked to remove reliance on UPS for both building and use.

## cetmodules 2.X ##

* Remove the need for forking experimental software for building with Spack: retain the ability to build with / for UPS while also being buildable with Spack.
* Improve cetmodules to embrace "modern" (_c._ 2014) CMake paradigms:  

	* Targets vs CMake variables with library filenames.
	* `Interface` and `OBJECT` libraries and `PUBLIC` vs `PRIVATE` vs `INTERFACE` dependencies.
    * Components.
    * Handling of transitive dependencies.
    * Automatic generation of CMake configuration files.
    * Automatic generation of package checksums.

## Upgrading from cetbuildtools ##

* Minimal changes required to start using cetmodules with UPS.
* Incremental best practice improvements.
* Mix cetbuildtools and cetmodules-using packages in an MRB development set.
* As changes are made to accommodate and ease building for Spack, retain the ability to build for UPS and use UPS-packaged dependencies.

## Status ##

* Working with art suite to refine and enhance compatibility and new functionality.
* Almost complete (hopefully this week).
* Documentation in process (couple of weeks).

## Rollout ##

* Discussion of new and technical aspects with external projects / experiments where necessary.
* LArSoft
* DAQ: TRACE (cetmodules 1.X), "cherry-picked" art code for online builds.
* Completion of documentation.
* Technical help available for corner cases, issues, _etc._
