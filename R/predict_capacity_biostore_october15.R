#' Predict biostore capacity scenario (starting October 15, 2025)
#'
#' Builds and runs the full biostore capacity model starting on October 15 2025.
#' It combines historical samples already in the biostore, current pending samples,
#' and future planned (PTF) arrivals to compute processing throughput, freezer
#' occupancy, and cumulative capacity using the CVXR optimization engine.
#'
#' @details
#' This function reproduces the "October 15 scenario" described in the internal
#' biostore analysis. It:
#' \enumerate{
#'   \item Reads historical data using `readHistorical()` to obtain the
#'         cumulative samples already processed and stored.
#'   \item Reads current pending counts using `pendingNumbers()` and schedules
#'         them to start processing on **2025-10-15**.
#'   \item Builds the 2025–2030 PTF plan via `merge_ptf_tube_counts()` and
#'         `valid_kit_ids()`, scales the 2025 portion to reflect only the
#'         remaining period (October 15 – December 31 2025), and expands yearly
#'         counts to monthly end-of-month arrivals.
#'   \item Calls [predict_capacity_speed()] with a constant processing capacity of
#'         **50 000 tubes per month**.
#' }
#'
#' @return
#' A tidy tibble with cumulative tubes and freezer equivalents by tube size and
#' phase ("current" vs "predicted").
#'
#' @examples
#' \dontrun{
#' res <- predict_capacity_biostore_onctober15()
#' head(res)
#' }
#'
#' @seealso [predict_capacity_speed()], [plot_predict_capacity_biostore_onctober15()]
#' @export
predict_capacity_biostore_onctober15 <- function(){
# tubes per freezer (example uses the denominators from your code)
freezer_scale <- tibble::tribble(
  ~tube_size, ~tubes_per_freezer,
  "1ml",      788256,
  "1.9ml",    438840
)

# CURRENT: already processed/stored counts by month (non-cumulative)
hist <- readHistorical()
current <- hist %>%
  select(date, starts_with("tubes_1")) %>%
  pivot_longer(
    cols = starts_with("tubes_1"),
    names_to  = "tube_size",
    values_to = "tubes_count"
  ) %>%
  mutate(tube_size = recode(tube_size,
                            "tubes_1.0_ml" = "1ml",
                            "tubes_1.9_ml" = "1.9ml"))


# PENDING: backlog without dates (to be processed first)
pn <- pendingNumbers()
pending <- tibble::tibble(
  date        = as.Date("2025-10-15"),# start processing pending
  tube_size   = c("1ml", "1.9ml"),
  tubes_count = c(
    as.numeric(pn[["tubes_1.0ml_pending"]]),  # 77,674
    as.numeric(pn[["tubes_1.9ml_pending"]])   # 88,350
  )
)

# PLANNED: scheduled incoming counts by month (non-cumulative)
ptf<-merge_ptf_tube_counts() %>% # only valid for 2024, since 2025 uses a new kit
  filter(year >= 2025)
kits_in_biostore <- valid_kit_ids()

kits_in_biostore_clean <- kits_in_biostore %>%
  mutate(
    # normalize participant_type
    participant_clean = case_when(
      participant_type == "current_partner" ~ "partner",
      TRUE ~ participant_type
    ),
    # harmonize kit_type_clean so it matches specimen_clean endings
    kit_suffix = case_when(
      kit_type_clean == "cord_blood"         ~ "cord_blood_core",
      kit_type_clean == "tier_2_placenta"    ~ "placenta_core",
      kit_type_clean == "urine_cup_child"    ~ "urine_cup_core",
      kit_type_clean == "urine_cup_maternal" ~ "urine_cup_core",
      kit_type_clean == "urine_cup_partner"  ~ "urine_cup_core",
      kit_type_clean == "urine_diaper"       ~ "urine_diaper_core",
      kit_type_clean == "urine_hat"          ~ "urine_hat_core",
      kit_type_clean == "whole_blood_child"  ~ "whole_blood_core",
      kit_type_clean == "whole_blood_maternal" ~ "whole_blood_core",
      TRUE ~ kit_type_clean
    ),
    # concatenate to specimen-style naming
    specimen_match = str_c(participant_clean, "_", kit_suffix)
  )

# filter specimens in kits_in_biostore_clean
ptf_filtered <- ptf %>%
  filter(specimen_clean %in% kits_in_biostore_clean$specimen_match) %>%
  filter(kit_count>0) %>%
  filter(pricing_option == "p1") %>% # p1 price option
  mutate(tubes_count = kit_count * tubes_per_kit) %>% # total tubes needed
  mutate(
    capacity_ocuped = case_when(
      tube_size == "1ml"  ~ tubes_count / 788256,
      tube_size == "1.9ml" ~ tubes_count / 438840,
      TRUE ~ NA_real_
    )
  )

ptf_scaled <- ptf_filtered %>%
  mutate(across(c(kit_count, tubes_per_kit, tubes_count, capacity_ocuped),
                ~ if_else(year == "2025", .x * as.numeric(difftime(as.Date("2025-12-31"), as.Date("2025-10-15"), units = "days"))/365, .x)))#  proportion of 2025 left

# 1) Start month for 2025 based on CURRENT (not hist_with_total)
# start_2025 <- current %>%
#   summarise(last_date = max(date, na.rm = TRUE)) %>%
#   pull(last_date) %>%
#   floor_date("month") %m+% months(1)
start_2025 <- as.Date("2025-10-15")

# 2) Helper: expand year totals into end-of-month records
expand_year_to_months <- function(df, start_2025) {
  df %>%
    mutate(
      year = as.integer(year),
      start_date = if_else(year == 2025L, start_2025, as.Date(paste0(year, "-01-01"))),
      end_date   = as.Date(paste0(year, "-12-31"))
    ) %>%
    rowwise() %>%
    mutate(
      months_1st  = list(seq.Date(from = start_date, to = end_date, by = "month")),  # 1st of each month
      n_months    = length(months_1st),
      tubes_month = tubes_count / n_months
    ) %>%
    unnest(months_1st, names_repair = "minimal") %>%
    transmute(
      date        = ceiling_date(months_1st, "month") - days(1),  # EOM
      tube_size,
      tubes_count = tubes_month
    )
}

# 3) Correct: build `planned` from the *scaled* PTF
planned <- ptf_scaled %>%
  filter(tube_size %in% c("1ml", "1.9ml")) %>%
  group_by(year, tube_size) %>%
  summarise(tubes_count = sum(tubes_count, na.rm = TRUE), .groups = "drop") %>%
  expand_year_to_months(start_2025) %>%
  arrange(date, tube_size)




# run
res <- predict_capacity_speed(
  current        = current,# date, tube_size, tubes_number
  pending        = pending,# tube_size, tubes_number
  planned        = planned,# date, tube_size, tubes_number
  freezer_scale  = freezer_scale,# tubes/freezer
  processing_speed = 50000 # tubes/month
  # start_next_month = T
)


# # validation
# # total equality
# total_res <- res %>% filter(tube_size == "Total") %>% summarise(max_cum = max(tubes_cum)) %>% pull(max_cum)
# total_in  <- sum(current$tubes_count) + sum(planned$tubes_count) + sum(pending$tubes_count)
# c(total_res = total_res, total_in = total_in)
#
# # per-size equality
# res %>% filter(tube_size %in% c("1ml","1.9ml")) %>%
#   group_by(tube_size) %>% summarise(max_cum = max(tubes_cum))
#
# bind_rows(
#   current %>% group_by(tube_size) %>% summarise(n = sum(tubes_count), .groups="drop"),
#   planned %>% group_by(tube_size) %>% summarise(n = sum(tubes_count), .groups="drop"),
#   pending %>% group_by(tube_size) %>% summarise(n = sum(tubes_count), .groups="drop")
# ) %>% group_by(tube_size) %>% summarise(total = sum(n))

res
}



