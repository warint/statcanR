#' Find Statistics Canada tables using a natural-language query
#'
#' Interprets a short description of the data needed and returns ranked
#' Statistics Canada table candidates. The query can contain a topic, Canadian
#' geography, and reference year or range. For example,
#' `"R&D expenditures in Quebec since 2020"` is interpreted as a research and
#' development expenditure topic, a Quebec geography constraint, and coverage
#' beginning in 2020.
#'
#' This function finds tables; it does not download or filter their
#' observations. Use the returned `id` with [statcan_data()], then apply any
#' required geography and date filters to the downloaded data. Rankings are a
#' discovery aid, so review the candidate title before downloading a large
#' table.
#'
#' The catalogue is cached for 24 hours. When a geography is present in the
#' query, metadata for a small set of leading candidates is retrieved through
#' WDS to confirm that the geography is a table member. That metadata is cached
#' for seven days. If metadata is temporarily unavailable, candidates can
#' still be returned with `geography_match = NA`.
#'
#' @param query One non-empty character string describing the desired data.
#' @param lang Language of the table titles: `"eng"` or `"fra"`.
#' @param n Maximum number of candidates to return, from 1 to 20.
#' @param refresh Logical; if `TRUE`, request a fresh catalogue and fresh
#'   candidate metadata from WDS.
#'
#' @return A data frame of ranked candidates. `id` contains the table number,
#'   `score` is the relevance score, and `match_reason` explains the ranking.
#'   Coverage dates describe the table as a whole. `geography_match` is `TRUE`
#'   when WDS metadata confirms every geography in the query, `FALSE` when it
#'   does not, and `NA` when no geography was requested or validation was not
#'   possible.
#' @export
#'
#' @examples
#' \dontrun{
#' matches <- statcan_find(
#'   "R&D expenditures in Quebec since 2020",
#'   lang = "eng"
#' )
#' matches[, c("title", "id", "match_reason")]
#' }
statcan_find <- function(query, lang = c("eng", "fra"), n = 5L,
                         refresh = FALSE) {
  lang <- match.arg(lang)
  if (!is.character(query) || length(query) != 1L || is.na(query) ||
      !nzchar(trimws(query))) {
    stop("`query` must be one non-empty character string.", call. = FALSE)
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n %% 1 != 0 ||
      n < 1 || n > 20) {
    stop("`n` must be one whole number from 1 to 20.", call. = FALSE)
  }
  if (!is.logical(refresh) || length(refresh) != 1L || is.na(refresh)) {
    stop("`refresh` must be TRUE or FALSE.", call. = FALSE)
  }
  n <- as.integer(n)

  parsed <- parse_statcan_query(query, lang)
  if (!length(parsed$topic_terms)) {
    stop(
      "The query must include a subject, not only a geography or date.",
      call. = FALSE
    )
  }

  candidates <- rank_statcan_catalogue(
    statcan_catalogue(refresh = refresh),
    parsed,
    lang
  )
  if (!nrow(candidates)) {
    return(empty_statcan_find_result())
  }

  geography_label <- parsed_geography_label(parsed, lang)
  candidates$geography <- rep(geography_label, nrow(candidates))
  candidates$geography_match <- rep(NA, nrow(candidates))

  if (nrow(parsed$geographies)) {
    pool_size <- min(nrow(candidates), max(20L, min(60L, n * 10L)))
    candidates <- candidates[seq_len(pool_size), , drop = FALSE]
    metadata <- statcan_metadata_for_tables(
      candidates$id,
      refresh = refresh
    )
    product_ids <- vapply(
      candidates$id,
      normalize_product_id,
      character(1)
    )
    candidates$geography_match <- vapply(
      product_ids,
      function(product_id) {
        candidate_metadata <- metadata[[product_id]]
        if (is.null(candidate_metadata)) {
          return(NA)
        }
        metadata_matches_geographies(
          candidate_metadata,
          parsed$geographies
        )
      },
      logical(1)
    )

    candidates$score[candidates$geography_match %in% TRUE] <- pmin(
      100,
      candidates$score[candidates$geography_match %in% TRUE] + 10
    )
    candidates <- candidates[
      is.na(candidates$geography_match) |
        candidates$geography_match,
      ,
      drop = FALSE
    ]
    if (!nrow(candidates)) {
      return(empty_statcan_find_result())
    }
    candidates <- order_statcan_candidates(candidates)
  }

  candidates <- candidates[seq_len(min(n, nrow(candidates))), , drop = FALSE]
  candidates$match_reason <- vapply(
    seq_len(nrow(candidates)),
    function(index) build_statcan_match_reason(
      candidates[index, , drop = FALSE],
      parsed,
      lang
    ),
    character(1)
  )
  candidates$rank <- seq_len(nrow(candidates))
  candidates$lang <- rep(lang, nrow(candidates))

  result <- candidates[
    c(
      "rank", "title", "id", "score", "match_reason", "start_date",
      "end_date", "release_date", "geography", "geography_match", "lang"
    )
  ]
  rownames(result) <- NULL
  result
}


