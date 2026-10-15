# Trait files: one row per person in the study population, with id, trait, status
# (0 censored, 1 the trait, 2 a competing event), age (years, the source of truth) and
# date (YYYY-MM-DD). Every trait file covers the same people (D9). A file may serve several
# traits, so each is read and checked once.

TRAIT_FILE_COLUMNS <- c("id", "trait", "status", "age", "date")
DAY <- 1 / 365.25

read_trait_file <- function(path, pedigree, study_end) {
  dt <- read_tsv_text(path)
  if (inherits(dt, "error")) {
    unreadable <- finding("trait_file_unreadable", conditionMessage(dt), path)
    return(list(data = NULL, findings = unreadable))
  }
  missing <- flag(!(TRAIT_FILE_COLUMNS %in% names(dt)), "trait_file_missing_column",
                  "required column missing", path, TRAIT_FILE_COLUMNS)
  if (!is.null(missing)) {
    return(list(data = NULL, findings = collect(missing)))
  }
  status <- suppressWarnings(as.integer(dt$status))
  age <- suppressWarnings(as.numeric(dt$age))
  date <- as_date(dt$date)
  values <- unique(stats::na.omit(dt$trait))
  f <- list(
    flag(is.na(dt$id), "trait_id_missing", "a row has no id", path, which(is.na(dt$id))),
    flag(duplicated(dt$id) & !is.na(dt$id), "trait_duplicate_id", "id has more than one row",
         path, dt$id),
    flag(length(values) != 1, "trait_file_trait_values",
         "the trait column must hold one value", path, values),
    flag(!(dt$status %in% c("0", "1", "2")), "status_invalid", "status must be 0, 1 or 2", path,
         sprintf("%s: %s", dt$id, dt$status)),
    flag(is.na(age) | age < 0 | !is.finite(age), "age_invalid",
         "age must be a number of years, 0 or more", path, sprintf("%s: %s", dt$id, dt$age)),
    flag(is.na(date), "date_invalid", "date must be a date, YYYY-MM-DD", path,
         sprintf("%s: %s", dt$id, dt$date))
  )
  if (!is.null(pedigree)) {
    birth <- pedigree$birth_date[match(dt$id, pedigree$id)]
    in_ped <- dt$id %in% pedigree$id
    years <- as.numeric(date - birth) / 365.25
    f <- c(f, list(
      flag(!in_ped & !is.na(dt$id), "trait_id_not_in_pedigree", "id has no pedigree row", path,
           dt$id),
      flag(date < birth, "date_before_birth", "date is before birth_date", path,
           sprintf("%s: %s, born %s", dt$id, date, birth)),
      flag(!is.null(study_end) & date > study_end, "date_after_study_end",
           "date is after study_end", path, sprintf("%s: %s", dt$id, date)),
      flag(abs(age - years) > DAY, "age_date_mismatch",
           "age differs from (date - birth_date) / 365.25 by more than a day", path,
           sprintf("%s: age %s, date %s, born %s", dt$id, dt$age, date, birth))
    ))
  }
  data <- data.table::data.table(id = dt$id, status = status, age = age, date = date)
  list(data = data, findings = collect(f))
}

# Checks every trait file and the study population they share. `files` are the distinct
# trait file paths. Returns list(data (named by path), population (ids), findings).
read_trait_files <- function(files, pedigree, study_end, stratify, pedigree_path) {
  read <- lapply(stats::setNames(nm = files), read_trait_file, pedigree = pedigree,
                 study_end = study_end)
  data <- lapply(read, `[[`, "data")
  findings <- collect(lapply(read, `[[`, "findings"))
  usable <- Filter(Negate(is.null), data)
  if (length(usable) == 0) {
    return(list(data = data, population = NULL, findings = findings))
  }
  ids <- lapply(usable, function(d) unique(stats::na.omit(d$id)))
  everyone <- Reduce(union, ids)
  short <- vapply(ids, function(i) length(setdiff(everyone, i)), integer(1))
  differs <- short > 0
  if (any(differs)) {
    first_missing <- vapply(ids[differs], function(i) setdiff(everyone, i)[1], "")
    differ <- finding("trait_population_differs",
                      paste("every trait file must hold the same people; give someone excluded",
                            "from a trait a censored row (status 0)"),
                      examples = sprintf("%s lacks %d of %d ids, e.g. %s",
                                         basename(names(ids))[differs], short[differs],
                                         length(everyone), first_missing),
                      count = sum(differs))
    findings <- collect(findings, differ)
  }
  population <- everyone
  if (!is.null(pedigree)) {
    people <- pedigree[id %in% population]
    no_birth <- flag(is.na(people$birth_date), "birth_date_missing",
                     "birth_date is missing for someone in the study population", pedigree_path,
                     people$id)
    findings <- collect(findings, no_birth)
    # A missing birth_year is a missing birth_date, already reported.
    for (col in setdiff(intersect(stratify, names(people)), "birth_year")) {
      na <- flag(is.na(people[[col]]), "stratum_na",
                 sprintf("%s is missing for someone in the study population", col),
                 pedigree_path, people$id)
      findings <- collect(findings, na)
    }
    findings <- collect(findings, few_cases(usable, people, stratify))
  }
  list(data = data, population = population, findings = findings)
}

# WARN when a trait file has fewer than 10 cases (status 1) in some stratum.
few_cases <- function(data, people, stratify, min_cases = 10L) {
  stratify <- intersect(stratify, names(people))
  if (length(stratify) == 0) {
    return(NULL)
  }
  strata <- unique(people[, ..stratify])
  out <- lapply(names(data), function(path) {
    cases <- data[[path]][status == 1]
    d <- people[, c("id", stratify), with = FALSE][cases, on = "id", nomatch = NULL]
    counts <- d[, .(cases = .N), by = stratify][strata, on = stratify]
    counts[is.na(cases), cases := 0L]
    low <- counts[cases < min_cases]
    if (nrow(low) == 0) {
      return(NULL)
    }
    label <- do.call(paste, c(low[, ..stratify], sep = "/"))
    finding("few_cases",
            sprintf("fewer than %d cases in a stratum; estimates there may be unstable or missing",
                    min_cases),
            path, sprintf("%s: %d", label, low$cases), severity = "WARN")
  })
  collect(out)
}
