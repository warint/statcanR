
<!-- README.md is generated from README.Rmd. Please edit that file -->

# statcanR

<!-- badges: start -->

[![Travis build
status](https://travis-ci.org/warint/statcanR.svg?branch=master)](https://travis-ci.org/warint/statcanR)
[![AppVeyor build
status](https://ci.appveyor.com/api/projects/status/github/warint/statcanR?branch=master&svg=true)](https://ci.appveyor.com/project/warint/statcanR)
<!-- badges: end -->

The goal of statcanR is to get all to get all Canadian statistics data
(CANSIM tables,now identify by Product IDs (PID)) without any limitation
and provided by the new Statistics Canada Web Data Service.

## Installation

You can install the released version of statcanR with devtools.

``` r
install.packages("devtools")
devtools::install_github('warint/statcanR')
```

## Example

This is a basic example which shows you how to get Canadian data

``` r
library(statcanR)
data <- sqs_statcan_data("14-10-0287-03","eng")
```

### Why SQS?

SQS stands for SKEMA Quantum Studio, a research and technological
development centre based in Montreal,Canada, that serves as the engine
room for the SKEMA Global lab in AI and the SKEMA Business School.

SKEMA Quantum Studio is also a state-of-the-art platform developed by
our team that enables scholars, students and professors to access one of
the most powerful analytical tools in higher education. By using data
science and artificial intelligence within the platform, new theories,
methods and concepts are being developed to study globalisation,
innovation and digital transformations that our society faces.

To learn more about the SKEMA Quantum Studio and the mission of the
SKEMA Global Lab in AI, please visit the following websites :
[SQS](https://quantumstudio.skemagloballab.io) ; [Global
Lab](https://skemagloballab.io/)