empty_statcan_find_result <- function() {
  data.frame(
    rank = integer(),
    title = character(),
    id = character(),
    score = numeric(),
    match_reason = character(),
    start_date = as.Date(character()),
    end_date = as.Date(character()),
    release_date = as.Date(character()),
    geography = character(),
    geography_match = logical(),
    lang = character(),
    stringsAsFactors = FALSE
  )
}


parse_statcan_query <- function(query, lang) {
  normalized <- normalize_statcan_search_text(query)
  geography_result <- extract_statcan_geographies(normalized)
  dates <- extract_statcan_query_dates(normalized, lang)
  topic_text <- geography_result$remaining_text
  topic_text <- gsub("\\b(?:19|20)[0-9]{2}\\b", " ", topic_text, perl = TRUE)

  list(
    topic_terms = canonical_statcan_tokens(topic_text),
    geographies = geography_result$geographies,
    start_date = dates$start_date,
    end_date = dates$end_date,
    date_label = dates$label
  )
}


normalize_statcan_search_text <- function(text) {
  text <- tolower(text)
  text <- gsub("&amp;", "&", text, fixed = TRUE)
  text <- gsub("&#0*39;|&apos;", "'", text, perl = TRUE)
  text <- gsub(
    "\\br\\s*(?:[-&+/]|and|et)\\s*d\\b",
    " research and development ",
    text,
    perl = TRUE
  )
  # `iconv(..., "ASCII//TRANSLIT")` is platform-dependent. In particular,
  # macOS can transliterate French accents with apostrophes (for example,
  # "Quebec" can become "qu'ebec"). Normalize common Latin characters first
  # so query parsing gives the same result on all CRAN platforms.
  replacements <- c(
    "[\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5]" = "a",
    "[\u00e7\u0107\u010d]" = "c", "[\u010f\u00f0]" = "d",
    "[\u00e8\u00e9\u00ea\u00eb]" = "e",
    "[\u00ec\u00ed\u00ee\u00ef]" = "i", "[\u00f1\u0148]" = "n",
    "[\u00f2\u00f3\u00f4\u00f5\u00f6\u00f8]" = "o",
    "[\u0159]" = "r", "[\u0161]" = "s", "[\u0165]" = "t",
    "[\u00f9\u00fa\u00fb\u00fc]" = "u", "[\u00fd\u00ff]" = "y",
    "[\u017e]" = "z", "\u00e6" = "ae", "\u0153" = "oe"
  )
  for (pattern in names(replacements)) {
    text <- gsub(pattern, replacements[[pattern]], text, perl = TRUE)
  }
  text <- iconv(text, to = "ASCII//TRANSLIT", sub = "")
  text <- gsub("[^a-z0-9]+", " ", text)
  trimws(gsub("[[:space:]]+", " ", text))
}


