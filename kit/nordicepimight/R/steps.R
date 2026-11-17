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

# The Apptainer image sets KIT_IN_IMAGE (container/nordicepimight.def), so messages name
# the command the user ran: `pixi run` from a checkout, `apptainer run IMAGE` in the image.
in_image <- function() nzchar(Sys.getenv("KIT_IN_IMAGE"))
kit_command <- function(image = in_image()) if (image) "apptainer run IMAGE" else "pixi run"

# Inside the image the kit sees only the home folder, the current folder, /tmp and the
# folders named with --bind, so a file that exists on the server can look missing. A link
# is followed inside the image, so its target must be bound, not the folder the link is in.
BIND_HINT <- paste(
  "The image sees only your home folder, the current folder, /tmp and the folders you",
  "name with --bind. If the file or folder exists, bind the folder it is in:",
  "apptainer run --bind /path/to/folder IMAGE ...",
  "If the path is a link, or passes through one, bind the folder the link points to."
)

# Creates an output folder. In the image, a folder that can't be created is most often
# under a folder not bound with --bind: the image itself is read-only.
create_out_dir <- function(dir, image = in_image()) {
  if (!dir.exists(dir) && !dir.create(dir, recursive = TRUE, showWarnings = FALSE)) {
    stop(paste(sprintf("can't create the output folder %s.", dir),
               if (image) BIND_HINT else "Check that you may write there."), call. = FALSE)
  }
  dir
}

begin_step <- function(out, step) {
  i <- match(step, STEPS)
  if (i > 1 && !file.exists(file.path(step_dir(out, STEPS[i - 1]), "DONE"))) {
    stop(sprintf("%s has not finished in %s; run `%s %s` first", STEPS[i - 1], out,
                 kit_command(), STEPS[i - 1]), call. = FALSE)
  }
  for (later in STEPS[i:length(STEPS)]) {
    unlink(step_dir(out, later), recursive = TRUE)
    unlink(file.path(out, TOP_LEVEL_OUTPUTS[[later]]))
  }
  create_out_dir(step_dir(out, step))
}

finish_step <- function(out, step) {
  writeLines(format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), file.path(step_dir(out, step), "DONE"))
}

# Each step's function, looked up when a step runs.
step_functions <- function() {
  list(check = run_check, cohort = run_cohort, epimight = run_epimight, tables = run_tables,
       report = run_report, export = run_export)
}

# The commands a user can type. The image's runscript adds template, pedsum and help.
kit_commands <- function(image = in_image()) {
  c("study", STEPS, "selftest", if (image) c("template", "pedsum", "help"))
}

# local/example.yaml as a site file for the image: its checkout-only header comments
# dropped and its plan path pointing into the image, keeping the comment column.
site_template <- function(example) {
  lines <- readLines(example)
  body <- lines[cumsum(!startsWith(lines, "#")) > 0]
  m <- regmatches(body, regexec("^plan: \\.\\./plan/(\\S+)( *)(.*)$", body))
  i <- which(lengths(m) > 0)
  if (length(i) != 1) stop(sprintf("%s has no `plan: ../plan/...` line", example), call. = FALSE)
  plan <- m[[i]]
  # /opt/kit/plan/ is 6 characters longer than ../plan/; at least one space before a comment.
  pad <- if (plan[4] == "") "" else strrep(" ", max(1, nchar(plan[3]) - 6))
  body[i] <- paste0("plan: /opt/kit/plan/", plan[2], pad, plan[4])
  c("# Site file for the nordic-geno-epimight image. Name with --bind every folder below",
    "# that is not under your home folder, the current folder or /tmp.", body)
}

# `pixi run <command> ...`: a step, every step in order (study), or the self-test.
main <- function(command, args = commandArgs(trailingOnly = TRUE)) {
  if (command == "selftest") {
    if (length(args) != 1) stop(sprintf("usage: %s selftest OUT/", kit_command()), call. = FALSE)
    quit(status = if (run_selftest(args[1])) 0 else 1, save = "no")
  }
  if (command == "study") {
    return(invisible(run_study(args)))
  }
  if (command == "template") {
    return(invisible(cat(site_template("local/example.yaml"), sep = "\n")))
  }
  if (!(command %in% STEPS)) {
    stop(sprintf("unknown command %s; the commands are %s", command,
                 paste(kit_commands(), collapse = ", ")), call. = FALSE)
  }
  run_step(command, step_functions()[[command]], args)
}

# pixi run study SITE.yaml OUT/: every step in order, stopping at the first that fails.
run_study <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 2) {
    stop(sprintf("usage: %s study SITE.yaml OUT/", kit_command()), call. = FALSE)
  }
  for (step in STEPS) {
    cat(sprintf("== %s\n", step))
    run_step(step, step_functions()[[step]], args)
  }
  invisible(TRUE)
}

# Stops when this kit is not the one the check step ran with, so the kit run.yaml names
# made every step of the run.
stop_if_kit_changed <- function(out, now = kit_source()) {
  was <- yaml::read_yaml(file.path(step_dir(out, "check"), "run.yaml"))$kit
  label <- function(kit) {
    sprintf("%s, commit %s", kit$version %||% "not recorded", kit$commit %||% "not recorded")
  }
  if (label(was) != label(now)) {
    stop(sprintf("`%s check` ran in %s with another kit (%s); this one is %s. Rerun it",
                 kit_command(), out, label(was), label(now)), call. = FALSE)
  }
}

# One step: reads `SITE.yaml OUT/` from the command line, runs
# `fun(study_path, out, dir)` in a fresh step directory, and marks it done when `fun`
# returns TRUE. Exits 1 otherwise.
run_step <- function(step, fun, args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 2) {
    stop(sprintf("usage: %s %s SITE.yaml OUT/", kit_command(), step), call. = FALSE)
  }
  study_path <- args[1]
  out <- sub("/+$", "", args[2])
  if (!file.exists(study_path)) {
    stop(paste(sprintf("%s not found.", study_path), if (in_image()) BIND_HINT),
         call. = FALSE)
  }
  if (step != "check" && file.exists(file.path(step_dir(out, "check"), "DONE"))) {
    changed <- changed_inputs(study_path, out)
    gone <- changed[!file.exists(changed)]
    if (length(gone) > 0) {
      stop(paste(sprintf("these inputs `%s check` read in %s are not found now:\n  %s",
                         kit_command(), out, paste(gone, collapse = "\n  ")),
                 if (in_image()) paste0("\n", BIND_HINT)), call. = FALSE)
    }
    if (length(changed) > 0) {
      stop(sprintf("these inputs differ from what `%s check` saw in %s; rerun it:\n  %s",
                   kit_command(), out, paste(changed, collapse = "\n  ")), call. = FALSE)
    }
    stop_if_kit_changed(out)
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
