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
readKBExcel <- function(x = "calculator_for_Suman.xlsx"){
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- readxl::read_xlsx(path = path, .name_repair = janitor::make_clean_names)
  x$x2d_tubes_ml <- janitor::make_clean_names(x$x2d_tubes_ml)
  x
}
#' Load in a file with current biospecimen collections
#'
#' @param x File name
#'
#' @returns A tibble with biospecimen collection information
#' @export
#'
#' @examples
#' readCollections()
readCollections <- function(x = "biospecimen_collection_for_biostore_calculations.xlsx"){
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
readHistorical <- function(x = "suchi_bam_submissions.csv"){ # may be useless now as information is in readCollections
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- utils::read.csv(file = path, header=TRUE)
  x <- tibble::as_tibble(x)
  x$date <- lubridate::ymd(x$date)
  x$cumulative_1.0 <- NULL
  x$cumulative_1.9 <- NULL
  x$cumulative_1.0 <- cumsum(x$tubes_1.0_ml)
  x$cumulative_1.9 <- cumsum(x$tubes_1.9_ml)
  x
}
#' Make Suchi's historical data "long" instead of "wide"
#'
#' @param x "Wide" version of historical data of ECHO submissions to BioStore
#'
#' @returns "Long" version of historical data of ECHO submissions to BioStore
#' @export
#'
#' @examples
#' longifyReadHistorical()
longifyReadHistorical <- function(x = readHistorical()){
  x <- tidyr::pivot_longer(x, cols = c("cumulative_1.0", "cumulative_1.9"), names_to = "tube_type", values_to = "total")
  x <- x %>% dplyr::mutate(tube_type = recode(.data$tube_type, "cumulative_1.0" = 'size 1.0mL', "cumulative_1.9" = 'size 1.9mL'))
}
totalBioStoreCapacity <- function(x, y){

  total_1.0ml <- 788256 # if at this number, can have 0 1.9 ml
  total_1.9ml <- 438840 # if at this number, can have 0 1.0 ml

  current_1.0ml <- 196412
  current_1.9ml <- 212692

  # equation is '(x + current_1.0ml)/total_1.0ml + (y + current_1.9ml)/total_1.9ml = 1'. Both a and b can move, but total capacity can't exceed 1

}
capacityFormula <- function(){
# ((total 1 ml tubes)/788256 + (total 1.9 ml tubes)/438840) = 1
  # once it reaches 1, capacity will be gone
}
# what kind of data is needed. total capacity, number of tubes per kit, expected collection
# instead of time, let's figure out the maximum number of kits that can be collected

# thinking of making this long instead of wide, but not really there yet
#readCollections() %>% dplyr::mutate_all(as.character) %>% tidyr::pivot_longer(cols = -c(collection_id, kit_type, biospecimen_type, participant))

# Function to find the date the freezer is full for a given model
find_full_date <- function(predictions, capacity, resultslm) {
  full_index <- which(predictions > capacity)[1]
  if (!is.na(full_index)) {
    full_date <- resultslm
    #full_date <- results_lm$date[full_index]
    return(as.character(full_date))
  } else {
    return("Freezer will not be full in the forecasted period.")
  }
}

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