canonical_statcan_tokens <- function(text) {
  normalized <- normalize_statcan_search_text(text)
  if (!nzchar(normalized)) {
    return(character())
  }
  normalized <- expand_statcan_acronyms(normalized)
  tokens <- unlist(strsplit(normalized, " ", fixed = TRUE), use.names = FALSE)
  dictionary <- c(
    research = "research",
    recherche = "research",
    recherches = "research",
    development = "development",
    developpement = "development",
    expenditure = "expenditure",
    expenditures = "expenditure",
    expense = "expenditure",
    expenses = "expenditure",
    spending = "expenditure",
    depense = "expenditure",
    depenses = "expenditure"
  )
  mapped <- unname(dictionary[tokens])
  tokens[!is.na(mapped)] <- mapped[!is.na(mapped)]

  stopwords <- c(
    "a", "about", "after", "all", "an", "and", "as", "at", "before",
    "between", "by", "data", "for", "from", "get", "give", "i", "in",
    "into", "me", "of", "on", "please", "province", "show", "since",
    "starting", "table", "tables", "the", "through", "to", "until",
    "with", "year", "years", "au", "aux", "avec", "avant", "de", "des",
    "depuis", "du", "en", "entre", "et", "jusqu", "la", "le", "les",
    "par", "pour", "sur", "un", "une", "r", "d"
  )
  unique(tokens[
    nzchar(tokens) &
      !tokens %in% stopwords &
      !grepl("^(?:19|20)[0-9]{2}$", tokens)
  ])
}


expand_statcan_acronyms <- function(text) {
  acronyms <- c(
    gdp = "gross domestic product",
    pib = "produit interieur brut",
    cpi = "consumer price index",
    ipc = "indice des prix a la consommation",
    ippi = "industrial product price index",
    ppi = "industrial product price index"
  )
  for (acronym in names(acronyms)) {
    text <- gsub(
      paste0("\\b", acronym, "\\b"),
      acronyms[[acronym]],
      text,
      perl = TRUE
    )
  }
  trimws(gsub("[[:space:]]+", " ", text))
}


