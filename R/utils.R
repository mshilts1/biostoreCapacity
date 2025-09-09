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
#'
#' @examples
#' readKBExcel()
readKBExcel <- function(x = "calculator_for_Suman.xlsx"){
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- readxl::read_xlsx(path = path, .name_repair = janitor::make_clean_names)
  x$x2d_tubes_ml <- janitor::make_clean_names(x$x2d_tubes_ml)
  x
}
readCollections <- function(x = "biospecimen_collection_for_biostore_calculations.xlsx"){
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- readxl::read_xlsx(path = path, .name_repair = janitor::make_clean_names)
  x
}
tubesPerKit <- function(x = "tubes_per_kit.csv"){ # may be useless now as information is in readCollections
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  x <- utils::read.csv(file = path, header=TRUE)
}
capacity <- function(x, what = "both"){
if(what == "both"){
x
}
}
capacityFormula <- function(){
# ((total 1 ml tubes)/788256 + (total 1.9 ml tubes)/438840) = 1
  # once it reaches 1, capacity will be gone
}
# what kind of data is needed. total capacity, number of tubes per kit, expected collection
# instead of time, let's figure out the maximum number of kits that can be collected

# thinking of making this long instead of wide, but not really there yet
#readCollections() %>% dplyr::mutate_all(as.character) %>% tidyr::pivot_longer(cols = -c(collection_id, kit_type, biospecimen_type, participant))

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

