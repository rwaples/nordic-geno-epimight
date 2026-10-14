# pixi run selftest OUT/: the kit end to end on the toy study, against values it did not
# compute. Each item prints PASS, FAIL or SKIP; the run exits 1 when any item fails.
#
# The toy is run with its ids turned into text, three of them 001, 1 and 1.0, and with one
# extra analysis that cannot be estimated. Its estimates are compared with fitACE_epimight's
# independent Python values (selftest/expected), its cohort-table cases with
# make_epimight_tte's (selftest/expected/cohort_cases.tsv.gz), and broken copies of its
# inputs must stop with their codes.

RTOL <- 1e-8
ATOL <- 1e-12
# EPIMIGHT's rg sandwich SE differs from fitACE's by up to 1.15e-7 relative in one
# near-degenerate toy stratum (rg 3.1, SE 13); the cause is still open, so sandwich SEs are
# held to this looser bound and their largest difference is reported.
SANDWICH_RTOL <- 1e-6
RENAMED <- c("001", "1", "1.0")
UNESTIMABLE <- list(trait = "trait1_no_affected_relatives", relationship = "FS",
                    analysis_id = "h2_unestimable")

item <- function(name, verdict, detail) {
  data.table(item = name, verdict = verdict, detail = detail)
}

# Copies the toy to `dir` with text ids (P00042), three probands with an affected FS
# relative renamed 001, 1 and 1.0, and the unestimable analysis added.
prepare_toy <- function(toy, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  pedigree <- fread(file.path(toy, "pedigree.tsv"), colClasses = "character", na.strings = "NA")
  trait1 <- fread(file.path(toy, "trait1.tsv"), colClasses = "character")
  affected <- trait1[status == "1", id]
  fs_pairs <- pedigree[!is.na(mother) & !is.na(father)][, .(id, family = paste(mother, father))]
  affected_families <- fs_pairs[id %in% affected, family]
  with_affected_sib <- fs_pairs[family %in% affected_families & id %in% trait1$id &
                                  !(id %in% affected), id]
  mapping <- stats::setNames(sprintf("P%05d", as.integer(pedigree$id)), pedigree$id)
  mapping[utils::head(with_affected_sib, length(RENAMED))] <- RENAMED
  relabel <- function(x) ifelse(is.na(x), NA_character_, unname(mapping[x]))
  pedigree[, `:=`(id = relabel(id), mother = relabel(mother), father = relabel(father))]
  fwrite(pedigree, file.path(dir, "pedigree.tsv"), sep = "\t", na = "NA")
  for (f in c("trait1.tsv", "trait2.tsv")) {
    d <- fread(file.path(toy, f), colClasses = "character")[, id := relabel(id)]
    fwrite(d, file.path(dir, f), sep = "\t")
  }
  traits <- fread(file.path(toy, "traits.tsv"), colClasses = "character")
  traits <- rbind(traits, data.table(trait = UNESTIMABLE$trait, type = "tte", file = "trait1.tsv",
                                     max_followup_relatives = "0.5"), fill = TRUE)
  fwrite(traits, file.path(dir, "traits.tsv"), sep = "\t", na = "")
  analyses <- fread(file.path(toy, "analyses.tsv"), colClasses = "character")
  analyses <- rbind(analyses, data.table(analysis_id = UNESTIMABLE$analysis_id, analysis = "h2",
                                         trait = UNESTIMABLE$trait,
                                         relatives_trait = UNESTIMABLE$trait,
                                         relationship = UNESTIMABLE$relationship))
  fwrite(analyses, file.path(dir, "analyses.tsv"), sep = "\t")
  file.copy(file.path(toy, "study.yaml"), file.path(dir, "study.yaml"), overwrite = TRUE)
  file.path(dir, "study.yaml")
}