#' Plot predicted biostore capacity scenario (October 15, 2025)
#'
#' Generates a ggplot of cumulative freezer equivalents by tube size and phase
#' for the October 15 2025 capacity forecast produced by
#' [predict_capacity_biostore_onctober15()].
#'
#' @param res Optional output of [predict_capacity_biostore_onctober15()].
#'   If not supplied, the function assumes a variable `res` already exists in
#'   the environment.
#'
#' @return
#' A **ggplot** object showing historical (solid) and predicted (dashed) trends
#' of cumulative freezer usage through 2030.
#'
#' @examples
#' \dontrun{
#' res <- predict_capacity_biostore_onctober15()
#' p <- plot_predict_capacity_biostore_onctober15(res)
#' print(p)
#' }
#'
#' @seealso [predict_capacity_biostore_onctober15()]
#' @export
plot_predict_capacity_biostore_onctober15 <- function(){
res <- predict_capacity_biostore_onctober15()
p <- ggplot(res %>% filter(freezers>1e-4) %>% mutate(phase = if_else(phase == "optimized", "predicted", phase)), aes(x = date, y = freezers_cum, color = tube_size,linetype = phase)) +
  geom_line(size = 1) +
  scale_x_date(date_breaks = "2 month", date_labels = "%b-%Y") +
  theme_minimal(base_size = 14) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1, size = 7),
    legend.title = element_blank()
  ) +
  labs(
    title = "Cumulative capacity (freezer equivalents) over time by tube size",
    x = "Date",
    y = "Cumulative freezers"
  )
# ggsave("man/figures/predicted_capacity_biostore_october15.png",p)


p
}
