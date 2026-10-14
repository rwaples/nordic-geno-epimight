# Relatives are counted by pedigree role, not birth order

Status: accepted for now (2026-10-14); to revisit with collaborators against birth order

## Context

The kit builds EPIMIGHT's input, the cohort table, so it decides who counts as a person's parent, aunt or
grandparent. EPIMIGHT's own SQL for the iPSYCH registry keeps, for vertical kinds, every
relative of that kind born before the person (`inst/extdata/sql/partials/relatives-counting.sql:57-58`
at `55803e1`), in either direction. That drops an uncle younger than his nephew and
admits an older nephew as if he were an uncle.

## Decision

Vertical relationships count by pedigree role: `PO` a person's parents, `Av` their aunts
and uncles, `1G` their grandparents, from pedigreegraph's directional pair codes (MO and
FO, Av, GP), whatever the birth dates. Sibling and cousin relationships are symmetric.

## Consequences

- Counts for `PO`, `Av` and `1G` can differ from those of iPSYCH's SQL and of
  make_epimight_tte with `vertical = "older"`, so their h² is not directly comparable.
- No relationship counts a person's children or nieces and nephews.