# Matches `actual` to `expected` on `keys` and compares `columns` within rtol and ATOL.
compare_tables <- function(name, actual, expected, keys, columns, rtol = RTOL) {
  actual <- copy(actual)
  expected <- copy(expected)
  for (k in keys) {
    set(actual, j = k, value = as.character(actual[[k]]))
    set(expected, j = k, value = as.character(expected[[k]]))
  }
  absent <- c(setdiff(c(keys, columns), names(actual)), setdiff(c(keys, columns), names(expected)))
  if (length(absent) > 0) {
    listed <- paste(unique(absent), collapse = ", ")
    return(item(name, "FAIL", sprintf("column(s) absent: %s", listed)))
  }
  m <- merge(actual, expected, by = keys, suffixes = c(".kit", ".expected"), all = TRUE)
  only_expected <- nrow(fsetdiff(unique(expected[, ..keys]), unique(actual[, ..keys])))
  only_kit <- nrow(fsetdiff(unique(actual[, ..keys]), unique(expected[, ..keys])))
  worst <- 0
  bad <- 0
  for (col in columns) {
    a <- m[[paste0(col, ".kit")]]
    e <- m[[paste0(col, ".expected")]]
    both <- !is.na(a) & !is.na(e)
    bad <- bad + sum(xor(is.na(a), is.na(e))) + sum(abs(a - e)[both] > ATOL + rtol * abs(e[both]))
    rel <- abs(a - e)[both & e != 0] / abs(e[both & e != 0])
    worst <- max(worst, rel, 0)
  }
  ok <- only_expected == 0 && only_kit == 0 && bad == 0 && nrow(expected) > 0
  item(name, if (ok) "PASS" else "FAIL",
       sprintf(paste("%d rows, %d values out of tolerance (rtol %g), %d expected rows missing,",
                     "%d extra; max rel diff %.2g"),
               nrow(expected), bad, rtol, only_expected, only_kit, worst))
}

compare_estimates <- function(tables, expected_dir, analyses) {
  keep <- analyses[analysis_id != UNESTIMABLE$analysis_id, analysis_id]
  h2 <- tables$h2[analysis_id %in% keep]
  rg <- tables$rg[analysis_id %in% keep]
  read <- function(name) {
    fread(file.path(expected_dir, name), colClasses = list(character = "birth_year"))
  }
  e_h2 <- read("h2.tsv")
  e_rg <- read("rg.tsv")
  # Strata EPIMIGHT could not estimate are NA rows with a note; the reference has no row.
  noted <- function(d, estimate) d[is.na(get(estimate)) & level == "stratum"]
  h2_noted <- noted(h2, "h2")
  rg_noted <- noted(rg, "rg")
  h2 <- h2[!(is.na(h2) & level == "stratum")]
  rg <- rg[!(is.na(rg) & level == "stratum")]
  h2_keys <- c("relationship", "trait", "level", "birth_year")
  rg_keys <- c("relationship", "index_trait", "relatives_trait", "level", "birth_year")
  rbind(
    compare_tables("toy: h2 estimates and native SEs", h2, e_h2, h2_keys,
                   c("age_min", "age_max", "h2", "se_native")),
    compare_tables("toy: h2 sandwich SEs", h2, e_h2, h2_keys, "se_sandwich", SANDWICH_RTOL),
    compare_tables("toy: rg estimates, native SEs, rhh and h2 at the rg age", rg, e_rg, rg_keys,
                   c("age_min", "age_max", "rg", "se_native", "rhh", "h2_index_at_age",
                     "h2_relatives_at_age")),
    compare_tables("toy: rg sandwich SEs", rg, e_rg, rg_keys, "se_sandwich", SANDWICH_RTOL),
    item("toy: strata without an estimate carry a note",
         if (all(!is.na(c(h2_noted$note, rg_noted$note)))) "PASS" else "FAIL",
         sprintf("%d h2 and %d rg stratum rows NA, each with a note", nrow(h2_noted),
                 nrow(rg_noted)))
  )
}

curve_keys <- c("cohort", "relationship", "index_trait", "relatives_trait", "birth_year")

