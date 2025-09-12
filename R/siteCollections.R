#' Parse file of site collections from Bio-Track
#'
#' @param x JSON file from Bio-Track
#'
#' @returns tibble with collections from sites that will go into biostore
#' @importFrom jsonlite fromJSON
#' @import stringr
#' @importFrom ids random_id
#'
siteCollectionsPre <- function(x = "site_report_2025_09_12_07_43_04.json"){ # json file must be pulled from elvislims with your credentials
  x <- normalizePath(file.path("/Users/meghanshilts/Downloads", x), mustWork = TRUE)
  collections <- jsonlite::fromJSON(txt = x, flatten= TRUE, simplifyDataFrame = TRUE)
  collections <- collections %>% tidyr::unnest("containers") %>% tidyr::unnest("specimen") %>% janitor::clean_names() %>% dplyr::mutate("storage_date" = as.Date(ymd_hms(.data$storage_date, quiet = TRUE)))

  biostoreCompatible <- collections %>% dplyr::filter(stringr::str_detect(.data$sample_type, stringr::regex("cryovial", ignore_case = TRUE)) | stringr::str_detect(.data$sample_type, stringr::regex("barcoded", ignore_case = TRUE))) %>% dplyr::filter(.data$sample_type != "7.0 mL Urine aliquots in 7.6 mL cryovial (orange capped)") %>% dplyr::mutate("tube_size" = case_when(
    stringr::str_detect(.data$sample_type, "1.0 mL cryovials") ~ "size 1.0mL",
    stringr::str_detect(.data$sample_type, "1.9 mL cryovials") ~ "size 1.9mL",
    stringr::str_detect(.data$sample_type, "1.9 mL barcoded") ~ "size 1.9mL",
    stringr::str_detect(.data$sample_type, "1.9 mL empty Barcoded") ~ "size 1.9mL",
    TRUE ~ "Other" # Default case for no match
  ))
}
specializedBySite <- function(x = "ECHOCycle2ELVISLabor-SpecializedCollectio_DATA_2025-09-12_1255.csv"){ # can only be pulled from REDCap with correct permissions and credentials
  spec_by_site <- tibble::as_tibble(utils::read.csv(file = normalizePath(file.path("/Users/meghanshilts/Downloads", x), mustWork = TRUE), header = TRUE))

  spec_by_site <- spec_by_site %>% dplyr::rename("cohort_study_site_id" = "record_id")
}
merged <- function(x = siteCollectionsPre(), y = specializedBySite()){
  mergeit <- merge(x, y, by = "cohort_study_site_id")
  tibble::as_tibble(mergeit)
}
deidentified <- function(x = merged()){
  random_ids <- ids::random_id(length(unique(x$cohort_study_site_id)))
  lookup_table <- data.frame(
    cohort_study_site_id = unique(x$cohort_study_site_id),
    site_id_randomized = random_ids
  )

  deident <- merge(lookup_table, x, by = "cohort_study_site_id")
  deident <- deident %>% dplyr::mutate("shipped" = ifelse(is.na(.data$shipment_id), 0, 1)) %>% dplyr::select(-c("cohort_study_site_id", "container_id", "storage_location", "specimen_id", "kit_number", "shipment_id")) %>% dplyr::relocate("site_id_randomized")
  tibble::as_tibble(deident)
}
write_deidentified <- function(x = deidentified()){
  file_path <- "inst/extdata/deidentified_specimen_collection.csv"
  utils::write.csv(x, file_path, row.names = FALSE)
}
