# Where the kit falls short of the SAP

This compares the kit with the first-pass statistical analysis plan,
`Firstpass_SAP_Scandinavian_Genealogy.txt`. Section numbers refer to the SAP.

The two agree on the core: pedsum validates the pedigree, the trait rules follow
`make_epimight_tte`, EPIMIGHT estimates h² and rg per birth-year stratum and pools them,
status is 1 diagnosis, 2 death and 0 censored, a missing parent can be `-1`, the software
is pinned, and only aggregate tables leave a site.

## Analysis windows

The SAP runs every analysis in four windows, W1 to W4 (4.2, 6.3). W2 is primary for
comparisons between countries, and W4 is run by Denmark and Sweden only. The kit has no
notion of a window. A window sets four things the kit can't express yet:

1. **Which diagnoses count.** Only diagnoses made inside the window's years count, for
   probands and relatives alike, so someone first seen in 2004 and again in 2010 is a
   case in 2010. That needs the diagnosis history, but a trait file has one row per
   person. Each window would need its own trait files.
2. **A censoring date shared by every country.** 31 December 2021 in W2 and W3, 31
   December 2023 in W4. The kit's `study_end` is set per site.
3. **A proband birth range.** Probands are born 1985 to 2005 in W2 and W3 and 1932 to
   2007 in W4. Everyone, whatever their birth year, still counts as a relative. The kit
   takes every person with a trait-file row as a proband.
4. **CMD in the parent generation (4.2).** In W2 and W3, cardiometabolic traits are
   estimated in the parents of the W2 index persons, with their siblings and parents as
   relatives. The index persons are at most 36 by the end of 2021, younger than most CMD
   onsets, while their parents are about 30 to 85 during 2008 to 2021. W4 index persons
   reach age 91, so W4 estimates CMD in the index persons themselves. The kit can't
   define probands by their relation to another cohort.

The open design question is whether a window is part of the plan (its diagnosis years,
censoring date, proband birth range and the countries that run it) or whether each site
prepares one data folder per window. Items 2 to 4 could be plan settings. Item 1 stays
with the sites as long as a trait file holds one row per person.

## What else the kit can't do yet

1. **Probands born in the country (4.1).** People born abroad count as relatives but
   not as probands. The kit has no rule for this, and the pedigree has no column that
   records it.

2. **Random-effects pooling across birth years (6.6).** The kit pools with fixed effects
   (`kit/nordicepimight/R/epimight.R:7`). EPIMIGHT's random-effects weight is
   1/(se² + var(estimates)), the sample variance of the stratum estimates rather than a
   between-stratum variance such as DerSimonian-Laird's τ² (`R/Analysis-class.R:104` at
   the pinned commit `55803e1`). It also needs at least two strata
   (`R/Pipeline-class.R:257`). This needs settling before the kit switches.

3. **Combining the two rg directions (6.5).** The SAP runs rg in both directions and
   combines them. The kit reports each direction separately.

4. **Disclosure (8).** The SAP uses each country's own minimum cell size (11 in Sweden,
   5 in Denmark and Norway) and merges small cells into adjacent birth years. The kit
   has one `export_min_count` in the shared plan, its tests require the same value in
   both plan files, and it suppresses or drops small cells instead of merging.

5. **Genealogy outputs (6.1, Steps 1 and 2).** The SAP wants pedsum summarize and parent
   completeness by birth decade, for the full pedigree and the W2 and W4 cohorts. The
   kit runs only pedsum validate, and does not export its output.

6. **Descriptive statistics (6.2, Step 3).** The SAP wants incidence by birth year and
   age and by diagnosis year and age, by sex, and prevalence among people alive and
   living in the country on 1 January. Prevalence needs residence and death data the
   kit doesn't take. `R/Summarise_incidence.R` bins case counts, with no sex split and
   no denominators.

## Where the plan differs from the SAP

The kit supports each of these; only `plan/` has to change.

1. **Relationships (Table 5).** For mental traits the primary is full siblings, with
   parents, maternal and paternal half siblings, first cousins, aunts and uncles, and
   grandparents as replication. The plan uses FS, HS and PO for every trait. The SAP
   leaves the CMD row of Table 5 empty.
2. **rg pairs (6.5).** Mental x mental uses full siblings, mental x CMD uses the index
   person and their parent, and an extra analysis pairs the supplementary CVD traits
   (not the combined ones). The plan runs FS, HS and PO for every pair.
3. **Birth-year strata (6.3, 6.4).** The SAP estimates per birth year; the plan uses
   5-year bins. Single years multiply the strata, and EPIMIGHT's run time at register
   scale is not yet measured.
4. **Main and supplementary traits (Table 3).** `plan/traits.tsv` doesn't mark which is
   which.

## Left to each site's data preparation

The kit can't check these. The README lists them under step 0:

- Remove adoptive links from parent-offspring and sibling relationships.
- Same-sex parents: keep the birth mother where known and set the other parent missing.
- Ignore MDD, BD and SCZ diagnoses before age 10. This needs the diagnosis history.
- Remove same-multiple-birth pairs from full siblings (4.1). The kit finds full siblings
  in the pedigree and counts MZ twins among them
  (`kit/nordicepimight/R/relationships.R:8`), so a site can only do this by leaving one
  twin of each pair out of the trait files. Open question 5 asks whether that is
  acceptable.
- The lower age limit for ASD is still open in the SAP.

The SAP proposes removing anyone ever diagnosed with BD from MDD cases. The kit's
`exclude_trait2: any` drops those people instead of keeping them as non-cases, and its
competing-risk action needs `before`, so the proposed competing-risk sensitivity
analysis can't use "ever".

## Output format

- The SAP asks for one file per estimate, such as
  `{country}_h2_{phenotype}_{familyType}_{window}.tsv`. The kit writes one long table
  per kind, which can be split.
- The SAP doesn't say which standard error to report. The kit reports the sandwich SE
  and keeps EPIMIGHT's native SE only for comparison.

## Questions for the collaborators

The analysis windows, random-effects pooling (item 2), disclosure (item 4), the rg pairs
and the handling of twins (open question 5) need the collaborators' answers.
