# Step 4, tables: EPIMIGHT's raw results as h2.tsv, rg.tsv and cif.tsv (runner decisions
# O1-O11, with analysis_id on every row, D16), plus cohort_summary.tsv and run.yaml.
#
# Rows come from the cohort table, not from what EPIMIGHT returned (O8): every analysis
# gets a row per stratum of its index trait and a pooled row. Each call's outcome is first
# checked against a prediction made from the cohort table and the other calls' results:
# an error EPIMIGHT was bound to raise becomes NA rows with a note naming the cause; any
# other error, or a predicted error that did not happen, stops the run.

NOTES <- list(
  no_positive_h2 = "no age with positive h2",
  stratum_no_affected_relative = "no proband in this stratum with a %s relative affected by %s",
  truncated = "h2 at age %d; last event age %d (later ages had h2 <= 0)",
  sandwich_negative = "sandwich variance negative; interval unavailable",
  rg_absent = "rg needs both h2 and a shared age",
  not_pooled = "%d of %d strata did not enter the pool",
  no_relative_rows = "no %s rows for trait %s",
  no_affected_relative = "no proband with a %s relative affected by %s",
  rg_join_empty = "no age shared by the CIFs and both h2 tables",
  no_poolable_stratum = "no stratum with a positive h2 and SE",
  no_poolable_rg = "no stratum with a finite rg and SE to pool"
)
# The text of the EPIMIGHT stop each predicted cause must produce (Pipeline-class.R).
STOP_MESSAGES <- c(
  no_relative_rows = "No family history TTE data found",
  no_affected_relative = "No probands with at least 1 relative",
  rg_join_empty = "After joining all cif and h2 results no data was left",
  no_poolable_stratum = "No stratum has a finite h2 with a positive SE"
)
ESTIMATE_RENAME <- c(se = "se_native", sandwich_se = "se_sandwich", sandwich_l95 = "l95_sandwich",
                     sandwich_u95 = "u95_sandwich")
CIF_RENAME <- c(se = "se_native", l95 = "l95_native", u95 = "u95_native")

h2_columns <- function(stratify) {
  c("analysis_id", "relationship", "relatedness", "trait", "level", stratify, "age_min",
    "age_max", "n_strata", "h2", "se_sandwich", "l95_sandwich", "u95_sandwich", "se_native",
    "note")
}
rg_columns <- function(stratify) {
  c("analysis_id", "relationship", "relatedness", "index_trait", "relatives_trait", "level",
    stratify, "age_min", "age_max", "n_strata", "rg", "se_sandwich", "l95_sandwich",
    "u95_sandwich", "se_native", "rhh", "h2_index_at_age", "h2_relatives_at_age", "note")
}
cif_columns <- function(stratify) {
  c("analysis_id", "cohort", "relationship", "index_trait", "relatives_trait", stratify, "age",
    "cif", "se_native", "l95_native", "u95_native", "cases")
}

# `d` with exactly `columns`, in order; absent ones are NA.
conform <- function(d, columns) {
  d <- copy(as.data.table(d))
  for (col in setdiff(columns, names(d))) set(d, j = col, value = NA)
  d[, ..columns]
}

cause <- function(code, ...) list(code = code, text = sprintf(NOTES[[code]], ...))

# Strata per trait and, per trait and relationship, the cohort-table rows and those with an
# affected relative: what decides EPIMIGHT's empty-cohort stops (Pipeline-class.R:724-757).
cohort_facts <- function(cohort, stratify) {
  list(
    strata = cohort[, unique(.SD), by = trait, .SDcols = stratify],
    relatives = cohort[, .(rows = .N, affected = sum(relatives_n_trait > 0)),
                       by = .(trait, relationship = relatives_kind)]
  )
}

cohort_cause <- function(facts, of_trait, of_relationship) {
  r <- facts$relatives[trait == of_trait & relationship == of_relationship]
  if (nrow(r) == 0) return(cause("no_relative_rows", of_relationship, of_trait))
  if (r$affected == 0) return(cause("no_affected_relative", of_relationship, of_trait))
  NULL
}

last_rows <- function(d, stratify) d[order(age)][, .SD[.N], by = stratify]

