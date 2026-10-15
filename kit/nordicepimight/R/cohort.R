# Step 2, cohort: builds EPIMIGHT's cohort table from the checked inputs. One row per
# proband, trait and relationship, for every trait an analysis names and every
# relationship any analysis uses (D8): the proband's status and whole-year age after the
# trait's rules, how many relatives of that relationship have a row in the trait file
# (relatives_n) and how many of them have status 1 (relatives_n_trait), and the strata.

COHORT_COLUMNS <- c("person_id", "trait", "trait_status", "trait_age", "relatives_kind",
                    "relatives_n", "relatives_n_trait")

# The relatives' window for each trait and relationship: relative_windows.tsv, else the
# trait's max_followup_relatives.
relatives_window <- function(traits, relationships, windows) {
  grid <- CJ(trait = traits$trait, relationship = relationships)
  grid[traits, default := i.max_followup_relatives, on = "trait"]
  grid[, w := default]
  if (!is.null(windows)) {
    grid[windows, w := i.max_followup_relatives, on = c("trait", "relationship")]
  }
  grid[, .(trait, relationship, w)]
}

build_cohort <- function(inputs) {
  study <- inputs$study
  used <- unique(c(inputs$analyses$trait, inputs$analyses$relatives_trait))
  traits <- inputs$traits[trait %in% used]
  relationships <- unique(inputs$analyses$relationship)
  pedigree <- inputs$pedigree
  pairs <- relative_pairs(pedigree, relationships)
  windows <- relatives_window(traits, relationships, inputs$relative_windows)
  rows_of <- function(file) {
    d <- copy(inputs$trait_data[[file]])
    d[, birth_date := pedigree$birth_date[chmatch(id, pedigree$id)]]
  }

  built <- lapply(seq_len(nrow(traits)), function(i) {
    def <- traits[i]
    rows <- rows_of(def$file_path)
    onsets <- if (def$exclude_trait2 != "none") {
      rows_of(inputs$traits[trait == def$trait2, file_path])[status == 1L]
    }
    ruled <- apply_rules(rows, def, onsets, study$study_end)
    probands <- ruled$probands
    tables <- lapply(relationships, function(rel) {
      w <- windows[trait == def$trait & relationship == rel, w]
      relatives <- relatives_status(rows, probands, def, w, study$study_end)
      counted <- relatives[pairs[relationship == rel], on = "relative_id", nomatch = NULL]
      counts <- counted[, .(relatives_n = .N, relatives_n_trait = sum(relative_status == 1L)),
                        by = person_id]
      out <- probands[, .(person_id = id, trait = def$trait, trait_status = status,
                          trait_age = as.integer(floor(age)), relatives_kind = rel)]
      out[counts, `:=`(relatives_n = i.relatives_n, relatives_n_trait = i.relatives_n_trait),
          on = "person_id"]
      out[is.na(relatives_n), `:=`(relatives_n = 0L, relatives_n_trait = 0L)]
      out
    })
    list(table = rbindlist(tables), log = ruled$log[, trait := def$trait])
  })
  cohort <- rbindlist(lapply(built, `[[`, "table"))
  at <- chmatch(cohort$person_id, pedigree$id)
  for (s in study$stratify) set(cohort, j = s, value = pedigree[[s]][at])
  setcolorder(cohort, c(COHORT_COLUMNS, study$stratify))
  setorderv(cohort, c("trait", "relatives_kind", "person_id"))
  rules_log <- rbindlist(lapply(built, `[[`, "log"))
  list(cohort = cohort[], rules_log = rules_log)
}

# One row per trait, relationship and stratum: probands, their outcomes, and their
# relatives.
cohort_summary <- function(cohort, stratify) {
  cohort[, .(probands = .N,
             cases = sum(trait_status == 1L),
             competing = sum(trait_status == 2L),
             censored = sum(trait_status == 0L),
             with_relatives = sum(relatives_n > 0),
             with_affected_relatives = sum(relatives_n_trait > 0),
             relatives = sum(relatives_n),
             affected_relatives = sum(relatives_n_trait)),
         keyby = c("trait", "relatives_kind", stratify)]
}

run_cohort <- function(study_path, out, dir) {
  inputs <- readRDS(file.path(step_dir(out, "check"), "inputs.rds"))
  data.table::setDTthreads(inputs$study$threads)
  pedigreegraph::configure_threads(inputs$study$threads)
  built <- build_cohort(inputs)
  cohort <- built$cohort
  empty <- setdiff(unique(c(inputs$analyses$trait, inputs$analyses$relatives_trait)),
                   unique(cohort$trait))
  fwrite(built$rules_log, file.path(dir, "rules.tsv"), sep = "\t")
  if (length(empty) > 0) {
    findings <- finding("trait_no_probands", "no probands are left after the trait's rules",
                        examples = empty, count = length(empty))
    write_findings(findings, file.path(dir, "findings.tsv"))
    cat(paste0("  ", format_findings(findings), "\n"), sep = "")
    return(FALSE)
  }
  fwrite(cohort, file.path(dir, "cohort.tsv"), sep = "\t", na = "NA", quote = FALSE)
  fwrite(cohort_summary(cohort, inputs$study$stratify), file.path(dir, "cohort_summary.tsv"),
         sep = "\t", na = "NA")
  cat(sprintf("cohort: %d rows, %d traits x %d relationships; rules changed %d people\n",
              nrow(cohort), uniqueN(cohort$trait), uniqueN(cohort$relatives_kind),
              sum(built$rules_log$people)))
  TRUE
}
