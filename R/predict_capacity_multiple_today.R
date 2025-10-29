# source("R/utils.R")
# source("R/multiple_freezers.R")
library(lubridate)
library(dplyr)
library(tidyr)
library(tibble)
library(readxl)
library(stringr)
library(janitor)


#' Predict and Save Capacity Forecasts for Multiple Sites (November 1 Version)
#'
#' @description
#' Runs a multi-site freezer capacity forecast and saves all results, including
#' tables and diagnostic plots, to the current working directory.
#' This version includes November 1 data updates and multi-site aggregation.
#'
#' @details
#' The function extends the single-site capacity model to all Biostore sites.
#' It loads historical throughput, pending kits, and PTF inflow plans, then
#' solves a CVXR-based linear optimization for each site to estimate required
#' freezers and processing sufficiency through 2030.
#'
#' Outputs include:
#' - Per-tube-type time series of arrivals, processing, and backlog
#' - Cumulative collected vs. stored curves
#' - Network-level freezer utilization over time
#' - Aggregated capacity crossing points per location
#'
#' The function saves both cleaned and year-end summary spreadsheets, as well as
#' publication-ready plots.
#'
#' @section Saved Outputs:
#' **Tables (.xlsx)**:
#' - `collected_counts_clean.xlsx`, `collected_counts_year_end.xlsx`
#' - `stored_counts_clean.xlsx`, `stored_counts_year_end.xlsx`
#' - `at_the_sites_counts_clean.xlsx`, `at_the_sites_counts_year_end.xlsx`
#' - `crossings_by_location.xlsx`
#'
#' **Plots (.png)**:
#' - `plot_backlog_processed_arrivals.png`
#' - `plot_cumulative_collected_vs_stored.png`
#' - `freezer_utilization.png`
#'
#' @return
#' This function does not return an object.
#' All results are saved in the current working directory.
#'
#' @examples
#' \dontrun{
#' predict_capacity_multiple_november1()
#' # After running, check the working directory for Excel summaries and PNG plots.
#' }
#'
#' @export
predict_capacity_multiple_today <- function(){

### options
  price_option <- "p2" # p1 or p2
  taday <- Sys.Date()


  ## 1 - get the data
  # excel_sheets("inst/extdata/Table 1. ECHO Kits and Aliquots.xlsx")

  # CURRENT and PENDING:
  dac <- read_excel("inst/extdata/Table 1. ECHO Kits and Aliquots.xlsx", sheet = "Table C1 simplified") # use labwear type not kit type.
  samples_at_the_sites <- dac%>%select(labware_type,`Collected - Received`) %>%
    rename(number=`Collected - Received`)
  samples_at_the_repository <-dac%>%select(labware_type,`Received at Repository`) %>%
    rename(number=`Received at Repository`)

  # PLANNED: scheduled incoming counts by month (non-cumulative)
  ptf<-kits_proj(make_long = TRUE) %>%
    filter(year >= 2025) %>%
    filter(pricing_option == price_option) %>% # p1 price option has more tubes
    select(-pricing_option)%>%
    mutate(
      specimen_clean = case_when(
        specimen_clean == "maternal_water_specialzied" ~ "maternal_water_specialized",
        TRUE ~ specimen_clean
      )
    )

  ptf_scaled <- ptf %>%
    mutate(across(
      kit_count,
      ~ if_else(
        year == "2025",
        .x * as.numeric(difftime(as.Date("2025-12-31"), taday, units = "days")) / 365,
        .x
      )
    ))#  proportion of 2025 left


  map_kit_to_labware <- read_excel("inst/extdata/Table 1. ECHO Kits and Aliquots.xlsx", sheet = "Table 1. MEGHAN COPY VERSION") # kits_proj_function_kit_type ~ specimen_clean
  # filter(!is.na(containers_per_rack) & containers_per_rack!="unknown")# # exlude ambient + partner semen + water bag
  # add maternal_placenta_tier1_core
  map_kit_to_labware <- map_kit_to_labware %>%
    bind_rows(
      tibble(
        `Protocol Version` = "current",
        kit_type = "maternal_placenta_tier1_core",
        labware_type = "maternal_placenta_tier1_core",
        labware_count = "1",             # character type
        location = "ambient",
        container = NA_character_,
        units_per_container = NA_character_,
        containers_per_rack = NA_character_,
        specimens_per_rack = NA_character_,
        kits_proj_function_kit_type = "maternal_placenta_tier1_core"
      )
    )


  ptf_map <- ptf_scaled %>%
    left_join(map_kit_to_labware,
              by = c("specimen_clean" = "kits_proj_function_kit_type"),
              relationship = "many-to-many")

  ptf_labware <- ptf_map %>%
    filter(labware_count != "unknown") %>% # remove partner_semen_specialized
    mutate(labware_count = as.numeric(labware_count)) %>%  # convert to numeric
    group_by(year, labware_type, location) %>%
    summarise(total_labware_count = sum(labware_count *kit_count , na.rm = TRUE)) %>%
    ungroup()

  # expand_year_to_months <- function(df, start_2025, finish_2030) {
  #   df %>%
  #     mutate(
  #       year = as.integer(year),
  #       start_date = if_else(year == 2025L, .env$start_2025, as.Date(paste0(year, "-01-01"))),
  #       end_date   = if_else(year == 2030L, .env$finish_2030, as.Date(paste0(year, "-12-31")))
  #     ) %>%
  #     rowwise() %>%
  #     mutate(
  #       months_seq = list(seq.Date(start_date, end_date, by = "month")),
  #       n_months   = length(months_seq),
  #       monthly_labware = total_labware_count / n_months
  #     ) %>%
  #     ungroup() %>%
  #     select(year, labware_type, location, months_seq, monthly_labware) %>%
  #     unnest(months_seq) %>%
  #     mutate(date = ceiling_date(months_seq, "month") - days(1)) %>%
  #     select(date, labware_type, location, year,
  #            total_labware_count = monthly_labware) %>%
  #
  #     # ---- Add post-2030 months as zeros ----
  #   bind_rows({
  #     df %>%
  #       filter(year == 2030L) %>%
  #       distinct(labware_type, location) %>%
  #       ungroup() %>%  # <-- Important: ungroup before mutate
  #       mutate(months_post = list(seq.Date(
  #         ceiling_date(finish_2030, "month"),
  #         as.Date("2030-12-31"), by = "month"
  #       ))) %>%
  #       unnest(months_post) %>%
  #       mutate(
  #         date = ceiling_date(months_post, "month") - days(1),
  #         year = 2030L,
  #         total_labware_count = 0
  #       ) %>%
  #       select(date, labware_type, location, year, total_labware_count)
  #   }) %>%
  #     arrange(labware_type, location, date)
  # }
  expand_year_to_months <- function(df, start_2025, finish_2030) {
    df %>%
      mutate(
        year = as.integer(year),
        start_date = if_else(year == 2025L, .env$start_2025, as.Date(paste0(year, "-01-01"))),
        end_date   = if_else(year == 2030L, .env$finish_2030, as.Date(paste0(year, "-12-31")))
      ) %>%
      rowwise() %>%
      mutate(
        # Generate all month-end dates within the range
        months_seq = list(seq.Date(start_date, end_date, by = "month")),

        # Calculate effective number of months with fractional correction for first month
        n_months_full = length(months_seq),
        first_month_days_total = days_in_month(start_date),
        first_month_days_used = first_month_days_total - day(start_date) + 1,
        first_month_fraction = first_month_days_used / first_month_days_total,

        # Adjusted total months accounting for partial first month
        n_months = (n_months_full - 1) + first_month_fraction,
        monthly_labware = total_labware_count / n_months
      ) %>%
      ungroup() %>%
      select(year, labware_type, location, months_seq, monthly_labware,
             start_date, first_month_fraction) %>%
      unnest(months_seq) %>%
      # mutate(
      #   date = ceiling_date(months_seq, "month") - days(1),
      #   # Apply the fractional adjustment to the first partial month
      #   total_labware_count = if_else(
      #     months_seq == floor_date(start_date, "month"),
      #     monthly_labware * first_month_fraction,
      #     monthly_labware
      #   )
      # )
      mutate(
        date = ceiling_date(months_seq, "month") - days(1),
        total_labware_count = if_else(
          year(months_seq) == year(start_date) & month(months_seq) == month(start_date),
          monthly_labware * first_month_fraction,
          monthly_labware
        )
      )%>%
      select(date, labware_type, location, year, total_labware_count) %>%

      # ---- Add post-2030 months as zeros ----
    bind_rows({
      df %>%
        filter(year == 2030L) %>%
        distinct(labware_type, location) %>%
        ungroup() %>%
        mutate(months_post = list(seq.Date(
          ceiling_date(.env$finish_2030, "month"),
          as.Date("2030-12-31"), by = "month"
        ))) %>%
        unnest(months_post) %>%
        mutate(
          date = ceiling_date(months_post, "month") - days(1),
          year = 2030L,
          total_labware_count = 0
        ) %>%
        select(date, labware_type, location, year, total_labware_count)
    }) %>%
      arrange(labware_type, location, date)
  }

  ptf_labware_month <- expand_year_to_months(ptf_labware,taday ,as.Date("2030-07-31"))

  # ggplot(ptf_labware_month %>% filter(labware_type=="Plastic bag"), aes(x = date,
  #                               y = total_labware_count,
  #                               color = labware_type)) +
  #   geom_line(linewidth = 1) +
  #   geom_point(size = 1.5) +
  #   labs(
  #     title = "Monthly Labware Usage",
  #     x = "Month",
  #     y = "Total Labware Count",
  #     color = "Labware Type"
  #   ) +
  #   theme_minimal(base_size = 13) +
  #   theme(
  #     legend.position = "bottom",
  #     panel.grid.minor = element_blank(),
  #     axis.text.x = element_text(angle = 45, hjust = 1)
  #   )



  # 2 -  accomodate to a matrix vector form
  planned <- ptf_labware_month %>%
    arrange(date, labware_type, location)

  # row_index <- planned %>%
  #   distinct(labware_type, location)
  # row_index <- map_kit_to_labware %>%
  #   distinct(labware_type, location) %>%
  #   bind_rows(
  #     tibble(
  #       labware_type = "kpa placenta bag",
  #       location = "ambient"
  #     )
  #   ) %>%
  #   distinct()
  row_index <- map_kit_to_labware %>%
    distinct(labware_type, location) %>%
    bind_rows(
      tibble(
        labware_type = "kpa placenta bag",
        location = "ambient"
      )
    ) %>%
    distinct() %>%
    mutate(
      location = factor(
        location,
        levels = c("biostore", "-80C freezer", "-20C freezer", "ambient")
      )
    ) %>%
    arrange(location, labware_type)

  # A_mat <- planned %>%
  #   unite("row_id", labware_type, location, sep = "|") %>%
  #   group_by(date, row_id) %>%
  #   summarise(tubes_count = sum(total_labware_count, na.rm = TRUE), .groups = "drop") %>%
  #   tidyr::pivot_wider(names_from = date, values_from = tubes_count, values_fill = 0) %>%
  #   arrange(factor(row_id, levels = row_index$row_id)) %>%
  #   tibble::column_to_rownames("row_id") %>%
  #   as.matrix()
  # A_mat <- planned %>%
  #   group_by(date, labware_type, location) %>%
  #   summarise(tubes_count = sum(total_labware_count, na.rm = TRUE), .groups = "drop") %>%
  #   right_join(row_index, by = c("labware_type", "location")) %>%
  #   mutate(tubes_count = replace_na(tubes_count, 0)) %>%
  #   pivot_wider(
  #     names_from = date,
  #     values_from = tubes_count,
  #     values_fill = 0
  #   ) %>%
  #   arrange(match(paste(labware_type, location), paste(row_index$labware_type, row_index$location))) %>%
  #   unite("row_id", labware_type, location, sep = "|", remove = FALSE) %>%
  #   column_to_rownames("row_id") %>%
  #   select(-labware_type, -location) %>%
  #   as.matrix()
  A_mat <- row_index %>%
    left_join(
      planned %>%
        filter(!is.na(date)) %>%             # make sure only valid dates remain
        mutate(date = as.Date(date)) %>%
        group_by(date, labware_type, location) %>%
        summarise(tubes_count = sum(total_labware_count, na.rm = TRUE), .groups = "drop"),
      by = c("labware_type", "location")
    ) %>%
    mutate(tubes_count = replace_na(tubes_count, 0)) %>%
    tidyr::pivot_wider(
      names_from  = date,
      values_from = tubes_count,
      values_fill = 0
    ) %>%
    select(!any_of("NA")) %>%               # ← remove the stray NA column
    arrange(match(
      paste(labware_type, location),
      paste(row_index$labware_type, row_index$location)
    )) %>%
    unite("row_id", labware_type, location, sep = "@", remove = FALSE) %>%
    tibble::column_to_rownames("row_id") %>%
    select(-labware_type, -location) %>%
    as.matrix()

  # add location

  samples_at_the_sites_loc <- row_index %>%
    filter(!(labware_type == "Cryovial with Label" & location == "ambient")) %>%
    right_join(samples_at_the_sites, by = "labware_type")

  samples_at_the_repository_loc <- row_index %>%
    filter(!(labware_type == "Cryovial with Label" & location == "ambient")) %>%
    right_join(samples_at_the_repository, by = "labware_type")


  # kepp as a vec in the right order
  sites_vec <- row_index %>%
    left_join(
      samples_at_the_sites_loc,
      by = c("labware_type", "location")
    ) %>%
    mutate(
      number = replace_na(number, 0)
    ) %>%
    pull(number)

  repo_vec <- row_index %>%
    left_join(
      samples_at_the_repository_loc,
      by = c("labware_type", "location")
    ) %>%
    mutate(
      number = replace_na(number, 0)
    ) %>%
    pull(number)

  # remove specimens that are not planned nor we have stock
  keep_specimens <- rowSums(A_mat)>0 | repo_vec >0 | sites_vec>0
  row_index <- row_index[keep_specimens,]
  A_mat <- A_mat[keep_specimens,]
  sites_vec <- sites_vec[keep_specimens]
  repo_vec  <- repo_vec[keep_specimens]

  if (price_option == "p1"){
    # for p1
    # fixed capacity
    # capacity_vec <- rep(80000, ncol(A_mat))
    # increasing capacity 1
    periods <- as.Date(colnames(A_mat))
    # capacity_vec <- case_when(
    #   format(periods, "%Y") <  "2026" ~ 30000,
    #   format(periods, "%Y") == "2026" ~ 50000,
    #   format(periods, "%Y") == "2027" ~ 70000,
    #   format(periods, "%Y") >= "2028" ~ 90000
    # )
    # increasing capacity 2
    capacity_vec <- case_when(
      format(periods, "%Y") <   "2027" ~ 30000,
      format(periods, "%Y") ==  "2027" ~ 90000,
      format(periods, "%Y") >=  "2028" ~ 90000,
    )
  }else{
    # for p2
    # fixed capacity
    # capacity_vec <- rep(55000, ncol(A_mat))
    # increasing capacity 1
    periods <- as.Date(colnames(A_mat))
    capacity_vec <- case_when(
      format(periods, "%Y") <  "2026" ~ 40000,
      format(periods, "%Y") == "2026" ~ 50000,
      format(periods, "%Y") >= "2027" ~ 60000
    )
  }

  # scale init capacity to remaining days
  first_month_days_total = days_in_month(taday)
  first_month_days_used  = first_month_days_total - day(taday) + 1
  first_month_fraction   = first_month_days_used / first_month_days_total
  capacity_vec[1] <- capacity_vec[1] * first_month_fraction


  w_vec = rep(1,nrow(A_mat))
  # prioritize ambient
  # w_vec[grep("@ambient", rownames(A_mat), ignore.case = TRUE)]=1.1
  res<-optimize_backlog_and_processed(
    A_mat = A_mat,
    capacity_vec = capacity_vec,
    stored_vec = sites_vec,
    w_vec = w_vec,
    w_stored = 1e6,
    w_stored_increase = 1e-6
  )







  plot_backlog_processed_arrivals <- function(Q_opt, X_opt, A_mat, periods, stored_vec) {
    stopifnot(is.matrix(Q_opt), is.matrix(X_opt), is.matrix(A_mat))
    stopifnot(all(dim(Q_opt) == dim(X_opt)), all(dim(Q_opt) == dim(A_mat)))
    stopifnot(length(periods) == ncol(Q_opt))
    stopifnot(length(stored_vec) == nrow(Q_opt))

    n_tube <- nrow(Q_opt)
    n_time <- ncol(Q_opt)

    # --- Use rownames from A_mat instead of generic Tube_1, Tube_2 ---
    tube_types <- rownames(A_mat)

    # --- Core tidy frames ---
    dfQ <- data.frame(
      tube_type = rep(tube_types, each = n_time),
      period = rep(periods, times = n_tube),
      value = as.vector(t(Q_opt)),
      metric = "Backlog (Q)"
    )
    dfX <- data.frame(
      tube_type = rep(tube_types, each = n_time),
      period = rep(periods, times = n_tube),
      value = as.vector(t(X_opt)),
      metric = "Processed (X)"
    )
    dfA <- data.frame(
      tube_type = rep(tube_types, each = n_time),
      period = rep(periods, times = n_tube),
      value = as.vector(t(A_mat)),
      metric = "Arrivals (A)"
    )

    df <- rbind(dfA, dfX, dfQ)

    # --- Find clear-out points ---
    clear_points <- lapply(seq_len(n_tube), function(i) {
      cum_processed <- cumsum(X_opt[i, ])
      idx <- which(cum_processed >= stored_vec[i])[1]
      if (!is.na(idx)) {
        data.frame(
          tube_type = tube_types[i],
          period = periods[idx],
          value = X_opt[i, idx]
        )
      } else NULL
    }) %>% dplyr::bind_rows()

    # --- Plot ---
    library(ggplot2)
    ggplot(df, aes(x = period, y = value, color = metric, linetype = metric)) +
      geom_line(linewidth = 1) +
      facet_wrap(~ tube_type, scales = "free_y",ncol = 3) +
      geom_point(data = clear_points, aes(x = period, y = value),
                 shape = 8, size = 4, color = "black", inherit.aes = FALSE) +
      scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
      theme_minimal(base_size = 13) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(
        title = "Arrivals (A), Processed (X), and Backlog (Q) per Tube Type",
        subtitle = "* indicates when initial backlog is cleared",
        x = "Time (months)",
        y = "Number of Tubes",
        color = "",
        linetype = ""
      )
  }
  p<-plot_backlog_processed_arrivals(
    res$Q_opt,
    res$X_opt,
    A_mat,
    as.Date(colnames(A_mat)),
    sites_vec
  )
  ggsave("plot_backlog_processed_arrivals.png", plot = p, width = 16, height = 21, dpi = 300)


  # 3- cumulatives and freezer capacity
  cumulative = 	t(apply(cbind(repo_vec,res$X_opt), 1, cumsum))
  rownames(cumulative) <- rownames(A_mat)
  colnames(cumulative) <- as.Date(c(taday,colnames(A_mat)))
  # rows of cumulative are in the order given in row_index

  # to number of raks
  map_labware_type_to_specimens_per_rack <- map_kit_to_labware %>%
    group_by(labware_type, location) %>%
    summarise(specimens_per_rack = first(specimens_per_rack), .groups = "drop")

  # to number of freezers
  rack_to_freezer <- read_excel("inst/extdata/Table 1. ECHO Kits and Aliquots.xlsx", sheet = "Table 2. ECHO Freezer Capacity")
  rack_to_freezer_clean <- rack_to_freezer %>%
    filter(!if_all(everything(), is.na))  # remove rows that are all NA

  # # parameter: choose which -20/-80 freezer to use
  selected_freezer <- "TSX70086FA"  # or "TSX60086FA"

  map_labware_type_to_specimens_per_freezer <- map_labware_type_to_specimens_per_rack %>%
    mutate(
      specimens_per_rack = suppressWarnings(as.numeric(specimens_per_rack)),  # convert numeric
      specimens_per_freezer =
        case_when(
          location == "biostore" ~ specimens_per_rack *
            rack_to_freezer_clean$rack_capacity[rack_to_freezer_clean$freezer_type == "BioStore 2"],

          location %in% c("-20C freezer", "-80C freezer") ~ specimens_per_rack *
            rack_to_freezer_clean$rack_capacity[rack_to_freezer_clean$freezer_type == selected_freezer],

          location == "ambient" ~ NA,  # infinity for ambient
          TRUE ~ NA_real_
        )
    )

  capacity_biostore_meghan <- capacityNumbers()
  freezer_per_specimen <- row_index %>%
    left_join(
      map_labware_type_to_specimens_per_freezer,
      by = c("labware_type", "location")
    ) %>%
    mutate(
      freezer_per_specimen = replace_na(1/specimens_per_freezer, 0)# if we dont have specimens_per_freezer then set to 0
    ) %>%
    mutate(
      freezer_per_specimen = case_when(
        labware_type == "1.0mL Barcoded Cryovial" & location == "biostore" ~ 1 / capacity_biostore_meghan$tubes_1.0ml_max_capacity,
        labware_type == "1.9mL Barcoded Cryovial" & location == "biostore" ~ 1 / capacity_biostore_meghan$tubes_1.9ml_max_capacity,
        TRUE ~ freezer_per_specimen
      )
    ) %>%
    pull(freezer_per_specimen)
  # freezer_per_specimen[is.infinite(freezer_per_specimen)] <- 0 # do not count 125 mL PFAS-free Bottle

  # 4- scale cumulative into freezer
  cum_scaled <- cumulative * freezer_per_specimen
  cum_by_location <- rowsum(cum_scaled, group = row_index$location)
  cum_by_location_clean <- cum_by_location[!rownames(cum_by_location) %in% c("ambient", "unknown"), ]
  # convert matrix to tidy tibble
  cum_by_location_long <- as.data.frame(cum_by_location_clean) %>%
    rownames_to_column("location") %>%
    pivot_longer(
      cols = -location,
      names_to = "period",
      values_to = "value"
    ) %>%
    mutate(period = as.Date(as.numeric(period), origin = "1970-01-01"))

  # --- Plot ---
  ggplot(cum_by_location_long, aes(x = period, y = value, color = location)) +
    geom_line(linewidth = 1.2) +
    theme_minimal(base_size = 13) +
    labs(
      title = "Cumulative Processed Tubes per Location",
      x = "Period (time index)",
      y = "Cumulative total",
      color = "Location"
    ) +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(angle = 45, hjust = 1)
    )

  cum_by_location_long_scaled <- cum_by_location_long %>%
    mutate(
      value_scaled = case_when(
        location == "-80C freezer" ~ value / 10,
        location == "-20C freezer" ~ value / 2,
        TRUE ~ value
      ),
      location_label = case_when(
        location == "-80C freezer" ~ "-80C freezer (x10)",
        location == "-20C freezer" ~ "-20C freezer (x2)",
        TRUE ~ location
      )
    )

  # ggplot(cum_by_location_long_scaled,
  #        aes(x = period, y = value_scaled, color = location_label)) +
  #   geom_line(linewidth = 1.2) +
  #   theme_minimal(base_size = 13) +
  #   labs(
  #     title = "Cumulative Processed Tubes per Location",
  #     x = "Period (time index)",
  #     y = "Cumulative total (scaled)",
  #     color = "Location"
  #   ) +
  #   theme(
  #     legend.position = "bottom",
  #     axis.text.x = element_text(angle = 45, hjust = 1)
  #   )
  p<-ggplot(cum_by_location_long_scaled,
            aes(x = period, y = value_scaled, color = location_label)) +
    geom_line(linewidth = 1.2) +
    theme_minimal(base_size = 13) +
    scale_x_date(
      date_labels = "%b %Y",
      date_breaks = "2 month"
    ) +
    scale_y_continuous(breaks = scales::pretty_breaks(n = 6)) +
    labs(
      title = "Cumulative Processed Tubes per Location",
      x = "Period (time index)",
      y = "Cumulative total",
      color = "Location"
    ) +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
  ggsave("freezer_utilization.png", plot = p, width = 8, height = 6, dpi = 300)


  # # print
  # library(dplyr)
  # library(knitr)
  # library(kableExtra)
  #
  # colnames(cumulative)[-1] <- as.character(as.Date(as.numeric(colnames(cumulative)[-1]), origin = "1970-01-01"))
  #
  # # 2. keep only integer part
  # cumulative_clean <- as.data.frame(cumulative) %>%
  #   mutate(across(where(is.numeric), floor))
  #
  # # 3. Pretty print
  # cumulative_clean %>%
  #   kbl(caption = "Cumulative counts (integer only)", format = "html", align = "r") %>%
  #   kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed")) %>%
  #   scroll_box(width = "100%", height = "600px") %>%
  #   column_spec(1, bold = TRUE, width = "20em")
  # write_xlsx(cumulative_clean, paste0("cumulative_counts_",price_option,".xlsx"))
  #
  #
  # # Convert all potential date-like column names to Date
  # date_strings <- colnames(cumulative_clean)[-1]
  # date_cols <- suppressWarnings(as.Date(date_strings))
  #
  # # Keep only valid Date columns
  # valid_dates <- !is.na(date_cols)
  # date_cols <- date_cols[valid_dates]
  # valid_colnames <- date_strings[valid_dates]
  #
  # # Find the last date per year
  # last_days <- tapply(date_cols, format(date_cols, "%Y"), max, na.rm = TRUE)
  #
  # # Convert numeric (like 20453) to Date properly
  # last_days <- as.Date(as.numeric(last_days), origin = "1970-01-01")
  #
  # # Make sure they exist as column names
  # keep_cols <- as.character(last_days)
  # keep_cols <- keep_cols[keep_cols %in% colnames(cumulative_clean)]
  #
  # # Subset
  # cumulative_year_end <- cumulative_clean %>%
  #   select(1, all_of(keep_cols))
  #
  # # Optional: rename to just the year for clarity
  # colnames(cumulative_year_end)[-1] <- format(as.Date(colnames(cumulative_year_end)[-1]), "%Y")
  #
  # # Export to Excel
  # library(writexl)
  # cumulative_year_end_out <- cumulative_year_end %>%
  #   tibble::rownames_to_column(var = "Sample_Type")
  #
  # write_xlsx(cumulative_year_end_out, "cumulative_counts_year_end.xlsx")
  #
  #
  #
  #
  # # 1. Convert numeric column names to Date (if needed)
  # colnames(res$Q_opt) <- colnames(cumulative[,-1])
  #
  # # 2. Keep only the integer part
  # Q_opt_clean <- as.data.frame(res$Q_opt) %>%
  #   mutate(across(where(is.numeric), floor))
  #
  # # 3. Pretty-print
  # Q_opt_clean %>%
  #   kbl(caption = "Q_opt (integer only)", format = "html", align = "r") %>%
  #   kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed")) %>%
  #   scroll_box(width = "100%", height = "600px") %>%
  #   column_spec(1, bold = TRUE, width = "20em")
  #
  # # 4. Export to Excel
  #
  # rownames(Q_opt_clean) <- rownames(cumulative_clean)
  # write_xlsx(Q_opt_clean, "Q_opt_clean.xlsx")
  #
  #
  #
  #
  # # 1. Convert all potential date-like column names to Date
  # date_strings <- colnames(Q_opt_clean)[-1]
  # date_cols <- suppressWarnings(as.Date(date_strings))
  #
  # # 2. Keep only valid Date columns
  # valid_dates <- !is.na(date_cols)
  # date_cols <- date_cols[valid_dates]
  # valid_colnames <- date_strings[valid_dates]
  #
  # # 3. Find last date per year
  # last_days <- tapply(date_cols, format(date_cols, "%Y"), max, na.rm = TRUE)
  #
  # # 4. Convert numeric year-day counts (like 20453) to real dates
  # last_days <- as.Date(as.numeric(last_days), origin = "1970-01-01")
  #
  # # 5. Keep only columns that exist in your data
  # keep_cols <- as.character(last_days)
  # keep_cols <- keep_cols[keep_cols %in% colnames(Q_opt_clean)]
  #
  # # 6. Subset to those columns + first column
  # Q_opt_year_end <- Q_opt_clean %>%
  #   select(1, all_of(keep_cols))
  #
  # # 7. Optional: rename to show only the year (e.g., 2025, 2026, ...)
  # colnames(Q_opt_year_end)[-1] <- format(as.Date(colnames(Q_opt_year_end)[-1]), "%Y")
  #
  # # 8. Export to Excel
  # rownames(Q_opt_year_end) <- rownames(cumulative_clean)
  # Q_opt_year_end_out <- Q_opt_year_end %>%
  #   tibble::rownames_to_column(var = "Sample_Type")
  #
  # write_xlsx(Q_opt_year_end_out, "Q_opt_year_end.xlsx")
  library(dplyr)
  library(writexl)
  library(tibble)

  save_year_end_summary <- function(df, prefix, keep_first_column=FALSE) {
    # 1. Convert numeric column names to Dates (if applicable)
    # date_names <- suppressWarnings(as.Date(as.numeric(colnames(df)[-1]), origin = origin))
    # valid_dates <- !is.na(date_names)
    # colnames(df)[-1][valid_dates] <- as.character(date_names[valid_dates])

    # 2. Keep only integer part
    df_clean <- df %>%
      mutate(across(where(is.numeric), floor))

    # 3. Save full table
    write_xlsx(df_clean %>% rownames_to_column("Sample_Type"),
               paste0(prefix, "_clean.xlsx"))

    # 4. Compute year-end subset
    # date_strings <- colnames(df_clean)[-1]
    first_col <- colnames(df_clean)[1]
    if (!keep_first_column) {
      # First column is a date → include all columns as date columns
      date_strings <- colnames(df_clean)
    } else {
      # First column is not a date → skip it
      date_strings <- colnames(df_clean)[-1]
    }
    date_cols <- suppressWarnings(as.Date(date_strings))
    valid_dates <- !is.na(date_cols)
    date_cols <- date_cols[valid_dates]

    # Find last day per year
    last_days <- tapply(date_cols, format(date_cols, "%Y"), max, na.rm = TRUE)
    last_days <- as.Date(as.numeric(last_days), origin = origin)

    # Match to actual columns
    keep_cols <- as.character(last_days)
    keep_cols <- keep_cols[keep_cols %in% colnames(df_clean)]

    if(keep_first_column){
      df_year_end <- df_clean %>%
        select(1,all_of(keep_cols))
      colnames(df_year_end)[-1] <- format(as.Date(colnames(df_year_end)[-1]), "%Y")
    }else{
      df_year_end <- df_clean %>%
        select(all_of(keep_cols))
      colnames(df_year_end) <- format(as.Date(colnames(df_year_end)), "%Y")
    }

    # Rename to just years


    # 5. Save year-end table
    write_xlsx(df_year_end %>% rownames_to_column("Sample_Type"),
               paste0(prefix, "_year_end.xlsx"))

    invisible(df_year_end)
  }

  colnames(cumulative) <- as.character(as.Date(as.numeric(colnames(cumulative)), origin = "1970-01-01"))
  cumulative_df <- as.data.frame(cumulative) %>%
    mutate(across(where(is.numeric), floor))
  colnames(cumulative_df)[1] <- "Current"
  save_year_end_summary(cumulative_df, prefix = "stored_counts", keep_first_column = T)

  Q_df <- as.data.frame(res$Q_opt) %>%
    mutate(across(where(is.numeric), floor))
  rownames(Q_df) <- rownames(cumulative_df)
  colnames(Q_df) <- colnames(cumulative_df)[-1]
  save_year_end_summary(Q_df, prefix = "at_the_sites_counts")

  # total collections cumulative
  Q_all <- cbind(sites_vec,Q_df)
  colnames(Q_all)[1] <- "Current"
  total_collected<-Q_all + cumulative_df
  save_year_end_summary(total_collected, prefix = "collected_counts", keep_first_column = T)

  # when the freezers are filled?
  library(purrr)
  crossings <- cum_by_location_long %>%
    arrange(location, period) %>%
    group_by(location) %>%
    mutate(prev_value = lag(value, default = first(value))) %>%
    filter(floor(value) > floor(prev_value)) %>%  # keep only when integer part increases
    mutate(threshold = floor(value)) %>%
    select(location, threshold, period)
  write_xlsx(crossings, "crossings_by_location.xlsx")


  # plot cumulative collected vs freezer
  plot_cumulative_collected_vs_stored <- function(Q_all, cumulative_df, periods, tube_labels) {
    # Convert inputs if needed
    Q_all <- as.matrix(Q_all)
    cumulative_df <- as.matrix(cumulative_df)

    stopifnot(all(dim(Q_all) == dim(cumulative_df)))
    stopifnot(length(periods) == ncol(Q_all))
    stopifnot(length(tube_labels) == nrow(Q_all))

    n_tube <- nrow(Q_all)
    n_time <- ncol(Q_all)
    tube_types <- tube_labels

    # --- tidy frames ---
    dfQ <- data.frame(
      tube_type = rep(tube_types, each = n_time),
      period = rep(periods, times = n_tube),
      value = as.vector(t(Q_all)),
      metric = "Collected"
    )
    dfS <- data.frame(
      tube_type = rep(tube_types, each = n_time),
      period = rep(periods, times = n_tube),
      value = as.vector(t(cumulative_df)),
      metric = "Stored"
    )

    df <- rbind(dfQ, dfS)

    # --- plot ---
    library(ggplot2)
    ggplot(df, aes(x = period, y = value, color = metric, linetype = metric)) +
      geom_line(linewidth = 1) +
      facet_wrap(~ tube_type, scales = "free_y", ncol = 3) +
      scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
      theme_minimal(base_size = 13) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(
        title = "Cumulative Collected vs Stored Tubes",
        x = "Time (months)",
        y = "Cumulative Number of Tubes",
        color = "",
        linetype = ""
      )
  }

  colnames(total_collected)[1] <- as.character(as.Date("2025-11-01"))
  colnames(cumulative_df)[1] <- as.character(as.Date("2025-11-01"))
  p <- plot_cumulative_collected_vs_stored(
    total_collected,
    cumulative_df,
    as.Date(colnames(cumulative_df)),
    rownames(cumulative_df)
  )

  ggsave("plot_cumulative_collected_vs_stored.png",
         plot = p, width = 16, height = 21, dpi = 300)
}
