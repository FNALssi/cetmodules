#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# install_pkgmeta()
# install_license()
#
#   Install package metadata such as INSTALL, README and LICENSE files
# in ${${CETMODULES_CURRENT_PROJECT_NAME}_PKG_META_DIR}.
#
# Usage: install_pkgmeta([SUBDIRNAME <subdir>] LIST ...)
#        install_pkgmeta([SUBDIRNAME <subdir>] [BASENAME_EXCLUDES ...]
#          [EXCLUDES ...] [EXTRAS ...] [SUBDIRS ...])
#
# Both forms take optional one-argument install options
# INSTALLER_LICENSE, INSTALLER_README and INSTALLER_WELCOME. These are
# ignored for "normal" tar-based archives, but if one specifies one or
# more suitable CPACK_GENERATOR values, the specified files will be
# embedded into the appropriate installer by CPack irrespective of any
# instruction to install the file.
#
# See CetInstall.cmake for full usage description.
#
# Recognized filename patterns:
#   INSTALL* *README* LICEN[CS]E LICEN[CS]E.* COPYING COPYING.*
#
# "install_license" was never completely appropriate as a name, so now
# we have a preferred new name with the former retained for historical
# compatibility.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(install_pkgmeta)
  if (NOT "PKG_META_DIR" IN_LIST CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(PKG_META_DIR .
      NO_WARN_REDUNDANT OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install package metadata such as INSTALL, README and LICENSE files."
      )
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.  
  cmake_parse_arguments(PARSE_ARGV 0 _IP ""
    "INSTALLER_LICENSE;INSTALLER_README;INSTALLER_WELCOME" "")
  _cet_install(pkgmeta ${CETMODULES_CURRENT_PROJECT_NAME}_PKG_META_DIR
    ${_IP_UNPARSED_ARGUMENTS}
    _SQUASH_SUBDIRS _INSTALL_ONLY
    _EXTRA_EXTRAS ${_IP_LIST} ${_IP_INSTALLER_LICENSE}
    ${_IP_INSTALLER_README} ${_IP_INSTALLER_WELCOME}
    _INSTALLED_FILES_VAR installed_files
    _GLOBS "INSTALL*" "*README*"
    "LICEN[CS]E" "LICEN[CS]E.*"
    "LICEN[CS]ES" "LICEN[CS]ES.*"
    "COPYING" "COPYING.*")
  if (DEFINED _IP_INSTALLER_LICENSE)
    set(license ${_IP_INSTALLER_LICENSE})
  else()
    set(licenses ${installed_files})
    list(FILTER licenses INCLUDE REGEX [[(^|/)LICEN[CS]ES?(\.[^/]+)?$]])
    if (licenses)
      list(GET licenses 0 license)
    endif()
  endif()
  if (DEFINED license)
    set(${CETMODULES_CURRENT_PROJECT_NAME}_CPACK_RESOURCE_FILE_LICENSE "${license}" CACHE INTERNAL
      "Installer license file for CMake Project ${CMAKE_PROJECT}")
  endif()
  if (DEFINED _IP_INSTALLER_README)
    set(readme "${_IP_INSTALLER_README}")
  else()
    set(readmes ${installed_files})
    list(FILTER readmes INCLUDE REGEX [=[[^/]*README[^/]*$]=])
    if (readmes)
      list(GET readmes 0 readme)
    endif()
  endif()
  if (DEFINED readme)
    set(${CETMODULES_CURRENT_PROJECT_NAME}_CPACK_RESOURCE_FILE_README "${readme}" CACHE INTERNAL
      "Installer README file for CMake Project ${CMAKE_PROJECT}")
  endif()
  if (DEFINED _IP_INSTALLER_WELCOME)
    set(${CETMODULES_CURRENT_PROJECT_NAME}_CPACK_RESOURCE_FILE_WELCOME "${_IP_INSTALLER_WELCOME}"
      CACHE INTERNAL
      "Installer WELCOME file for CMake Project ${CMAKE_PROJECT}")
  endif()
endfunction()

function(install_license)
  message(WARNING "install_license() is deprecated in favor of install_pkgmeta()")
  install_pkgmeta(${ARGN})
endfunction()
