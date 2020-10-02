
#' deprecated-statcanR
#'
#'
#' Easily connect to Statistics Canada's Web Data Service with R. Open economic data (formerly known as CANSIM tables, now identified by Product IDs (PID)) are accessible as a data frame, directly in the user's R environment.
#'
#' The
#' \code{sqs_statcan_data()} function has 2 arguments to fulfill to get data: {tableNumber} & {lang}.
#'
#'
#' The tableNumber argument simply refers to the table number of the Statistics Canada data table a user wants to collect,
#' such as '27-10-0014-01' for the Federal expenditures on science and technology, by socio-economic objectives, as an example.
#'
#'
#' To get the table number: \url{https://www150.statcan.gc.ca/n1/en/type/data}.
#'
#' The second argument, lang, refers to the language. As Canada is a bilingual country, Statistics Canada displays all the economic data in both languages.
#' Therefore, users can choose to collect satistics data tables in French or English by setting the lang argument with c('fra', 'eng').
#'
#'
#'
#' @param tableNumber The table number of the Statistics Canada data table
#' @param lang The language wanted
#'
#' @return The output will be a data table representing the data associated with the chosen table number.
#' @export
#'
#' @import  data.table
#' @import  curl
#'
#' @name statcanR-deprecated
#'
#' @examples
#' mydata <- sqs_statcan_data('27-10-0014-01', 'eng')
#'
#' 
#'
#'


# Scraping function for statcan
sqs_statcan_data <- function(tableNumber, lang)
{
  
  .Deprecated(msg = "'sqs_statcan_data()' will be removed in the next version and replaced by the simpler function 'statcan_data()'")  
  
  # In the next version, we will uncomment the next line:
  # .Defunct(msg = "'sqs_statcan_data()' has been removed from this package and replaced with 'statcan_data()'")
  
  # identifying the table number
  tableNumber <- gsub("-", "", substr(tableNumber, 1, nchar(tableNumber) - 
                                        2))
  
  # getting data in English version
  if (lang == "eng")
  {
    # downloading the data file in English version
    urlEng <- paste0("https://www150.statcan.gc.ca/n1/en/tbl/csv/", 
                     tableNumber, "-eng.zip")
    
    download_dir <- file.path(tempdir(), "datasetEng.zip")
    #utils::download.file(urlEng, download_dir, method = "curl")
    #data.table::fread(input = urlEng, file = download_dir)
    #RCurl::getURL(urlEng, ssl.verifyhost=FALSE, ssl.verifypeer=FALSE)
    curl::curl_download(urlEng, download_dir)
    
    # unziping the downloaded data file in English version
    unzip_dir <- file.path(paste0(tempdir(), "/"))
    utils::unzip(zipfile = download_dir, exdir = unzip_dir)
    unlink(download_dir)
    
    # loading the data file in English version
    csv_file <- file.path(paste0(tempdir(), "/", tableNumber, ".csv"))
    sqs_data <- data.table::fread(csv_file)
    
    # adding to the data.frame or data.table the Official Data Table
    # Indicator defined by Statitics Canada and based on metadata file.
    sqs_data$INDICATOR <- as.character(0)
    sqs_data$INDICATOR <- as.character(utils::read.csv(paste0(tempdir(), 
                                                              "/", tableNumber, "_MetaData.csv"))[1, 1])
  }
  
  # getting data in French version
  if (lang == "fra")
  {
    # downloading the data file in French version
    urlFra <- paste0("https://www150.statcan.gc.ca/n1/fr/tbl/csv/", 
                     tableNumber, "-fra.zip")
    
    download_dir <- file.path(tempdir(), "datasetFra.zip")
    #utils::download.file(urlFra, download_dir, method = "curl")
    #data.table::fread(urlFra, download_dir)
    curl::curl_download(urlFra, download_dir)
    
    # unzipping the downloaded data file in French version
    unzip_dir <- file.path(paste0(tempdir(), "/"))
    utils::unzip(zipfile = download_dir, exdir = unzip_dir)
    unlink(download_dir)
    
    # loading the data file in French version
    csv_file <- file.path(paste0(tempdir(), "/", tableNumber, ".csv"))
    sqs_data <- data.table::fread(csv_file)
    
    # adding to the data.frame or data.table the Official Data Table
    # Indicator defined by Statitics Canada and based on metadata file.
    sqs_data$INDICATOR <- as.character(0)
    sqs_data$INDICATOR <- as.character(utils::read.csv(paste0(tempdir(), 
                                                              "/", tableNumber, "_MetaData.csv"))[1, 1])
  }
  
  # removing the temp folder and creating a data frame
  unlink(tempdir())
  data.table::setDF(return(sqs_data))
}

