# The eight relationships an analysis may name (ADR 0003, D13): the pedigreegraph pair
# codes each one sums, whether only the person's elders count (directional: the person is
# the pair's first member, the offspring, descendant or niece/nephew), and the relatedness
# EPIMIGHT uses, twice the nominal kinship (FS folds in MZ twins at the full-sib value).

RELATIONSHIPS <- data.table::data.table(
  relationship = c("PO", "FS", "HS", "mHS", "pHS", "Av", "1G", "1C"),
  pair_codes = list(c("MO", "FO"), c("FS", "MZ"), c("MHS", "PHS"), "MHS", "PHS", "Av", "GP", "1C"),
  directional = c(TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE),
  relatedness = c(0.5, 0.5, 0.25, 0.25, 0.25, 0.25, 0.25, 0.125)
)
RELATIONSHIP_CHOICE <- sprintf("relationship must be one of %s",
                               paste(RELATIONSHIPS$relationship, collapse = ", "))

# The kinship degree the sandwich's max_degree must reach for each relationship.
relationship_degree <- function(relationship) {
  categories <- pedigreegraph::relationship_categories()
  degree <- stats::setNames(categories$degree, categories$code)
  codes <- RELATIONSHIPS$pair_codes[match(relationship, RELATIONSHIPS$relationship)]
  vapply(codes, function(c) if (is.null(c)) NA_real_ else max(degree[c]), numeric(1))
}
