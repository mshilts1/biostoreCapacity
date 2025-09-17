#' Code is all Eric Koplin!
#'
#' @returns arima
#' @export
#' @importFrom stats time
#' @importFrom stats start
#'
#' @examples
#' predict_capacity()
predict_capacity <- function(hist_init, horizon = 6) {
  # 2. Aggregate to monthly using zoo::as.yearmon
  zoo_total <- zoo::zoo(hist_init$total_capacity, order.by = hist_init$date)
  # zoo_cov <- zoo::zoo(hist_init[, c("prop_1ml", "total_submitted_capacity")], order.by = hist_init$date)

  monthly_total <- stats::aggregate(zoo_total, as.yearmon, mean)
  # monthly_cov <- stats::aggregate(zoo_cov, as.yearmon, mean)

  # 3. Convert aggregated series to ts for ARIMA
  ts_total <- stats::ts(zoo::coredata(monthly_total),
                 start = c(as.numeric(format(start(monthly_total), "%Y")),
                           as.numeric(format(start(monthly_total), "%m"))),
                 frequency = 12)

  # ts_prop <- stats::ts(zoo::coredata(monthly_cov[,"prop_1ml"]),
  #               start = c(as.numeric(format(start(monthly_cov), "%Y")),
  #                         as.numeric(format(start(monthly_cov), "%m"))),
  #               frequency = 12)
  #
  # ts_total_submitted_capacity <- stats::ts(zoo::coredata(monthly_cov[,"total_submitted_capacity"]),
  #                                   start = c(as.numeric(format(start(monthly_cov), "%Y")),
  #                                             as.numeric(format(start(monthly_cov), "%m"))),
  #                                   frequency = 12)

  # 4. Fit ARIMA models for each covariate and forecast
  # fit_prop  <- forecast::auto.arima(ts_prop)
  # ts_total_submitted_capacity <- forecast::auto.arima(ts_total_submitted_capacity)
  #
  # fc_prop  <- forecast::forecast(fit_prop,  h = horizon)
  # fc_total_submitted_capacity <- forecast::forecast(ts_total_submitted_capacity, h = horizon)
  #
  # # 5. Build future covariates from forecasts
  # future_cov <- cbind(
  #   prop_1ml     = as.numeric(fc_prop[[covariates_interval]]),
  #   total_submitted_capacity = as.numeric(fc_total_submitted_capacity[[covariates_interval]])
  # )


  # 6. Fit ARIMA for total capacity with covariates and forecast
  # xreg_cov <- zoo::coredata(monthly_cov)
  # fit_total <- forecast::auto.arima(ts_total, xreg = xreg_cov)
  fit_total <- forecast::auto.arima(ts_total)

  # fc_total <- forecast::forecast(fit_total, xreg = future_cov, h = horizon)
  fc_total <- forecast::forecast(fit_total, h = horizon)

  # Prepare data for plotting with calendar dates
  #library(zoo)

  # Observed monthly dates and values
  obs_dates <- as.Date(zoo::as.yearmon(time(monthly_total)))
  obs_values <- zoo::coredata(monthly_total)

  # Forecast dates
  fc_dates <- as.Date(zoo::as.yearmon(time(fc_total$mean)))

  # Build data frame for observed data
  df_obs <- data.frame(
    date = obs_dates,
    total_capacity = obs_values,
    type = "Observed"
  )

  # Build data frame for forecast data (mean and intervals)
  df_fc <- data.frame(
    date = rep(fc_dates, times = 3),
    total_capacity = c(as.numeric(fc_total$mean),
                       as.numeric(fc_total$lower[,2]),
                       as.numeric(fc_total$upper[,2])),
    interval = rep(c("Mean", "Lower", "Upper"), each = length(fc_dates)),
    type = "Forecast"
  )

  # Combine observed and forecast mean for plotting lines
  # df_line <- rbind(
  #   df_obs %>% select(date, total_capacity, type),
  #   df_fc %>% filter(interval == "Mean") %>% select(date, total_capacity, type)
  # )
  df_line <- rbind(
    df_obs %>% dplyr::select(.data$date, .data$total_capacity, .data$type),
    df_fc %>% dplyr::filter(interval == "Mean") %>% dplyr::select(.data$date, .data$total_capacity, .data$type)
  )
  # add the last observed point to forecast line to avoid the visual jump
  last_obs_point <- utils::tail(df_obs, 1)
  df_line <- rbind(df_line, last_obs_point %>% dplyr::mutate(type = "Forecast"))

  # Prepare forecast ribbon data
  df_ribbon <- df_fc %>%
    dplyr::filter(interval %in% c("Lower", "Upper")) %>%
    tidyr::pivot_wider(names_from = interval, values_from = .data$total_capacity)

  # add crossing dates
  # Forecast results
  t_forecast <- stats::time(fc_total$mean)            # monthly time index
  mean_vals  <- as.numeric(fc_total$mean)
  upper_vals <- as.numeric(fc_total$upper[,2]) # 95% upper

  # Put into zoo with yearmon index
  # Convert forecast index to Date (1st of each month)
  zoo_mean  <- zoo::zoo(mean_vals,  as.Date(zoo::as.yearmon(t_forecast)))
  zoo_upper <- zoo::zoo(upper_vals, as.Date(zoo::as.yearmon(t_forecast)))

  # Now interpolate to daily grid
  fine_grid <- seq(from = stats::start(zoo_mean), to = stats::end(zoo_mean) + 31, by = "day")

  fine_mean  <- zoo::na.approx(zoo_mean,  xout = fine_grid)
  fine_upper <- zoo::na.approx(zoo_upper, xout = fine_grid)

  # Find crossings
  mean_idx  <- which(fine_mean  >= 1)[1]
  upper_idx <- which(fine_upper >= 1)[1]

  mean_cross_date  <- if (length(mean_idx))  fine_grid[mean_idx]  else NA
  upper_cross_date <- if (length(upper_idx)) fine_grid[upper_idx] else NA

  #print(list(mean_cross = mean_cross_date, upper_cross = upper_cross_date))

  # Build annotation label
  annot_lbl <- paste0("Mean crosses: ", ifelse(is.na(mean_cross_date), "NA", format(mean_cross_date, "%Y-%m-%d")),
                      "\n95% upper crosses: ", ifelse(is.na(upper_cross_date), "NA", format(upper_cross_date, "%Y-%m-%d")))

  list(
    df_obs = df_obs,
    df_fc = df_fc,
    df_line = df_line,
    df_ribbon = df_ribbon,
    fc_dates = fc_dates,
    annot_lbl = annot_lbl
  )
}

