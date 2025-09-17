
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

To estimate this, the data in the model should try to include:

- Historical data of the rate of freezer filling from ECHO. ✅  
- Current and future biospecimen kit builds. ✅  
- Expected number of biospecimens to be collected over time. ❌

✅ means we have that data.  
❌ means **WE AS THE LAB CORE** are missing (some of) that specific
information, but it does exist!

## What is the total BioStore II capacity?

The simplest equation for calculating BioStore capacity is:

$$\frac{(a + x)}{788,256} + \frac{(b + y)}{438,840} = 1$$

where:

| Component | Description |
|---:|----|
| $a$ | number of ECHO 1.0 ml tubes already collected (~200K as of September 2025) |
| $x$ | number of 1.0 ml tubes still to be collected for ECHO |
| $b$ | number of ECHO 1.9 ml tubes already collected (~210K as of September 2025) |
| $y$ | number of 1.9 ml tubes still to be collected for ECHO |
| 788,256 | maximum number of 1.0 ml tubes that can be stored in the BioStore, if no 1.9 ml tubes |
| 438,840 | maximum number of 1.9 ml tubes that can be stored in the BioStore, if no 1.0 ml tubes |

Both $x$ and $y$ will continue to increase, but as one increases, the
capacity for the other decreases. The total capacity cannot exceed 1, or
100%.

## What should go into the forecast model of when the BioStore will be at capacity?

How can we estimate both $x$ and $y$ above, and when the capacity of the
BioStore will be full?

**This is the data that I think we need to predict when the BioStore
will be full:**

- Historical data (time series data on number of ECHO tubes added to the
  BioStore over time). ✅  
- Expected number of kits that will be collected by kit type over time.
  ❌
  - Expected number of kits over time needs to include ability to handle
    complexities introduced due to “specialized” kits, which are not
    collected by all sites. 🟡  
- Number of tubes in current kit builds per each kit type. ✅  
- Proportion of tubes from each kit type expected to be sent back to the
  biorepository. (e.g., may get only a tiny bit of urine from young
  babies, and so may not receive all three 1.9ml tubes for storage). 🟡

### General proposed model structure

Here’s an idea of the kind of formula I’m thinking of, where $FF$ is
“Freezer Filling”:

First, we can attempt to make a model using the historical data of ECHO
submissions to the BioStore:

$$FF_{t+1} = f(FF_{t} + FF_{t-1} + FF_{t-2} + \cdots + error)$$

Second, we know there were changes to the ECHO protocol that will mean
the historical rate of data can’t be relied on alone, as we need to
consider other predictor variables:

$$FF_{pv} = f(enrollment, collection, tubes, loss, error)$$

where:  
$enrollment$ is the expected number of participants from whom specimens
will be collected from. WE DO NOT HAVE THIS DATA.  
$collection$ is the biospecimen collection schedule over time.  
$tubes$ is the number of tubes per each biospecimen collection kit.  
$loss$ is some sort of drop-out rate; participant drop-out, not all
tubes from a kit being returned to the biorepository, etc.

The final model would be something mixing the two above models:

$$FF_{mixed} = f(FF_{t+1},FF_{pv, error})$$

$error$ in all models isn’t mean to indicate error in the colloquial
sense, but to allow for random variation and the effects of variables
not captured in the model.

## Usage