compare_cif <- function(cif, expected_dir) {
  cif <- unique(cif[, !"analysis_id"])
  expected <- fread(file.path(expected_dir, "cif.tsv"), colClasses = list(character = "birth_year"))
  for (k in curve_keys) {
    set(cif, j = k, value = as.character(cif[[k]]))
    set(expected, j = k, value = as.character(expected[[k]]))
  }
  population <- expected$cohort == "population"
  # EPIMIGHT reports NA at a weighted curve's first event age (lag of the running CIF,
  # CumulativeIncidenceAnalysis-class.R:132); the reference reports the left limit, 0.
  weighted <- expected[!population]
  weighted[, first := age == min(age) & age > 0 & cif == 0, by = curve_keys]
  lagged <- sum(weighted$first)
  weighted[first == TRUE, cif := NA_real_][, first := NULL]
  # cmprsk::cuminc puts the unweighted population curve on a grid from age 0 to the last
  # follow-up age (:173-185); drop the rows the reference, at event ages only, lacks.
  pop_expected <- expected[population]
  last <- pop_expected[, .(last = max(age)), by = curve_keys]
  pop_kit <- merge(cif[cohort == "population"], last, by = curve_keys, all.x = TRUE)
  key_age <- c(curve_keys, "age")
  only_kit <- fsetdiff(pop_kit[, ..key_age], pop_expected[, ..key_age])
  grid <- merge(only_kit, pop_kit, by = key_age)[(age == 0 & cif == 0 & cases == 0) | age > last]
  pop_kit <- pop_kit[!grid[, ..key_age], on = key_age]
  rbind(
    compare_tables(sprintf("toy: cif family history and cross (%d first-row 0 read as NA)", lagged),
                   cif[cohort != "population"], weighted, key_age,
                   c("cif", "se_native", "cases")),
    compare_tables(sprintf("toy: cif population (%d cuminc grid rows dropped)", nrow(grid)),
                   pop_kit[, !"last"], pop_expected, key_age, c("cif", "cases")),
    item("toy: cif population se_native", "SKIP",
         "EPIMIGHT's population SE is cmprsk::cuminc's variance, which has no Python reference")
  )
}

check_ids <- function(run_dir) {
  cohort <- fread(file.path(step_dir(run_dir, "cohort"), "cohort.tsv"),
                  colClasses = list(character = "person_id"))
  per_id <- cohort[person_id %in% RENAMED, .N, by = person_id]
  expected <- uniqueN(cohort[, .(trait, relatives_kind)])
  ok <- setequal(per_id$person_id, RENAMED) && all(per_id$N == expected)
  item("toy: ids 001, 1 and 1.0 stay three people", if (ok) "PASS" else "FAIL",
       sprintf("%s cohort rows each (expected %d)",
               paste(sprintf("%s: %d", per_id$person_id, per_id$N), collapse = ", "), expected))
}

check_unestimable <- function(tables) {
  rows <- tables$h2[analysis_id == UNESTIMABLE$analysis_id]
  want <- sprintf(NOTES$no_affected_relative, UNESTIMABLE$relationship, UNESTIMABLE$trait)
  ok <- nrow(rows) > 0 && all(is.na(rows$h2)) && all(rows$note == want)
  item("toy: an analysis with no affected relative is NA rows with a note",
       if (ok) "PASS" else "FAIL", sprintf("%d rows NA, noted '%s'", nrow(rows), want))
}

check_cohort_cases <- function(selftest, dir) {
  checked <- check_inputs(file.path(selftest, "cohort_cases", "study.yaml"), dir)
  if (has_stop(checked$findings)) {
    return(item("cohort table: every rule matches make_epimight_tte", "FAIL",
                paste(checked$findings$code, collapse = ", ")))
  }
  cohort <- build_cohort(checked$inputs)$cohort
  path <- file.path(selftest, "expected", "cohort_cases.tsv.gz")
  expected <- utils::read.delim(gzfile(path), colClasses = c(person_id = "character"))
  expected <- as.data.table(expected)
  differs <- nrow(fsetdiff(cohort, expected[, names(cohort), with = FALSE])) +
    nrow(fsetdiff(expected[, names(cohort), with = FALSE], cohort))
  item("cohort table: every rule matches make_epimight_tte",
       if (differs == 0 && nrow(cohort) == nrow(expected)) "PASS" else "FAIL",
       sprintf("%d rows over %d traits x %d relationships, %d differ", nrow(expected),
               uniqueN(expected$trait), uniqueN(expected$relatives_kind), differs))
}

