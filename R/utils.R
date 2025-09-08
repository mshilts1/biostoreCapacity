#' Load in BioStore capacity Excel file from Karen Beeri
#'
#' @param x Exact name of the file
#'
#' @returns A clean tibble of the Excel file for further manipulation
#' @export
#' @importFrom readxl read_xlsx
#' @importFrom janitor make_clean_names
#'
#' @examples
#' readKBExcel()
readKBExcel <- function(x = "calculator_for_Suman.xlsx"){
  path <- system.file("extdata", x, package = "biostoreCapacity", mustWork = TRUE)
  print(path)
  readxl::read_xlsx(path = path, .name_repair = janitor::make_clean_names)
}