statcan_geography_dictionary <- function() {
  list(
    list(eng = "Canada", fra = "Canada", aliases = c("canada")),
    list(
      eng = "Newfoundland and Labrador",
      fra = "Terre-Neuve-et-Labrador",
      aliases = c("newfoundland and labrador", "terre neuve et labrador")
    ),
    list(
      eng = "Prince Edward Island",
      fra = "\u00cele-du-Prince-\u00c9douard",
      aliases = c("prince edward island", "ile du prince edouard")
    ),
    list(
      eng = "Nova Scotia", fra = "Nouvelle-\u00c9cosse",
      aliases = c("nova scotia", "nouvelle ecosse")
    ),
    list(
      eng = "New Brunswick", fra = "Nouveau-Brunswick",
      aliases = c("new brunswick", "nouveau brunswick")
    ),
    list(
      eng = "Quebec", fra = "Qu\u00e9bec",
      aliases = c("province of quebec", "province de quebec", "quebec", "qc")
    ),
    list(eng = "Ontario", fra = "Ontario", aliases = c("ontario")),
    list(eng = "Manitoba", fra = "Manitoba", aliases = c("manitoba")),
    list(
      eng = "Saskatchewan", fra = "Saskatchewan",
      aliases = c("saskatchewan")
    ),
    list(eng = "Alberta", fra = "Alberta", aliases = c("alberta")),
    list(
      eng = "British Columbia", fra = "Colombie-Britannique",
      aliases = c("british columbia", "colombie britannique", "b c")
    ),
    list(eng = "Yukon", fra = "Yukon", aliases = c("yukon")),
    list(
      eng = "Northwest Territories", fra = "Territoires du Nord-Ouest",
      aliases = c("northwest territories", "territoires du nord ouest")
    ),
    list(eng = "Nunavut", fra = "Nunavut", aliases = c("nunavut")),
    list(eng = "St. John's", fra = "St. John's", aliases = c("st johns")),
    list(eng = "Halifax", fra = "Halifax", aliases = c("halifax")),
    list(eng = "Moncton", fra = "Moncton", aliases = c("moncton")),
    list(eng = "Saint John", fra = "Saint John", aliases = c("saint john")),
    list(eng = "Saguenay", fra = "Saguenay", aliases = c("saguenay")),
    list(
      eng = "Quebec City", fra = "Qu\u00e9bec",
      aliases = c("quebec city")
    ),
    list(eng = "Sherbrooke", fra = "Sherbrooke", aliases = c("sherbrooke")),
    list(
      eng = "Trois-Rivi\u00e8res", fra = "Trois-Rivi\u00e8res",
      aliases = c("trois rivieres")
    ),
    list(eng = "Montreal", fra = "Montr\u00e9al", aliases = c("montreal")),
    list(
      eng = "Ottawa - Gatineau", fra = "Ottawa - Gatineau",
      aliases = c("ottawa gatineau", "ottawa", "gatineau")
    ),
    list(eng = "Kingston", fra = "Kingston", aliases = c("kingston")),
    list(eng = "Belleville", fra = "Belleville", aliases = c("belleville")),
    list(
      eng = "Peterborough", fra = "Peterborough",
      aliases = c("peterborough")
    ),
    list(eng = "Oshawa", fra = "Oshawa", aliases = c("oshawa")),
    list(eng = "Toronto", fra = "Toronto", aliases = c("toronto")),
    list(eng = "Hamilton", fra = "Hamilton", aliases = c("hamilton")),
    list(
      eng = "St. Catharines - Niagara",
      fra = "St. Catharines - Niagara",
      aliases = c("st catharines niagara", "st catharines")
    ),
    list(
      eng = "Kitchener - Cambridge - Waterloo",
      fra = "Kitchener - Cambridge - Waterloo",
      aliases = c(
        "kitchener cambridge waterloo", "kitchener", "cambridge", "waterloo"
      )
    ),
    list(eng = "Brantford", fra = "Brantford", aliases = c("brantford")),
    list(eng = "Guelph", fra = "Guelph", aliases = c("guelph")),
    list(eng = "London", fra = "London", aliases = c("london")),
    list(eng = "Windsor", fra = "Windsor", aliases = c("windsor")),
    list(eng = "Barrie", fra = "Barrie", aliases = c("barrie")),
    list(
      eng = "Greater Sudbury", fra = "Grand Sudbury",
      aliases = c("greater sudbury", "grand sudbury", "sudbury")
    ),
    list(
      eng = "Thunder Bay", fra = "Thunder Bay",
      aliases = c("thunder bay")
    ),
    list(eng = "Winnipeg", fra = "Winnipeg", aliases = c("winnipeg")),
    list(eng = "Regina", fra = "Regina", aliases = c("regina")),
    list(eng = "Saskatoon", fra = "Saskatoon", aliases = c("saskatoon")),
    list(eng = "Calgary", fra = "Calgary", aliases = c("calgary")),
    list(eng = "Edmonton", fra = "Edmonton", aliases = c("edmonton")),
    list(eng = "Lethbridge", fra = "Lethbridge", aliases = c("lethbridge")),
    list(eng = "Kelowna", fra = "Kelowna", aliases = c("kelowna")),
    list(
      eng = "Abbotsford - Mission", fra = "Abbotsford - Mission",
      aliases = c("abbotsford mission", "abbotsford")
    ),
    list(eng = "Vancouver", fra = "Vancouver", aliases = c("vancouver")),
    list(eng = "Victoria", fra = "Victoria", aliases = c("victoria")),
    list(eng = "Nanaimo", fra = "Nanaimo", aliases = c("nanaimo")),
    list(eng = "Chilliwack", fra = "Chilliwack", aliases = c("chilliwack")),
    list(eng = "Kamloops", fra = "Kamloops", aliases = c("kamloops"))
  )
}


extract_statcan_geographies <- function(normalized_query) {
  remaining <- paste0(" ", normalized_query, " ")
  found <- list()
  for (geography in statcan_geography_dictionary()) {
    aliases <- unique(normalize_statcan_search_text(geography$aliases))
    aliases <- aliases[order(nchar(aliases), decreasing = TRUE)]
    matched <- aliases[vapply(
      aliases,
      function(alias) grepl(
        paste0(" ", alias, " "),
        remaining,
        fixed = TRUE
      ),
      logical(1)
    )]
    if (!length(matched)) {
      next
    }
    found[[length(found) + 1L]] <- geography
    remaining <- gsub(
      paste0(" ", matched[[1L]], " "),
      " ",
      remaining,
      fixed = TRUE
    )
    remaining <- paste0(" ", trimws(gsub(" +", " ", remaining)), " ")
  }

  geographies <- if (length(found)) {
    data.frame(
      eng = vapply(found, `[[`, character(1), "eng"),
      fra = vapply(found, `[[`, character(1), "fra"),
      aliases = I(lapply(found, `[[`, "aliases")),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      eng = character(),
      fra = character(),
      aliases = I(list()),
      stringsAsFactors = FALSE
    )
  }

  list(
    geographies = geographies,
    remaining_text = trimws(gsub(" +", " ", remaining))
  )
}