You can install the development version of biostoreCapacity from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("mshilts1/biostoreCapacity")
```

Eventually, I’m going to *attempt* to put this on Shiny so it’s easy for
anyone to use, but I will still keep the source code transparent on
GitHub.

``` r
suppressPackageStartupMessages(library(biostoreCapacity))
```

## Plot Historical Data

#### Plot rate of accessioning over time:

This includes “pending” tubes, which are tubes that are still at the
sites but will be shipped here eventually and should be counted towards
the BioStore’s total inventory.

![](man/figures/plot_history.png)

### Eric Koplin’s ARIMA model

Eric Koplin has developed two ARIMA models using the `forecast` package
to predict when the BioStore will be full based on historical data with
different adjustments:

![](man/figures/single_arima.png)

### Site collection information for model priors and adjustments

I’ve created a function which will get the data from elvislims from
Bio-Track with all site collections, and information from REDCap about
which specialized collections each site’s PI signed up for.

Both sets of data can only be accessed by someone with the correct
credentials on both sites, and so are not publicly available here or
anywhere else.

The data gets merged, processed, cleaned, and all potentially
identifiable data is removed. Site ID is replaced by a randomized ID, so
we can get SOME idea about enrollment numbers by site, but the actual
site ID can’t be pulled from this data. (Yes, someone who is already
extremely knowledgable about the operations of ECHO Cycle 2 could
probably figure out sites from the data, but that type of person would
already have access to the full data.)

``` r
site_collections()
#> # A tibble: 204,017 × 16
#>    site_id_randomized               number_of_containers container_type capacity
#>    <chr>                                           <int> <chr>             <int>
#>  1 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  2 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  3 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  4 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  5 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  6 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  7 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  8 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#>  9 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#> 10 2f65c9a05b770edb650f839c06514908                  119 [FH prefixed]…       48
#> # ℹ 204,007 more rows
#> # ℹ 12 more variables: number_of_specimen <int>, specimen_type <chr>,
#> #   sample_type <chr>, storage_date <chr>, nominal_volume <chr>,
#> #   partial_aliquot <lgl>, partial_volume <dbl>, tube_size <chr>,
#> #   specialized_whole_blood <int>, specialized_breast_milk <int>,
#> #   specialized_urine <int>, shipped <int>
```

## Future kit builds and biospecimen collection protocol

We can’t really use this information yet, because we do not have a clear
estimate of the number of participants.

``` r
biospecimen_collections <- readCollections()
biospecimen_collections
#> # A tibble: 27 × 29
#>    collection_id   kit_type biospecimen_type participant tube_size tubes_per_kit
#>    <chr>           <chr>    <chr>            <chr>       <chr>             <dbl>
#>  1 breastmilk_1.9… breastm… breastmilk       maternal    1.9ml                 8
#>  2 breastmilk_1ml… breastm… breastmilk       maternal    1ml                  10
#>  3 urine_diaper_1… urine_d… urine            child       1.9ml                 3
#>  4 whole_blood_ch… whole_b… whole_blood      child       1.9ml                 6
#>  5 whole_blood_ch… whole_b… whole_blood      child       1ml                  10
#>  6 whole_blood_ch… whole_b… whole_blood      child       1.9ml                 6
#>  7 whole_blood_ch… whole_b… whole_blood      child       1ml                  10
#>  8 urine_diaper_1… urine_d… urine            child       1.9ml                 3
#>  9 urine_cup_chil… urine_c… urine            child       1.9ml                 3
#> 10 whole_blood_ch… whole_b… whole_blood      child       1.9ml                 6
#> # ℹ 17 more rows
#> # ℹ 23 more variables: proportion_from_kit_collected <dbl>, visit <chr>,
#> #   visit_logical_order <dbl>, specimen_type <chr>, y_2025 <dbl>, y_2026 <dbl>,
#> #   y_2027 <dbl>, y_2028 <dbl>, y_2029 <dbl>, y_2030 <dbl>,
#> #   y_2025_proportion <dbl>, y_2026_proportion <dbl>, y_2027_proportion <dbl>,
#> #   y_2028_proportion <dbl>, y_2029_proportion <dbl>, y_2030_proportion <dbl>,
#> #   specialized_obesity <chr>, specialized_obesity_proportion <chr>, …
```

**Information in `readCollections()` that can be assumed to be “true”
for the sake of building the model:**

- All columns with information about the kit builds:
  - `collection_id`, `kit_type`, `biospecimen_type`, `participant`,
    `tube_size`, `tubes_per_kit`.  
- All columns about the biospecimen collection timeline:
  - `visit`, `specimen_type`, `y_2025`, `y_2026`, `y_2027`, `y_2028`,
    `y_2029`, `y_2030`, `specialized_obesity`, `specialized_chemphys`,
    `specialized_lifestyle`.

**Speculative columns all contain the word “proportion” in the name:**

    * `proportion_from_kit_collected`, `y_2025_proportion`, `y_2026_proportion`, `y_2027_proportion`, `y_2028_proportion`, `y_2029_proportion`, `y_2030_proportion`, `specialized_obesity_proportion`, `specialized_chemphys_proportion`, `specialized_lifestyle_proportion`.   

------------------------------------------------------------------------

# Only read below if you want more details!

A more thorough description of every column in `readCollections()`:

| Variable | Description |
|---:|----|
| collection_id | a unique ID. a concatenation of kit_type, tube_size, visit, and specimen_type |
| kit_type | concatenation of biospecimen_type and participant |
| biospecimen_type | type of biospecimen being collected (e.g., urine or blood, etc…) |
| participant | specimen to be collected from an ECHO child, child’s mother, or child’s mother’s current partner |
| tube_size | whether tube is 1.0mL or 1.9mL (1.9mL tubes take up more space in the BioStore.) |
| tubes_per_kit | number of tubes of specified size in that specific kit |
| proportion_from_kit_collected | what proportion of tubes in that kit are we expecting to be returned to be stored in the BioStore? for example, newborn babies may not produce enough urine for all three 1.9mL tubes to be filled and returned. maybe only two will be returned |
| visit | time point in child’s or child’s mother’s life when specimen is collected |
| visit_logical_order | not really that useful here, but orders the visit column by the logical order of an ECHO child’s life (sort of; due to preconception protocol, that gets complicated) |
| specimen_type | is specimen considered by ECHO a core, preconception, or specialized specimen? this is important because sites are expected to at least try to collect every core specimen, while sites are only allowed to collected specific specialized specimens. the preconception specimens are somewhere in the middle |
| y_2025 | 1 (yes)/ 0 (no) column. is this specific specimen to be collected in calendar year 2025? |
| y_2026 | same as for y_2025, but calendar year 2026 |
| y_2027 | same as for y_2025, but calendar year 2027 |
| y_2028 | same as for y_2025, but calendar year 2028 |
| y_2029 | same as for y_2025, but calendar year 2029 |
| y_2030 | same as for y_2025, but calendar year 2030 |
| y_2025_proportion | this is set to 0.25 because there’s only about 25% of calendar year 2025 left |
| y_2026_proportion | leave at 1 unless there’s some reason to think specimens won’t be collected for all of 2026 |
| y_2027_proportion | leave at 1 unless there’s some reason to think specimens won’t be collected for all of 2027 |
| y_2028_proportion | leave at 1 unless there’s some reason to think specimens won’t be collected for all of 2028 |
| y_2029_proportion | leave at 1 unless there’s some reason to think specimens won’t be collected for all of 2029 |
| y_2030_proportion | leave at 1 unless there’s some reason to think specimens won’t be collected for all of 2030 |
| specialized_obesity | is that biospecimen being collected by sites where the PI selected obesity as an outcome of interest? |
| specialized_obesity_proportion | proportion of participants from sites where PI selected obesity as outcome of interest. |
| specialized_chemphys | is that biospecimen being collected by sites where the PI selected Chemical/Phyical as an exposure of interest? |
| specialized_chemphys_proportion | proportion of participants from sites where PI selected Chemical/Physical as exposure of interest |
| specialized_lifestyle | is that biospecimen being collected by sites where the PI selected Lifestyle as an exposure of interest? |
| specialized_lifestyle_proportion | proportion of participants from sites where PI selected Lifestyle as exposure of interest |
| notes | general notes about the data for your reference |

Green checkmark (✅ ) means we have that data, a yellow dot (🟡) means
it’s speculative estimated data that we can kind of guess at, while a
red x (❌ ) means **WE AS THE LAB CORE** are missing that specific
information but it does exist.
