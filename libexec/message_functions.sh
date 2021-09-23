########################################################################
# Logging and screen output.
#
# Globals:
#
# * _cet_redirected
#
# * _cet_do_verbose
########################################################################

maybe_redirect() {
  if log_no_tee; then
    info "redirecting output to $log"
    exec 3>&1 4>&2 >"$log" 2>&1
    info "buildtool log started at $(date)"
    (( _cet_redirected = 1 ))
    trap "restore_output_streams; cleanup" EXIT
  else
    trap "cleanup" EXIT
  fi
}

restore_output_streams() {
  eval 'printf "\n"' ${_cet_redirected:+1>&3}
  if (( _cet_redirected )); then
    info "buildtool finished at $(date); log written to $log"
    exec 2>&4- 1>&3-
  fi
}

writeStuff() {
  printf -- "$*\n"
  if (( _cet_redirected )); then printf -- "$*\n" 1>&3; fi; }

writeToErr() {
  printf -- "$*\n\n" 1>&2
  if (( _cet_redirected )); then printf -- "$*\n\n" 1>&4; fi; }

report() { writeStuff "$*"; }

info() { writeStuff "INFO: $*"; }

notify() { writeToErr "NOTIFY: $*"; }

verbose() { if (( _cet_do_verbose )); then writeStuff "VERBOSE: $*"; fi }

warning() { writeToErr "WARNING: $*"; }

error() { writeToErr "ERROR: $*"; }

fatal_error() {
  if [[ $1 =~ ^[[:digit:]]+$ ]]; then exitval=$1; shift; else exitval=1; fi
  writeToErr "FATAL ERROR: $*"; exit $exitval
}

internal_error() {
  if [[ $1 =~ ^[[:digit:]]+$ ]]; then exitval=$1; shift; else exitval=1; fi
  writeToErr "INTERNAL ERROR: $*"; unset TMP; exit $exitval
}

### Local Variables:
### mode: sh
### eval: (sh-set-shell "bash" t nil)
### End:
