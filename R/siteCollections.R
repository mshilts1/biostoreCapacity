#' Parse file of site collections from Bio-Track
#'
#' @param x JSON file from Bio-Track
#'
#' @returns tibble with collections from sites that will go into biostore
#' @importFrom jsonlite fromJSON
#' @import stringr
#'
siteCollectionsPre <- function(x = "site_report_2025_09_12_07_43_04.json"){ # json file must be pulled from elvislims with your credentials
  x <- normalizePath(file.path("/Users/meghanshilts/Downloads", x), mustWork = TRUE)
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
