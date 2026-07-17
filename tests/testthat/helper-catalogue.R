sample_catalogue <- function() {
  data.frame(
    title_eng = c(
      "Bank assets",
      "Consumer prices",
      "International exports",
      "Gross domestic expenditures on research and development",
      "Research and development personnel"
    ),
    title_fra = c(
      "Actifs bancaires",
      "Prix à la consommation",
      "Exportations internationales",
      "Dépenses intérieures brutes en recherche et développement",
      "Personnel affecté à la recherche et au développement"
    ),
    id = c(
      "10-10-0004-01", "18-10-0004-01", "36-10-0434-01",
      "27-10-0273-01", "27-10-0015-01"
    ),
    start_date = as.Date(c(
      "1978-01-01", "2000-01-01", "1990-01-01", "1963-01-01",
      "2015-01-01"
    )),
    end_date = as.Date(c(
      "2026-01-01", "2026-01-01", "2026-01-01", "2025-01-01",
      "2025-01-01"
    )),
    release_date = as.Date(c(
      "2026-07-16", "2026-07-15", "2026-07-14", "2025-11-27",
      "2025-08-27"
    )),
    archived = rep(FALSE, 5L),
    frequency_code = as.integer(c(12, 6, 12, 12, 12)),
    stringsAsFactors = FALSE
  )
}
