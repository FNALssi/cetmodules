########################################################################
# install_python
#
# CMake function to integrate with python distutils functionlity.
#
# Usage: install_python([NO_INSTALL] SETUP_PY <setup.py>)
#
#        install_python([NO_INSTALL] <OPTIONS>)
#
# In the first usage mode, the specified user-provided setup.py file
# will be invoked to build and install the files at the right
# time. Apart from the optional NO_INSTALL, other options and arguments
# are not permitted.
#
# In the second usage mode, the user specifies different components of
# the python package they wish to construct. Valid arguments to specify
# these components are: NAME VERSION SETUP_ARGS SETUP_PREAMBLE SCRIPTS
# MODULES PACKAGES PACKGE_DATA DATA_FILES. A setup.py file is
# constructed to build and install the specified components. The
# optional NO_INSTALL is also honored in this usage.
#
#####################################
# OPTIONS
#
# SETUP_PREAMBLE <preamble>
#
# If specified, <preamble> is placed at the beginning of the generated
# setup.py file, prior to the invocation of the setup() function. If not
# specified, a basic import command will prepare for the invocation of
# setup().
#
# NAME <name>
#
# If specified, the name of the python package (defaults to the product
# name).
#
# VERSION <version>
#
# If specified, the version of the python package (defaults to the
# product version).
#
# SCRIPTS <script>+
#
# Specify executable python scripts to be installed in bin/. The same
# file may be specified as both a module and a script.
# 
# MODULES <module>+
#
# Specify single python files for use as modules (with import). They
# will be installed in lib/.
#
# PACKAGES <package>+
#
# Specify packages. They will be installed under lib, with pkg1.pkg2
# installed as pkg1/pkg2.
#
# PACKAGE_DATA
#
# Specify non-python files for inclusion in a python package. If
# specified, this argument has sub-arguments:
#
#   ROOT <file>+
#
#   PKG <pkg-name> <file>+
#
# The former specifies non-python files for inclusion in the "root"
# (top-level) package; the latter lists files for inclusion in the
# specified package.
#
# DATA_FILES
#
# Specify files for inclusion in the package in particular non-package
# subdirectories. If specified, this argument should be presented in the
# format:
#
#   DIR <dir> <files>+
#
# SETUP_ARGS <arg>+
#
# Further arguments to the distutils setup() command, if required.
#
####################################
# EXAMPLES
#
# For a directory containing the following files:
#
#   README.txt
#   test.py
#   test2.py
#   test3.py
#   pkg1/README-pkg1.txt
#   pkg1/__init__.py
#   pkg1/bill.py
#   pkg1/pkg2/README-pkg2.txt
#   pkg1/pkg2/__init__.py
#   pkg1/pkg2/fred.py
#
# use (e.g.):
#
# install_python(SCRIPTS test.py test2.py test3.py
#    MODULES test2
#    PACKAGES pkg1 pkg1.pkg2
#    PACKAGE_DATA ROOT README.txt PKG pkg1 README-pkg1.txt
#    DATA_FILES
#    DIR doc README.txt pkg1/README-pkg1.txt pkg1/pkg2/README-pkg2.txt
#    DIR etc README.txt pkg1/README-pkg1.txt pkg1/pkg2/README-pkg2.txt
#    )
#
# For the following effects:
#
# After build, the following files will be placed under ${CETPKG_BUILD}:
#    bin/test.py
#    bin/test2.py
#    bin/test3.py
#    doc/README.txt
#    doc/README-pkg1.txt
#    doc/README-pkg2.txt
#    etc/README.txt
#    etc/README-pkg1.txt
#    etc/README-pkg2.txt
#    lib/art-1.09.02-py2.7.egg-info
#    lib/pkg1/__init__.py
#    lib/pkg1/__init__.pyc
#    lib/pkg1/bill.py
#    lib/pkg1/bill.pyc
#    lib/pkg1/pkg2/__init__.py
#    lib/pkg1/pkg2/__init__.pyc
#    lib/pkg1/pkg2/fred.py
#    lib/pkg1/pkg2/fred.pyc
#    lib/pkg1/README-pkg1.txt
#    lib/test2.py
#    lib/test2.pyc
#
# After install, the same files will be visible under
# ${XX_DIR}/{doc,etc} and ${XX_FQ_DIR}/{lib,bin} in the installed
# product.
#
########################################################################

