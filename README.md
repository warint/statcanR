
<!-- README.md is generated from README.Rmd. Please edit that file -->

# statcanR

# <img src="man/figures/LOGO.png" align="right" />

<!-- badges: start -->

[![Travis build
status](https://travis-ci.org/warint/statcanR.svg?branch=master)](https://travis-ci.org/warint/statcanR)
[![AppVeyor build
status](https://ci.appveyor.com/api/projects/status/github/warint/statcanR?branch=master&svg=true)](https://ci.appveyor.com/project/warint/statcanR)
<!-- badges: end -->

Easily connect to Statistics Canada’s Web Data Service with R. Open
economic data (formerly known as CANSIM tables, now identified by
Product IDs (PID)) are accessible as a data frame, directly in the
user’s R environment.

## Installation

The released version of statcanR package is accessible through devtools.

``` r
install.packages("devtools")
devtools::install_github('warint/statcanR')
```

## Example

This section presents an example of how to use the statcanR R package
and its function sqs\_statcan\_data().

The following example is provided to illustrate how to use the function.
It consists in collecting some descriptive statistics about the Canadian
Labour Force at the federal, provincial and industrial levels, on a
monthly basis.

With a simple web search ‘statistics canada wages by industry
metropolitan area monthly’, the table number can easily be found on
Statisitcs Canada’s webpage. Here is below a figure that illustrates
this example, such as ‘27-10-0014-01’ for the Federal expenditures on
science and technology, by socio-economic objectives.

Once the table number is identified, the sqs\_statcan\_data() function
is easy to use in order to collect the data, as following:

``` r
library(statcanR)
mydata <- sqs_statcan_data("27-10-0014-01","eng")
```

### Statistics Canada Open Licence

This licence is issued on behalf of Her Majesty the Queen in Right of
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
the
Information.

##### Acknowledgment of Source according to Statistics Canada Open Licence Agreement

Statistics Canada has a specific procedure regarding the ackowledgment
of source :

You shall include and maintain the following notice on all licensed
rights of the
    Information:

    Source: Statistics Canada, name of product, reference date. Reproduced and distributed on an "as is" basis with the permission of Statistics Canada.

Where any Information is contained within a Value-added Product, you
shall include on such Value-added Product the following
    notice:

    Adapted from Statistics Canada, name of product, reference date. This does not constitute an endorsement by Statistics Canada of this product.

### Cite statcanR

To cite stantcanR package in your work:

Warin, T., Romain Le Duc (2019). statcanR: Client for Statistics
Canada’s Open Economic Data. v0.1.0.

``` r
@Manual{R-statcanR,
   title = {statcanR: Client for Statistics Canada's Open Economic Data},
   author = {Thierry Warin and Romain {Le Duc}},
   note = {R package version 0.1.0},
   url = {http://github.com/warint/statcanR},
   year = {2019},
 }
```

### Why SQS?

SQS stands for SKEMA Quantum Studio, a research and technological
development centre based in Montreal, Canada, that serves as the engine
room for the SKEMA Global lab in AI.

SKEMA Quantum Studio is also a state-of-the-art platform developed by
our team that enables scholars, students and professors to access one of
the most powerful analytical tools in higher education. By using data
science and artificial intelligence within the platform, new theories,
methods and concepts are being developed to study globalisation,
innovation and digital transformations that our society faces.

To learn more about the SKEMA Quantum Studio and the mission of the
SKEMA Global Lab in AI, please visit the following websites :
[SQS](https://quantumstudio.skemagloballab.io) ; [Global
Lab](https://skemagloballab.io/).

### Acknowledgments

The authors would like to thank the Center for Interuniversity Research
and Analysis of Organizations (CIRANO, Montreal) for its support, as
well as Thibault Senegas, Marine Leroi and Martin Paquette at SKEMA
Global Lab in AI. However, errors and omissions are ours.
