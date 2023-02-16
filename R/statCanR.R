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
#' @import curl
#' @import tibble
#' @import qpdf
#' @importFrom httr http_error
#' @importFrom data.table fread
#' @importFrom data.table setDF
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
    #curl::curl_download(urlEng, download_dir)
  
    if (httr::http_error(urlEng)) { # network is down = message (not an error anymore)
      message("No Internet connection or incorrect statcan table number or Statistics Canada website under maintenance.")
      #return(NULL)
    } else { # network is up = proceed to download via curl
      message("statcanR: downloading remote table.")
      with(options(timeout = max(300, getOption("timeout"))),curl::curl_download(urlEng, download_dir))
    
      
    # unziping the downloaded data file in English version
    unzip_dir <- file.path(paste0(tempdir(), "/"))
    utils::unzip(zipfile = download_dir, exdir = unzip_dir)
    unlink(download_dir)
    
    # loading the data file in English version
    csv_file <- file.path(paste0(tempdir(), "/", tableNumber, ".csv"))
    can_data <- data.table::fread(csv_file)
    
    # adding to the data.frame or data.table the Official Data Table
    # Indicator defined by Statistics Canada and based on metadata file.
    can_data$INDICATOR <- as.character(0)
    can_data$COORDINATE <- as.character(can_data$COORDINATE)
    can_data$INDICATOR <- as.character(readr::read_csv(paste0(tempdir(), 
                                                              "/", tableNumber, "_MetaData.csv"))[1, 1])
    
    if(nchar(can_data[1,1])==9){
      can_data$REF_DATE <- sub(".*/", "", can_data$REF_DATE)
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 3, 31, sep = "-"))
      can_data <- tibble::add_column(can_data, REF_PERIOD = "Fiscal year", .before = 2) 
    }
    
    else if(nchar(can_data[1,1])==7){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, sep = "-"))
    }
    
    else if(nchar(can_data[1,1])==4){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, 1, sep = "-"))
    }
    
    else{
      can_data$REF_DATE <- as.Date(can_data$REF_DATE)
    }
    
    # creating a data frame
    data.table::setDF(return(can_data))
    
    } # /if - network up or down    
    
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
    #curl::curl_download(urlFra, download_dir)
    
    if (httr::http_error(urlFra)) { # network is down = message (not an error anymore)
      message("No Internet connection or incorrect statcan table number or Statistics Canada website under maintenance.")
      return(NULL)
    } else { # network is up = proceed to download via curl
      message("statcanR: downloading remote table.")
      with(options(timeout = max(300, getOption("timeout"))),curl::curl_download(urlFra, download_dir))
    
    
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
    can_data$COORDINATE <- as.character(can_data$COORDINATE)
    can_data$INDICATOR <- as.character(readr::read_delim(paste0(tempdir(), 
                                                              "/", tableNumber, "_MetaData.csv"), delim = ";", escape_double = FALSE, trim_ws = TRUE)[1, 1])
    
    can_data[,1] <- "REF_DATE"
    
    if(nchar(can_data[1,1])==9){
      can_data$REF_DATE <- sub(".*/", "", can_data$REF_DATE)
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 3, 31, sep = "-"))
      can_data <- tibble::add_column(can_data, REF_PERIOD = "Fiscal year", .before = 2) 
    }
    
    else if(nchar(can_data[1,1])==7){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, sep = "-"))
    }
    
    else if(nchar(can_data[1,1])==4){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, 1, sep = "-"))
    }
    
    else{
      can_data$REF_DATE <- as.Date(can_data$REF_DATE)
    }
    
    # creating a data frame
    data.table::setDF(return(can_data))
    } # /if - network up or down   
  
  }
  
  
  # removing the temp folder and creating a data frame
  unlink(tempdir())
  
}

#' statcanR download data function
#'
#' @param tableNumber The table number of the Statistics Canada data table
#' @param lang The language wanted
#'
#' @return The output will be  a data table and csv file representing the data associated with the chosen table number.
#' @export
#' 
#' 
#' @import curl
#' @import tibble
#' @importFrom httr http_error
#' @importFrom data.table fread
#' @importFrom data.table setDF
#'
#' @examples
#' mydata <- statcan_data('27-10-0014-01', 'eng')

