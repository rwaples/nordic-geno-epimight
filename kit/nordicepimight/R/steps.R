# The kit's steps run in order, each from `pixi run <step> SITE.yaml OUT/`, and write
# OUT/<n>_<step>/. A step starts only when the one before it has finished (its DONE
# marker), and starting a step deletes its own output and every later step's, so OUT/
# never mixes runs.

STEPS <- c("check", "cohort", "epimight", "tables", "report", "export")
STEP_DIRS <- stats::setNames(paste0(seq_along(STEPS), "_", STEPS), STEPS)
# Files later steps write at the top of OUT/, by the step that writes them.
TOP_LEVEL_OUTPUTS <- list(
  tables = c("h2.tsv", "rg.tsv", "cif.tsv", "cohort_summary.tsv", "run.yaml"),
  report = "report.html"
)

step_dir <- function(out, step) file.path(out, STEP_DIRS[[step]])

begin_step <- function(out, step) {
  i <- match(step, STEPS)
  if (i > 1 && !file.exists(file.path(step_dir(out, STEPS[i - 1]), "DONE"))) {
    stop(sprintf("%s has not finished in %s; run `pixi run %s` first", STEPS[i - 1], out,
                 STEPS[i - 1]), call. = FALSE)
  }
  for (later in STEPS[i:length(STEPS)]) {
    unlink(step_dir(out, later), recursive = TRUE)
    unlink(file.path(out, TOP_LEVEL_OUTPUTS[[later]]))
  }
  dir <- step_dir(out, step)
  dir.create(dir, recursive = TRUE)
  dir
}

finish_step <- function(out, step) {
  writeLines(format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), file.path(step_dir(out, step), "DONE"))
}

# Each step's function, looked up when a step runs.
step_functions <- function() {
  list(check = run_check, cohort = run_cohort, epimight = run_epimight, tables = run_tables,
       report = run_report, export = run_export)
}

# `pixi run <command> ...`: a step, every step in order (study), or the self-test.
main <- function(command, args = commandArgs(trailingOnly = TRUE)) {
  if (command == "selftest") {
    if (length(args) != 1) stop("usage: pixi run selftest OUT/", call. = FALSE)
    quit(status = if (run_selftest(args[1])) 0 else 1, save = "no")
  }
  if (command == "study") {
    return(invisible(run_study(args)))
  }
  if (!(command %in% STEPS)) stop(sprintf("unknown step %s", command), call. = FALSE)
  run_step(command, step_functions()[[command]], args)
}

# pixi run study SITE.yaml OUT/: every step in order, stopping at the first that fails.
run_study <- function(args = commandArgs(trailingOnly = TRUE)) {
  for (step in STEPS) {
    cat(sprintf("== %s\n", step))
    run_step(step, step_functions()[[step]], args)
  }
  invisible(TRUE)
}

# One step: reads `SITE.yaml OUT/` from the command line, runs
# `fun(study_path, out, dir)` in a fresh step directory, and marks it done when `fun`
# returns TRUE. Exits 1 otherwise.
run_step <- function(step, fun, args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 2) {
    stop(sprintf("usage: pixi run %s SITE.yaml OUT/", step), call. = FALSE)
  }
  study_path <- args[1]
  out <- sub("/+$", "", args[2])
  if (!file.exists(study_path)) stop(sprintf("%s not found", study_path), call. = FALSE)
  if (step != "check" && file.exists(file.path(step_dir(out, "check"), "DONE"))) {
    changed <- changed_inputs(study_path, out)
    if (length(changed) > 0) {
      stop(sprintf("these inputs differ from what `pixi run check` saw in %s; rerun it:\n  %s",
                   out, paste(changed, collapse = "\n  ")), call. = FALSE)
    }
  }
  dir <- begin_step(out, step)
  ok <- fun(study_path, out, dir)
  if (isTRUE(ok)) {
    finish_step(out, step)
  } else {
    quit(status = 1, save = "no")
  }
  invisible(ok)
}
