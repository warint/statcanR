
## Resubmission

This is a resubmission. In this version I have :

* Omitted the redundancies in the Description field.

* Deleted the \dontrun{} in our example as recommended. 

* Modified our code so that the function does not write by default in the user's home filespace . To do so, I omitted all default path = 
getwd() in the function.

* Modified the vignettes so it can reflect our modifications in our code.

* Added information in the README.Rmd regarding references and acknowledgment.

## Test environments
* local OS X install, R 3.6.1
* ubuntu 14.04 (on travis-ci), R 3.6.1
* microsoft (on appveyor), R 3.6.1
* win-builder (devel and release)

## R CMD check results

0 errors | 0 warnings | 0 note

* This is a new release.

## Downstream dependencies
There are currently no downstream dependencies for this package.