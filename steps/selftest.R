# pixi run selftest OUT/
#
# Runs the kit on the toy study in selftest/ and compares every result with values the kit
# did not compute. Prints one PASS, FAIL or SKIP line per item; exits 1 when any fails.

suppressPackageStartupMessages(library(nordicepimight))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("usage: pixi run selftest OUT/", call. = FALSE)
quit(status = if (run_selftest(args[1])) 0 else 1, save = "no")