########################################################################
include(CMakeParseArguments)

function (_to_python_list OUTPUT_VAR)
  cmake_parse_arguments(TPL
    "APPEND"
    "PYTHON_VAR"
    ""
    ${ARGN}
    )
  if (TPL_PYTHON_VAR)
    set(tmp "${TPL_PYTHON_VAR}=[ ")
  else()
    set(tmp "[ ")
  endif()
  foreach (item ${TPL_UNPARSED_ARGUMENTS})
    if (NOT item OR item MATCHES "[^-\\+0-9\\.]*([eE][-0-9]+)?")
      set(item "'${item}'")
    endif()
    set(tmp "${tmp}${item},")
  endforeach()
  string(REGEX REPLACE "(,| )$" " ]" tmp "${tmp}")
  if (TPL_APPEND)
    set(${OUTPUT_VAR} "${${OUTPUT_VAR}}${tmp}" PARENT_SCOPE)
  else()
    set(${OUTPUT_VAR} "${tmp}" PARENT_SCOPE)
  endif()
endfunction()

function(install_python)
  set(setup_arg_indent "        ")
  cmake_parse_arguments(IP
    "NO_INSTALL"
    "SETUP_PY;NAME;VERSION"
    "SETUP_ARGS;SETUP_PREAMBLE;SCRIPTS;MODULES;PACKAGES;PACKAGE_DATA;DATA_FILES"
    ${ARGN})
  if (NOT IP_SCRIPTS AND NOT IP_MODULES AND NOT IP_SETUP_PY AND NOT PACKAGES)
    message(FATAL_ERROR "install_python called with no defined "
      "SCRIPTS, MODULES, PACKAGES or SETUP_PY.")
  endif()
  if (IP_SETUP_PY)
    foreach (var NAME VERSION SETUP_ARGS SETUP_PREAMBLE SCRIPTS MODULES PACKAGES PACKGE_DATA DATA_FILES)
      if (IP_${var})
        list(APPEND error_vars "${var}")
      endif()
    endforeach()
    if (error_vars)
      message(FATAL_ERROR "install_python: specification of ${error_vars} not valid with SETUP_PY."
        "makes no sense.")
    endif()
  endif()
  if (IP_PACKAGE_DATA AND NOT IP_PACKAGES)
    message(FATAL_ERROR "install_python: PACKAGE_DATA makes no sense without PACKAGES.")
  endif()
  if (NOT IP_NAME)
    set(IP_NAME ${product})
  endif() # IP_NAME
  if (NOT IP_VERSION)
    set(IP_VERSION ${cet_dot_version})
  endif() # IP_VERSION
  if (IP_SCRIPTS) # scripts=[ ... ]
    foreach(item ${IP_SCRIPTS})
      list(APPEND tmp "${CMAKE_CURRENT_SOURCE_DIR}/${item}")
    endforeach()
    set(IP_SCRIPTS "${tmp}")
    _to_python_list(scripts
      PYTHON_VAR scripts
      ${IP_SCRIPTS})
    list(APPEND IP_SETUP_ARGS "${scripts}")
  endif() # IP_SCRIPTS
  if (IP_MODULES) # modules=[ ... ]
    _to_python_list(modules
      PYTHON_VAR py_modules
      ${IP_MODULES})
    list(APPEND IP_SETUP_ARGS "${modules}")
  endif() # IP_MODULES
  if (IP_PACKAGES) # packages=[ ... ]
    _to_python_list(packages
      PYTHON_VAR packages
      ${IP_PACKAGES})
    list(APPEND IP_SETUP_ARGS "${packages}")
  endif() # IP_PACKAGES
  unset(this_list)
  if (IP_PACKAGE_DATA) # package_data={ '' : [ ... ] '<pkg>' [ ... ] ... }
    foreach(arg ${IP_PACKAGE_DATA})
      if (arg STREQUAL "ROOT" OR arg STREQUAL "PKG")
        if (NOT package_data)
          set(package_data "package_data={ ")
        endif()
        if (this_list) # Already have a list to process.
          set(package_data "${package_data}'${this_pkg}' : ")
          _to_python_list(package_data APPEND ${this_list})
          set(package_data "${package_data},\n${setup_arg_indent}               ")
          unset(this_list)
        endif()
        if (arg STREQUAL "ROOT")
          set(this_pkg "")
        elseif(arg STREQUAL "PKG")
          set(new_pkg TRUE)
        endif()
      elseif(new_pkg) # Package name.
        set(this_pkg "${arg}")
        unset(new_pkg)
      else() # Just a list element.
        if (NOT package_data) # Error
          message(FATAL_ERROR "install_python: PACKAGE_DATA first argument must be ROOT or PKG.")
        endif()
        list(APPEND this_list "${arg}")
      endif()
    endforeach()
    if (this_list) # One last list to process.
      set(package_data "${package_data}'${this_pkg}' : ")
      _to_python_list(package_data APPEND ${this_list})
    endif()
    set(package_data "${package_data} }")
    list(APPEND IP_SETUP_ARGS "${package_data}")
  endif() # IP_PACKAGE_DATA
  unset(this_list)
  if (IP_DATA_FILES) # data_files=[ ('<dir>', [ ... ]), ... ]
    foreach(arg ${IP_DATA_FILES})
      if (arg STREQUAL "DIR")
        if (NOT data_files)
          set(data_files "data_files=[ ")
        endif()
        if (this_list) # Already have a list to process.
          set(data_files "${data_files}('${this_dir}', ")
          _to_python_list(data_files APPEND ${this_list})
          set(data_files "${data_files}),\n${setup_arg_indent}             ")
          unset(this_list)
        endif()
        set(new_dir TRUE)
      elseif(new_dir) # Dir name.
        set(this_dir "${arg}")
        unset(new_dir)
      else() # Just a list element.
        if (NOT data_files) # Error
          message(FATAL_ERROR "install_python: DATA_FILES first argument must be DIR.")
        endif()
        list(APPEND this_list "${CMAKE_CURRENT_SOURCE_DIR}/${arg}")
      endif()
    endforeach()
    if (this_list) # One last list to process.
      set(data_files "${data_files}('${this_dir}', ")
      _to_python_list(data_files APPEND ${this_list})
      set(data_files "${data_files})")
    endif()
    set(data_files "${data_files} ]")
    list(APPEND IP_SETUP_ARGS "${data_files}")
  endif() # IP_DATA_FILES
  if (NOT IP_SETUP_PY)
    set(IP_SETUP_PY "${CMAKE_CURRENT_BINARY_DIR}/setup.py")
    if (IP_SETUP_PREAMBLE)
      file(WRITE "${IP_SETUP_PY}" ${IP_SETUP_PREAMBLE})
    else()
      file(WRITE "${IP_SETUP_PY}"
        "from distutils.core import setup, Extension\n"
        )
    endif()
    set(setup_items 
      "name='${IP_NAME}'"
      "version='${IP_VERSION}'"
      "package_dir={ '' : '${CMAKE_CURRENT_SOURCE_DIR}' }"
      "${IP_SETUP_ARGS}")
    string(REPLACE ";" ",\n${setup_arg_indent}" setup_arg_string "${setup_items}")
    file(APPEND "${IP_SETUP_PY}"
      "\n\n"
      "if __name__ == '__main__':\n"
      "  setup(${setup_arg_string})\n"
      )
  endif()
  add_custom_target(python_${IP_NAME}_build
    ALL
    COMMAND python "${IP_SETUP_PY}" install --install-lib="${CMAKE_BINARY_DIR}/lib" --install-scripts="${CMAKE_BINARY_DIR}/lib" --install-headers="${product}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    DEPENDS "${IP_SETUP_PY}"
    )
  if (NOT IP_NO_INSTALL)
    install(CODE "execute_process(COMMAND python \"${IP_SETUP_PY}\" install --prefix=${CMAKE_INSTALL_PREFIX}/${product}/${version} --install-lib=${CMAKE_INSTALL_PREFIX}/${${product}_lib_dir} --install-scripts=${CMAKE_INSTALL_PREFIX}/${${product}_bin_dir} --install-headers=${CMAKE_INSTALL_PREFIX}/${${product}_inc_dir})")
  endif()
endfunction()