#' statcanR
#'
#'
#' Easily connect to Statistics Canada's Web Data Service with R. Open economic data (formerly known as CANSIM tables, now identified by Product IDs (PID)) are accessible as a data frame, directly in the user's R environment.
#'
#' The
#' \code{statcan_data()} function has 2 arguments to fulfill to get data: {tableNumber} & {lang}.
#'
#'
#' The tableNumber argument simply refers to the table number of the Statistics Canada data table a user wants to collect,
#' such as '27-10-0014-01' for the Federal expenditures on science and technology, by socio-economic objectives, as an example.
#'
#'
#' To get the table number: \url{https://www150.statcan.gc.ca/n1/en/type/data}.
#'
#' The second argument, lang, refers to the language. As Canada is a bilingual country, Statistics Canada displays all the economic data in both languages.
#' Therefore, users can choose to collect satistics data tables in French or English by setting the lang argument with c('fra', 'eng').
#'
#'
#'
#' @param tableNumber The table number of the Statistics Canada data table
#' @param lang The language wanted
#'
#' @return The output will be a data table representing the data associated with the chosen table number.
#' @export
#'
#' @import  data.table
#' @import  curl
#'
#'
#' @examples
#' mydata <- statcan_data('27-10-0014-01', 'eng')
#'


# Scraping function for statcan
statcan_data <- function(tableNumber, lang)
{
  
  # identifying the table number
  tableNumber <- gsub("-", "", substr(tableNumber, 1, nchar(tableNumber) - 
                                        2))
  
  # getting data in English version
  if (lang == "eng")
  {
    # downloading the data file in English version
    urlEng <- paste0("https://www150.statcan.gc.ca/n1/en/tbl/csv/", 
                     tableNumber, "-eng.zip")
    
    download_dir <- file.path(tempdir(), "datasetEng.zip")
    #utils::download.file(urlEng, download_dir, method = "curl")
    #data.table::fread(input = urlEng, file = download_dir)
    #RCurl::getURL(urlEng, ssl.verifyhost=FALSE, ssl.verifypeer=FALSE)
    curl::curl_download(urlEng, download_dir)
    
    # unziping the downloaded data file in English version
    unzip_dir <- file.path(paste0(tempdir(), "/"))
    utils::unzip(zipfile = download_dir, exdir = unzip_dir)
    unlink(download_dir)
    
    # loading the data file in English version
    csv_file <- file.path(paste0(tempdir(), "/", tableNumber, ".csv"))
    can_data <- data.table::fread(csv_file)
    
    # adding to the data.frame or data.table the Official Data Table
    # Indicator defined by Statitics Canada and based on metadata file.
    can_data$INDICATOR <- as.character(0)
    can_data$INDICATOR <- as.character(utils::read.csv(paste0(tempdir(), 
                                                              "/", tableNumber, "_MetaData.csv"))[1, 1])
  }
  
  # getting data in French version
  if (lang == "fra")
  {
    # downloading the data file in French version
    urlFra <- paste0("https://www150.statcan.gc.ca/n1/fr/tbl/csv/", 
                     tableNumber, "-fra.zip")
    
    download_dir <- file.path(tempdir(), "datasetFra.zip")
    #utils::download.file(urlFra, download_dir, method = "curl")
    #data.table::fread(urlFra, download_dir)
    curl::curl_download(urlFra, download_dir)
    
    # unzipping the downloaded data file in French version
    unzip_dir <- file.path(paste0(tempdir(), "/"))
    utils::unzip(zipfile = download_dir, exdir = unzip_dir)
    unlink(download_dir)
    
    # loading the data file in French version
    csv_file <- file.path(paste0(tempdir(), "/", tableNumber, ".csv"))
    can_data <- data.table::fread(csv_file)
    
    # adding to the data.frame or data.table the Official Data Table
    # Indicator defined by Statitics Canada and based on metadata file.
    can_data$INDICATOR <- as.character(0)
    can_data$INDICATOR <- as.character(utils::read.csv(paste0(tempdir(), 
                                                              "/", tableNumber, "_MetaData.csv"))[1, 1])
  }
  
  # removing the temp folder and creating a data frame
  unlink(tempdir())
  data.table::setDF(return(can_data))
}

