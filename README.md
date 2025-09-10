
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

To estimate this, the data in the model should include:

- Historical data of the rate of freezer filling from ECHO.  
- Future biospecimen kit builds.  
- Expected enrollment numbers from ?????? (I DO NOT HAVE THIS YET).

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

## What is the total BioStore II capacity?

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

## What should go into the forecast model of when the BioStore will be at capacity?

- Historical data (time series data on number of ECHO tubes store in the
  BioStore). ✓  
- Expected number of kits that will be collected by kit type over time.
  ✘  
- Expected number of kits over time needs to include ability to handle
  complexities introduced due to “specialized” kits, which are not
  collected by all sites.  
- Number of tubes in current kit builds per each kit type. ✓  
- Proportion of tubes from each kit type expected to be sent back to the
  biorepository. (e.g., may get only a tiny bit of urine from young
  babies, and so won’t get all three 1.9ml tubes back.).  
- <span style="color:blue">blue</span>.
