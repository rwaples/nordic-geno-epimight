# The pedigree file: one row per person with id, mother, father, sex and birth_date, plus
# any columns the study stratifies on. Ids are text. An unknown parent is NA, blank or -1,
# never 0 (0 is a parent only when it is someone's id). pedsum (Python) checks the
# structure and writes the validated pedigree, with parents that have no row of their own
# added as founders.

PEDIGREE_COLUMNS <- c("id", "mother", "father", "sex", "birth_date")
# pedsum's fixes that leave the pedigree as the file meant it; any other finding stops.
PEDSUM_HARMLESS <- c("duplicate_rows", "sex_role_override")
PEDSUM_PARENT_REFS <- c("parent_refs_present_mother", "parent_refs_present_father")

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
  f <- list(
    flag((dt$mother %in% "0" | dt$father %in% "0") & !("0" %in% dt$id), "parent_zero",
         "a parent is 0 and 0 has no row; write an unknown parent as NA, blank or -1", path, dt$id),
    flag(is.na(dt$birth_date), "birth_date_missing", "birth_date is missing", path, dt$id),
    flag(!is.na(dt$birth_date) & is.na(birth), "birth_date_invalid",
         "birth_date must be a date, YYYY-MM-DD", path, sprintf("%s: %s", dt$id, dt$birth_date)),
    flag(!(stratify_extra %in% names(dt)), "stratify_not_in_pedigree",
         "a stratify column is not in the pedigree file", path, stratify_extra),
    flag("birth_year" %in% names(dt) & "birth_year" %in% stratify, "pedigree_birth_year_replaced",
         "the pedigree's own birth_year column is replaced by the year of birth_date", path,
         "birth_year", severity = "WARN")
  )
  dt[, birth_date := birth]
  dt[, birth_year := data.table::year(birth_date)]
  if ("birth_year" %in% stratify) {
    dt[, birth_year := as.integer(birth_year %/% birth_year_bin * birth_year_bin)]
  }
  list(pedigree = dt, findings = collect(f))
}

# Runs pedsum validate on the pedigree in `dir`. Returns list(validated, findings):
# pedsum's validated pedigree (id, mother, father as text, external parents added as
# founders), or NULL when the pedigree stops the run.
validate_pedigree <- function(pedigree, dir, threads, external_parent_cap, source) {
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
  read_pedsum_findings(dir, status, external_parent_cap, source)
}

read_pedsum_findings <- function(dir, status, external_parent_cap, source) {
  log_tail <- function() {
    lines <- tryCatch(readLines(file.path(dir, "pedsum.log")), error = function(e) character())
    utils::tail(lines, 5)
  }
  log_path <- file.path(dir, "validate.log")
  if (!file.exists(log_path)) {
    stopped <- finding("pedigree_invalid",
                       sprintf("pedsum validate stopped before checking (exit %d)", status),
                       source, log_tail())
    return(list(validated = NULL, findings = stopped))
  }
  log <- data.table::fread(log_path, sep = "\t", colClasses = "character", na.strings = "")
  refs <- log[check %in% PEDSUM_PARENT_REFS & !(id %in% "0"),
              .(refs = sum(as.integer(n_refs))), by = id][order(-refs, id)]
  harmless <- log[check %in% PEDSUM_HARMLESS]
  other <- log[!(check %in% c(PEDSUM_PARENT_REFS, PEDSUM_HARMLESS))]
  per_check <- other[, .N, by = check]
  f <- list(
    if (nrow(other) > 0) {
      finding("pedigree_invalid",
              sprintf("pedsum validate found: %s; details in 1_check/pedsum/validate.log",
                      paste(sprintf("%s (%d)", per_check$check, per_check$N), collapse = ", ")),
              source, sprintf("%s %s: %s", other$check, other$id, other$detail), nrow(other))
    },
    flag(refs$refs > external_parent_cap, "external_parent_over_cap",
         sprintf(paste("a parent id with no row of its own has more than %d children",
                       "(external_parent_cap), so it is probably a code for an unknown parent.",
                       "Write unknown parents as NA, blank or -1"), external_parent_cap),
         source, sprintf("%s: %d children", refs$id, refs$refs)),
    if (nrow(refs) > 0) {
      finding("external_parents",
              sprintf(paste("%d parent id(s) have no row of their own and were added as",
                            "founders; the one with most children has %d"),
                      nrow(refs), max(refs$refs)),
              source, sprintf("%s: %d children", refs$id, refs$refs), nrow(refs), "WARN")
    },
    if (nrow(harmless) > 0) {
      finding("pedigree_autofixed",
              "pedsum fixed the pedigree as the file implies; see validate.log", source,
              sprintf("%s %s: %s", harmless$check, harmless$id, harmless$detail),
              nrow(harmless), "WARN")
    }
  )
  findings <- collect(f)
  validated <- file.path(dir, "validate.tsv.gz")
  if (!has_stop(findings) && (!(status %in% c(0, 1)) || !file.exists(validated))) {
    failed <- finding("pedigree_invalid", sprintf("pedsum validate failed (exit %d)", status),
                      source, log_tail())
    findings <- collect(findings, failed)
  }
  list(validated = if (has_stop(findings)) NULL else read_validated(validated), findings = findings)
}

read_validated <- function(path) {
  d <- utils::read.delim(gzfile(path), colClasses = "character", na.strings = "")
  as.data.table(d)[, .(id, mother, father)]
}
