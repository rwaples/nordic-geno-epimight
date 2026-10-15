# A run reads two files. The site file (local/<site>.yaml, one per country) says where that
# site's pedigree and trait files are and when its follow-up ends; it names the plan file
# (plan/initial.yaml), which is the same at every site: the traits, the analyses and the
# shared settings. Relative paths are resolved from the folder of the file that names
# them; the trait files from the site's data folder.

SITE_REQUIRED <- c("site", "plan", "data_folder", "pedigree_path", "study_end")
SITE_DEFAULTS <- list(threads = 1L)
PLAN_REQUIRED <- c("traits", "analyses", "stratify")
PLAN_DEFAULTS <- list(relative_windows = NULL, birth_year_bin = 1L, max_degree = 3L,
                      export_min_count = 5L)
LIMITS <- list(threads = c(1, 1024), birth_year_bin = c(1, 200), max_degree = c(1, 5),
               export_min_count = c(1, 100))

# A whole number in [lo, hi], or NA.
as_whole <- function(x, lo, hi = Inf) {
  if (length(x) != 1 || !is.numeric(x) || is.na(x) || x != round(x) || x < lo || x > hi) {
    return(NA_integer_)
  }
  as.integer(x)
}

# `value` as given when absolute, else relative to `root`.
resolve_path <- function(root, value) {
  absolute <- !is.na(value) & grepl("^(/|~|[A-Za-z]:[/\\\\])", value)
  ifelse(absolute, path.expand(value), file.path(root, value))
}

# A date written YYYY-MM-DD, or NA.
as_date <- function(x) {
  x <- as.character(x)
  ok <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)
  out <- rep(data.table::as.IDate(NA), length(x))
  out[ok] <- data.table::as.IDate(x[ok], format = "%Y-%m-%d")
  out
}

# Reads one YAML config with `required` keys and `defaults`. Returns list(values, findings);
# values is NULL when the file cannot be read.
read_config <- function(path, required, defaults) {
  raw <- tryCatch(yaml::read_yaml(path), error = function(e) e)
  if (inherits(raw, "error") || !is.list(raw) || is.null(names(raw))) {
    msg <- if (inherits(raw, "error")) conditionMessage(raw) else "not a YAML mapping"
    return(list(values = NULL, findings = finding("config_unreadable", msg, path)))
  }
  known <- c(required, names(defaults))
  findings <- collect(
    flag(!(names(raw) %in% known), "config_unknown_key",
         sprintf("unknown key; the keys are %s", paste(known, collapse = ", ")), path, names(raw)),
    flag(!(required %in% names(raw)), "config_missing_key", "required key missing", path,
         required)
  )
  list(values = utils::modifyList(defaults, raw[intersect(names(raw), known)]),
       findings = findings, raw = raw)
}

# `values[[key]]` as an existing path resolved from `root`, or NULL with a finding.
config_path <- function(values, key, root, source, folder = FALSE) {
  value <- values[[key]]
  if (is.null(value)) {
    return(list(path = NULL, findings = NULL))
  }
  if (!is.character(value) || length(value) != 1) {
    return(list(path = NULL, findings = finding("config_value_invalid",
                                                paste(key, "must be one path"), source, key)))
  }
  path <- resolve_path(root, value)
  exists <- if (folder) dir.exists(path) else file.exists(path) && !dir.exists(path)
  if (!exists) {
    what <- if (folder) "folder" else "file"
    missing <- finding("file_missing", sprintf("%s %s not found", key, what), source, path)
    return(list(path = NULL, findings = missing))
  }
  list(path = normalizePath(path), findings = NULL)
}

# Each of `keys` in `values` as an existing path resolved from `root`: list(paths, findings).
config_paths <- function(values, keys, root, source, folder = FALSE) {
  found <- lapply(stats::setNames(nm = keys), config_path, values = values, root = root,
                  source = source, folder = folder)
  list(paths = lapply(found, `[[`, "path"), findings = lapply(found, `[[`, "findings"))
}

stratify_finding <- function(stratify, source) {
  s <- stratify
  ok <- is.character(s) && length(s) > 0 && !anyNA(s) && all(s != "") && !anyDuplicated(s)
  if (!ok) {
    finding("stratify_invalid",
            "stratify must list one or more distinct pedigree columns (or birth_year)", source,
            format(s))
  }
}

# Reads the site file and the plan it names. Returns list(study, findings); study is NULL when
# the site file cannot be read.
read_study <- function(path) {
  site <- read_config(path, SITE_REQUIRED, SITE_DEFAULTS)
  if (is.null(site$values)) {
    return(list(study = NULL, findings = site$findings))
  }
  study <- site$values
  study$path <- normalizePath(path)
  folders <- config_paths(site$values, "data_folder", dirname(study$path), path, folder = TRUE)
  files <- config_paths(site$values, c("plan", "pedigree_path"), dirname(study$path), path)
  findings <- list(site$findings, folders$findings, files$findings)
  study$data_folder <- folders$paths$data_folder
  study$pedigree_path <- files$paths$pedigree_path
  study$plan_path <- files$paths$plan
  study$plan <- NULL
  if (!is.null(study$plan_path)) {
    plan <- read_config(study$plan_path, PLAN_REQUIRED, PLAN_DEFAULTS)
    findings <- c(findings, list(plan$findings))
    if (!is.null(plan$values)) {
      tables <- config_paths(plan$values, c("traits", "analyses", "relative_windows"),
                             dirname(study$plan_path), study$plan_path)
      findings <- c(findings, tables$findings)
      plan$values[names(tables$paths)] <- tables$paths
      study <- utils::modifyList(study, plan$values, keep.null = TRUE)
      bad <- if ("stratify" %in% names(plan$raw)) {
        stratify_finding(plan$raw$stratify, study$plan_path)
      }
      if (!is.null(bad)) study$stratify <- NULL
      findings <- c(findings, list(bad))
    }
  }
  if ("study_end" %in% names(site$raw)) {
    study$study_end <- as_date(site$raw$study_end)
    if (length(site$raw$study_end) != 1 || is.na(study$study_end)) {
      bad <- finding("study_end_invalid", "study_end must be one date, YYYY-MM-DD", path,
                     format(site$raw$study_end))
      findings <- c(findings, list(bad))
      study$study_end <- NULL
    }
  }
  if (!is.character(study$site) || length(study$site) != 1 || !nzchar(study$site)) {
    findings <- c(findings, list(finding("config_value_invalid", "site must be a name", path,
                                         format(study$site))))
  }
  defaults <- c(SITE_DEFAULTS, PLAN_DEFAULTS)
  for (key in names(LIMITS)) {
    lo <- LIMITS[[key]][1]
    hi <- LIMITS[[key]][2]
    value <- as_whole(study[[key]] %||% defaults[[key]], lo, hi)
    if (is.na(value)) {
      source <- if (key %in% names(SITE_DEFAULTS)) path else study$plan_path
      bad <- finding("config_value_invalid",
                     sprintf("%s must be a whole number from %s to %s", key, lo, hi), source,
                     sprintf("%s: %s", key, format(study[[key]])))
      findings <- c(findings, list(bad))
      value <- defaults[[key]]
    }
    study[[key]] <- value
  }
  list(study = study, findings = collect(findings))
}
