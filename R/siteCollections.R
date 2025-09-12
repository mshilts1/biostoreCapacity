#' Parse file of site collections from Bio-Track
#'
#' @param x JSON file from Bio-Track
#'
#' @returns
#' @export
#' @importFrom jsonlite fromJSON
#' @import stringr
#'
#' @examples
#' siteCollections()
siteCollections <- function(x = "site_report_2025_09_11_07_43_04.json"){
  x <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  collections <- jsonlite::fromJSON(txt = x, flatten= TRUE, simplifyDataFrame = TRUE)
  collections <- collections %>% tidyr::unnest("containers") %>% tidyr::unnest("specimen") %>% janitor::clean_names() %>% dplyr::mutate("storage_date" = as.Date(ymd_hms(.data$storage_date)))

  biostoreCompatible <- collections %>% dplyr::filter(stringr::str_detect(.data$sample_type, stringr::regex("cryovial", ignore_case = TRUE)) | stringr::str_detect(.data$sample_type, stringr::regex("barcoded", ignore_case = TRUE))) %>% dplyr::filter(.data$sample_type != "7.0 mL Urine aliquots in 7.6 mL cryovial (orange capped)") %>% dplyr::mutate("tube_size" = case_when(
    stringr::str_detect(.data$sample_type, "1.0 mL cryovials") ~ "size 1.0mL",
    stringr::str_detect(.data$sample_type, "1.9 mL cryovials") ~ "size 1.9mL",
    stringr::str_detect(.data$sample_type, "1.9 mL barcoded") ~ "size 1.9mL",
    stringr::str_detect(.data$sample_type, "1.9 mL empty Barcoded") ~ "size 1.9mL",
    TRUE ~ "Other" # Default case for no match
  ))
}
