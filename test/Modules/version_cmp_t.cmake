include(ParseVersionString)

cet_version_cmp(RESULT "${VERSION_A}" "${VERSION_B}")
message(STATUS ${RESULT})
