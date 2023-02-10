#' Searching function for statcanR
#'
#'
#' Easily connect to Statistics Canada's Web Data Service with R. Open economic data (formerly known as CANSIM tables, now identified by Product IDs (PID)) are accessible as a data frame, directly in the user's R environment.
#'
#'
#' @description The \code{statcan_search()} function has 1 arguments to fulfill to find a database: {keywords}.
#' The keywords argument refers to words that can be found in either the title or the description of the database. For example, inserting the keywords
#' "economy","export",and "link" will bring up the title, table id, description, and release date for databases that include these keywords. In this case, only one data table ("Supply and use tables, link-1997 level")
#' would be returned as it is the only data table containing all three words.
#'
#'
#' @param keywords The words that appear in the title or description of the data table
#' @param lang The language wanted
#'
#' @return The output will be the title, id, description, and release date of a table
#' @export
#'
#' @import data.table
#' @import DT
#' @import curl
#' @import qpdf
#'
#' @examples 
#' statcan_search(c("economy","export","link"),"eng")


statcan_search <- function(keywords,lang)
{
  
  # Loading data
  if (lang == "eng")
  {
    
  # downloading the data file in English version
    url <- paste0("https://warin.ca/datalake/statcanR/statcan_database.csv")
  
  if (httr::http_error(url)) 
    { # network is down = message (not an error anymore)
      message("No tables with this combination of keywords")
    }
  
  else{ 
    path <- file.path(tempdir(), "temp.csv")
    curl::curl_download(url, path)
    csv_file <- file.path(paste0(tempdir(), "/temp.csv"))
    statcan_data <- readr::read_csv(csv_file,col_types = readr::cols(release_date = readr::col_character()))

    
    # Creating the keyword matches
    keyword_regex <- paste0("(", paste(keywords, collapse = "|"), ")", collapse = ".*")
    
    matches <- apply(statcan_data, 1, function(row) {
      all(sapply(keywords, function(x) {
        grepl(x, paste(as.character(row), collapse = " "))
      }))
    })
    
    
    # Keep only obs with matched keywords and create datatable 
    filtered_data <- statcan_data[matches, ]
    datatable(filtered_data, options = list(pageLength = 10))
    }
  }
  
  # Loading data
  if (lang == "fra")
  {
    
    # downloading the data file in English version
    url <- paste0("https://warin.ca/datalake/statcanR/statcan_database_fr.csv")
    
    if (httr::http_error(url)) 
    { # network is down = message (not an error anymore)
      message("No tables with this combination of keywords")
    }
    
    else{ 
      path <- file.path(tempdir(), "temp.csv")
      curl::curl_download(url, path)
      csv_file <- file.path(paste0(tempdir(), "/temp.csv"))
      statcan_data <- readr::read_csv(csv_file,col_types = readr::cols(release_date = readr::col_character()))

      
      # Creating the keyword matches
      keyword_regex <- paste0("(", paste(keywords, collapse = "|"), ")", collapse = ".*")
      
      matches <- apply(statcan_data, 1, function(row) {
        all(sapply(keywords, function(x) {
          grepl(x, paste(as.character(row), collapse = " "))
        }))
      })
      
      
      # Keep only obs with matched keywords and create datatable 
      filtered_data <- statcan_data[matches, ]
      datatable(filtered_data, options = list(pageLength = 10))
    }
  }
  
}

  