single_arima <- function() {
  horizon <- 6  # months
  covariates_interval <- "mean" # "upper" for a worst case scenario on the covariates

  # 1. Load and adjust with initial stock
  hist <- readHistorical()
  init_1ml  <- 196412 - hist$cumulative_1.0[nrow(hist)]
  init_1.9ml <- 212692 - hist$cumulative_1.9[nrow(hist)]

  hist_init <- hist %>%
    dplyr::mutate(
      "cumulative_1.0" = .data$cumulative_1.0 + init_1ml,
      "cumulative_1.9" = .data$cumulative_1.9 + init_1.9ml,
      "capacity_1.0_ml" = .data$cumulative_1.0 / 788256,
      "capacity_1.9_ml" = .data$cumulative_1.9 / 438840,
      "total_capacity"  = .data$capacity_1.0_ml + .data$capacity_1.9_ml,
      "prop_1ml" = .data$tubes_1.0_ml / (.data$tubes_1.0_ml + .data$tubes_1.9_ml),
      "prop_1ml" = ifelse(is.na(.data$prop_1ml), 0, .data$prop_1ml),
      "total_submitted_capacity" = .5*.data$total_submitted/788256 +  .5*.data$total_submitted/438840 # this is our prior on how many will return from each site
    ) %>%
    dplyr::select(.data$date, .data$total_capacity, .data$prop_1ml, .data$total_submitted_capacity)

  # Create hist_final by appending a new row with date "2025-09-02" and fixed cumulative values
  new_row <- tibble::tibble(
    date = as.Date("2025-09-02"),
    cumulative_1.0 = 196412,
    cumulative_1.9 = 212692,
    tubes_1.0_ml = NA_real_,
    tubes_1.9_ml = NA_real_,
    total_submitted = NA_real_
  )

  hist_extended <- dplyr::bind_rows(hist, new_row) %>%
    dplyr::arrange(date) %>%
    dplyr::mutate(
      capacity_1.0_ml = cumulative_1.0 / 788256,
      capacity_1.9_ml = cumulative_1.9 / 438840,
      total_capacity = capacity_1.0_ml + capacity_1.9_ml,
      prop_1ml = tubes_1.0_ml / (tubes_1.0_ml + tubes_1.9_ml),
      prop_1ml = ifelse(is.na(prop_1ml), 0, prop_1ml),
      total_submitted_capacity = 0.5 * total_submitted / 788256 + 0.5 * total_submitted / 438840
    ) %>%
    dplyr::select(date, total_capacity, prop_1ml, total_submitted_capacity)

  # Call the new function to get forecast data
  forecast_results <- predict_capacity(hist_init, horizon)
  forecast_final <- predict_capacity(hist_extended, horizon)

  # Compute pessimistic crossing date by reproducing mean-crossing logic for forecast_final$df_fc
  # Extract mean forecast values and dates
  fc_final_mean_vals <- forecast_final$df_fc %>% dplyr::filter(interval == "Mean") %>% dplyr::pull(total_capacity)
  fc_final_dates <- forecast_final$df_fc %>% dplyr::filter(interval == "Mean") %>% dplyr::pull(date)

  # Create zoo series
  zoo_final_mean <- zoo::zoo(fc_final_mean_vals, fc_final_dates)

  # Create fine daily grid from min to max date plus 31 days
  fine_grid_final <- seq(from = min(fc_final_dates), to = max(fc_final_dates) + 31, by = "day")

  # Interpolate to daily grid
  fine_mean_final <- zoo::na.approx(zoo_final_mean, xout = fine_grid_final)

  # Find first date where interpolated mean >= 1
  final_mean_idx <- which(fine_mean_final >= 1)[1]
  final_mean_cross_date <- if (length(final_mean_idx)) fine_grid_final[final_mean_idx] else NA

  # Build combined annotation label with optimistic and pessimistic messages
  combined_annot_lbl <- paste0(
    "Optimistic (init stock) Mean crosses: ", ifelse(is.na(forecast_results$annot_lbl), "NA", sub("Mean crosses: ([^\n]+).*", "\\1", forecast_results$annot_lbl)),
    "\nPessimistic (final jump) Mean crosses: ", ifelse(is.na(final_mean_cross_date), "NA", format(final_mean_cross_date, "%Y-%m-%d"))
  )

  # Plot results using ggplot with calendar dates
  ggplot2::ggplot() +
    geom_line(data = forecast_results$df_line %>% dplyr::filter(.data$type == "Observed"),
              aes(x = date, y = .data$total_capacity, color = "Observed Init")) +
    geom_point(data = forecast_results$df_line %>% dplyr::filter(.data$type == "Observed"),
               aes(x = date, y = .data$total_capacity, color = "Observed Init")) +
    geom_line(data = forecast_final$df_line %>% dplyr::filter(.data$type == "Observed"),
              aes(x = date, y = .data$total_capacity, color = "Observed Final")) +
    geom_point(data = forecast_final$df_line %>% dplyr::filter(.data$type == "Observed"),
               aes(x = date, y = .data$total_capacity, color = "Observed Final")) +
    geom_line(data = forecast_results$df_line %>% dplyr::filter(.data$type == "Forecast"),
              aes(x = date, y = .data$total_capacity, color = "Forecast Init")) +
    geom_ribbon(data = forecast_results$df_ribbon,
                aes(x = .data$date, ymin = .data$Lower, ymax = .data$Upper, fill = "Forecast Init"),
                alpha = 0.2) +
    geom_line(data = forecast_final$df_fc %>% dplyr::filter(interval == "Mean"),
              aes(x = date, y = total_capacity, color = "Forecast Final")) +
    geom_ribbon(data = forecast_final$df_ribbon,
                aes(x = date, ymin = Lower, ymax = Upper, fill = "Forecast Final"),
                alpha = 0.2) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
    annotate("text", x = max(forecast_results$fc_dates), y = 1.05, label = combined_annot_lbl,
             hjust = 1, vjust = 5, color = "darkred") +
    ggtitle("Monthly total capacity with ARIMA + covariates (aggregated monthly)") +
    ylab("Fraction full") + # complained about non ASCII characters
    xlab("") +
    scale_x_date(date_labels = "%Y-%m", date_breaks = "1 month") +
    scale_color_manual(name = "Line Type",
                       values = c("Observed Init" = "blue", "Observed Final" = "green", "Forecast Init" = "blue", "Forecast Final" = "green"),
                       guide = "none") +
    scale_fill_manual(
      name = "Model",
      values = c("Forecast Init" = "blue", "Forecast Final" = "green"),
      labels = c("Forecast Init" = "Init stock",
                 "Forecast Final" = "Final jump")
    ) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}
