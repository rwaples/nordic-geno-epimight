# study.yaml: where the inputs are and the study-wide settings. Paths are relative to the
# folder holding study.yaml.

STUDY_REQUIRED <- c("pedigree", "traits", "analyses", "study_end", "stratify")
STUDY_DEFAULTS <- list(relative_windows = NULL, birth_year_bin = 1L, threads = 1L,
                       max_degree = 3L, external_parent_cap = 30L)
STUDY_FILES <- c("pedigree", "traits", "analyses", "relative_windows")

# A whole number in [lo, hi], or NA.
as_whole <- function(x, lo, hi = Inf) {
  if (length(x) != 1 || !is.numeric(x) || is.na(x) || x != round(x) || x < lo || x > hi) {
    return(NA_integer_)
  }
  as.integer(x)
}

# A date written YYYY-MM-DD, or NA.
as_date <- function(x) {
  x <- as.character(x)
  ok <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)
  out <- rep(data.table::as.IDate(NA), length(x))
  out[ok] <- data.table::as.IDate(x[ok], format = "%Y-%m-%d")
  out
}

# Reads study.yaml. Returns list(study, findings); study is NULL when the file is unusable.
read_study <- function(path) {
  raw <- tryCatch(yaml::read_yaml(path), error = function(e) e)
  if (inherits(raw, "error") || !is.list(raw) || is.null(names(raw))) {
    msg <- if (inherits(raw, "error")) conditionMessage(raw) else "not a YAML mapping"
    return(list(study = NULL, findings = finding("study_unreadable", msg, path)))
  }
  known <- c(STUDY_REQUIRED, names(STUDY_DEFAULTS))
  findings <- list(
    flag(!(names(raw) %in% known), "study_unknown_key",
         sprintf("unknown key; the keys are %s", paste(known, collapse = ", ")), path, names(raw)),
    flag(!(STUDY_REQUIRED %in% names(raw)), "study_missing_key", "required key missing", path,
         STUDY_REQUIRED)
  )
  study <- utils::modifyList(STUDY_DEFAULTS, raw[intersect(names(raw), known)])
  study$path <- normalizePath(path)
  root <- dirname(study$path)

  for (key in intersect(STUDY_FILES, names(raw))) {
    value <- raw[[key]]
    if (!is.character(value) || length(value) != 1) {
      findings <- c(findings, list(finding("study_value_invalid", paste(key, "must be one path"),
                                           path, key)))
      study[key] <- list(NULL)
      next
    }
    file <- file.path(root, value)
    if (!file.exists(file)) {
      findings <- c(findings, list(finding("file_missing", sprintf("%s file not found", key),
                                           path, file)))
      study[key] <- list(NULL)
    } else {
      study[[key]] <- normalizePath(file)
    }
  }

  if ("study_end" %in% names(raw)) {
    study$study_end <- as_date(raw$study_end)
    if (length(raw$study_end) != 1 || is.na(study$study_end)) {
      bad <- finding("study_end_invalid", "study_end must be one date, YYYY-MM-DD", path,
                     format(raw$study_end))
      findings <- c(findings, list(bad))
      study$study_end <- NULL
    }
  }
  if ("stratify" %in% names(raw)) {
    s <- raw$stratify
    if (!is.character(s) || length(s) == 0 || anyNA(s) || any(s == "") || anyDuplicated(s)) {
      bad <- finding("stratify_invalid",
                     "stratify must list one or more distinct pedigree columns (or birth_year)",
                     path, format(s))
      findings <- c(findings, list(bad))
      study$stratify <- NULL
    }
  }
  limits <- list(birth_year_bin = c(1, 200), threads = c(1, 1024), max_degree = c(1, 5),
                 external_parent_cap = c(1, Inf))
  for (key in names(limits)) {
    value <- as_whole(study[[key]], limits[[key]][1], limits[[key]][2])
    if (is.na(value)) {
      bad <- finding("study_value_invalid",
                     sprintf("%s must be a whole number from %s to %s", key, limits[[key]][1],
                             limits[[key]][2]),
                     path, sprintf("%s: %s", key, format(study[[key]])))
      findings <- c(findings, list(bad))
    }
    study[[key]] <- value
  }
  list(study = study, findings = collect(findings))
}
