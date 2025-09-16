
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
information, but it does exist!.

## What is the total BioStore II capacity?

The simplest equation for calculating BioStore capacity is:

$$\frac{(196,412 + x)}{788,256} + \frac{(212,692 + y)}{438,840} = 1$$

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
historical_data_long_proportions <- longifyReadHistorical(total_or_prop = "prop") # same as directly above, but proportions of freezer capacity instead of raw numbers
```

#### Plot rate of accessioning over time:

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

#### Plot overall proportion of BioStore filled over time:

This includes “pending” tubes, which are tubes that are still at the
sites but will be shipped here eventually and should be counted towards
the BioStore’s total inventory.

``` r
ggplot(longifyReadHistorical(total_or_prop = "prop", add_pending = TRUE), aes(x = date, y = total, colour = tube_type)) +
  geom_point() +
  geom_smooth() +
  theme_bw() +
  ylab("Cumulative Proportion of BioStore Capacity Filled") +
  xlab("") +
  scale_x_date(date_breaks = "2 month", date_labels = "%b %y") + 
  geom_hline(yintercept = 1)
#> `geom_smooth()` using method = 'loess' and formula = 'y ~ x'
```

<img src="man/figures/README-plot_history_prop-1.png" width="100%" />

### Eric Koplin’s ARIMA model

Eric Koplin has built an ARIMA model using the forecast package to
predict when the BioStore would be full based on the historical rate of
filling:

``` r
single_arima()
```

<img src="man/figures/README-arima-1.png" width="100%" />

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

``` r
readcollectionsdescriptions() 
```

<div id="mxwaieferh" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#mxwaieferh table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
&#10;#mxwaieferh thead, #mxwaieferh tbody, #mxwaieferh tfoot, #mxwaieferh tr, #mxwaieferh td, #mxwaieferh th {
  border-style: none;
}
&#10;#mxwaieferh p {
  margin: 0;
  padding: 0;
}
&#10;#mxwaieferh .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}
&#10;#mxwaieferh .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}
&#10;#mxwaieferh .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}
&#10;#mxwaieferh .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}
&#10;#mxwaieferh .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}
&#10;#mxwaieferh .gt_column_spanner_outer:first-child {
  padding-left: 0;
}
&#10;#mxwaieferh .gt_column_spanner_outer:last-child {
  padding-right: 0;
}
&#10;#mxwaieferh .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}
&#10;#mxwaieferh .gt_spanner_row {
  border-bottom-style: hidden;
}
&#10;#mxwaieferh .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}
&#10;#mxwaieferh .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}
&#10;#mxwaieferh .gt_from_md > :first-child {
  margin-top: 0;
}
&#10;#mxwaieferh .gt_from_md > :last-child {
  margin-bottom: 0;
}
&#10;#mxwaieferh .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}
&#10;#mxwaieferh .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#mxwaieferh .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}
&#10;#mxwaieferh .gt_row_group_first td {
  border-top-width: 2px;
}
&#10;#mxwaieferh .gt_row_group_first th {
  border-top-width: 2px;
}
&#10;#mxwaieferh .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#mxwaieferh .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_first_summary_row.thick {
  border-top-width: 2px;
}
&#10;#mxwaieferh .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#mxwaieferh .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}
&#10;#mxwaieferh .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#mxwaieferh .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}
&#10;#mxwaieferh .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#mxwaieferh .gt_left {
  text-align: left;
}
&#10;#mxwaieferh .gt_center {
  text-align: center;
}
&#10;#mxwaieferh .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
&#10;#mxwaieferh .gt_font_normal {
  font-weight: normal;
}
&#10;#mxwaieferh .gt_font_bold {
  font-weight: bold;
}
&#10;#mxwaieferh .gt_font_italic {
  font-style: italic;
}
&#10;#mxwaieferh .gt_super {
  font-size: 65%;
}
&#10;#mxwaieferh .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}
&#10;#mxwaieferh .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}
&#10;#mxwaieferh .gt_indent_1 {
  text-indent: 5px;
}
&#10;#mxwaieferh .gt_indent_2 {
  text-indent: 10px;
}
&#10;#mxwaieferh .gt_indent_3 {
  text-indent: 15px;
}
&#10;#mxwaieferh .gt_indent_4 {
  text-indent: 20px;
}
&#10;#mxwaieferh .gt_indent_5 {
  text-indent: 25px;
}
&#10;#mxwaieferh .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}
&#10;#mxwaieferh div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Variable">Variable</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Description">Description</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Variable" class="gt_row gt_left">collection_id</td>
<td headers="Description" class="gt_row gt_left">a unique ID. a concatenation of kit_type, tube_size, visit, and specimen_type</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">kit_type</td>
<td headers="Description" class="gt_row gt_left">concatenation of biospecimen_type and participant</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">biospecimen_type</td>
<td headers="Description" class="gt_row gt_left">type of biospecimen being collected (e.g., urine or blood, etc...)</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">participant</td>
<td headers="Description" class="gt_row gt_left">specimen to be collected from an ECHO child, child's mother, or child's mother's current partner</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">tube_size</td>
<td headers="Description" class="gt_row gt_left">whether tube is 1.0mL or 1.9mL (1.9mL tubes take up more space in the BioStore.)</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">tubes_per_kit</td>
<td headers="Description" class="gt_row gt_left">number of tubes of specified size in that specific kit</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">proportion_from_kit_collected</td>
<td headers="Description" class="gt_row gt_left">what proportion of tubes in that kit are we expecting to be returned to be stored in the BioStore? for example, newborn babies may not produce enough urine for all three 1.9mL tubes to be filled and returned. maybe only two will be returned</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">visit</td>
<td headers="Description" class="gt_row gt_left">time point in child's or child's mother's life when specimen is collected</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">visit_logical_order</td>
<td headers="Description" class="gt_row gt_left">not really that useful here, but orders the visit column by the logical order of an ECHO child's life (sort of; due to preconception protocol, that gets complicated)</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">specimen_type</td>
<td headers="Description" class="gt_row gt_left">is specimen considered by ECHO a core, preconception, or specialized specimen? this is important because sites are expected to at least try to collect every core specimen, while sites are only allowed to collected specific specialized specimens. the preconception specimens are somewhere in the middle</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2025</td>
<td headers="Description" class="gt_row gt_left">1 (yes)/ 0 (no) column. is this specific specimen to be collected in calendar year 2025?</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2026</td>
<td headers="Description" class="gt_row gt_left">same as for y_2025, but calendar year 2026</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2027</td>
<td headers="Description" class="gt_row gt_left">same as for y_2025, but calendar year 2027</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2028</td>
<td headers="Description" class="gt_row gt_left">same as for y_2025, but calendar year 2028</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2029</td>
<td headers="Description" class="gt_row gt_left">same as for y_2025, but calendar year 2029</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2030</td>
<td headers="Description" class="gt_row gt_left">same as for y_2025, but calendar year 2030</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2025_proportion</td>
<td headers="Description" class="gt_row gt_left">this is set to 0.25 because there's only about 25% of calendar year 2025 left</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2026_proportion</td>
<td headers="Description" class="gt_row gt_left">leave at 1 unless there's some reason to think specimens won't be collected for all of 2026</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2027_proportion</td>
<td headers="Description" class="gt_row gt_left">leave at 1 unless there's some reason to think specimens won't be collected for all of 2027</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2028_proportion</td>
<td headers="Description" class="gt_row gt_left">leave at 1 unless there's some reason to think specimens won't be collected for all of 2028</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2029_proportion</td>
<td headers="Description" class="gt_row gt_left">leave at 1 unless there's some reason to think specimens won't be collected for all of 2029</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">y_2030_proportion</td>
<td headers="Description" class="gt_row gt_left">leave at 1 unless there's some reason to think specimens won't be collected for all of 2030</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">specialized_obesity</td>
<td headers="Description" class="gt_row gt_left">is that biospecimen being collected by sites where the PI selected 'Obesity' as an outcome of interest?</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">specialized_obesity_proportion</td>
<td headers="Description" class="gt_row gt_left">proportion of participants from sites where PI selected 'Obesity' as outcome of interest.</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">specialized_chemphys</td>
<td headers="Description" class="gt_row gt_left">is that biospecimen being collected by sites where the PI selected 'Chemical/Phyical' as an exposure of interest?</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">specialized_chemphys_proportion</td>
<td headers="Description" class="gt_row gt_left">proportion of participants from sites where PI selected 'Chemical/Physical' as exposure of interest</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">specialized_lifestyle</td>
<td headers="Description" class="gt_row gt_left">is that biospecimen being collected by sites where the PI selected 'Lifestyle' as an exposure of interest?</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">specialized_lifestyle_proportion</td>
<td headers="Description" class="gt_row gt_left">proportion of participants from sites where PI selected 'Lifestyle'' as exposure of interest</td></tr>
    <tr><td headers="Variable" class="gt_row gt_left">notes</td>
<td headers="Description" class="gt_row gt_left">general notes about the data for your reference</td></tr>
  </tbody>
  &#10;  
</table>
</div>

Green checkmark (✅ ) means we have that data, a yellow dot (🟡) means
it’s speculative estimated data that we can kind of guess at, while a
red x (❌ ) means **WE AS THE LAB CORE** are missing that specific
information but it does exist.
