
#' statcanR
#'
#'
#'Get all Canadian statistics data (CANSIM tables) now identify by Product IDs (PID) by the new Statistics Canada Web Data Service
#'
#'The
#'\code{_sqs_statcan_data()_} function has 2 arguments to fulfill to get data: {tableNumber} & {lang}
#'
#'
#'The tableNumber argument simply referes to the table number of the Statistics Canada data table you want to collect,
#'such as '14-10-0287-03' for the Labour force characteristics by province, monthly, seasonally adjusted_ as an example.
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

# Scrapping function for statcan
sqs_statcan_data <- function(tableNumber, lang){


  #table number
  tableNumber <- gsub("-", "", substr(tableNumber, 1, nchar(tableNumber)-2))

  #create path
  path <- "./"

  #create a temporary folder to manipulated the scraped data
  dir.create(file.path(path, "temp"))

  #get data in english version
  if(lang == "eng"){
    #download the data file in english version
    urlEng <- paste0("https://www150.statcan.gc.ca/n1/en/tbl/csv/",
                     tableNumber,
                     "-eng.zip")
    utils::download.file(urlEng,
                  destfile=paste0(path,"/temp/datasetEng.zip"),
                  method="curl")

    #unzip the downloaded data file in english version
    utils::unzip(paste0(path, "/temp/datasetEng.zip"),
          exdir = paste0(path,"/temp"))

    #load the data file in english version
    data <- data.table::fread(paste0(path,
                         "/temp/",
                         tableNumber,
                         ".csv"))

    #add to the data.frame or data.table the Official Data Table Indicator
    #defined by Statitics Canada and based on metadata file.
    data$INDICATOR <- as.character(0)
    data$INDICATOR <- as.character(utils::read.csv(paste0(path,
                                                   "/temp/",
                                                   tableNumber,
                                                   "_MetaData.csv")
    )[1,1])
  }

  #get data in french version
  if(lang == "fra"){
    #download the data file in french version
    urlFra <- paste0("https://www150.statcan.gc.ca/n1/fr/tbl/csv/",
                     tableNumber,
                     "-fra.zip")
    utils::download.file(urlFra,
                  destfile=paste0(path, "/temp/datasetFra.zip"),
                  method="curl")

    #unzip the downloaded data file in french version
    utils::unzip(paste0(path, "/temp/datasetFra.zip"),
          exdir = paste0(path,"/temp"))

    #load the data file in french version
    data <- data.table::fread(paste0(path,
                         "/temp/",
                         tableNumber,
                         ".csv"))
    #add to the data.frame or data.table the Official Data Table Indicator
    #defined by Statitics Canada and based on metadata file.
    data$INDICATEUR <- as.character(0)
    data$INDICATEUR <- as.character(utils::read.csv(paste0(path,
                                                    "/temp/",
                                                    tableNumber,
                                                    "_MetaData.csv")
    )[1,1])
  }

  unlink(paste0(path,"/temp/"), recursive = TRUE)

  return(data)



}
