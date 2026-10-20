# Where the kit falls short of the SAP

This compares the kit with version 8 of the statistical analysis plan (20 October 2026),
`SAP_Scandinavian_Genealogy.md`. Section numbers refer to the SAP.

The two agree on the core: pedsum validates the pedigree, the trait rules follow
`make_epimight_tte`, EPIMIGHT estimates h² and rg per birth-year stratum and pools them,
status is 1 diagnosis, 2 death from another cause and 0 censored, a missing parent is
`-1`, the software is pinned, and only aggregate tables leave a site. The kit already
supports every relationship the SAP uses (FS, PO, mHS, pHS, Av, 1C) and the trait2 rule
of the mental-disorder hierarchy (5.3).

## Analysis windows

The SAP runs every analysis in three windows (4.2, 6.3):

- **W1:** all available data.
- **W2:** probands born 1960 to 2007, all diagnoses, follow-up to the end of each
  country's data (DK 2023, SE 2024, NO 2021).
- **W3:** probands born 1985 to 2005, only diagnoses made 2008 to 2021, everyone
  censored at 31 December 2021. A sensitivity analysis extends the birth cohort to 2015
  for ASD.

The kit has no notion of a window. W1 needs nothing new. W2 fits the kit's per-site
`study_end` but needs a proband birth range. W3 needs all four of these:

1. **Which diagnoses count (W3).** Only diagnoses made 2008 to 2021 count, for probands
   and relatives alike, so someone first seen in 2004 and again in 2010 is a case in
   2010. That needs the diagnosis history, but a trait file has one row per person. W3
   needs its own trait files.
2. **A censoring date shared by every country (W3).** 31 December 2021. The kit's
   `study_end` is set per site, so each site would have to set it to 2021-12-31 for W3
   and nothing checks that they did.
3. **A proband birth range (W2, W3).** Probands are born 1960 to 2007 in W2, 1985 to
   2005 in W3 and 1985 to 2015 in the W3 ASD sensitivity analysis. Everyone, whatever
   their birth year, still counts as a relative. The kit takes every person with a
   trait-file row as a proband.
4. **CMD in the parent generation (W3, 4.2).** In W3, cardiometabolic traits are
   estimated in the parents of the W3 index persons, with their siblings and parents as
   relatives. The index persons are at most 36 by the end of 2021, younger than most
   CMD onsets. The kit can't define probands by their relation to another cohort.

The open design question is whether a window is part of the plan (its diagnosis years,
censoring date and proband birth range) or whether each site prepares one data folder
per window. Items 2 to 4 could be plan settings. Item 1 stays with the sites as long as
a trait file holds one row per person.

## What else the kit can't do yet

1. **Twins (4.1).** The SAP keeps sex-discordant twin pairs as full siblings and leaves
   out sex-concordant pairs. The kit leaves every pair from one multiple-birth set out
   of `FS`, whatever their sex (`kit/nordicepimight/R/relationships.R:45`, ADR 0005).
   It needs a sex test on the pair (open question 5).

2. **Probands born in the country (4.1).** People born abroad count as relatives but
   not as probands. The kit has no rule for this, and the pedigree has no column that
   records it.

3. **Three birth-cohort groupings (6.4, 6.6).** The SAP estimates every h² and rg per
   birth year, per 5-year and per 10-year birth cohort, and meta-analyses within each
   grouping. A plan has one `birth_year_bin`, and the kit's tests require the same value
   in both plan files. Three groupings need either three runs or a list of bins in one
   plan. Single years multiply the strata, and EPIMIGHT's run time at register scale is
   not yet measured.

4. **Random-effects pooling (6.6).** The kit pools with fixed effects
   (`kit/nordicepimight/R/epimight.R:7`). EPIMIGHT's random-effects weight is
   1/(se² + var(estimates)), the sample variance of the stratum estimates rather than a
   between-stratum variance such as DerSimonian-Laird's τ² (`R/Analysis-class.R:104` at
   the pinned commit `55803e1`). It also needs at least two strata
   (`R/Pipeline-class.R:257`). This needs settling before the kit switches.

