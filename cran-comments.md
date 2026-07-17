## Resubmission

This is a return of an archived package. Version 0.2.6 was the last release
published by CRAN, and the package was archived on 2025-12-03 for repeated
Internet-access policy violations.

The update preserves the three established public functions and their existing
required arguments and adds `statcan_find()` for ranked natural-language table
discovery. It replaces obsolete data-download URLs with Statistics Canada's
documented Web Data Service method, fixes CSV output and temporary file
handling, removes an obsolete bundled catalogue, and updates the package tests
and documentation.

This release performs no Internet access during installation, package loading,
examples, tests, or vignette builds. Network requests occur only when a user
explicitly calls one of the four public data-discovery or access functions. Those requests use
timeouts and fail gracefully with informative errors when Statistics Canada's
service is unavailable or returns an unexpected response. `statcan_search()`
can use its most recent valid user cache when the service is unavailable.

Thierry Warin is the sole author and maintainer of this release. There is no
change of maintainer or maintainer email address from the last CRAN release.

## Test environments

* Local: macOS 26.5.2, R 4.5.1
* GitHub Actions: macOS, Windows, and Ubuntu; R release, devel, and oldrel

## R CMD check results

0 errors | 0 warnings | 1 note

The NOTE is expected for a package returning from the CRAN archive:

* New submission; package was archived on CRAN for repeated Internet-access
  policy violations.

The changes addressing that archival reason are described above.

## Downstream dependencies

The archived CRAN release had no reverse dependencies. The public function
names and existing required arguments are unchanged.
