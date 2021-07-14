include(ParseVersionString)

# Sub-test counts.
set(RUN_COUNT 0)
set(FAIL_COUNT 0)

# Test function for single variable, including SEP and lists.
function(pvs_test VERSION EXPECTED)
  parse_version_string("${VERSION}" ${ARGN} RESULT)
  message(CHECK_START
    "parse_version_string(\"${VERSION}\" ${ARGN} RESULT) -> \"${EXPECTED}\"")
  math(EXPR RUN_COUNT "${RUN_COUNT} + 1")
  if (RESULT STREQUAL EXPECTED)
    message(CHECK_PASS "OK")
  else()
    message(CHECK_FAIL "FAIL: \"${RESULT}\"")
    math(EXPR FAIL_COUNT "${FAIL_COUNT} + 1")
    set(FAIL_COUNT ${FAIL_COUNT} PARENT_SCOPE)
  endif()
  set(RUN_COUNT ${RUN_COUNT} PARENT_SCOPE)
endfunction()

pvs_test("develop" ";;;;develop;101;develop")
pvs_test("develop" "develop" SEP .)
pvs_test(".develop" ";;;;develop;101;develop")
pvs_test(".develop" "develop" SEP .)
pvs_test(".develop" ".develop" SEP . EXTRA_SEP .)
pvs_test(".develop" "develop" SEP -)
pvs_test("vdevelop" ";;;;develop;101;develop")
pvs_test(".versatility" ";;;;versatility;101;versatility")
pvs_test("1.5.rc7" "1;5;;;rc7;-1;rc;7")
pvs_test("1.5.rc7" "1.5rc7" SEP .)
pvs_test("1-5-rc7" "1.5.rc7" SEP . EXTRA_SEP .)
pvs_test("1-5-rc7" "1-5rc7" SEP -)
pvs_test("1..5" "1.0.5" SEP .)
pvs_test("1..5" "1;;5")
pvs_test("1rc7" "1;;;;rc7;-1;rc;7")
pvs_test("1..rc7" "1;;;;rc7;-1;rc;7")
pvs_test("vart-develop-nightly-2021152663"
  ";;;;art-develop-nightly-2021152663;103;art-develop-nightly;2021152663")
pvs_test("2.3.0-snapshot-20210615"
  "2;3;0;;snapshot-20210615;3;snapshot;20210615")
pvs_test("2.3-snapshot-20210615000000.20003"
  "2;3;;;snapshot-20210615000000.20003;3;snapshot;20210615000000.20003")

# Aggregated test report
if (FAIL_COUNT)
  message(FATAL_ERROR "parse_version_string_t: ${FAIL_COUNT}/${RUN_COUNT} FAILED")
else()
  message(VERBOSE "parse_version_string_t: ${RUN_COUNT}/${RUN_COUNT} PASSED")
endif()
