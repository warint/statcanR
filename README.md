
<!-- README.md is generated from README.Rmd. Please edit that file -->

# pkgdown <img src="man/figures/LOGO.png" align="right" />

# statcanR

<!-- badges: start -->

<!-- badges: end -->

The goal of statcanR is to get all to get all Canadian statistics data
(CANSIM tables,now identify by Product IDs (PID)) without any limitation
and provided by the new Statistics Canada Web Data Service

## Installation

You can install the released version of statcanR with devtools.

``` r

devtools::install_github("https://github.com/warint/statcanR")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(statcanR)
data <- sqs_statcan_data("14-10-0063-01", "eng")
```

## SKEMA Global Lab in AI

For more information on the SKEMA Global Lab in AI or the SKEMA Quantum Studio, you can visit our [website](https://skemagloballab.io/).
