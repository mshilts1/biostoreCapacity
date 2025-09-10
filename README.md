
<!-- README.md is generated from README.Rmd. Please edit that file -->

# biostoreCapacity

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/biostoreCapacity)](https://CRAN.R-project.org/package=biostoreCapacity)
[![R-CMD-check](https://github.com/mshilts1/biostoreCapacity/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mshilts1/biostoreCapacity/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of `biostoreCapacity` is to attempt to predict when VUMC’s
institutional resource [BioStore II
freezer](https://www.vumc.org/oor/index.php/vumc-biospecimen-storage)
will be full and unable to store any additional ECHO biospecimens.

To estimate this, the data in the model should include:

- Historical data of the rate of freezer filling from ECHO.  
- Future biospecimen kit builds.  
- Expected participant enrollment numbers from ?????? (I DO NOT HAVE
  THIS YET).

## Installation

You can install the development version of biostoreCapacity from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("mshilts1/biostoreCapacity")
```

Eventually, I’m going to *attempt* to put this on Shiny so it’s easy for
anyone to use, but I will still keep the source code transparent on
GitHub.

## What is the total BioStore II capacity?

The simplest equation for calculating BioStore capacity is:

<center>

$((196,412 + x)/788,256) + ((212,692 + y)/438,840)) = 1$
</center>

where:  
\* $196,412$ is the number of ECHO 1.0 ml tubes already stored (or
pending) in the BioStore (as of 2025-09-02).  
\* $x$ is the number of 1.0 ml tubes still to be collected for ECHO.  
\* $212,692$ is the number of ECHO 1.9 ml tubes already stored (or
pending) in the BioStore (as of 2025-09-02).  
\* $y$ is the number of 1.9 ml tubes still to be collected for ECHO.  
\* $788,256$ is the absolute maximum number of 1.0 ml tubes that can be
stored in the BioStore (assuming 0 1.9 ml tubes).  
\* $438,840$ is the absolute maximum number of 1.0 ml tubes that can be
stored in the BioStore (assuming 0 1.9 ml tubes).

Both $x$ and $y$ can increase, but as one increases the capacity for the
other decreases. The total capacity cannot exceed 1, or 100%.

## What should go into the forecast model of when the BioStore will be at capacity?

How can we estimate both $x$ and $y$ above, and when the capacity of the
BioStore will be full?

**This is the data that I think we need to predict when the BioStore
will be full:**

- Historical data (time series data on number of ECHO tubes store in the
  BioStore). $\color{green}{\text{✓}}$  
- Expected number of kits that will be collected by kit type over time.
  $\color{red}{\text{✘}}$  
- Expected number of kits over time needs to include ability to handle
  complexities introduced due to “specialized” kits, which are not
  collected by all sites. $\color{red}{\text{✘}}$
- Number of tubes in current kit builds per each kit type.
  $\color{green}{\text{✓}}$  
- Proportion of tubes from each kit type expected to be sent back to the
  biorepository. (e.g., may get only a tiny bit of urine from young
  babies, and so won’t get all three 1.9ml tubes back.).
  $\color{red}{\text{✘}}$

Green checkmark ($\color{green}{\text{✓}}$ ) means we have that data,
while a red x ($\color{red}{\text{✘}}$ ) means we don’t yet have it.

## Usage

``` r
library(biostoreCapacity)
#> Registered S3 method overwritten by 'quantmod':
#>   method            from
#>   as.zoo.data.frame zoo
```

## Load in data above that we do have

### Historical data

``` r
historical_data <- readHistorical()
historical_data_long <- longifyReadHistorical() # same thing as above, but in "long" format for easier plotting
```

Plot rate of accessioning over time:

``` r
library(ggplot2)
ggplot(historical_data_long, aes(x = date, y = total, colour = tube_type)) +
  geom_point() +
  geom_smooth() +
  theme_bw() +
  ylab("Cumulative Tubes Submitted to BioStore") +
  xlab("") +
  scale_x_date(date_breaks = "2 month", date_labels = "%b %y")
#> `geom_smooth()` using method = 'loess' and formula = 'y ~ x'
```

<img src="man/figures/README-plot_history-1.png" width="100%" />

### Future kit builds and biospecimen collection protocol

``` r
biospecimen_collections <- readCollections()
biospecimen_collections
#> # A tibble: 27 × 29
#>    collection_id   kit_type biospecimen_type participant tube_size tubes_per_kit
#>    <chr>           <chr>    <chr>            <chr>       <chr>             <dbl>
#>  1 breastmilk_1.9… breastm… breastmilk       maternal    1.9ml                 8
#>  2 breastmilk_1ml… breastm… breastmilk       maternal    1ml                  10
#>  3 cord_blood_1.9… cord_bl… cord_blood       child       1.9ml                 6
#>  4 cord_blood_1ml… cord_bl… cord_blood       child       1ml                  10
#>  5 placenta_1.9ml… placenta placenta         maternal    1.9ml                16
#>  6 urine_cup_mate… urine_c… urine            maternal    1.9ml                 3
#>  7 urine_cup_mate… urine_c… urine            maternal    1.9ml                 3
#>  8 urine_diaper_1… urine_d… urine            child       1.9ml                 3
#>  9 urine_cup_curr… urine_c… urine            partner     1.9ml                 3
#> 10 urine_cup_mate… urine_c… urine            maternal    1.9ml                 3
#> # ℹ 17 more rows
#> # ℹ 23 more variables: proportion_from_kit_collected <dbl>, visit <chr>,
#> #   visit_logical_order <dbl>, specimen_type <chr>, y_2025 <dbl>, y_2026 <dbl>,
#> #   y_2027 <dbl>, y_2028 <dbl>, y_2029 <dbl>, y_2030 <dbl>,
#> #   y_2025_multiplier <dbl>, y_2026_multiplier <dbl>, y_2027_multiplier <dbl>,
#> #   y_2028_multiplier <dbl>, y_2029_multiplier <dbl>, y_2030_multiplier <dbl>,
#> #   specialized_obesity <chr>, specialized_obesity_multiplier <chr>, …
```
