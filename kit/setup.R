# pixi run setup
#
# Setup: builds epimight and pedigreegraph from their pinned GitHub commits
# (kit/nordicepimight/inst/pins.yaml) into this pixi environment, then installs the kit's own
# package. A package already built from its pinned commit is kept, so rerunning is cheap.
# Needs internet access the first time; pedigreegraph compiles Rust (a few minutes).

pinned <- yaml::read_yaml("kit/nordicepimight/inst/pins.yaml")

# Everything below installs into .libPaths()[1], which must be this environment's library
# (pixi.toml sets R_LIBS_USER=NULL); a library ahead of it would take the installs.
env_lib <- normalizePath(R.home("library"), winslash = "/")
if (!identical(normalizePath(.libPaths()[1], winslash = "/"), env_lib)) {
  stop(sprintf(paste("R would install into %s, not this environment's library %s. Run",
                     "setup with `pixi run setup`, and take R_LIBS out of ~/.Renviron."),
               .libPaths()[1], env_lib), call. = FALSE)
}

built_from <- function(pkg) {
  desc <- suppressWarnings(utils::packageDescription(pkg))
  if (is.list(desc)) desc$RemoteSha %||% NA_character_ else NA_character_
}

install_pinned <- function(pkg) {
  pin <- pinned[[pkg]]
  if (identical(built_from(pkg), pin$commit)) {
    message(sprintf("%s %s already built from %s", pkg, pin$version, substr(pin$commit, 1, 7)))
    return(invisible())
  }
  message(sprintf("building %s %s from %s@%s", pkg, pin$version, pin$repo,
                  substr(pin$commit, 1, 7)))
  # build = FALSE installs from the unpacked repository: pedigreegraph's Rust crate depends
  # on the repository's core crate by a path outside r/, which a built tarball would drop.
  remotes::install_github(
    pin$repo, ref = pin$commit, subdir = pin$subdir, build = FALSE,
    dependencies = FALSE, upgrade = "never", force = TRUE, quiet = FALSE
  )
  if (!identical(built_from(pkg), pin$commit)) {
    stop(sprintf("%s did not install from %s", pkg, pin$commit), call. = FALSE)
  }
}

# Windows only: conda-forge's Matrix 1.7-6 (r45h5ea86f4_0) calls BLAS and LAPACK through
# 32-bit runtime pseudo-relocations, so a process that loads it dies with "32 bit pseudo
# relocation ... out of range" whenever Windows maps Matrix.dll more than 2 GB from MKL,
# about one start in 20 once survival, pedigreegraph and the tidyverse are loaded. Built
# here from CRAN's source of the same version, its calls go through import thunks. The
# stamp in the package folder holds the build's Built field, which any other build of
# Matrix (a pixi reinstall or upgrade) changes, so only this build passes.
rebuild_matrix_on_windows <- function() {
  if (.Platform$OS.type != "windows") {
    return(invisible())
  }
  # Missing or half-written when a rebuild was stopped partway.
  if (!is.list(suppressWarnings(utils::packageDescription("Matrix", lib.loc = env_lib)))) {
    stop(paste("Matrix is missing or broken in the pixi environment, most likely because its",
               "rebuild was stopped. Delete", file.path(env_lib, "Matrix"), "and run",
               "`pixi reinstall r-matrix`, then `pixi run setup` again."), call. = FALSE)
  }
  stamp <- function() file.path(find.package("Matrix"), "kit-built-from-source")
  built <- function() utils::packageDescription("Matrix")$Built
  version <- utils::packageDescription("Matrix")$Version
  if (file.exists(stamp()) && identical(readLines(stamp()), built())) {
    message(sprintf("Matrix %s already built from source", version))
    return(invisible())
  }
  message(sprintf(paste("building Matrix %s from CRAN's source",
                        "(conda-forge's Windows build can crash on load)"), version))
  # Built in a folder of its own, so a build that fails or crashes leaves conda's Matrix
  # in place; it replaces conda's only once it is complete.
  staging <- tempfile("matrix-build-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  # remotes returns NA, not an error, when the download fails.
  installed <- remotes::install_version("Matrix", version, repos = "https://cloud.r-project.org",
                                        lib = staging, dependencies = FALSE, upgrade = "never",
                                        quiet = FALSE)
  new <- suppressWarnings(utils::packageDescription("Matrix", lib.loc = staging))
  if (!identical(unname(installed), "Matrix") || !is.list(new) ||
        !identical(new$Version, version)) {
    stop(sprintf(paste("Matrix %s did not build from CRAN's source; conda's build is still",
                       "installed. The end of the output above says why."), version),
         call. = FALSE)
  }
  target <- file.path(env_lib, "Matrix")
  aside <- paste0(target, ".conda")
  unlink(aside, recursive = TRUE)
  if (!file.rename(target, aside)) {
    stop(sprintf("can't move %s aside to replace it; close any R that has Matrix loaded",
                 target), call. = FALSE)
  }
  if (!file.copy(file.path(staging, "Matrix"), env_lib, recursive = TRUE)) {
    unlink(target, recursive = TRUE)
    file.rename(aside, target)
    stop(sprintf("can't copy the built Matrix into %s; conda's build is back", env_lib),
         call. = FALSE)
  }
  unlink(aside, recursive = TRUE)
  writeLines(built(), stamp())
}

rebuild_matrix_on_windows()
install_pinned("pedigreegraph")
install_pinned("epimight")

# The kit's commit and `git describe`, which run.yaml records: from the image build
# (container/build.sh sets both variables), else from git when this folder is the top of
# its own checkout, so an enclosing repository is never read. `-dirty` marks changed or
# untracked files under kit/. NULL when neither knows.
source_stamp <- function() {
  env <- Sys.getenv(c("KIT_COMMIT", "KIT_VERSION"))
  if (all(nzchar(env))) {
    return(unname(env))
  }
  git <- function(...) {
    tryCatch(system2("git", c(...), stdout = TRUE, stderr = FALSE),
             error = function(e) NULL, warning = function(w) NULL)
  }
  if (!identical(git("rev-parse", "--show-prefix"), "")) {
    return(NULL)
  }
  commit <- git("rev-parse", "HEAD")
  version <- git("describe", "--tags", "--always")
  if (length(commit) != 1 || length(version) != 1) {
    return(NULL)
  }
  dirty <- length(git("status", "--porcelain", "--", "kit")) > 0
  c(commit, paste0(version, if (dirty) "-dirty"))
}

message("installing nordicepimight")
stamp <- source_stamp()
stamped <- file.path(tempfile(), "nordicepimight")
dir.create(dirname(stamped))
file.copy("kit/nordicepimight", dirname(stamped), recursive = TRUE)
if (!is.null(stamp)) {
  cat(sprintf("RemoteSha: %s\nRemoteRef: %s\n", stamp[1], stamp[2]),
      file = file.path(stamped, "DESCRIPTION"), append = TRUE)
}
install.packages(stamped, repos = NULL, type = "source", quiet = TRUE)

library(nordicepimight)
problems <- pin_mismatches()
if (length(problems) > 0) stop(paste(problems, collapse = "\n"), call. = FALSE)
if (!("run_h2_pooled" %in% names(epimight::Pipeline$public_methods))) {
  stop("the installed epimight has no Pipeline$run_h2_pooled", call. = FALSE)
}
versions <- vapply(pinned, `[[`, "", "version")
message("setup done: ", paste(names(pinned), versions, collapse = ", "))