5. **Mental x CVD rg with W1 h² (6.5, Table 7).** The SAP's parent-offspring rg uses
   the h² estimates from W1 in each country. The kit computes each rg from h² of the
   same run (`kit/nordicepimight/R/epimight.R:55`), so an rg in W2 or W3 would use that
   window's h² (open question 11).

6. **Combining the two rg directions (6.5).** The SAP runs rg in both directions and
   combines them. The kit reports each direction separately.

7. **Disclosure (8).** The SAP uses each country's own minimum cell size (11 in Sweden,
   5 in Denmark and Norway) and merges small cells into adjacent birth years. The kit
   has one `export_min_count` in the shared plan, its tests require the same value in
   both plan files, and it suppresses or drops small cells instead of merging.

8. **Genealogy outputs (6.1, Steps 1 and 2).** The SAP wants pedsum summarize and parent
   completeness by birth decade, for the full pedigree and the W2 and W3 cohorts. The
   kit runs only pedsum validate, and does not export its output.

9. **Descriptive statistics (6.2, Step 3).** The SAP wants incidence by birth year and
   age and by diagnosis year and age, by sex, for the whole population and the W2 and
   W3 cohorts, and prevalence among people alive and living in the country on 1
   January. Prevalence needs residence and death data the kit doesn't take.
   `R/Summarise_incidence.R` bins case counts, with no sex split and no denominators.

## Where the plan differs from the SAP

The kit supports each of these; only `plan/` has to change.

1. **Relationships (Table 6).** Full siblings are the main analysis; parent-offspring,
   maternal and paternal half siblings, aunts and uncles, and first cousins are
   additional. Grandparents are not used. The plan uses FS, HS and PO for every trait.
2. **rg pairs (Table 7).** Mental x mental and CVD x CVD use full siblings, mental x CVD
   uses parent-offspring, and a combined CVD group is not paired with its own
   components. The plan runs FS, HS and PO for every pair, and the initial plan has no
   CVD x CVD pairs.
3. **Mental-disorder hierarchy (5.3, Table 4).** MDD excludes anyone with BD, and BD
   excludes anyone with SCZ, with `exclude_trait2: any` and `trait2_action: exclude`.
   MDD and SCZ are independent. `plan/traits.tsv` has no trait2 rules yet. Whether the
   rule also applies to relatives is open question 10.
4. **Main and supplementary traits (Table 3).** `plan/traits.tsv` doesn't mark which is
   which.
5. **Phenotype codes (5).** The SAP's mapping is `ICD_codes_Mental_CVD v.14.6.2026.xlsx`,
   and the codes per country and disorder are under review. The plan's traits come from
   `Definitions/Phenotype_list.tsv`.

## Left to each site's data preparation

The kit can't check these. The README lists them under step 0.

- **Adoptions.** Links between adoptees and their adoptive parents are kept (4.1). Sites
  should not remove them.
- **Same-sex parents.** With two mothers registered, set the father ID to `-1`; with two
  fathers, set the mother ID to `-1` (4.1).
- **Cause of death.** Causes of death count as diagnoses. For CVD, the patient registers
  and the cause of death register are combined: the first record in either sets onset,
  and a CVD death is status 1, not a competing event (5.1).
- **Age limits.** Ignore MDD, BD and SCZ diagnoses before age 10 and ASD diagnoses before
  age 4; the first diagnosis from that age on sets status and age. Someone whose only
  diagnosis was before the limit is censored (0) at emigration or end of follow-up, or
  2 at death (5.2). This needs the diagnosis history.
- **ICD versions.** W3 uses ICD-10 only; W1 and W2 also use ICD-8 and ICD-9 in Denmark
  and Sweden (5.1).
- **W3 diagnosis filter.** Only diagnoses made 2008 to 2021 count (window item 1 above).

## Output format

- The SAP asks for one file per estimate, such as
  `{country}_h2_{phenotype}_{familyType}_{window}.tsv`, each with the per-stratum and
  the meta-analysed estimates for each grouping. The kit writes one long table per kind,
  which can be split.
- The SAP doesn't say which standard error to report. The kit reports the sandwich SE
  and keeps EPIMIGHT's native SE only for comparison.

## Questions for the collaborators

The analysis windows, random-effects pooling (item 4), the W1 h² in mental x CVD rg
(item 5), disclosure (item 7) and the open questions in `open-questions.md` need the
collaborators' answers.