# Each stratum's rg age and both h2 values there, as rg_estimates joins the five tables
# (Pipeline-class.R:43-101). NULL when one of them is missing.
rg_ages <- function(results, i, j, rel, stratify) {
  keys <- c("age", stratify)
  tables <- list(results[[job_id("cif", i)]], results[[job_id("cif", i, j, rel)]],
                 results[[job_id("cif", j)]], results[[job_id("h2", i, i, rel)]],
                 results[[job_id("h2", j, j, rel)]])
  if (any(vapply(tables, is.null, logical(1)))) {
    return(NULL)
  }
  joined <- Reduce(function(a, b) merge(a, b, by = keys), list(
    tables[[1]][, ..keys], tables[[2]][, ..keys], tables[[3]][, ..keys],
    tables[[4]][, c(keys, "h2"), with = FALSE][, .(age, h2_index_at_age = h2), by = stratify],
    tables[[5]][, c(keys, "h2"), with = FALSE][, .(age, h2_relatives_at_age = h2), by = stratify]
  ))
  last_rows(joined, stratify)
}

# rg_ages for every rg call, by its job id; computed once and shared.
all_rg_ages <- function(jobs, results, stratify) {
  rg <- jobs[kind == "rg"]
  stats::setNames(lapply(seq_len(nrow(rg)), function(k) {
    rg_ages(results, rg$index_trait[k], rg$relatives_trait[k], rg$relationship[k], stratify)
  }), rg$job)
}

rg_ages_of <- function(ages, i, j, rel) ages[[job_id("rg", i, j, rel)]]

# Whether no stratum of an rg call has a finite rg and SE, so nothing can be pooled.
# EPIMIGHT does not stop then (run_meta sums over nothing, Analysis-class.R:96-101), so the
# pooled row is NA with a note whatever the pooled call returned.
nothing_to_pool <- function(rg) {
  !is.null(rg) && nrow(rg[is.finite(rg) & is.finite(se)]) == 0
}

predict_stop <- function(job, facts, results, stratify, ages) {
  rel <- job$relationship
  switch(job$kind,
    cif = if (!is.na(rel)) cohort_cause(facts, job$relatives_trait, rel),
    h2 = cohort_cause(facts, job$index_trait, rel),
    h2_pooled = {
      found <- cohort_cause(facts, job$index_trait, rel)
      h2 <- results[[job_id("h2", job$index_trait, job$index_trait, rel)]]
      if (is.null(found) && !is.null(h2)) {
        usable <- last_rows(h2, stratify)[is.finite(h2) & is.finite(se) & se > 0]
        if (nrow(usable) == 0) found <- cause("no_poolable_stratum")
      }
      found
    },
    rg = ,
    rg_pooled = {
      found <- cohort_cause(facts, job$index_trait, rel) %||%
        cohort_cause(facts, job$relatives_trait, rel)
      at <- rg_ages_of(ages, job$index_trait, job$relatives_trait, rel)
      if (is.null(found) && !is.null(at) && nrow(at) == 0) found <- cause("rg_join_empty")
      found
    }
  )
}

# Each errored job's note, and a STOP for every outcome its prediction did not match.
classify_jobs <- function(jobs, facts, results, stratify,
                          ages = all_rg_ages(jobs, results, stratify)) {
  notes <- list()
  findings <- list()
  for (k in seq_len(nrow(jobs))) {
    job <- jobs[k]
    predicted <- predict_stop(job, facts, results, stratify, ages)
    stratum_rg <- results[[job_id("rg", job$index_trait, job$relatives_trait, job$relationship)]]
    if (job$kind == "rg_pooled" && is.null(predicted) && nothing_to_pool(stratum_rg)) {
      notes[[job$job]] <- NOTES$no_poolable_rg
      next
    }
    expected <- if (is.null(predicted)) NA_character_ else STOP_MESSAGES[[predicted$code]]
    if (job$status == "ok" && !is.null(predicted)) {
      unmet <- finding("epimight_prediction_unmet",
                       sprintf("%s ran, but the kit predicted EPIMIGHT would stop on it: %s",
                               job$job, predicted$text))
      findings <- c(findings, list(unmet))
    } else if (job$status == "error" && !isTRUE(grepl(expected, job$error, fixed = TRUE))) {
      unpredicted <- finding("epimight_error_unpredicted",
                             sprintf(paste("%s stopped with an error the kit did not predict:",
                                           "%s (predicted: %s)"),
                                     job$job, job$error, if (is.na(expected)) "none" else expected))
      findings <- c(findings, list(unpredicted))
    } else if (job$status == "error") {
      notes[[job$job]] <- predicted$text
    } else if (job$kind == "rg") {
      at <- ages[[job$job]]
      only <- function(a, b) nrow(fsetdiff(unique(a[, ..stratify]), unique(b[, ..stratify])))
      rg <- results[[job$job]]
      if (!is.null(at) && (only(at, rg) > 0 || only(rg, at) > 0)) {
        mismatch <- finding("rg_age_rebuild_mismatch",
                            sprintf("%s: rebuilt rg ages cover %d strata, EPIMIGHT's rg %d",
                                    job$job, nrow(at), nrow(rg)))
        findings <- c(findings, list(mismatch))
      }
    }
  }
  list(notes = notes, findings = collect(findings), ages = ages)
}

