.. increment-version-manual-description: Increment-version Command-Line Reference

increment-version(1)
*******************

.. parsed-literal::

NAME
    increment-version: Increment the current version of a cetmodules-using
    package.

SYNOPSIS

    increment-version mode [options] [--] [package-loc+]

    increment-version --help | -h | -?

    mode: [ -M | --major] | [ -m | --minor ] | [ -u | --micro ] | [ -p |
    --patch ] | [ --update-only package,version | -U package,version ]

    options: [ --client-dir package-client-search-path | -c
    package-client-search-path ]+ | [ --dry-run | -n ] | [ --tag ] | [
    --verbose | -v ]

    Options marked with + are repeatable and cumulative.

    Exactly one mode specification is expected, although -U may be used
    several times to specify multiple package/version pairs to update the
    references thereto.

DESCRIPTION
    increment-version will increment the current version of a cetmodules-using
    package. Optionally find all other packages where said package is listed
    as a dependency and update the required version.

  ARGUMENTS
    package-loc
        Path to top directory of package whose version should be bumped.

  Modes
    Precisely one mode type should be specified (although -U may be specified
    multiple times).

    -M
    --major
        Increment the major version number, zeroing all used subordinate
        version designators.

    -m
    --minor
        Increment the minor version number, zeroing all used subordinate
        version designators.

    -u
    --micro
        Increment the micro version number, resetting any patch number.

    -p
    --patch
        Increment the patch number.

    --update-only package,version
    -U package,version
        Do not increment any version numbers; simply navigate the directories
        specified with the --client-dir option (or ./ if not specified) to
        update any references to the named package(s) to use the specified
        version(s) thereof.

  OPTIONS
    --client-dir package-client-search-path
    -c package-client-search-path
        Specify a directory to search for product_deps files in which to
        update the set-up versions of the updated prodoct(s); or those of
        products specified with -U.

    --debug
    -d  Debug mode: leave temporary files available.

    --dry-run
    -n  Do not actually update anything: just say what would be done.

    --tag
        Commit changes to product_deps and tag all updated packages with their
        new versions.

    --verbose
    -v  Be more chatty.


