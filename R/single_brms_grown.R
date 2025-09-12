#' Forecast capacity using a brms growth curve (no regular spacing; posterior propagation)
#'
#' Fits two simple `brms` models to forecast the covariates on the *original*
#' (irregular) date grid, then fits a logistic growth curve for total capacity
#' where the inflection time (xmid) is shifted by the covariates. It produces
#' daily forecasts for a given horizon and reports the first dates when the
#' posterior mean and the 95% upper credible bound reach capacity = 1.
#'
#' Key points:
#' - **No regularization of historical dates** (we keep your original spacing).
#' - **Same covariates as ARIMA**: `prop_1ml`, `total_submitted_capacity`.
#' - **Posterior propagation**: we forward posterior draws from the covariate
#'   models into the growth model instead of using point forecasts.
#'
#' @param horizon Integer; number of months to forecast ahead.
#' @param chains,iter,seed MCMC settings passed to brms::brm().
#' @return A list with fitted models, a forecast data.frame, crossing dates, and a
#'   ggplot object.
#' @export
#' @examples
#' # res <- single_brms_growth()
#' # res$mean_cross_date; res$upper_cross_date; res$plot
single_brms_growth <- function(
  horizon = 12,
  chains = 2,
  iter = 2000,
  seed = 123
) {

  # ---- 1) Load history and compute the same covariates used in single_arima() ----
  hist <- readHistorical()
  init_1ml   <- 196412 - hist$cumulative_1.0[nrow(hist)]
  init_1.9ml <- 212692 - hist$cumulative_1.9[nrow(hist)]

  hist_init <- hist %>%
    dplyr::mutate(
      # align cumulative counts
      cumulative_1.0 = .data$cumulative_1.0 + init_1ml,
      cumulative_1.9 = .data$cumulative_1.9 + init_1.9ml,
      capacity_1.0_ml = .data$cumulative_1.0 / 788256,
      capacity_1.9_ml = .data$cumulative_1.9 / 438840,
      total_capacity  = .data$capacity_1.0_ml + .data$capacity_1.9_ml,
      prop_1ml = .data$tubes_1.0_ml / (.data$tubes_1.0_ml + .data$tubes_1.9_ml),
      prop_1ml = dplyr::if_else(is.na(.data$prop_1ml), 0, .data$prop_1ml),
      # prior on how many will return from each site
      total_submitted_capacity = 0.5*.data$total_submitted/788256 + 0.5*.data$total_submitted/438840
    ) %>%
    # NOTE: use bare names in select() to avoid tidyselect .data warning
    dplyr::select(date, total_capacity, prop_1ml, total_submitted_capacity) %>%
    dplyr::arrange(.data$date)

  # ---- 2) Time index: keep irregular dates, but center & scale time for stability ----
  t0 <- min(hist_init$date, na.rm = TRUE)
  hist_init <- hist_init %>%
    dplyr::mutate(
      t_raw = as.numeric(.data$date - t0)
    )
  center_t <- mean(hist_init$t_raw, na.rm = TRUE)
  scale_t  <- stats::sd(hist_init$t_raw, na.rm = TRUE)
  if (!is.finite(scale_t) || scale_t <= 0) scale_t <- 1
  hist_init <- hist_init %>%
    dplyr::mutate(t = (.data$t_raw - center_t) / scale_t)

  # ---- 3) Fit covariate models on the irregular grid (smooths in time) ----
  set.seed(seed)

  fit_prop <- brms::brm(
    formula = prop_1ml ~ s(t, k = 10),
    data    = hist_init,
    family  = gaussian(),
    chains  = chains, iter = iter, seed = seed,
    refresh = 0
  )

  fit_sub <- brms::brm(
    formula = total_submitted_capacity ~ s(t, k = 10),
    data    = hist_init,
    family  = gaussian(),
    chains  = chains, iter = iter, seed = seed,
    refresh = 0
  )

  # ---- 4) Build future *daily* grid over the horizon (keep history irregular) ----
  last_date <- max(hist_init$date, na.rm = TRUE)
  future_dates <- seq.Date(
    from = last_date + 1,
    to   = lubridate::`%m+%`(last_date, lubridate::period(months = horizon)),
    by   = "day"
  )

  future <- dplyr::tibble(date = future_dates) %>%
    dplyr::mutate(
      t_raw = as.numeric(.data$date - t0),
      t = (.data$t_raw - center_t) / scale_t
    )

  # ---- 5) Posterior draws for the covariates on the future grid ----
  prop_draws <- brms::posterior_epred(fit_prop, newdata = future, re_formula = NA) # S1 x T
  sub_draws  <- brms::posterior_epred(fit_sub,  newdata = future, re_formula = NA) # S2 x T

  # ---- 6) Nonlinear growth curve for total capacity (logistic) ----
  # total_capacity = Asym / (1 + exp((xmid - t)/scal))
  # xmid is shifted by the covariates.
  growth_bf <- brms::bf(
    total_capacity ~ Asym/(1 + exp((xmid - t)/scal)),
    Asym ~ 1,
    xmid ~ 1 + prop_1ml + total_submitted_capacity,
    scal ~ 1,
    nl   = TRUE
  )

  # Priors with scaled time (t ~ roughly N(0,1))
  growth_priors <- c(
    brms::set_prior("normal(1, 0.05)", nlpar = "Asym", lb = 0.5),
    brms::set_prior("normal(0, 1)",    nlpar = "xmid", coef = "Intercept"),
    brms::set_prior("normal(0, 1)",    nlpar = "xmid", coef = "prop_1ml"),
    brms::set_prior("normal(0, 1)",    nlpar = "xmid", coef = "total_submitted_capacity"),
    brms::set_prior("normal(1, 0.5)",  nlpar = "scal", lb = 0.1)
  )

  fit_total <- brms::brm(
    formula = growth_bf,
    data    = hist_init,
    family  = gaussian(),
    prior   = growth_priors,
    control = list(adapt_delta = 0.995, max_treedepth = 12),
    chains  = chains, iter = iter, seed = seed,
    refresh = 0
  )

  # ---- 7) Propagate covariate posterior into the growth model ----
  # Pair draw s from each covariate model with draw s from the growth model.
  # (Simple approximation to the joint predictive distribution.)
  n_draws_total <- nrow(
    brms::posterior_epred(fit_total, newdata = hist_init[1, , drop = FALSE], re_formula = NA)
  )
  S <- min(nrow(prop_draws), nrow(sub_draws), n_draws_total)

  total_draws <- matrix(NA_real_, nrow = S, ncol = nrow(future))
  for (s in seq_len(S)) {
    newdata_s <- future
    # clamp proportion to [0,1] for robustness
    newdata_s$prop_1ml <- pmin(pmax(prop_draws[s, ], 0), 1)
    newdata_s$total_submitted_capacity <- sub_draws[s, ]

    pred_s <- brms::posterior_epred(
      fit_total,
      newdata   = newdata_s,
      draw_ids  = s,
      re_formula = NA
    )
    total_draws[s, ] <- as.numeric(pred_s)
  }

  pred_mean  <- colMeans(total_draws)
  pred_lower <- apply(total_draws, 2, stats::quantile, 0.025)
  pred_upper <- apply(total_draws, 2, stats::quantile, 0.975)

  forecast_df <- dplyr::tibble(
    date = future$date,
    mean = pred_mean, lower = pred_lower, upper = pred_upper
  )

  # ---- 8) First dates where the mean and 95% upper intervals cross capacity = 1 ----
  idx_mean  <- which(forecast_df$mean  >= 1)[1]
  idx_upper <- which(forecast_df$upper >= 1)[1]
  mean_cross_date  <- if (!is.na(idx_mean))  forecast_df$date[idx_mean]  else as.Date(NA)
  upper_cross_date <- if (!is.na(idx_upper)) forecast_df$date[idx_upper] else as.Date(NA)

  # ---- 9) Plot (observed + forecast with ribbon) and annotate crossings ----
  p <- ggplot2::ggplot() +
    ggplot2::geom_line(
      data = hist_init,
      ggplot2::aes(x = .data$date, y = .data$total_capacity),
      linewidth = 0.5
    ) +
    ggplot2::geom_ribbon(
      data = forecast_df,
      ggplot2::aes(x = .data$date, ymin = .data$lower, ymax = .data$upper),
      alpha = 0.2
    ) +
    ggplot2::geom_line(
      data = forecast_df,
      ggplot2::aes(x = .data$date, y = .data$mean)
    ) +
    ggplot2::geom_hline(yintercept = 1, linetype = "dashed") +
    ggplot2::annotate(
      "text",
      x = max(forecast_df$date, na.rm = TRUE), y = 1.05,
      label = paste0(
        "Mean crosses: ", ifelse(is.na(mean_cross_date), "NA", format(mean_cross_date, "%Y-%m-%d")),
        "\n95% upper crosses: ", ifelse(is.na(upper_cross_date), "NA", format(upper_cross_date, "%Y-%m-%d"))
      ),
      hjust = 1, vjust = 5
    ) +
    ggplot2::ggtitle("Capacity forecast with brms logistic growth (irregular time)") +
    ggplot2::ylab("Fraction full") +
    ggplot2::xlab("") +
    ggplot2::scale_x_date(date_labels = "%Y-%m", date_breaks = "1 month") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))

  # ---- 10) Return compact outputs similar to the ARIMA function ----
  list(
    fit_total = fit_total,
    fit_prop  = fit_prop,
    fit_sub   = fit_sub,
    forecast  = forecast_df,
    mean_cross_date  = mean_cross_date,
    upper_cross_date = upper_cross_date,
    plot = p
  )
}
