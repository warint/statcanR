
#' statcanR
#'
#'
#'An R package to acccess Statistics Canada's open economic data (formerly known as CANSIM tables) now identified by Product IDs (PID) by the new Statistics Canada's Web Data Service
#'
#'The
#'\code{_sqs_statcan_data()_} function has 2 arguments to fulfill to get data: {tableNumber} & {lang}
#'
#'
#'The tableNumber argument simply refers to the table number of the Statistics Canada data table a user wants to collect,
#'such as '14-10-0287-03' for the Labour force variales by province, monthly, seasonally adjusted_ as an example.
#'
#'To get the table number :\url{https://www150.statcan.gc.ca/n1/en/type/data}
#'
#'The second argument, lang, referes to the language. As Canada is a bilingual country, Statistics Canada displays all data in both languages.
#' Therefore, users can choose if they want to get satistics data tables in French or English by setting the lang argument with c("fra", "eng").
#'
#'
#' @param tableNumber The table number of the Statistics Canada data table
#' @param lang The language wanted
#'
#' @return The output will be a data table representing the data associated with the chosen table number
#' @export
#'
#'@import data.table
#'
#'
#' @examples
#' \dontrun{
#' datatable <- sqs_statcan_data("14-10-0287-03","eng")
#'}

# Scraping function for statcan
sqs_statcan_data <- function(tableNumber, lang){
  
  # identifying the user's current folder
  dir_user <- getwd()
  setwd(dir_user)
  
  # identifying the table number
  tableNumber <- gsub("-", "", substr(tableNumber, 1, nchar(tableNumber)-2))
  
  # creating path
  path <- "./"
  
  # creating a temporary folder to work on the collected data
  dir.create(file.path(path, "temp"))
  
  # getting data in English version
  if(lang == "eng"){
    # downloading the data file in English version
    urlEng <- paste0("https://www150.statcan.gc.ca/n1/en/tbl/csv/",
                     tableNumber,
                     "-eng.zip")
    utils::download.file(urlEng,
                         destfile=paste0(path,"/temp/datasetEng.zip"),
                         method="curl")
    
    # unziping the downloaded data file in English version
    utils::unzip(paste0(path, "/temp/datasetEng.zip"),
                 exdir = paste0(path,"/temp"))
    
    # loading the data file in English version
    sqs_data <- data.table::fread(paste0(path,
                                     "/temp/",
                                     tableNumber,
                                     ".csv"))
    
    # adding to the data.frame or data.table the Official Data Table Indicator
    # defined by Statitics Canada and based on metadata file.
    sqs_data$INDICATOR <- as.character(0)
    sqs_data$INDICATOR <- as.character(utils::read.csv(paste0(path,
                                                          "/temp/",
                                                          tableNumber,
                                                          "_MetaData.csv")
    )[1,1])
  }
  
  # getting data in French version
  if(lang == "fra"){
    # downloading the data file in French version
    urlFra <- paste0("https://www150.statcan.gc.ca/n1/fr/tbl/csv/",
                     tableNumber,
                     "-fra.zip")
    utils::download.file(urlFra,
                         destfile=paste0(path, "/temp/datasetFra.zip"),
                         method="curl")
    
    # unzipping the downloaded data file in French version
    utils::unzip(paste0(path, "/temp/datasetFra.zip"),
                 exdir = paste0(path,"/temp"))
    
    # loading the data file in French version
    sqs_data <- data.table::fread(paste0(path,
                                     "/temp/",
                                     tableNumber,
                                     ".csv"))
    # adding to the data.frame or data.table the Official Data Table Indicator
    # defined by Statitics Canada and based on metadata file.
    sqs_data$INDICATEUR <- as.character(0)
    sqs_data$INDICATEUR <- as.character(utils::read.csv(paste0(path,
                                                           "/temp/",
                                                           tableNumber,
                                                           "_MetaData.csv")
    )[1,1])
  }
  
  # deleting the temp folder
  unlink(paste0(path,"/temp/"), recursive = TRUE)
  
  data.table::setDF(return(sqs_data))
  
}
