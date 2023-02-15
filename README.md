
<!-- README.md is generated from README.Rmd. Please edit that file -->

# statcanR

<!-- badges: start -->

[![Travis build
status](https://travis-ci.com/warint/statcanR.svg?branch=master)](https://travis-ci.org/github/warint/statcanR)
[![AppVeyor build
status](https://ci.appveyor.com/api/projects/status/github/warint/statcanR?branch=master&svg=true)](https://ci.appveyor.com/project/warint/statcanR)
[![Mentioned in
Awesome](https://awesome.re/mentioned-badge.svg)](https://github.com/SNStatComp/awesome-official-statistics-software)
[![CRAN
status](https://www.r-pkg.org/badges/version/statcanR)](https://CRAN.R-project.org/package=statcanR)
[![](https://cranlogs.r-pkg.org/badges/grand-total/statcanR?color=blue)](https://cran.r-project.org/package=statcanR)

<!-- badges: end -->

# Overview

Easily connect to Statistics Canada’s Web Data Service with R. Find and 
access open economic data (formerly known as CANSIM tables, now identified by
Product IDs (PID)) which are accessible as a data frame, directly in the
user’s R environment.

## Shiny App : statcanR ExploR

<img src="man/figures/shiny.png" />

For people less comfortable with R and to allow more people to have
access to our package, we have also developed a Shiny
application.Through the same logic present in our package, researchers
can retrieve data from Statistics Canada.

statcanR EploR is available [\[here\]](https://warin.ca/shiny/statcanr/)

## Installation

The released version of statcanR package is accessible through CRAN and
devtools.

``` r
install.packages("statcanR")

install.packages("devtools")
devtools::install_github('warint/statcanR')
```

## Example

This section presents an example of how to use the `statcanR` R package
and its functions: `statcan_search()`, `statcan_data()`, and 
`statcan_download_data()`.

The following example is provided to illustrate how to use the
functions. It consists in collecting some descriptive statistics about
the Canadian Labour Force at the federal, provincial and industrial
levels, on a monthly basis.

To identify a relevant table, the statcan_search() function can be used
by using a keyword or set of keywords and specifying the language in which the 
data will be presented (English or French). Below is an example that reveals
the data tables we could be interested in:

``` r
library(statcanR)
statcan_search(c("federal","expenditures","objectives"),"eng")
```

Notice that for each corresponding table, the unique table number identifier is 
also presented. Let's focus the first table out of the two that appear, which 
contains data on Federal expenditures on science and technology,
by socio-economic objectives. Once this table number is identified
(‘27-10-0014-01’), the statcan_data() function is easy
to use in order to collect the data, as following:

``` r
library(statcanR)
mydata <- statcan_data("27-10-0014-01","eng")
```

For the `statcan_download_data()` function there is no difference on how
to use it, the only difference is that this function allow you to
download the data in a csv file on top of having the data in your
environment.

``` r
library(statcanR)
mydata <- statcan_download_data("27-10-0014-01","eng")
```

### Video Tutorial

Tutorial made by Professor Charles Saunders, Director of Master of
Financial Economics Program at Western University
[biography](https://economics.uwo.ca/people/faculty/saunders.html)

Thanks!

<https://www.youtube.com/embed/z9TDUlgT5lc>

### Statistics Canada Open Licence

This licence is issued on behalf of His Majesty the King in Right of
Canada, as represented by the Minister for Statistics Canada
(“Statistics Canada”) to you (an individual or a legal entity that you
are authorized to represent).

Statistics Canada may modify this licence at any time, and such
modifications shall be effective immediately upon posting of the
modified licence on the Statistics Canada website. Your use of the
Information will be governed by the terms of the licence in force as of
the date and time you accessed the Information.

Please refer to the [terms of
licence](https://www.statcan.gc.ca/eng/reference/licence) before using
the Information.

##### Acknowledgment of Source according to Statistics Canada Open Licence Agreement

Statistics Canada has a specific procedure regarding the acknowledgment
of source :

You shall include and maintain the following notice on all licensed
rights of the Information:

    Source: Statistics Canada, name of product, reference date. Reproduced and distributed on an "as is" basis with the permission of Statistics Canada.

Where any Information is contained within a Value-added Product, you
shall include on such Value-added Product the following notice:

    Adapted from Statistics Canada, name of product, reference date. This does not constitute an endorsement by Statistics Canada of this product.

### Cite statcanR

To cite stantcanR package in your work:

Warin, T. (2023). statcanR: Client for Statistics
Canada’s Open Economic Data. v0.2.4.

``` r
@Manual{R-statcanR,
   title = {statcanR: Client for Statistics Canada's Open Economic Data},
   author = {Thierry Warin},
   note = {R package version 0.2.4},
   url = {https://github.com/warint/statcanR},
   year = {2023}"
 }
```

### Acknowledgments

The author would like to thank the Center for Interuniversity Research
and Analysis of Organizations (CIRANO, Montreal) for its support, as
well as Thibault Senegas, Jeremy Schneider, Marine Leroi, Martin Paquette and Romain Le Duc. However,
errors and omissions are his.
