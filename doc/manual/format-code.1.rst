.. format-code-manual-description: Format-code Command-Line Reference

format-code(1)
**************

Usage
=====

  format-code -d <directory> [-c|-n] [-v] [--use-available]

Options
-------

  -d [--directory] arg   Top-level directory to apply formatting script.
  -c [--commit]          Commit changes after code-formatting has been applied.
                         To use the 'commit' option, you must have a clean working
                         area before invoking this script.
  -n [--dry-run]         No changes will be made.
  -v [--verbose]
  --use-available        Use the version of clang-format already set up for use.
                         This option can be used to override clang-format 7.0.0.