extract_statcan_query_dates <- function(normalized_query, lang) {
  year_matches <- regmatches(
    normalized_query,
    gregexpr("\\b(?:19|20)[0-9]{2}\\b", normalized_query, perl = TRUE)
  )[[1L]]
  if (!length(year_matches) || identical(year_matches, "")) {
    return(list(
      start_date = as.Date(NA),
      end_date = as.Date(NA),
      label = NA_character_
    ))
  }

  years <- as.integer(year_matches)
  if (length(years) >= 2L) {
    start_year <- min(years)
    end_year <- max(years)
    label <- if (lang == "eng") {
      paste(start_year, "to", end_year)
    } else {
      paste(start_year, "\u00e0", end_year)
    }
    return(list(
      start_date = as.Date(paste0(start_year, "-01-01")),
      end_date = as.Date(paste0(end_year, "-12-31")),
      label = label
    ))
  }

  year <- years[[1L]]
  starts_at_year <- grepl(
    "\\b(since|from|after|starting|depuis)\\b|a partir",
    normalized_query,
    perl = TRUE
  )
  ends_at_year <- grepl(
    "\\b(until|through|before|jusqu)\\b",
    normalized_query,
    perl = TRUE
  )
  if (starts_at_year && !ends_at_year) {
    return(list(
      start_date = as.Date(paste0(year, "-01-01")),
      end_date = as.Date(NA),
      label = if (lang == "eng") {
        paste("since", year)
      } else {
        paste("depuis", year)
      }
    ))
  }
  if (ends_at_year && !starts_at_year) {
    return(list(
      start_date = as.Date(NA),
      end_date = as.Date(paste0(year, "-12-31")),
      label = if (lang == "eng") {
        paste("through", year)
      } else {
        paste("jusqu'en", year)
      }
    ))
  }

  list(
    start_date = as.Date(paste0(year, "-01-01")),
    end_date = as.Date(paste0(year, "-12-31")),
    label = if (lang == "eng") paste("year", year) else {
      paste("ann\u00e9e", year)
    }
  )
}


rank_statcan_catalogue <- function(catalogue, parsed, lang) {
  title_column <- if (lang == "eng") "title_eng" else "title_fra"
  titles <- catalogue[[title_column]]
  title_terms <- lapply(titles, canonical_statcan_tokens)
  query_terms <- parsed$topic_terms

  matched_count <- vapply(
    title_terms,
    function(terms) sum(vapply(
      query_terms,
      term_matches_statcan_title,
      logical(1),
      title_terms = terms
    )),
    integer(1)
  )
  match_ratio <- matched_count / length(query_terms)
  title_term_count <- vapply(
    title_terms,
    function(terms) max(1L, length(unique(terms))),
    integer(1)
  )
  # Prefer a concise title when two tables match the same query terms. This
  # tends to rank a broad table ahead of a highly specialized table whose
  # title happens to contain the same words.
  topic_density <- matched_count / title_term_count

  date_match <- statcan_date_coverage(
    catalogue$start_date,
    catalogue$end_date,
    parsed$start_date,
    parsed$end_date
  )
  keep <- matched_count > 0L & (is.na(date_match) | date_match)
  if (!any(keep)) {
    return(data.frame())
  }

  current_bonus <- ifelse(
    is.na(catalogue$archived),
    0,
    ifelse(catalogue$archived, -10, 5)
  )
  date_bonus <- ifelse(is.na(date_match), 0, ifelse(date_match, 5, 0))
  score <- round(
    60 * match_ratio +
      10 * (matched_count == length(query_terms)) +
      10 * topic_density +
      date_bonus +
      current_bonus,
    1
  )

  candidates <- data.frame(
    title = titles[keep],
    id = catalogue$id[keep],
    score = score[keep],
    start_date = catalogue$start_date[keep],
    end_date = catalogue$end_date[keep],
    release_date = catalogue$release_date[keep],
    archived = catalogue$archived[keep],
    matched_count = matched_count[keep],
    topic_count = rep(length(query_terms), sum(keep)),
    date_match = date_match[keep],
    stringsAsFactors = FALSE
  )
  order_statcan_candidates(candidates)
}


