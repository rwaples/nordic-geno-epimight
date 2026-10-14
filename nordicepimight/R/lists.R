# The trait list (traits.tsv), the analysis list (analyses.tsv) and the optional
# relatives' windows (relative_windows.tsv). Each reader returns list(table, findings);
# table is NULL when the file is unusable. A blank cell or NA means "not set".

TRAIT_TYPES <- "tte"
TRAIT_RULE_COLUMNS <- c("min_followup", "max_followup", "max_followup_relatives", "trait2",
                        "exclude_trait2", "trait2_window", "trait2_window_type", "trait2_action",
                        "filter_relatives")
RULE_CHOICES <- list(exclude_trait2 = c("none", "before", "after", "any"),
                     trait2_window_type = c("within", "at_least"),
                     trait2_action = c("exclude", "competing"))
ANALYSIS_COLUMNS <- c("analysis_id", "analysis", "trait", "relatives_trait", "relationship")
NAME_PATTERN <- "^[A-Za-z0-9_.-]+$"

one_of <- function(x) paste(x, collapse = ", ")

read_tsv_text <- function(path) {
  tryCatch(
    data.table::fread(path, sep = "\t", colClasses = "character", na.strings = c("", "NA"),
                      strip.white = TRUE, showProgress = FALSE),
    error = function(e) e
  )
}

# Reads a TSV with exactly the `required` columns plus any of `optional`.
read_list <- function(path, required, optional = character(), what) {
  dt <- read_tsv_text(path)
  if (inherits(dt, "error")) {
    return(list(table = NULL, findings = finding(paste0(what, "_unreadable"),
                                                 conditionMessage(dt), path)))
  }
  findings <- collect(
    flag(!(required %in% names(dt)), paste0(what, "_missing_column"), "required column missing",
         path, required),
    flag(!(names(dt) %in% c(required, optional)), paste0(what, "_unknown_column"),
         sprintf("unknown column; the columns are %s", one_of(c(required, optional))),
         path, names(dt))
  )
  if (nrow(findings) > 0) {
    return(list(table = NULL, findings = findings))
  }
  for (col in setdiff(optional, names(dt))) data.table::set(dt, j = col, value = NA_character_)
  list(table = dt, findings = findings)
}

# A non-negative number, NA when blank; parse failures come back as NaN.
parse_number <- function(x, positive = FALSE) {
  value <- suppressWarnings(as.numeric(x))
  bad <- !is.na(x) & (is.na(value) | value < 0 | (positive & value == 0) | !is.finite(value))
  value[bad] <- NaN
  value
}

read_traits <- function(path) {
  read <- read_list(path, c("trait", "type", "file"), TRAIT_RULE_COLUMNS, "traits")
  t <- read$table
  if (is.null(t)) {
    return(read)
  }
  label <- function(col) sprintf("%s: %s", t$trait, t[[col]])
  f <- list(
    flag(is.na(t$trait) | !grepl(NAME_PATTERN, t$trait), "trait_name_invalid",
         "a trait name uses only letters, digits, '_', '.' and '-'", path, t$trait),
    flag(duplicated(t$trait) & !is.na(t$trait), "trait_duplicate", "trait listed twice", path,
         t$trait),
    flag(!(t$type %in% TRAIT_TYPES), "trait_type_unknown",
         sprintf("type must be %s", paste(TRAIT_TYPES, collapse = ", ")), path, label("type")),
    flag(is.na(t$file), "trait_file_missing", "no trait file given", path, t$trait)
  )
  # Trait files are relative to traits.tsv.
  t[, file_path := ifelse(is.na(file), NA_character_, resolve_path(dirname(path), file))]
  f <- c(f, list(flag(!is.na(t$file) & !file.exists(t$file_path), "trait_file_missing",
                      "trait file not found", path, t$file_path)))
  t[!is.na(file_path) & file.exists(file_path), file_path := normalizePath(file_path)]

  # Follow-up windows, in years (make_epimight_tte's min_followup, max_followup and
  # max_followup_relatives). The relatives' window defaults to the probands'; "none" lifts it.
  relatives_none <- tolower(t$max_followup_relatives) %in% "none"
  windows <- list(min_followup = FALSE, max_followup = TRUE, max_followup_relatives = TRUE,
                  trait2_window = FALSE)
  for (col in names(windows)) {
    raw <- t[[col]]
    if (col == "max_followup_relatives") raw[relatives_none] <- NA
    value <- parse_number(raw, positive = windows[[col]])
    f <- c(f, list(flag(is.nan(value), "trait_rule_invalid",
                        sprintf("%s must be a %s number of years%s", col,
                                if (windows[[col]]) "positive" else "non-negative",
                                if (col == "max_followup_relatives") ", or none" else ""),
                        path, label(col))))
    data.table::set(t, j = col, value = value)
  }
  t[is.na(max_followup_relatives) & !relatives_none, max_followup_relatives := max_followup]

  for (col in names(RULE_CHOICES)) {
    value <- ifelse(is.na(t[[col]]), RULE_CHOICES[[col]][1], t[[col]])
    f <- c(f, list(flag(!(value %in% RULE_CHOICES[[col]]), "trait_rule_invalid",
                        sprintf("%s must be one of %s", col, one_of(RULE_CHOICES[[col]])),
                        path, label(col))))
    data.table::set(t, j = col, value = value)
  }
  filter_rel <- toupper(t$filter_relatives)
  f <- c(f, list(flag(!is.na(filter_rel) & !(filter_rel %in% c("TRUE", "FALSE")),
                      "trait_rule_invalid", "filter_relatives must be TRUE or FALSE", path,
                      label("filter_relatives"))))
  t[, filter_relatives := filter_rel %in% "TRUE"]

  excludes <- t$exclude_trait2 != "none"
  f <- c(f, list(
    flag(excludes & is.na(t$trait2), "trait2_missing", "exclude_trait2 is set but trait2 is not",
         path, t$trait),
    flag(!is.na(t$trait2) & !(t$trait2 %in% t$trait), "trait2_unknown",
         "trait2 must name a trait in this list", path, label("trait2")),
    flag(!is.na(t$trait2) & t$trait2 == t$trait, "trait2_self", "trait2 is the trait itself",
         path, t$trait),
    flag(t$trait2_action == "competing" & t$exclude_trait2 != "before",
         "trait2_competing_needs_before",
         paste("trait2_action competing needs exclude_trait2 before",
               "(an onset after the event cannot end follow-up)"),
         path, label("exclude_trait2")),
    flag(!excludes & (!is.na(t$trait2) | !is.na(t$trait2_window)), "trait2_unused",
         "trait2 or trait2_window is set but exclude_trait2 is none, so they do nothing", path,
         t$trait, severity = "WARN")
  ))
  list(table = t, findings = collect(f))
}

