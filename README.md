
<!-- README.md is generated from README.Rmd. Please edit that file -->

# biostoreCapacity

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/biostoreCapacity)](https://CRAN.R-project.org/package=biostoreCapacity)
<!-- badges: end -->

The goal of biostoreCapacity is to attempt to predict when VUMC’s
institutional resource BioStore II freezer will be full and unable to
store any additional ECHO biospecimens.

To estimate this, the data in the model include:  
\* Historical data of the rate of filling from ECHO.  
\* Future biospecimen kit builds.  
\* Expected enrollment numbers from ?????? (I DO NOT HAVE THIS YET).

## Installation

You can install the development version of biostoreCapacity from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("mshilts1/biostoreCapacity")
```

I’m going to attempt to put this on Shiny so it’s easy for anyone to
use, but will still make the source code transparent on GitHub.

## Usage

``` r
library(biostoreCapacity)
```

The simplest equation for calculating BioStore capacity is:

$((196,412 + x)/788,256) + ((212,692 + y)/438,840)) = 1$

where:  
\* $196,412$ is the number of ECHO 1.0 ml tubes already stored (or
pending) in the BioStore (as of 2025-09-02).  
\* $x$ is the number of 1.0 ml tubes still to be collected for ECHO.  
\* $212,692$ is the number of ECHO 1.9 ml tubes already stored (or
pending) in the BioStore (as of 2025-09-02).  
\* $y$ is the number of 1.9 ml tubes still to be collected for ECHO.  
\* $788,256$ is the absolute maximum number of 1.0 ml tubes that be
stored in the BioStore (assuming 0 1.9 ml tubes).  
\* $438,840$ is the absolute maximum number of 1.0 ml tubes that be
stored in the BioStore (assuming 0 1.9 ml tubes).

Both $x$ and $y$ can increase, but as one increases the capacity for the
other decreases. The total capacity cannot exceed 1, or 100%.