join_notes <- function(...) {
  parts <- list(...)
  out <- do.call(paste, c(lapply(parts, function(p) ifelse(is.na(p), "", p)), sep = "; "))
  out <- gsub("^(; )+|(; )+$", "", gsub("(; ){2,}", "; ", out))
  ifelse(out == "", NA_character_, out)
}

sandwich_missing <- function(d) d$present & !is.finite(d$se_sandwich)

missing_rows <- function(expected, note) {
  copy(expected)[, `:=`(level = "stratum", n_strata = 0L, note = note)]
}

pooled_values <- function(d, estimate, expected) {
  d <- copy(d)
  setnames(d, names(ESTIMATE_RENAME), ESTIMATE_RENAME, skip_absent = TRUE)
  missing <- expected - d$n_strata
  d[, note := join_notes(
    if (missing > 0) sprintf(NOTES$not_pooled, missing, expected) else NA_character_,
    if (!is.finite(se_sandwich) && is.finite(d[[estimate]])) NOTES$sandwich_negative else NA
  )]
  d
}

h2_block <- function(a, facts, results, notes, stratify) {
  trait <- a$trait
  rel <- a$relationship
  expected <- facts$strata[trait == a$trait, ..stratify]
  identity <- list(analysis_id = a$analysis_id, relationship = rel,
                   relatedness = RELATIONSHIPS$relatedness[RELATIONSHIPS$relationship == rel],
                   trait = trait)
  id <- job_id("h2", trait, trait, rel)
  if (!is.null(notes[[id]])) {
    strata <- missing_rows(expected, notes[[id]])
  } else {
    last <- last_rows(results[[id]], stratify)
    setnames(last, names(ESTIMATE_RENAME), ESTIMATE_RENAME)
    last[, present := TRUE]
    pop <- results[[job_id("cif", trait)]]
    fh <- results[[job_id("cif", trait, trait, rel)]]
    keys <- c("age", stratify)
    both <- merge(pop[, ..keys], fh[, ..keys], by = keys)
    last_event <- both[, .(last_event = max(age)), by = stratify]
    in_fh <- unique(fh[, ..stratify])[, in_fh := TRUE]
    strata <- Reduce(function(x, y) merge(x, y, by = stratify, all.x = TRUE),
                     list(expected, last, last_event, in_fh))
    strata[is.na(present), present := FALSE]
    strata[is.na(in_fh), in_fh := FALSE]
    strata[, `:=`(level = "stratum", age_min = age, age_max = age, n_strata = as.integer(present))]
    strata[, note := join_notes(
      ifelse(!present & !in_fh, sprintf(NOTES$stratum_no_affected_relative, rel, trait), NA),
      ifelse(!present & in_fh, NOTES$no_positive_h2, NA),
      ifelse(present & age < last_event, sprintf(NOTES$truncated, as.integer(age),
                                                 as.integer(last_event)), NA),
      ifelse(sandwich_missing(strata), NOTES$sandwich_negative, NA)
    )]
  }
  pooled_id <- job_id("h2_pooled", trait, trait, rel)
  pooled <- if (!is.null(notes[[pooled_id]])) {
    data.table(note = notes[[pooled_id]])
  } else {
    pooled_values(results[[pooled_id]], "h2", nrow(expected))
  }
  pooled[, level := "pooled"]
  columns <- h2_columns(stratify)
  rbind(conform(strata[, (names(identity)) := identity], columns),
        conform(pooled[, (names(identity)) := identity], columns))
}