read_analyses <- function(path, traits, max_degree) {
  read <- read_list(path, ANALYSIS_COLUMNS, what = "analyses")
  a <- read$table
  if (is.null(a)) {
    return(read)
  }
  known_traits <- if (is.null(traits)) character() else traits$trait
  degree <- relationship_degree(a$relationship)
  f <- list(
    flag(is.na(a$analysis_id) | !grepl(NAME_PATTERN, a$analysis_id), "analysis_id_invalid",
         "an analysis_id uses only letters, digits, '_', '.' and '-'", path, a$analysis_id),
    flag(duplicated(a$analysis_id) & !is.na(a$analysis_id), "analysis_id_duplicate",
         "analysis_id listed twice", path, a$analysis_id),
    flag(!(a$analysis %in% c("h2", "rg")), "analysis_unknown", "analysis must be h2 or rg", path,
         sprintf("%s: %s", a$analysis_id, a$analysis)),
    flag(!(a$relationship %in% RELATIONSHIPS$relationship), "relationship_unknown",
         RELATIONSHIP_CHOICE, path, sprintf("%s: %s", a$analysis_id, a$relationship)),
    flag(a$analysis == "h2" & a$trait != a$relatives_trait, "h2_relatives_trait_differs",
         "an h2 analysis needs relatives_trait equal to trait", path, a$analysis_id),
    flag(a$analysis == "rg" & a$trait == a$relatives_trait, "rg_same_trait",
         "an rg analysis needs two different traits", path, a$analysis_id),
    flag(duplicated(a[, setdiff(ANALYSIS_COLUMNS, "analysis_id"), with = FALSE]),
         "analysis_duplicate",
         "the same analysis is listed twice under different ids", path, a$analysis_id),
    flag(degree > max_degree, "max_degree_below_relationship",
         sprintf(paste("max_degree %d leaves out pairs of this relationship, so its sandwich SE",
                       "would miss their covariance; raise max_degree"), max_degree),
         path, sprintf("%s: %s", a$analysis_id, a$relationship))
  )
  if (!is.null(traits)) {
    unknown <- !(a$trait %in% known_traits) | !(a$relatives_trait %in% known_traits)
    f <- c(f, list(flag(unknown, "analysis_trait_unknown",
                        "trait and relatives_trait must name traits in traits.tsv", path,
                        sprintf("%s: %s, %s", a$analysis_id, a$trait, a$relatives_trait))))
  }
  list(table = a, findings = collect(f))
}

read_relative_windows <- function(path, traits) {
  read <- read_list(path, c("trait", "relationship", "max_followup_relatives"),
                    what = "relative_windows")
  w <- read$table
  if (is.null(w)) {
    return(read)
  }
  none <- tolower(w$max_followup_relatives) %in% "none"
  value <- parse_number(ifelse(none, NA, w$max_followup_relatives), positive = TRUE)
  label <- sprintf("%s %s: %s", w$trait, w$relationship, w$max_followup_relatives)
  f <- list(
    flag(!is.null(traits) & !(w$trait %in% traits$trait), "relative_windows_trait_unknown",
         "trait must name a trait in traits.tsv", path, label),
    flag(!(w$relationship %in% RELATIONSHIPS$relationship), "relationship_unknown",
         RELATIONSHIP_CHOICE, path, label),
    flag(is.nan(value) | (is.na(value) & !none), "trait_rule_invalid",
         "max_followup_relatives must be a positive number of years, or none", path, label),
    flag(duplicated(w[, .(trait, relationship)]), "relative_windows_duplicate",
         "trait and relationship listed twice", path, label)
  )
  w[, max_followup_relatives := value]
  list(table = w, findings = collect(f))
}
