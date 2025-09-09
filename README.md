
<!-- README.md is generated from README.Rmd. Please edit that file -->

# biostoreCapacity

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/biostoreCapacity)](https://CRAN.R-project.org/package=biostoreCapacity)
<!-- badges: end -->

The goal of biostoreCapacity is to …

## Installation

You can install the development version of biostoreCapacity from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("mshilts1/biostoreCapacity")
```

## Usage

``` r
library(biostoreCapacity)
```

The simplest equation for calculating BioStore capacity is:

$((196,412 + x)/788,256) + ((212,692 + y)/438,840)) = 1$

where:  
\* $196,412$ is the current number of 1.0 ml tubes already stored (or
pending storage) in the BioStore (as of 2025-09-02).  
\* $x$ is the number of 1.0 ml tubes still to be collected for ECHO.  
\* $212,692$ is the current number of 1.9 ml tubes already stored (or
pending storage) in the BioStore (as of 2025-09-02).  
\* $y$ is the number of 1.9 ml tubes still to be collected ECHO.  
\* $788,256$ is the absolute maximum number of 1.0 ml tubes that be
stored in the BioStore (assuming 0 1.9 ml tubes).  
\* $438,840$ is the absolute maximum number of 1.0 ml tubes that be
stored in the BioStore (assuming 0 1.9 ml tubes).