rg_block <- function(a, facts, results, notes, stratify, ages) {
  i <- a$trait
  j <- a$relatives_trait
  rel <- a$relationship
  expected <- facts$strata[trait == i, ..stratify]
  identity <- list(analysis_id = a$analysis_id, relationship = rel,
                   relatedness = RELATIONSHIPS$relatedness[RELATIONSHIPS$relationship == rel],
                   index_trait = i, relatives_trait = j)
  id <- job_id("rg", i, j, rel)
  if (!is.null(notes[[id]])) {
    strata <- missing_rows(expected, notes[[id]])
  } else {
    rg <- copy(results[[id]])
    setnames(rg, names(ESTIMATE_RENAME), ESTIMATE_RENAME)
    rg[, present := TRUE]
    at <- rg_ages_of(ages, i, j, rel)
    strata <- merge(merge(expected, at, by = stratify, all.x = TRUE), rg, by = stratify,
                    all.x = TRUE)
    strata[is.na(present), present := FALSE]
    strata[, `:=`(level = "stratum", age_min = age, age_max = age, n_strata = as.integer(present),
                  rhh = rg * sqrt(h2_index_at_age * h2_relatives_at_age))]
    strata[, note := join_notes(ifelse(!present, NOTES$rg_absent, NA),
                                ifelse(sandwich_missing(strata), NOTES$sandwich_negative, NA))]
  }
  pooled_id <- job_id("rg_pooled", i, j, rel)
  pooled <- if (!is.null(notes[[pooled_id]])) {
    data.table(note = notes[[pooled_id]])
  } else {
    entered <- strata[is.finite(rg) & is.finite(se_native)]
    d <- copy(results[[pooled_id]])[, n_strata := nrow(entered)]
    pooled_values(d, "rg", nrow(expected))[, `:=`(age_min = min(entered$age),
                                                  age_max = max(entered$age))]
  }
  pooled[, level := "pooled"]
  columns <- rg_columns(stratify)
  rbind(conform(strata[, (names(identity)) := identity], columns),
        conform(pooled[, (names(identity)) := identity], columns))
}

cif_rows <- function(a, results, stratify) {
  curves <- if (a$analysis == "h2") {
    list(list("population", a$trait, NA, NA),
         list("family_history", a$trait, a$trait, a$relationship))
  } else {
    list(list("population", a$trait, NA, NA), list("population", a$relatives_trait, NA, NA),
         list("cross", a$trait, a$relatives_trait, a$relationship))
  }
  rbindlist(lapply(curves, function(cv) {
    d <- results[[job_id("cif", cv[[2]], cv[[3]], cv[[4]])]]
    if (is.null(d)) {
      return(NULL)
    }
    d <- copy(d)
    setnames(d, names(CIF_RENAME), CIF_RENAME)
    d[, `:=`(analysis_id = a$analysis_id, cohort = cv[[1]], relationship = cv[[4]],
             index_trait = cv[[2]], relatives_trait = cv[[3]])]
    conform(d, cif_columns(stratify))
  }))
}

# The unrounded tables, or NULL with the findings that stop the run.
build_tables <- function(analyses, cohort, epimight, stratify) {
  facts <- cohort_facts(cohort, stratify)
  results <- epimight$results
  verdict <- classify_jobs(epimight$jobs, facts, results, stratify)
  if (has_stop(verdict$findings)) {
    return(list(tables = NULL, findings = verdict$findings))
  }
  h2 <- rbindlist(lapply(which(analyses$analysis == "h2"), function(k) {
    h2_block(analyses[k], facts, results, verdict$notes, stratify)
  }))
  rg <- rbindlist(lapply(which(analyses$analysis == "rg"), function(k) {
    rg_block(analyses[k], facts, results, verdict$notes, stratify, verdict$ages)
  }))
  cif <- rbindlist(lapply(seq_len(nrow(analyses)), function(k) {
    cif_rows(analyses[k], results, stratify)
  }))
  list(tables = list(h2 = conform(h2, h2_columns(stratify)),
                     rg = conform(rg, rg_columns(stratify)),
                     cif = conform(cif, cif_columns(stratify))),
       findings = verdict$findings)
}