term_matches_statcan_title <- function(term, title_terms) {
  if (term %in% title_terms) {
    return(TRUE)
  }
  if (nchar(term) < 5L || !length(title_terms)) {
    return(FALSE)
  }
  any(vapply(
    title_terms[nchar(title_terms) >= 5L],
    function(title_term) {
      startsWith(title_term, term) || startsWith(term, title_term)
    },
    logical(1)
  ))
}


statcan_date_coverage <- function(table_start, table_end,
                                  query_start, query_end) {
  if (is.na(query_start) && is.na(query_end)) {
    return(rep(NA, length(table_start)))
  }
  required_start <- if (is.na(query_start)) query_end else query_start
  required_end <- if (is.na(query_end)) query_start else query_end
  known <- !is.na(table_start) & !is.na(table_end)
  result <- rep(NA, length(table_start))
  result[known] <- table_start[known] <= required_start &
    table_end[known] >= required_end
  result
}


order_statcan_candidates <- function(candidates) {
  release_order <- as.numeric(candidates$release_date)
  release_order[is.na(release_order)] <- -Inf
  candidates[
    order(-candidates$score, -release_order, candidates$title),
    ,
    drop = FALSE
  ]
}


parsed_geography_label <- function(parsed, lang) {
  if (!nrow(parsed$geographies)) {
    return(NA_character_)
  }
  paste(parsed$geographies[[lang]], collapse = ", ")
}


build_statcan_match_reason <- function(candidate, parsed, lang) {
  if (lang == "eng") {
    reasons <- paste0(
      candidate$matched_count, "/", candidate$topic_count,
      " topic terms matched"
    )
    if (nrow(parsed$geographies)) {
      reasons <- c(
        reasons,
        if (candidate$geography_match %in% TRUE) {
          paste0("includes ", candidate$geography)
        } else {
          "geography could not be verified"
        }
      )
    }
    if (!is.na(parsed$date_label)) {
      reasons <- c(
        reasons,
        if (candidate$date_match %in% TRUE) {
          paste0("covers ", parsed$date_label)
        } else {
          "date coverage unavailable"
        }
      )
    }
    if (!is.na(candidate$archived)) {
      reasons <- c(
        reasons,
        if (candidate$archived) "archived table" else "current table"
      )
    }
  } else {
    reasons <- paste0(
      candidate$matched_count, "/", candidate$topic_count,
      " termes th\u00e9matiques correspondants"
    )
    if (nrow(parsed$geographies)) {
      reasons <- c(
        reasons,
        if (candidate$geography_match %in% TRUE) {
          paste0("comprend ", candidate$geography)
        } else {
          "g\u00e9ographie non v\u00e9rifi\u00e9e"
        }
      )
    }
    if (!is.na(parsed$date_label)) {
      reasons <- c(
        reasons,
        if (candidate$date_match %in% TRUE) {
          paste0("couvre ", parsed$date_label)
        } else {
          "couverture chronologique indisponible"
        }
      )
    }
    if (!is.na(candidate$archived)) {
      reasons <- c(
        reasons,
        if (candidate$archived) "tableau archiv\u00e9" else "tableau actuel"
      )
    }
  }
  paste(reasons, collapse = "; ")
}


metadata_matches_geographies <- function(metadata, geographies) {
  members <- normalize_statcan_search_text(c(
    metadata$geographies_eng,
    metadata$geographies_fra
  ))
  all(vapply(
    seq_len(nrow(geographies)),
    function(index) {
      aliases <- normalize_statcan_search_text(
        unlist(geographies$aliases[index], use.names = FALSE)
      )
      any(vapply(
        aliases,
        function(alias) any(
          members == alias |
            startsWith(members, paste0(alias, " ")) |
            startsWith(alias, paste0(members, " "))
        ),
        logical(1)
      ))
    },
    logical(1)
  ))
}


