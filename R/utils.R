#' Load in BioStore capacity Excel file from Karen Beeri
#'
#' @param x Exact name of the file
#'
#' @returns A clean tibble of the Excel file for further manipulation
#' @export
#' @importFrom readxl read_xlsx
#' @importFrom janitor make_clean_names
#' @importFrom scales percent
#' @import ggplot2
#' @import tibble
#' @import tidyr
#' @import lubridate
#' @import forecast
#' @import dplyr
#'
#' @examples
#' readKBExcel()
readKBExcel <- function(x = "calculator_for_Suman.xlsx") {
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- readxl::read_xlsx(path = path, .name_repair = janitor::make_clean_names)
  x$x2d_tubes_ml <- janitor::make_clean_names(x$x2d_tubes_ml)
  x
}
#' Get max capacity for 1.0 and 1.9 ml tubes
#'
#' @param x input data from Karen Beeri about BioStore capacity and fullness
#'
#' @returns a list of MAXIMUM possible tubes of each size that can go in the BioStore
#' @export
#'
#' @examples
#' capacityNumbers()
capacityNumbers <- function(x = readKBExcel()){
  tubes_1.0ml <- x %>% filter(.data$x2d_tubes_ml == "fluid_x_1_0m_l_tube") %>% pull(.data$tube_capacity_one_bank)
  tubes_1.9ml <- x %>% filter(.data$x2d_tubes_ml == "x1_9m_l_capped_vial") %>% pull(.data$tube_capacity_one_bank)
  return(list("tubes_1.0ml_max_capacity" = tubes_1.0ml, "tubes_1.9ml_max_capacity" = tubes_1.9ml))
}
#' Pending numbers
#'
#' @param x input data from Suchi and Karen Beeri about tubes pending storage
#'
#' @returns a list of pending tubes of each size slated to go in the BioStore
#' @export
#'
#' @examples
#' pendingNumbers()
pendingNumbers <- function(x = readKBExcel()){
  tubes_1.0ml <- x %>% filter(.data$x2d_tubes_ml == "fluid_x_1_0m_l_tube") %>% pull(.data$pending_per_suchi)
  tubes_1.9ml <- x %>% filter(.data$x2d_tubes_ml == "x1_9m_l_capped_vial") %>% pull(.data$pending_per_suchi)
  return(list("tubes_1.0ml_pending" = tubes_1.0ml, "tubes_1.9ml_pending" = tubes_1.9ml))
}
#' Load in a file with current biospecimen collection protocol and timeline
#'
#' @param x File name
#'
#' @returns A tibble with biospecimen collection information
#' @export
#'
#' @examples
#' readCollections()
readCollections <- function(x = "biospecimen_collection_for_biostore_calculations.xlsx") {
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- readxl::read_xlsx(path = path, .name_repair = janitor::make_clean_names)
  x
}
#' Read in file from Suchi with historical data on ECHO submissions to the BioStore
#'
#' @param x File name
#'
#' @returns A tibble with historical data on ECHO submissions to the BioStore
#' @export
#'
#' @examples
#' readHistorical()
readHistorical <- function(x = "suchi_bam_submissions.csv") {
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- utils::read.csv(file = path, header = TRUE)
  x <- tibble::as_tibble(x)
  x$date <- lubridate::ymd(x$date)

  x$cumulative_1.0 <- NULL
  x$cumulative_1.9 <- NULL
  x$cumulative_total <- NULL
  x$proportion_1.0 <- NULL
  x$proportion_1.9 <- NULL
  x$proportion_total <- NULL

  x$cumulative_1.0 <- cumsum(x$tubes_1.0_ml)
  x$cumulative_1.9 <- cumsum(x$tubes_1.9_ml)
  x$cumulative_total <- x$cumulative_1.0 + x$cumulative_1.9
  x$proportion_1.0 <- x$cumulative_1.0/capacityNumbers()$tubes_1.0ml_max_capacity
  x$proportion_1.9 <- x$cumulative_1.9/capacityNumbers()$tubes_1.9ml_max_capacity
  x$proportion_total <- x$proportion_1.0 + x$proportion_1.9
  x
}
addPending <- function(x = readHistorical(), y = pendingNumbers()){
  x <- x %>% add_row(date = ymd("2025-09-11"), total_submitted = y$tubes_1.9ml_pending + y$tubes_1.0ml_pending,  tubes_1.9_ml = y$tubes_1.9ml_pending, tubes_1.0_ml = y$tubes_1.0ml_pending)
  x$cumulative_1.0 <- cumsum(x$tubes_1.0_ml)
  x$cumulative_1.9 <- cumsum(x$tubes_1.9_ml)
  x$cumulative_total <- x$cumulative_1.0 + x$cumulative_1.9
  x$proportion_1.0 <- x$cumulative_1.0/capacityNumbers()$tubes_1.0ml_max_capacity
  x$proportion_1.9 <- x$cumulative_1.9/capacityNumbers()$tubes_1.9ml_max_capacity
  x$proportion_total <- x$proportion_1.0 + x$proportion_1.9
  x
}
#' Make Suchi's historical data "long" instead of "wide"
#'
#' @param x "Wide" version of historical data of ECHO submissions to BioStore
#' @param total_or_prop "total" for raw numbers or "prop" for proportion of BioStore
#' @param add_pending Add in "pending" tubes that are at sites but not here yet?
#'
#' @returns "Long" version of historical data of ECHO submissions to BioStore
#' @export
#'
#' @examples
#' longifyReadHistorical() # cumulative totals as raw numbers
#' longifyReadHistorical(total_or_prop = "prop") # cumulative total as a proportion of freezer capacity
longifyReadHistorical <- function(x = readHistorical(), total_or_prop = "total", add_pending = FALSE) {
  if(add_pending == TRUE){
    x <- addPending()
  }

  if(total_or_prop == "total"){
  x <- tidyr::pivot_longer(x, cols = c("cumulative_1.0", "cumulative_1.9", "cumulative_total"), names_to = "tube_type", values_to = "total")
  x <- x %>% dplyr::mutate(tube_type = recode(.data$tube_type, "cumulative_1.0" = "size 1.0mL", "cumulative_1.9" = "size 1.9mL", "cumulative_total" = "all sizes"))
  return(x)
  }
  if(total_or_prop == "prop"){
    x <- tidyr::pivot_longer(x, cols = c("proportion_1.0", "proportion_1.9", "proportion_total"), names_to = "tube_type", values_to = "total")
    x <- x %>% dplyr::mutate(tube_type = recode(.data$tube_type, "proportion_1.0" = "size 1.0mL", "proportion_1.9" = "size 1.9mL", "proportion_total" = "all sizes"))
    return(x)
  }
}
#' Create a zoo ts object from historical data
#' https://cran.r-project.org/web/packages/zoo/index.html
#'
#' @param x Historical data
#' @param tube tube size, and whether cumulative or not. Options are "tubes_1.0_ml", "tubes_1.9_ml", "cumulative_1.0" or "cumulative_1.9"
#'
#' @returns zoo ts object
#' @export
#' @import zoo
#'
#' @examples
#' zoo_ts()
zoo_ts <- function(x = readHistorical(), tube = "cumulative_1.0") {
  zoo(x[[tube]], x$date)
  # may need to explore as.ts option to coerce to ts object
}
#' Calculate total BioStore capacity
#'
#' @param x number of 1.0 ml tubes that could be added to storage
#' @param y number of 1.9 ml tubes that could be added to storage
#'
#' @returns nothing yet
#' @export
#'
#' @examples
#' totalBioStoreCapacity(x = 100, y = 100) # function doesn't do anything yet
totalBioStoreCapacity <- function(x = NULL, y = NULL) {
  total_1.0ml <- 788256 # if at this number, can have 0 1.9 ml # pulled from readKBExcel()
  total_1.9ml <- 438840 # if at this number, can have 0 1.0 ml # pulled from readKBExcel()

  current_1.0ml <- 196412 # pulled from readKBExcel()
  current_1.9ml <- 212692 # pulled from readKBExcel()

  # equation is '(x + current_1.0ml)/total_1.0ml + (y + current_1.9ml)/total_1.9ml = 1'. Both a and b can move, but total capacity can't exceed 1
}
capacityFormula <- function() {
  # ((total 1 ml tubes)/788256 + (total 1.9 ml tubes)/438840) = 1
  # once it reaches 1, capacity will be gone
}
# what kind of data is needed. total capacity, number of tubes per kit, expected collection
# instead of time, let's figure out the maximum number of kits that can be collected

