# The eight relationships an analysis may name (ADR 0003, D13): the pedigreegraph pair
# codes each one sums, whether only the person's elders count (directional: the person is
# the pair's first member, the offspring, descendant or niece/nephew), and the relatedness
# EPIMIGHT uses, twice the nominal kinship. pedigreegraph gets no twin links, so twins
# come out as FS pairs, and relative_pairs leaves same-multiple-birth pairs out of FS.

RELATIONSHIPS <- data.table::data.table(
  relationship = c("PO", "FS", "HS", "mHS", "pHS", "Av", "1G", "1C"),
  pair_codes = list(c("MO", "FO"), "FS", c("MHS", "PHS"), "MHS", "PHS", "Av", "GP", "1C"),
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

# Each person's relatives for the given relationships, from the validated pedigree (its
# ids are text): data.table(person_id, relative_id, relationship). A directional
# relationship lists only the person's elders (the pair's second member); the others list
# every pair both ways. Two members of one multiple-birth set are not FS (SAP 4.1); they
# stay probands and every other kind of relative. Only full sibs share a set.
relative_pairs <- function(pedigree, relationships) {
  ids <- pedigree$id
  graph <- pedigreegraph::pedigree_graph(data.frame(
    id = seq_along(ids), mother = chmatch(pedigree$mother, ids),
    father = chmatch(pedigree$father, ids)
  ))
  wanted <- RELATIONSHIPS[relationship %in% relationships]
  pairs <- as.data.table(pedigreegraph::relationship_pairs(
    graph, categories = unique(unlist(wanted$pair_codes)), progress = FALSE
  ))
  pairs[, code := as.character(code)]
  birth_set <- pedigree$multiple_birth_set
  if (is.null(birth_set)) {
    stop("the checked pedigree has no multiple_birth_set column; rerun the check step",
         call. = FALSE)
  }
  pairs <- pairs[!(code == "FS" & fcoalesce(birth_set[first_id] == birth_set[second_id], FALSE))]
  out <- rbindlist(lapply(seq_len(nrow(wanted)), function(i) {
    p <- pairs[code %in% wanted$pair_codes[[i]]]
    both <- if (wanted$directional[i]) {
      p[, .(person = first_id, relative = second_id)]
    } else {
      rbind(p[, .(person = first_id, relative = second_id)],
            p[, .(person = second_id, relative = first_id)])
    }
    unique(both[person != relative])[, relationship := wanted$relationship[i]]
  }))
  out[, .(person_id = ids[person], relative_id = ids[relative], relationship)]
}