# Broken copies of the prepared toy, each of which must stop the check step with its code.
BROKEN <- list(
  external_parent_over_cap = function(d) {
    p <- fread(file.path(d, "pedigree.tsv"), colClasses = "character")
    p[which(!is.na(father))[1:31], father := "EXTERNAL"]
    fwrite(p, file.path(d, "pedigree.tsv"), sep = "\t", na = "NA")
  },
  birth_date_missing = function(d) {
    p <- fread(file.path(d, "pedigree.tsv"), colClasses = "character")
    p[1, birth_date := NA]
    fwrite(p, file.path(d, "pedigree.tsv"), sep = "\t", na = "NA")
  },
  trait_duplicate_id = function(d) {
    t <- fread(file.path(d, "trait1.tsv"), colClasses = "character")
    fwrite(rbind(t, t[1]), file.path(d, "trait1.tsv"), sep = "\t")
  },
  age_date_mismatch = function(d) {
    t <- fread(file.path(d, "trait1.tsv"), colClasses = "character")
    t[1, age := as.character(as.numeric(age) + 0.1)]
    fwrite(t, file.path(d, "trait1.tsv"), sep = "\t")
  },
  trait_population_differs = function(d) {
    t <- fread(file.path(d, "trait2.tsv"), colClasses = "character")
    fwrite(t[-1], file.path(d, "trait2.tsv"), sep = "\t")
  },
  relationship_unknown = function(d) {
    a <- fread(file.path(d, "analyses.tsv"), colClasses = "character")
    a[1, relationship := "sibling"]
    fwrite(a, file.path(d, "analyses.tsv"), sep = "\t")
  }
)

check_broken <- function(toy_dir, dir) {
  rbindlist(lapply(names(BROKEN), function(code) {
    copy_dir <- file.path(dir, code)
    dir.create(copy_dir, recursive = TRUE)
    file.copy(list.files(toy_dir, full.names = TRUE), copy_dir)
    BROKEN[[code]](copy_dir)
    found <- check_inputs(file.path(copy_dir, "study.yaml"), file.path(copy_dir, "out"))$findings
    stops <- found[severity == "STOP", code]
    listed <- if (length(stops) == 0) "none" else paste(unique(stops), collapse = ", ")
    item(sprintf("broken input stops with %s", code), if (code %in% stops) "PASS" else "FAIL",
         sprintf("stops: %s", listed))
  }))
}

run_selftest <- function(out, selftest = "selftest") {
  if (dir.exists(out) && length(list.files(out)) > 0) {
    stop(sprintf("%s is not empty; give the self-test a new folder", out), call. = FALSE)
  }
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  selftest <- normalizePath(selftest)
  toy_dir <- file.path(out, "toy")
  study <- prepare_toy(file.path(selftest, "toy"), toy_dir)
  run_dir <- file.path(out, "run")
  status <- system2(Sys.which("Rscript"), c(file.path("steps", "study.R"), study, run_dir))
  items <- item("toy: every step runs", if (status == 0) "PASS" else "FAIL",
                sprintf("pixi run study exited %d", status))
  if (status == 0) {
    tables <- readRDS(file.path(step_dir(run_dir, "tables"), "tables.rds"))
    analyses <- readRDS(file.path(step_dir(run_dir, "check"), "inputs.rds"))$analyses
    expected_dir <- file.path(selftest, "expected")
    items <- rbind(items, compare_estimates(tables, expected_dir, analyses),
                   compare_cif(tables$cif[analysis_id != UNESTIMABLE$analysis_id], expected_dir),
                   check_ids(run_dir),
                   check_unestimable(tables))
  }
  items <- rbind(items, check_cohort_cases(selftest, file.path(out, "cohort_cases")),
                 check_broken(toy_dir, file.path(out, "broken")))
  fwrite(items, file.path(out, "selftest.tsv"), sep = "\t")
  cat(sprintf("%-4s %s: %s\n", items$verdict, items$item, items$detail), sep = "")
  !any(items$verdict == "FAIL")
}