# thinking of making this long instead of wide, but not really there yet
# readCollections() %>% dplyr::mutate_all(as.character) %>% tidyr::pivot_longer(cols = -c(collection_id, kit_type, biospecimen_type, participant))
#' Function to find the date the freezer is full. Under development!
#'
#' @param predictions predictions
#' @param capacity capacity
#' @param resultslm model
#'
#' @returns date when freezer will be full. function in development and doesn't do much yet
find_full_date <- function(predictions, capacity, resultslm) {
  full_index <- which(predictions > capacity)[1]
  if (!is.na(full_index)) {
    full_date <- resultslm
    # full_date <- results_lm$date[full_index]
    return(as.character(full_date))
  } else {
    return("Freezer will not be full in the forecasted period.")
  }
}
#' Make a very simple plot to visually represent how full and empty freezer is at a given time
#'
#' @param used Percent of freezer currently occupied
#'
#' @returns A ggplot2 plot
freezer_fullness_graph <- function(used = NULL) {
  free <- 1 - used

  # Create a data frame with freezer space information
  freezer_data <- data.frame(
    space = c("Used", "Free"),
    percentage = c(used, free)
  )

  # Add a text label for positioning
  freezer_data$label_pos <- NULL
  freezer_data$label_pos <- cumsum(.data$percentage) - .data$percentage / 2

  # Create the stacked bar chart
  ggplot2::ggplot(freezer_data, ggplot2::aes(x = "Freezer", y = .data$percentage, fill = .data$space)) +
    ggplot2::geom_bar(stat = "identity", width = 0.5) +
    ggplot2::scale_fill_manual(
      values = c("Used" = "#B22222", "Free" = "#87CEEB"),
      labels = c("Used Space", "Free Space")
    ) +
    ggplot2::geom_text(
      ggplot2::aes(y = .data$label_pos, label = scales::percent(.data$percentage)),
      color = "white",
      size = 5
    ) +
    labs(
      title = "BioStore II Capacity",
      fill = NULL
    ) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.title = element_text(hjust = 0.5, size = 16),
      legend.position = "bottom"
    )
}
forecastBioStoreCapacity <- function() {
  forecast::forecast()
}
#' Load in de-identified information about site biospecimen collections
#'
#' @param x file name of deidentified biospecimen collections file
#'
#' @returns a tibble with this information
#' @export
#'
#' @examples
#' site_collections()
site_collections <- function(x = "deidentified_specimen_collection.csv"){
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- utils::read.csv(file = path, header = TRUE)
  x <- tibble::as_tibble(x)
  #x$date <- lubridate::ymd(x$date)
  x
}
