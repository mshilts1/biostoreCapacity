#' Projection of future collections
#'
#' @param pt Participant projections
#' @param bc Biospecimen collection protocol
#'
#' @returns a tibble
#' @export
#'
#' @examples
#' future_projections()
future_projections <- function(pt = participants_proj(), bc = readCollections()){
  visit_participants_no_azenta_tubes <- c("6_11_months_child", "24_35_months_child", "18_20_years_child") # at this time (September 17 2025), to my knowledge, biospecimens collected from this participants during this age group do not include any Azenta tubes, and so can be removed from this specific modeling.
  pt <- pt %>% dplyr::filter(!.data$visit_participant %in% visit_participants_no_azenta_tubes) %>% dplyr::select(-c(.data$visit, .data$maternal_specimen, .data$child_specimen, .data$partner_specimen))
  x <- dplyr::full_join(bc, pt, by = "visit_participant", relationship = "many-to-many")

  if(any(is.na(x$collection_id))){
    warning("There should not be any NAs in the collection_id column. Check that input data is correct.")
  }
  if(any(is.na(x$pt_group))){
    warning("There should not be any NAs in the pt_group column. Check that input data is correct.")
  }

  return(x)
}
