# Step 3, epimight: one EPIMIGHT Pipeline over the cohort table and the validated pedigree,
# and one call per distinct estimate the analyses need. Every call runs inside tryCatch;
# the tables step decides which errors EPIMIGHT was bound to raise. Writes
# 3_epimight/results.rds (each call's arguments, outcome and unrounded result) and
# jobs.tsv (each call's outcome and time).

POOLED_METHOD <- "fixed"

cif_args <- function(stratify, index, relatives = NULL, relationship = NULL) {
  args <- list(index_trait = index)
  if (!is.null(relatives)) {
    args <- c(args, list(relatives_trait = relatives, relatives_kind = relationship))
  }
  c(args, list(stratify_columns = as.list(stratify)))
}

h2_args <- function(stratify, trait, relationship, relatedness) {
  list(cif_pop = cif_args(stratify, trait),
       cif_fh = cif_args(stratify, trait, trait, relationship),
       relatedness = relatedness)
}

job_id <- function(kind, index, relatives = NA, relationship = NA) {
  paste(c(kind, index, stats::na.omit(c(relatives, relationship))), collapse = "|")
}

# Every call the analyses need, each once: the population CIF of each trait, then per
# trait and relationship its family-history CIF, h2 and pooled h2, then per rg analysis its
# cross CIF, rg and pooled rg. An rg also needs both traits' h2 tables (for its ages).
plan_jobs <- function(analyses, stratify) {
  relatedness <- function(rel) RELATIONSHIPS$relatedness[match(rel, RELATIONSHIPS$relationship)]
  h2_of <- unique(rbind(analyses[, .(trait, relationship)],
                        analyses[analysis == "rg", .(trait = relatives_trait, relationship)]))
  job <- function(kind, method, index, relatives, rel, args) {
    data.table(job = job_id(kind, index, relatives, rel), kind = kind, method = method,
               index_trait = index, relatives_trait = relatives, relationship = rel,
               args = list(args))
  }
  population <- lapply(unique(h2_of$trait), function(t) {
    job("cif", "run_cif", t, NA, NA, cif_args(stratify, t))
  })
  same_trait <- lapply(seq_len(nrow(h2_of)), function(k) {
    t <- h2_of$trait[k]
    rel <- h2_of$relationship[k]
    h2 <- h2_args(stratify, t, rel, relatedness(rel))
    rbind(job("cif", "run_cif", t, t, rel, cif_args(stratify, t, t, rel)),
          job("h2", "run_h2", t, t, rel, h2),
          job("h2_pooled", "run_h2_pooled", t, t, rel, c(h2, list(method = POOLED_METHOD))))
  })
  rg <- unique(analyses[analysis == "rg", .(trait, relatives_trait, relationship)])
  cross <- lapply(seq_len(nrow(rg)), function(k) {
    i <- rg$trait[k]
    j <- rg$relatives_trait[k]
    rel <- rg$relationship[k]
    args <- list(h2_t1 = h2_args(stratify, i, rel, relatedness(rel)),
                 h2_t2 = h2_args(stratify, j, rel, relatedness(rel)),
                 relatedness = relatedness(rel),
                 cif_cross = cif_args(stratify, i, j, rel))
    rbind(job("cif", "run_cif", i, j, rel, cif_args(stratify, i, j, rel)),
          job("rg", "run_rg", i, j, rel, args),
          job("rg_pooled", "run_rg", i, j, rel, c(args, list(meta_analyze = POOLED_METHOD))))
  })
  unique(rbindlist(c(population, same_trait, cross)), by = "job")
}

run_job <- function(pipeline, job) {
  started <- proc.time()[["elapsed"]]
  warnings <- character()
  outcome <- tryCatch(
    withCallingHandlers(
      {
        res <- do.call(pipeline[[job$method]], job$args[[1]])
        list(status = "ok", error = NA_character_, result = as.data.table(res$results),
             sandwich = res$metadata$sandwich)
      },
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      list(status = "error", error = conditionMessage(e), result = NULL, sandwich = NULL)
    }
  )
  c(outcome, list(seconds = proc.time()[["elapsed"]] - started,
                  warnings = paste(unique(warnings), collapse = " | ")))
}

read_cohort <- function(path, stratify) {
  classes <- list(character = c("person_id", "trait", "relatives_kind", stratify),
                  integer = c("trait_status", "relatives_n", "relatives_n_trait"),
                  numeric = "trait_age")
  fread(path, sep = "\t", colClasses = classes, na.strings = "NA")
}

run_epimight <- function(study_path, out, dir) {
  inputs <- readRDS(file.path(step_dir(out, "check"), "inputs.rds"))
  study <- inputs$study
  setDTthreads(study$threads)
  pedigreegraph::configure_threads(study$threads)
  options(pedigreegraph.progress = FALSE)
  cohort <- read_cohort(file.path(step_dir(out, "cohort"), "cohort.tsv"), study$stratify)
  pedigree <- inputs$validated_pedigree[, .(person_id = id, mother_id = mother, father_id = father)]
  started <- proc.time()[["elapsed"]]
  pipeline <- suppressWarnings(epimight::Pipeline$new(pool = cohort, pedigree = pedigree,
                                                      max_degree = study$max_degree))
  jobs <- plan_jobs(inputs$analyses, study$stratify)
  ran <- lapply(seq_len(nrow(jobs)), function(i) {
    job <- jobs[i]
    o <- run_job(pipeline, job)
    cat(sprintf("  %-50s %-5s %6.1fs%s\n", job$job, o$status, o$seconds,
                if (is.na(o$error)) "" else paste0("  ", o$error)))
    o
  })
  results <- stats::setNames(lapply(ran, `[[`, "result"), jobs$job)
  jobs[, `:=`(status = vapply(ran, `[[`, "", "status"),
              error = vapply(ran, `[[`, "", "error"),
              warnings = vapply(ran, `[[`, "", "warnings"),
              seconds = vapply(ran, `[[`, 0, "seconds"),
              sandwich_batch_size = vapply(ran, function(o) o$sandwich$batch_size %||% NA_real_, 0),
              sandwich_passes = vapply(ran, function(o) o$sandwich$passes %||% NA_real_, 0))]
  saveRDS(list(jobs = jobs, results = results,
               wall_seconds = proc.time()[["elapsed"]] - started,
               installed = installed_sources(), r_version = R.version.string),
          file.path(dir, "results.rds"))
  fwrite(jobs[, !"args"], file.path(dir, "jobs.tsv"), sep = "\t", na = "NA")
  cat(sprintf("epimight: %d calls, %d ok, %d errors (the tables step checks them)\n", nrow(jobs),
              sum(jobs$status == "ok"), sum(jobs$status == "error")))
  TRUE
}
