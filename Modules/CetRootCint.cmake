#
# cet_rootcint( <output_name> [NO_INSTALL] ) 
# runs rootcint against files in CMAKE_CURRENT_SOURCE_DIR and puts the result in CMAKE_CURRENT_BINARY_DIR

include(CMakeParseArguments)
include(CetPackagePath)

# make sure ROOT_VERSION has been defined
if( NOT ROOT_VERSION )
  message(FATAL_ERROR "cet_rootcint: ROOT_VERSION is undefined")
elseif(NOT (HAVE_ROOT6 OR HAVE_ROOT5))
  message(FATAL_ERROR "cet_rootcint: missing ROOT classification variables.")
endif()

if (HAVE_ROOT6)
  set(RC_PROG ${ROOTCLING})
  set(RC_DICT_TYPE "ROOT Cling")
  if (ROOT6_HAS_NOINCLUDEPATHS)
    set(RC_FLAGS -noIncludePaths)
  else()
    set(RC_FLAGS)
  endif()
else() # ROOT5
  set(RC_PROG ${ROOTCINT})
  set(RC_DICT_TYPE "ROOT CINT")
  set(RC_FLAGS
    -c # Generate code for interactive interpreter use.
    -p # Use compiler's preprocessor.
    # Retained for backward compatibility -- these should all be NOP.
    -D_POSIX_SOURCE
		-D_SVID_SOURCE
		-D_BSD_SOURCE
		-D_POSIX_C_SOURCE=2
		-DDEFECT_NO_IOSTREAM_NAMESPACES
		-DDEFECT_NO_JZEXT
		-DDEFECT_NO_INTHEX
		-DDEFECT_NO_INTHOLLERITH
		-DDEFECT_NO_READONLY
		-DDEFECT_NO_DIRECT_FIXED
		-DDEFECT_NO_STRUCTURE
    )
endif()

function(cet_rootcint rc_output_name)
  set(cet_rootcint_usage "USAGE: cet_rootcint( <package name> [NO_INSTALL] )")
  cmake_parse_arguments(RC "NO_INSTALL" "" "" ${ARGN})

  # there are no default arguments
  if( RC_UNPARSED_ARGUMENTS )
    message(FATAL_ERROR  "cet_rootcint: Incorrect arguments. ${ARGV} \n ${cet_rootcint_usage}")
  endif()
  ##message(STATUS "cet_rootcint debug: cet_rootcint called with ${rc_output_name}")
  ##get_filename_component(pkgname ${CMAKE_CURRENT_SOURCE_DIR} NAME )
  ##message(STATUS "cet_rootcint debug: pkgname is ${pkgname} - ${PACKAGE} - ${package}")

  # generate the list of headers to be parsed by cint
  cet_package_path(curdir)
  FILE(GLOB CINT_CXX *.cxx )
  foreach( file ${CINT_CXX} )
    STRING( REGEX REPLACE ".cxx" ".h" header ${file} )
    get_filename_component( cint_file ${file} NAME_WE )
    set( CINT_HEADER_LIST ${curdir}/${cint_file}.h ${CINT_HEADER_LIST} )
    set( CINT_DEPENDS ${header} ${CINT_DEPENDS} )
  endforeach( file )
  ##message(STATUS "cint header list is now ${CINT_HEADER_LIST}" )

  ##message(STATUS "cet_rootcint: running ${ROOTCINT} and using headers in ${ROOTSYS}/include")
  get_property(inc_dirs DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
  set (RC_GENERATED_CODE ${CMAKE_CURRENT_BINARY_DIR}/${rc_output_name}Cint.cc)
  if (HAVE_ROOT5)
    list(APPEND inc_dirs .)
    list(APPEND RC_GENERATED_CODE ${CMAKE_CURRENT_BINARY_DIR}/${rc_output_name}Cint.h)
  else() # ROOT6
    if (NOT RC_LIB_TARGET)
      if (TARGET ${rc_output_name}_dict)
        set(RC_LIB_TARGET ${rc_output_name}_dict)
      elseif (TARGET ${rc_output_name})
        set(RC_LIB_TARGET ${rc_output_name})
      endif()
    endif()
    if (RC_LIB_TARGET)
      set(lib_path "$<TARGET_PROPERTY:${RC_LIB_TARGET},LIBRARY_OUTPUT_DIRECTORY>")
    else()
      set(lib_path ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    endif()
    set(RC_RMF ${lib_path}/${CMAKE_SHARED_LIBRARY_PREFIX}${rc_output_name}.rootmap)
    set(RC_PCM ${lib_path}/${CMAKE_SHARED_LIBRARY_PREFIX}${rc_output_name}_rdict.pcm)
    set(RC_OUTPUT_LIBRARY
      ${lib_path}/${CMAKE_SHARED_LIBRARY_PREFIX}${rc_output_name}${CMAKE_SHARED_LIBRARY_SUFFIX})
    get_filename_component(RC_RML ${RC_OUTPUT_LIBRARY} NAME)
    list(APPEND RC_FLAGS
      -s ${RC_OUTPUT_LIBRARY}
      -rml ${RC_RML}
      -rmf ${RC_RMF}
      )
    if (NOT ROOT6_HAS_NOINCLUDEPATH)
      # Header line and OS X lib name fixing only necessary for older ROOT6.
      set(RC_EXTRA
        COMMAND perl -wapi.bak -e "s&\\.dylib\\.so&.dylib&g$<SEMICOLON> s&^(header\\s+)([^/]+)$&\${1}${curdir}/\${2}&" "${RC_RMF}"
        COMMAND rm -f "${RC_RMF}.bak")
    endif()
  endif()
  foreach( dir ${inc_dirs} )
    set( CINT_INCS -I${dir} ${CINT_INCS} )
  endforeach( dir )
  ##message(STATUS "cet_rootcint: include_directories ${CINT_INCS}")
  add_custom_command(
    # Extra outputs commented out until custom_command OUTPUT supports
    # generator flags.
    OUTPUT ${RC_GENERATED_CODE} # ${RC_PCM} ${RC_RMF}
    COMMAND ${RC_PROG} -f ${CMAKE_CURRENT_BINARY_DIR}/${rc_output_name}Cint.cc
    ${RC_FLAGS}
		-I${CMAKE_SOURCE_DIR} ${CINT_INCS}
    -I${ROOTSYS}/include
		-DUSE_ROOT
		${CINT_HEADER_LIST} LinkDef.h
    ${RC_EXTRA}
    DEPENDS ${CINT_DEPENDS} LinkDef.h
    IMPLICIT_DEPENDS ${CINT_DEPENDS} LinkDef.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Generating ${RC_DICT_TYPE} dictionary files in ${curdir}"
    VERBATIM
    )

  # set variable for install_source
  if( NOT RC_NO_INSTALL )
    set(cet_generated_code ${RC_GENERATED_CODE} PARENT_SCOPE)
    if (RC_PCM)
      install(FILES ${RC_PCM} DESTINATION ${flavorqual_dir}/lib)
    endif()
    if (RC_RMF)
      install(FILES ${RC_RMF} DESTINATION ${flavorqual_dir}/lib)
    endif()
  endif( NOT RC_NO_INSTALL )
  #message( STATUS "cet_rootcint debug: generated code list ${cet_generated_code}")
endfunction(cet_rootcint)
