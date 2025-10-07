library(dplyr)
library(tidyr)
library(lubridate)
library(CVXR)


#' Predict Freezer Capacity and Sample Backlog
#'
#' Solves an optimization model to estimate processing and freezer needs
#' based on current, pending, and planned tube arrivals.
#'
#' @param current Data frame with `date`, `tube_size`, `tubes_count` (current stock).
#' @param pending Data frame with `date`, `tube_size`, `tubes_count` (pending backlog).
#' @param planned Data frame with `date`, `tube_size`, `tubes_count` (planned inflows).
#' @param freezer_scale Data frame with `tube_size` and `tubes_per_freezer`.
#' @param processing_speed Numeric, tubes per month the lab can process.
#' @param tol Numeric tolerance for solver stability.
#'
#' @return A tidy tibble with dates, tube sizes, cumulative tube and freezer counts, and phase labels.
#' @examples
#' \dontrun{
#' res <- predict_capacity(current, pending, planned, freezer_scale)
#' }
#' @export
predict_capacity_speed <- function(current,
                             pending,
                             planned,
                             freezer_scale,
                             processing_speed = 50000,
                             tol = 1e-6) {
  # ---------------- helpers ----------------
  eom      <- function(d) ceiling_date(as.Date(d), "month") - days(1)  # end-of-month
  month_id <- function(d) floor_date(as.Date(d), "month")
  dimon    <- function(d) as.integer(days_in_month(as.Date(d)))

  # ------------- clean inputs --------------
  current <- current %>%
    transmute(date = as.Date(date),
              month = month_id(date),
              tube_size = as.character(tube_size),
              tubes_count = as.numeric(tubes_count)) %>%
    filter(!is.na(month), !is.na(tube_size), !is.na(tubes_count))

  planned <- planned %>%
    transmute(date = as.Date(date),
              tube_size = as.character(tube_size),
              tubes_count = as.numeric(tubes_count)) %>%
    filter(!is.na(date), !is.na(tube_size), !is.na(tubes_count))

  pending <- pending %>%
    transmute(date = as.Date(date),
              tube_size = as.character(tube_size),
              tubes_count = as.numeric(tubes_count)) %>%
    filter(!is.na(date), !is.na(tube_size), !is.na(tubes_count))

  freezer_scale <- freezer_scale %>%
    transmute(tube_size = as.character(tube_size),
              tubes_per_freezer = as.numeric(tubes_per_freezer)) %>%
    filter(!is.na(tube_size), !is.na(tubes_per_freezer))

  # only sizes we can convert to freezers
  current <- current %>% semi_join(freezer_scale, by = "tube_size")
  planned <- planned %>% semi_join(freezer_scale, by = "tube_size")
  pending <- pending %>% semi_join(freezer_scale, by = "tube_size")

  sizes <- freezer_scale$tube_size
  if (length(sizes) != 2L) {
    stop("This CVXR version supports exactly 2 tube sizes; found: ",
         paste(sizes, collapse = ", "),
         ". Provide two sizes in freezer_scale (e.g., '1ml' and '1.9ml').")
  }
  size_A <- sizes[1]
  size_B <- sizes[2]

  # -------- historical "current" (as-is) ----
  current_m <- current %>%
    group_by(month, tube_size) %>%
    summarise(tubes_processed = sum(tubes_count, na.rm = TRUE), .groups = "drop")

  # start date = day after last historical EOM (or earliest event's month start if no history)
  if (nrow(current_m) > 0) {
    last_cur_month <- max(current_m$month)
    start_date <- eom(last_cur_month) + days(1)
  } else {
    earliest_event <- suppressWarnings(min(c(planned$date, pending$date), na.rm = TRUE))
    start_date <- if (is.finite(earliest_event)) floor_date(earliest_event, "month")
    else floor_date(Sys.Date(), "month")
  }

  # ------------- event-aware grid ----------
  # event dates on/after start
  event_dates <- c(planned$date, pending$date)
  event_dates <- event_dates[!is.na(event_dates) & event_dates >= start_date]

  # total to process = B0 (pending before start) + future arrivals
  B0_A <- sum(pending$tubes_count[pending$tube_size == size_A & pending$date < start_date], na.rm = TRUE)
  B0_B <- sum(pending$tubes_count[pending$tube_size == size_B & pending$date < start_date], na.rm = TRUE)

  total_future_arrivals <- sum(planned$tubes_count[planned$date >= start_date], na.rm = TRUE) +
    sum(pending$tubes_count[pending$date >= start_date], na.rm = TRUE)
  total_to_process <- B0_A + B0_B + total_future_arrivals

  base_last_date <- if (length(event_dates) > 0) max(event_dates) else start_date
  tail_months <- if (is.na(processing_speed) || processing_speed < tol) 0L
  else max(0L, ceiling(total_to_process / processing_speed) + 2L)

  # month-end boundaries from start month to base_last + tail
  last_eom_with_tail <- eom(floor_date(base_last_date, "month") %m+% months(tail_months))
  eom_seq <- seq(eom(floor_date(start_date, "month")), last_eom_with_tail, by = "month")

  # cut points are EOMs and event dates, plus ONE final extra EOM so events map to "next segment"
  cut_points <- sort(unique(c(eom_seq[eom_seq >= start_date], event_dates)))
  final_cut  <- eom(floor_date(last_eom_with_tail %m+% months(1), "month"))
  cut_points <- sort(unique(c(cut_points, final_cut)))

  # build segments: [seg_start .. seg_end] (inclusive)
  T_h <- length(cut_points)
  seg_start <- start_date
  cap_vec <- numeric(T_h)
  seg_start_vec <- as.Date(rep(NA, T_h))
  seg_end_vec   <- as.Date(rep(NA, T_h))

  for (t in seq_len(T_h)) {
    seg_end <- cut_points[t]
    seg_days <- as.integer(seg_end - seg_start + 1L)    # inclusive
    cap_vec[t] <- processing_speed * seg_days / dimon(seg_start)  # pro-rate by month of seg_start
    seg_start_vec[t] <- seg_start
    seg_end_vec[t]   <- seg_end
    seg_start <- seg_end + days(1)
  }

  segments <- tibble(seg_id = seq_len(T_h),
                     seg_start = seg_start_vec,
                     seg_end   = seg_end_vec,
                     cap       = cap_vec)

  # -------- arrivals per segment (robust) ----
  # All future events (pending + planned), mapped to the NEXT segment
  events_future <- bind_rows(
    planned %>% filter(date >= start_date) %>% mutate(kind = "planned"),
    pending %>% filter(date >= start_date) %>% mutate(kind = "pending")
  )

  if (nrow(events_future) > 0) {
    events_future <- events_future %>%
      mutate(seg_here = match(date, cut_points),
             seg_id   = seg_here + 1L) %>%        # map to NEXT segment
      filter(!is.na(seg_id) & seg_id <= T_h)
  }

  arrivals_wide <- if (nrow(events_future) > 0) {
    events_future %>%
      inner_join(segments %>% select(seg_id), by = "seg_id") %>%   # keep only valid segments
      group_by(seg_id, tube_size) %>%
      summarise(inflow = sum(tubes_count, na.rm = TRUE), .groups = "drop") %>%
      tidyr::pivot_wider(id_cols = seg_id,
                         names_from = tube_size,
                         values_from = inflow,
                         values_fill = 0)
  } else {
    tibble(seg_id = integer(0))
  }

  aA <- numeric(T_h)
  aB <- numeric(T_h)
  if (nrow(arrivals_wide) > 0) {
    if (size_A %in% names(arrivals_wide)) aA[arrivals_wide$seg_id] <- arrivals_wide[[size_A]]
    if (size_B %in% names(arrivals_wide)) aB[arrivals_wide$seg_id] <- arrivals_wide[[size_B]]
  }

  # -------------- CVXR CVXR::Variables ----------
  P_A <- CVXR::Variable(T_h, nonneg = TRUE)
  P_B <- CVXR::Variable(T_h, nonneg = TRUE)
  B_A <- CVXR::Variable(T_h, nonneg = TRUE)
  B_B <- CVXR::Variable(T_h, nonneg = TRUE)

  # --------------- constraints ------------
  cons <- list(
    B_A[1] == B0_A + aA[1] - P_A[1],
    B_B[1] == B0_B + aB[1] - P_B[1],
    P_A + P_B <= cap_vec
  )
  if (T_h >= 2) {
    cons <- c(cons,
              B_A[2:T_h] == B_A[1:(T_h - 1)] + aA[2:T_h] - P_A[2:T_h],
              B_B[2:T_h] == B_B[1:(T_h - 1)] + aB[2:T_h] - P_B[2:T_h])
  }

  # --------------- objective --------------
  w_A <- 1; w_B <- 1
  obj <- CVXR::sum_entries(w_A * B_A + w_B * B_B)

  prob <- CVXR::Problem(CVXR::Minimize(obj), cons)
  result <- CVXR::solve(prob, solver = "ECOS")
  if (!(result$status %in% c("optimal", "optimal_inaccurate"))) {
    stop("Solver failed with status: ", result$status)
  }

  # --------------- solution ---------------
  pA <- as.numeric(result$getValue(P_A))
  pB <- as.numeric(result$getValue(P_B))
  bA <- as.numeric(result$getValue(B_A))
  bB <- as.numeric(result$getValue(B_B))

  # optimized rows at segment ends
  opt_df <- bind_rows(
    tibble(date = segments$seg_end, tube_size = size_A, tubes_processed = pA, backlog = bA),
    tibble(date = segments$seg_end, tube_size = size_B, tubes_processed = pB, backlog = bB)
  ) %>% mutate(phase = "optimized")

  # historical rows at EOM
  past_df <- current_m %>%
    mutate(date = eom(month), phase = "current") %>%
    select(date, tube_size, tubes_processed, phase) %>%
    mutate(backlog = NA_real_)

  # combine & convert to freezers + cumulative
  monthly_df <- bind_rows(past_df, opt_df) %>%
    arrange(tube_size, date) %>%
    left_join(freezer_scale, by = "tube_size") %>%
    mutate(freezers = tubes_processed / tubes_per_freezer) %>%
    group_by(tube_size) %>%
    arrange(date, .by_group = TRUE) %>%
    mutate(
      tubes_cum    = cumsum(replace_na(tubes_processed, 0)),
      freezers_cum = cumsum(replace_na(freezers, 0))
    ) %>%
    ungroup()

  # total with phase
  phase_by_date <- monthly_df %>%
    group_by(date) %>%
    summarise(
      phase = case_when(
        any(phase == "optimized", na.rm = TRUE) ~ "optimized",
        any(phase == "current",   na.rm = TRUE) ~ "current",
        TRUE ~ NA_character_
      ),
      .groups = "drop"
    )

  total_monthly <- monthly_df %>%
    group_by(date) %>%
    summarise(
      tubes_processed = sum(tubes_processed, na.rm = TRUE),
      freezers        = sum(freezers,        na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(date) %>%
    mutate(
      tube_size    = "Total",
      tubes_cum    = cumsum(tubes_processed),
      freezers_cum = cumsum(freezers)
    ) %>%
    left_join(phase_by_date, by = "date")

  bind_rows(
    monthly_df %>% select(date, tube_size, tubes_processed, freezers, tubes_cum, freezers_cum, phase),
    total_monthly %>% select(date, tube_size, tubes_processed, freezers, tubes_cum, freezers_cum, phase)
  ) %>%
    arrange(tube_size, date)
}



