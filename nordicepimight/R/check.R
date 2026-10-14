# Step 1, check: reads every input, runs every check whose inputs are usable, and writes
# 1_check/findings.tsv, 1_check/run.yaml and, when nothing stops the run,
# 1_check/inputs.rds, the parsed inputs the later steps read.

# `validate` runs pedsum on the pedigree; tests that are not about the pedigree pass a stub.
check_inputs <- function(study_path, dir, validate = validate_pedigree) {
  s <- read_study(study_path)
  study <- s$study
  if (is.null(study)) {
    return(list(findings = s$findings, inputs = NULL))
  }
  traits <- if (!is.null(study$traits)) read_traits(study$traits)
  analyses <- if (!is.null(study$analyses)) {
    read_analyses(study$analyses, traits$table, study$max_degree %||% 5L)
  }
  windows <- if (!is.null(study$relative_windows)) {
    read_relative_windows(study$relative_windows, traits$table)
  }
  ped <- if (!is.null(study$pedigree)) {
    read_pedigree(study$pedigree, study$stratify %||% character(), study$birth_year_bin %||% 1L)
  }
  validated <- if (!is.null(ped$pedigree)) {
    validate(ped$pedigree, file.path(dir, "pedsum"), study$threads %||% 1L,
             study$external_parent_cap %||% 30L, study$pedigree)
  }
  files <- unique(stats::na.omit(as.character(traits$table$file_path)))
  files <- files[file.exists(files)]
  trait_files <- if (length(files) > 0) {
    read_trait_files(files, ped$pedigree, study$study_end, study$stratify %||% character())
  }
  mismatches <- pin_mismatches()
  pins <- flag(rep(TRUE, length(mismatches)), "pins_mismatch",
               "the installed package differs from its pin", examples = mismatches)

  findings <- collect(s$findings, traits$findings, analyses$findings, windows$findings,
                      ped$findings, validated$findings, trait_files$findings, pins)
  inputs <- if (!has_stop(findings)) {
    list(study = study, traits = traits$table, analyses = analyses$table,
         relative_windows = windows$table, pedigree = ped$pedigree,
         validated_pedigree = validated$validated, trait_data = trait_files$data,
         population = trait_files$population)
  }
  list(findings = findings, inputs = inputs)
}

input_files <- function(study_path) {
  study <- read_study(study_path)$study
  traits <- if (!is.null(study$traits)) read_traits(study$traits)$table
  paths <- c(study = study$path, pedigree = study$pedigree, traits = study$traits,
             analyses = study$analyses, relative_windows = study$relative_windows,
             stats::setNames(unique(traits$file_path), unique(traits$file)))
  paths[file.exists(paths)]
}

run_check <- function(study_path, out, dir) {
  result <- check_inputs(study_path, dir)
  findings <- result$findings
  write_findings(findings, file.path(dir, "findings.tsv"))
  files <- input_files(study_path)
  yaml::write_yaml(list(
    step = "check",
    finished = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    stopped = has_stop(findings),
    stops = sum(findings$severity == "STOP"),
    warnings = sum(findings$severity == "WARN"),
    inputs = lapply(files, function(p) list(path = unname(p), md5 = unname(tools::md5sum(p)))),
    installed = installed_sources(),
    r_version = R.version.string
  ), file.path(dir, "run.yaml"))
  cat(paste0("  ", format_findings(findings), "\n"), sep = "")
  if (has_stop(findings)) {
    cat(sprintf("check: %d stop(s); fix them and rerun. Details in %s\n",
                sum(findings$severity == "STOP"), file.path(dir, "findings.tsv")))
    return(FALSE)
  }
  saveRDS(result$inputs, file.path(dir, "inputs.rds"))
  cat(sprintf("check: passed with %d warning(s); %d people in the study population\n",
              sum(findings$severity == "WARN"), length(result$inputs$population)))
  TRUE
}
