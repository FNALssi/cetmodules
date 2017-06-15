
FILE(GLOB modules [^.]*.cmake )
INSTALL(FILES ${modules}
  DESTINATION Modules
  )