statcan_metadata_for_tables <- function(table_ids, refresh = FALSE) {
  product_ids <- unique(vapply(
    table_ids,
    normalize_product_id,
    character(1)
  ))
  result <- stats::setNames(vector("list", length(product_ids)), product_ids)
  stale <- stats::setNames(vector("list", length(product_ids)), product_ids)
  cache_dir <- tools::R_user_dir("statcanR", which = "cache")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  clean_statcan_metadata_cache(cache_dir)
  cache_ttl <- 7 * 24 * 60 * 60

  for (product_id in product_ids) {
    cache_file <- statcan_metadata_cache_file(cache_dir, product_id)
    if (!file.exists(cache_file)) {
      next
    }
    cached <- tryCatch(readRDS(cache_file), error = function(error) NULL)
    if (!is.list(cached) || !is_valid_statcan_cube_metadata(cached$metadata)) {
      next
    }
    stale[product_id] <- list(cached$metadata)
    age <- as.numeric(difftime(
      Sys.time(), file.info(cache_file)$mtime, units = "secs"
    ))
    if (!refresh && !is.na(age) && age < cache_ttl) {
      result[product_id] <- list(cached$metadata)
    }
  }

  needed <- product_ids[vapply(result, is.null, logical(1))]
  errors <- character()
  if (length(needed)) {
    chunks <- split(needed, ceiling(seq_along(needed) / 10L))
    for (chunk in chunks) {
      fetched <- tryCatch(
        fetch_statcan_cube_metadata(chunk),
        error = function(error) error
      )
      if (inherits(fetched, "error")) {
        errors <- c(errors, conditionMessage(fetched))
        next
      }
      for (product_id in names(fetched)) {
        result[product_id] <- list(fetched[[product_id]])
        cache_file <- statcan_metadata_cache_file(cache_dir, product_id)
        tryCatch(
          saveRDS(
            list(metadata = fetched[[product_id]]),
            cache_file,
            version = 3L
          ),
          error = function(error) NULL
        )
      }
    }
  }

  missing <- product_ids[vapply(result, is.null, logical(1))]
  for (product_id in missing) {
    if (!is.null(stale[[product_id]])) {
      result[product_id] <- list(stale[[product_id]])
    }
  }
  still_missing <- product_ids[vapply(result, is.null, logical(1))]
  if (length(errors)) {
    warning(
      "Unable to refresh some Statistics Canada table metadata; cached ",
      "metadata was used where available. ",
      paste(unique(errors), collapse = " "),
      call. = FALSE
    )
  } else if (length(still_missing)) {
    warning(
      "Statistics Canada did not return metadata for some candidates; ",
      "their geography could not be verified.",
      call. = FALSE
    )
  }
  result
}


statcan_metadata_cache_file <- function(cache_dir, product_id) {
  file.path(cache_dir, paste0("metadata_", product_id, ".rds"))
}


clean_statcan_metadata_cache <- function(cache_dir) {
  files <- list.files(
    cache_dir,
    pattern = "^metadata_[0-9]{8}\\.rds$",
    full.names = TRUE
  )
  if (!length(files)) {
    return(invisible())
  }
  age <- as.numeric(difftime(
    Sys.time(), file.info(files)$mtime, units = "days"
  ))
  outdated <- files[!is.na(age) & age > 30]
  if (length(outdated)) {
    unlink(outdated, force = TRUE)
  }
  invisible()
}