# Doubles rounded to 6 significant digits (O11); integers and text unchanged.
write_rounded <- function(d, path) {
  d <- copy(d)
  doubles <- names(d)[vapply(d, is.double, logical(1))]
  for (col in doubles) set(d, j = col, value = signif(d[[col]], 6))
  fwrite(d, path, sep = "\t", na = "NA", quote = FALSE)
}

run_tables <- function(study_path, out, dir) {
  inputs <- readRDS(file.path(step_dir(out, "check"), "inputs.rds"))
  study <- inputs$study
  epimight <- readRDS(file.path(step_dir(out, "epimight"), "results.rds"))
  cohort <- read_cohort(file.path(step_dir(out, "cohort"), "cohort.tsv"), study$stratify)
  built <- build_tables(inputs$analyses, cohort, epimight, study$stratify)
  write_findings(built$findings, file.path(dir, "findings.tsv"))
  if (is.null(built$tables)) {
    cat(paste0("  ", format_findings(built$findings), "\n"), sep = "")
    return(FALSE)
  }
  saveRDS(built$tables, file.path(dir, "tables.rds"))
  for (name in names(built$tables)) {
    write_rounded(built$tables[[name]], file.path(out, paste0(name, ".tsv")))
  }
  file.copy(file.path(step_dir(out, "cohort"), "cohort_summary.tsv"),
            file.path(out, "cohort_summary.tsv"), overwrite = TRUE)
  yaml::write_yaml(run_record(out, inputs, epimight, built$tables), file.path(out, "run.yaml"))
  h2 <- built$tables$h2
  cat(sprintf("tables: h2 %d rows (%d with an estimate), rg %d rows (%d), cif %d rows\n",
              nrow(h2), sum(is.finite(h2$h2)), nrow(built$tables$rg),
              sum(is.finite(built$tables$rg$rg)), nrow(built$tables$cif)))
  TRUE
}

# run.yaml (O9): what ran, on what, with which settings, and how it went.
run_record <- function(out, inputs, epimight, tables) {
  check <- yaml::read_yaml(file.path(step_dir(out, "check"), "run.yaml"))
  check_findings <- fread(file.path(step_dir(out, "check"), "findings.tsv"))
  jobs <- epimight$jobs
  study <- inputs$study
  count <- function(d, estimate) list(rows = nrow(d), estimated = sum(is.finite(d[[estimate]])))
  relatedness <- stats::setNames(RELATIONSHIPS$relatedness, RELATIONSHIPS$relationship)
  list(
    kit = list(nordicepimight = as.character(utils::packageVersion("nordicepimight"))),
    installed = epimight$installed,
    r_version = epimight$r_version,
    inputs = check$inputs,
    settings = list(
      stratify = study$stratify, birth_year_bin = study$birth_year_bin,
      study_end = format(study$study_end), max_degree = study$max_degree,
      threads = study$threads, external_parent_cap = study$external_parent_cap,
      pooling = POOLED_METHOD, ages = "floored to whole years",
      relatedness = as.list(relatedness[unique(inputs$analyses$relationship)])
    ),
    population = length(inputs$population),
    warnings = lapply(split(check_findings[severity == "WARN"], by = "code"), function(f) {
      list(count = sum(f$count), message = f$message[1])
    }),
    epimight = list(
      calls = nrow(jobs), ok = sum(jobs$status == "ok"),
      expected_stops = sum(jobs$status == "error"),
      sandwich_batch_sizes = as.integer(sort(unique(stats::na.omit(jobs$sandwich_batch_size)))),
      sandwich_passes_max = as.integer(max(c(0, jobs$sandwich_passes), na.rm = TRUE)),
      wall_seconds = round(epimight$wall_seconds, 1)
    ),
    outputs = list(h2 = count(tables$h2, "h2"), rg = count(tables$rg, "rg"),
                   cif = list(rows = nrow(tables$cif)))
  )
}
