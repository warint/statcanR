
#' statcanR
#'
#'
#' Easily connect to Statistics Canada's Web Data Service with R. Open economic data (formerly known as CANSIM tables, now identified by Product IDs (PID)) are accessible as a data frame, directly in the user's R environment.
#'
#' The
#' \code{sqs_statcan_data()} function has 2 arguments to fulfill to get data: {tableNumber} & {lang}.
#'
#'
#' The tableNumber argument simply refers to the table number of the Statistics Canada data table a user wants to collect,
#' such as '14-10-0287-03' for the labour force variables by province, monthly, seasonally adjusted, as an example.
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
#' @import  downloader
#'
#'
#' @examples
#' mydata <- sqs_statcan_data('14-10-0287-03', 'eng')
#'
#'
#'
#'
#'
#' # Scraping function for statcan
sqs_statcan_data <- function(tableNumber, lang)
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
        downloader::download(urlEng, download_dir, mode = "wb")
        
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
        downloader::download(urlFra, download_dir, mode = "wb")
        
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