fetch_statcan_cube_metadata <- function(product_ids) {
  endpoint <- paste0(
    "https://www150.statcan.gc.ca/",
    "t1/wds/rest/getCubeMetadata"
  )
  body <- lapply(product_ids, function(product_id) {
    list(productId = as.numeric(product_id))
  })
  response <- httr::POST(
    endpoint,
    body = body,
    encode = "json",
    httr::timeout(60),
    httr::user_agent(statcan_user_agent())
  )
  httr::stop_for_status(response)
  payload <- jsonlite::fromJSON(
    httr::content(response, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )
  normalize_statcan_cube_metadata(payload)
}


normalize_statcan_cube_metadata <- function(payload) {
  if (!is.list(payload)) {
    return(list())
  }
  entries <- if (!is.null(payload$status) && !is.null(payload$object)) {
    list(payload)
  } else {
    payload
  }
  result <- list()
  for (entry in entries) {
    if (!is.list(entry) || !identical(entry$status, "SUCCESS") ||
        !is.list(entry$object)) {
      next
    }
    object <- entry$object
    product_id <- tryCatch(
      normalize_product_id(as.character(object$productId)),
      error = function(error) NA_character_
    )
    if (is.na(product_id)) {
      next
    }
    dimensions <- object$dimension
    if (is.null(dimensions)) {
      dimensions <- object$dimensions
    }
    if (is.null(dimensions)) {
      dimensions <- list()
    }
    geography_dimensions <- Filter(function(dimension) {
      if (!is.list(dimension)) {
        return(FALSE)
      }
      names <- normalize_statcan_search_text(c(
        dimension$dimensionNameEn,
        dimension$dimensionNameFr
      ))
      any(names %in% c("geography", "geographie"))
    }, dimensions)

    geographies_eng <- unlist(lapply(geography_dimensions, function(dimension) {
      members <- dimension$member
      if (is.null(members)) dimension$members else members
    }), recursive = FALSE, use.names = FALSE)
    geographies_fra <- geographies_eng
    geographies_eng <- unique(vapply(
      geographies_eng,
      function(member) metadata_member_name(member, "memberNameEn"),
      character(1)
    ))
    geographies_fra <- unique(vapply(
      geographies_fra,
      function(member) metadata_member_name(member, "memberNameFr"),
      character(1)
    ))
    geographies_eng <- geographies_eng[nzchar(geographies_eng)]
    geographies_fra <- geographies_fra[nzchar(geographies_fra)]

    archive_value <- object$archiveStatusCode
    if (is.null(archive_value)) {
      archive_value <- object$archived
    }
    archived <- if (is.null(archive_value)) {
      NA
    } else {
      normalize_archive_status(archive_value)[[1L]]
    }
    metadata <- list(
      id = product_id,
      title_eng = decode_statcan_entities(
        metadata_scalar_character(object$cubeTitleEn)
      ),
      title_fra = decode_statcan_entities(
        metadata_scalar_character(object$cubeTitleFr)
      ),
      start_date = metadata_scalar_date(object$cubeStartDate),
      end_date = metadata_scalar_date(object$cubeEndDate),
      archived = archived,
      geographies_eng = geographies_eng,
      geographies_fra = geographies_fra
    )
    if (is_valid_statcan_cube_metadata(metadata)) {
      result[product_id] <- list(metadata)
    }
  }
  result
}


metadata_member_name <- function(member, field) {
  if (!is.list(member) || is.null(member[[field]]) ||
      length(member[[field]]) != 1L || is.na(member[[field]])) {
    return("")
  }
  as.character(member[[field]])
}


metadata_scalar_character <- function(value) {
  if (is.null(value) || length(value) != 1L || is.na(value)) "" else {
    as.character(value)
  }
}


metadata_scalar_date <- function(value) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(as.Date(NA))
  }
  suppressWarnings(as.Date(substr(as.character(value), 1L, 10L)))
}


is_valid_statcan_cube_metadata <- function(metadata) {
  is.list(metadata) &&
    is.character(metadata$id) && length(metadata$id) == 1L &&
    grepl("^[0-9]{8}$", metadata$id) &&
    is.character(metadata$title_eng) && length(metadata$title_eng) == 1L &&
    is.character(metadata$title_fra) && length(metadata$title_fra) == 1L &&
    inherits(metadata$start_date, "Date") &&
    length(metadata$start_date) == 1L &&
    inherits(metadata$end_date, "Date") &&
    length(metadata$end_date) == 1L &&
    is.logical(metadata$archived) && length(metadata$archived) == 1L &&
    is.character(metadata$geographies_eng) &&
    is.character(metadata$geographies_fra)
}
