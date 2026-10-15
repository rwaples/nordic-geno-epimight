# The pedigree file: one row per person with id, mother, father, sex and birth_date, plus
# any columns the study stratifies on. Ids are text. An unknown parent is NA, blank or -1.
# The site repairs the pedigree with pedsum (Python) before the run; the kit uses the file
# as it is and only checks it, with pedsum validate, which must find nothing.

PEDIGREE_COLUMNS <- c("id", "mother", "father", "sex", "birth_date")

read_pedigree <- function(path, stratify, birth_year_bin) {
  dt <- read_tsv_text(path)
  if (inherits(dt, "error")) {
    return(list(pedigree = NULL, findings = finding("pedigree_unreadable", conditionMessage(dt),
                                                    path)))
  }
  missing <- flag(!(PEDIGREE_COLUMNS %in% names(dt)), "pedigree_missing_column",
                  "required column missing", path, PEDIGREE_COLUMNS)
  if (!is.null(missing)) {
    return(list(pedigree = NULL, findings = collect(missing)))
  }
  for (col in c("mother", "father")) dt[get(col) %in% "-1", (col) := NA_character_]
  birth <- as_date(dt$birth_date)
  stratify_extra <- setdiff(stratify, "birth_year")
  own_year <- if ("birth_year" %in% names(dt)) suppressWarnings(as.integer(dt$birth_year))
  year <- data.table::year(birth)
  year_differs <- !is.null(own_year) &&
    any(xor(is.na(own_year), is.na(year)) | own_year != year, na.rm = TRUE)
  f <- list(
    flag(!is.na(dt$birth_date) & is.na(birth), "birth_date_invalid",
         "birth_date must be a date, YYYY-MM-DD", path, sprintf("%s: %s", dt$id, dt$birth_date)),
    flag(!(stratify_extra %in% names(dt)), "stratify_not_in_pedigree",
         "a stratify column is not in the pedigree file", path, stratify_extra),
    flag(year_differs & "birth_year" %in% stratify, "pedigree_birth_year_replaced",
         "the pedigree's own birth_year column differs from the year of birth_date and is replaced",
         path, "birth_year", severity = "WARN")
  )
  dt[, birth_date := birth]
  dt[, birth_year := year]
  if ("birth_year" %in% stratify) {
    dt[, birth_year := as.integer(birth_year %/% birth_year_bin * birth_year_bin)]
  }
  list(pedigree = dt, findings = collect(f))
}

# Runs pedsum validate on the pedigree in `dir`. Returns the findings: none when pedsum
# finds nothing, else one STOP, because any repair belongs in the site's own pedsum run.
validate_pedigree <- function(pedigree, dir, threads, source) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  input <- file.path(dir, "pedsum_input.tsv")
  data.table::fwrite(pedigree[, .(id, mother, father, sex,
                                  birth_year = data.table::year(birth_date))],
                     input, sep = "\t", na = "")
  log <- file.path(dir, "pedsum.log")
  status <- system2(Sys.which("python"),
                    c("-I", "-m", "pedsum", "validate", "--in", input, "--out", dir,
                      "--birth-year-col", "birth_year", "--threads", threads),
                    stdout = log, stderr = log)
  read_pedsum_findings(dir, status, source)
}

read_pedsum_findings <- function(dir, status, source) {
  log_path <- file.path(dir, "validate.log")
  found <- if (file.exists(log_path)) {
    data.table::fread(log_path, sep = "\t", colClasses = "character", na.strings = "")
  }
  if (!is.null(found) && nrow(found) > 0) {
    per_check <- found[, .N, by = check]
    return(finding("pedigree_invalid",
                   sprintf(paste("pedsum validate found: %s; repair the pedigree with pedsum",
                                 "before the run (step 0); details in",
                                 "1_check/pedsum/validate.log"),
                           paste(sprintf("%s (%d)", per_check$check, per_check$N),
                                 collapse = ", ")),
                   source, sprintf("%s %s: %s", found$check, found$id, found$detail),
                   nrow(found)))
  }
  if (status != 0 || is.null(found)) {
    lines <- tryCatch(readLines(file.path(dir, "pedsum.log")), error = function(e) character())
    return(finding("pedigree_invalid", sprintf("pedsum validate failed (exit %d)", status),
                   source, utils::tail(lines, 5)))
  }
  no_findings()
}
