# The pedigree file: one row per person with id, mother, father, sex and birth_date, plus
# any columns the study stratifies on. pedsum owns the pedigree (ADR 0005): it reads the
# site's file, checks it and must find nothing, and the kit reads the copy pedsum writes.
# The kit never parses the site's file itself and adds no pedigree checks of its own.

# Without the site's own multiple-birth column, full sibs born at most this many days apart
# form a multiple-birth set; 1 also catches twins born either side of midnight.
TWIN_MAX_DAYS <- 1L

# A mother or father with more children than this is a pedsum finding: almost always a code
# for an unknown parent, such as 9999, rather than a person (pedsum's suggested limits for a
# human register).
MAX_CHILDREN <- c(mother = 20L, father = 50L)

# Where the multiple-birth sets come from: the pedsum options that find them and the
# description run.yaml records.
multiple_birth_source <- function(column) {
  if (is.null(column)) {
    list(args = c("--twin-max-days", TWIN_MAX_DAYS),
         description = sprintf("full sibs born at most %d day apart (pedsum --twin-max-days)",
                               TWIN_MAX_DAYS))
  } else {
    list(args = c("--multiple-birth-col", shQuote(column)),
         description = sprintf("the pedigree's %s column (pedsum --multiple-birth-col)", column))
  }
}

# Runs pedsum validate on the site's pedigree file and reads back the pedigree it wrote
# (validate.tsv.gz, every column as text). Returns list(pedigree, findings):
# no findings when pedsum finds nothing, else one STOP, because any repair belongs in the
# site's own pedsum run (step 0). The pedigree is NULL when pedsum wrote none. pedsum finds
# the multiple-birth sets from birth dates, or reads them from `multiple_birth_column`, the
# register's own set id; either way pedsum writes them, numbered, as multiple_birth_set.
validate_pedigree <- function(path, dir, threads, multiple_birth_column = NULL) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  log <- file.path(dir, "pedsum.log")
  status <- system2(Sys.which("python"),
                    c("-I", "-m", "pedsum", "validate", "--in", shQuote(path),
                      "--out", shQuote(dir),
                      "--birth-year-col", "birth_year", "--birth-date-col", "birth_date",
                      "--max-children-mother", MAX_CHILDREN[["mother"]],
                      "--max-children-father", MAX_CHILDREN[["father"]],
                      multiple_birth_source(multiple_birth_column)$args, "--threads", threads),
                    stdout = log, stderr = log)
  written <- file.path(dir, "validate.tsv.gz")
  pedigree <- if (file.exists(written)) {
    data.table::fread(cmd = paste("gzip -dc", shQuote(written)), sep = "\t",
                      colClasses = "character", na.strings = "", showProgress = FALSE)
  }
  list(pedigree = pedigree, findings = read_pedsum_findings(dir, status, path))
}

# pedsum exits 0 when it finds nothing and 1 when it only reports findings; any other exit
# (2 blocked, 3 out of memory, ...) is a failure and is reported with the end of its log.
read_pedsum_findings <- function(dir, status, source) {
  log_path <- file.path(dir, "validate.log")
  found <- if (file.exists(log_path)) {
    data.table::fread(log_path, sep = "\t", colClasses = "character", na.strings = "")
  }
  found_any <- !is.null(found) && nrow(found) > 0
  if (status == 0 && !is.null(found) && !found_any) {
    return(no_findings())
  }
  message <- character()
  examples <- character()
  if (!(status == 1 && found_any)) {
    lines <- tryCatch(readLines(file.path(dir, "pedsum.log")), error = function(e) character())
    message <- sprintf("pedsum validate failed (exit %d); the end of 1_check/pedsum/pedsum.log",
                       status)
    examples <- utils::tail(lines, 5)
  }
  if (found_any) {
    per_check <- found[, .N, by = check]
    message <- c(message, sprintf(
      paste("pedsum validate found: %s; repair the pedigree with pedsum before the run",
            "(step 0); details in 1_check/pedsum/validate.log"),
      paste(sprintf("%s (%d)", per_check$check, per_check$N), collapse = ", ")
    ))
    examples <- c(examples, sprintf("%s %s: %s", found$check, found$id, found$detail))
  }
  finding("pedigree_invalid", paste(message, collapse = "; "), source, examples,
          if (found_any) nrow(found) else 1L)
}

# The kit's columns on pedsum's pedigree: an unknown parent as NA, birth_date as a date,
# birth_year from it (binned when the study stratifies on it), and multiple_birth_set (NA
# outside a set). pedsum keeps each row's own missing-parent token (-1, ., NA, ...); once
# it finds nothing, every other parent has a row, so a parent without one is unknown.
prepare_pedigree <- function(dt, stratify, birth_year_bin, path) {
  stratify_extra <- setdiff(stratify, "birth_year")
  missing <- flag(!(stratify_extra %in% names(dt)), "stratify_not_in_pedigree",
                  "a stratify column is not in the pedigree file", path, stratify_extra)
  for (col in c("mother", "father")) dt[!(get(col) %chin% id), (col) := NA_character_]
  dt[, birth_date := as_date(birth_date)]
  dt[, birth_year := data.table::year(birth_date)]
  if ("birth_year" %in% stratify) {
    dt[, birth_year := as.integer(birth_year %/% birth_year_bin * birth_year_bin)]
  }
  list(pedigree = dt, findings = collect(missing))
}