# Download function for statcan
statcan_download_data <- function(tableNumber, lang)
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
    #curl::curl_download(urlEng, download_dir)
    
    if (httr::http_error(urlEng)) { # network is down = message (not an error anymore)
      message("No Internet connection or incorrect statcan table number or Statistics Canada website under maintenance.")
      #return(NULL)
    } else { # network is up = proceed to download via curl
      message("statcanR: downloading remote table.")
      with(options(timeout = max(300, getOption("timeout"))),curl::curl_download(urlEng, download_dir))
    
    # unziping the downloaded data file in English version
    unzip_dir <- file.path(paste0(tempdir(), "/"))
    utils::unzip(zipfile = download_dir, exdir = unzip_dir)
    unlink(download_dir)
    
    # loading the data file in English version
    csv_file <- file.path(paste0(tempdir(), "/", tableNumber, ".csv"))
    can_data <- data.table::fread(csv_file)
    
    # adding to the data.frame or data.table the Official Data Table
    # Indicator defined by Statistics Canada and based on metadata file.
    can_data$INDICATOR <- as.character(0)
    can_data$COORDINATE <- as.character(can_data$COORDINATE)
    can_data$INDICATOR <- as.character(readr::read_csv(paste0(tempdir(), 
                                                              "/", tableNumber, "_MetaData.csv"))[1, 1])
    
    if(nchar(can_data[1,1])==9){
      can_data$REF_DATE <- sub(".*/", "", can_data$REF_DATE)
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 3, 31, sep = "-"))
      can_data <- tibble::add_column(can_data, REF_PERIOD = "Fiscal year", .before = 2) 
    }
    
    else if(nchar(can_data[1,1])==7){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, sep = "-"))
    }
    
    else if(nchar(can_data[1,1])==4){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, 1, sep = "-"))
    }
    
    else{
      can_data$REF_DATE <- as.Date(can_data$REF_DATE)
    }
    # creating a data frame
    data.table::setDF(return(can_data))
    readr::write_csv(can_data, paste0("./statcan_",tableNumber,"_", lang,".csv"))
    
    } # /if - network up or down    
    
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
    #curl::curl_download(urlFra, download_dir)
    
    if (httr::http_error(urlFra)) { # network is down = message (not an error anymore)
      message("No Internet connection or incorrect statcan table number or Statistics Canada website under maintenance.")
      return(NULL)
    } else { # network is up = proceed to download via curl
      message("statcanR: downloading remote table.")
      with(options(timeout = max(300, getOption("timeout"))),curl::curl_download(urlFra, download_dir))
     
    
    
    # unzipping the downloaded data file in French version
    unzip_dir <- file.path(paste0(tempdir(), "/"))
    utils::unzip(zipfile = download_dir, exdir = unzip_dir)
    unlink(download_dir)
    
    # loading the data file in French version
    csv_file <- file.path(paste0(tempdir(), "/", tableNumber, ".csv"))
    can_data <- data.table::fread(csv_file)
    
    # adding to the data.frame or data.table the Official Data Table
    # Indicator defined by Statistics Canada and based on metadata file.
    can_data$INDICATOR <- as.character(0)
    can_data$COORDINATE <- as.character(can_data$COORDINATE)
    can_data$INDICATOR <- as.character(readr::read_delim(paste0(tempdir(), 
                                                                "/", tableNumber, "_MetaData.csv"), delim = ";", escape_double = FALSE, trim_ws = TRUE)[1, 1])
    
    can_data[,1] <- "REF_DATE"
    
    if(nchar(can_data[1,1])==9){
      can_data$REF_DATE <- sub(".*/", "", can_data$REF_DATE)
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 3, 31, sep = "-"))
      can_data <- tibble::add_column(can_data, REF_PERIOD = "Fiscal year", .before = 2) 
    }
    
    else if(nchar(can_data[1,1])==7){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, sep = "-"))
    }
    
    else if(nchar(can_data[1,1])==4){
      can_data$REF_DATE <- as.Date(paste(can_data$REF_DATE, 1, 1, sep = "-"))
    }
    
    else{
      can_data$REF_DATE <- as.Date(can_data$REF_DATE)
    }
    # creating a data frame
    data.table::setDF(return(can_data))
    
    readr::write_csv(can_data, paste0("./statcan_",tableNumber,"_", lang,".csv"))
    } # /if - network up or down  
  }
  
  # removing the temp folder and creating a data frame
  unlink(tempdir())
}