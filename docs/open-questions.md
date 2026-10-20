# Open questions for collaborators

These refer to version 8 of the SAP (`SAP_Scandinavian_Genealogy.md`, 20 October 2026).
Questions 1 to 5 are about choices in the kit and the shared plan; the answers may change
them. Questions 6 to 8 ask how to read the SAP's W3 window (sections 4.2 and 6.3). The
kit needs the answers before it can support that window. Question 9 is about how sites
build the trait files. Questions 10 to 12 come from new rules in version 8.

1. **Which relatives count.** A relative counts only if they have a row in the trait
   file, after any relatives' follow-up window. Someone without a row is unobserved,
   not unaffected. Is that what `make_epimight_tte` intends?

2. **Parents, aunts and uncles.** The kit finds them from the pedigree, so an uncle
   younger than his nephew is still his uncle (ADR 0003). EPIMIGHT's registry SQL and
   `make_epimight_tte`'s `vertical = "older"` use birth order instead. Which should the
   kit use?

3. **One study population.** Every trait file must list the same people, and someone
   excluded from a trait keeps a censored row. Do your registers need different people
   per trait?

4. **Rename haemorrhagic stroke from `HS` to `HST`.** In
   `Definitions/Phenotype_list.tsv`, haemorrhagic stroke is abbreviated `HS`, the same
   code the kit uses for half siblings. The kit keeps the two apart, but tables and plots
   that show both are easy to misread. Could the abbreviation become `HST`? The shared
   plan (`plan/traits.tsv`, `plan/analyses.tsv`) will follow.

5. **Which twin pairs leave full siblings.** Version 8 settles the main question (4.1):
   sex-discordant twin pairs stay full siblings and sex-concordant pairs are left out.
   The kit still leaves every pair of a multiple-birth set out of `FS` (ADR 0005) and
   will change. Two details remain:
   - Does "left out" mean out of `FS` only, or out of every relationship? The kit now
     keeps both people as probands and as every other kind of relative.
   - In a set of three or more, is each pair judged by its own sexes, so a
     brother-sister pair from mixed-sex triplets stays in?

## The W3 window

6. **Where follow-up starts.** W3 observes everyone from 1 January 2008 and censors at 31
   December 2021, but EPIMIGHT measures age from birth and has no delayed entry, so the
   estimates are per birth cohort. What age does a W3 proband's follow-up start at? Is a
   proband who died or emigrated before 2008 left out, or kept with status 2 or 0 at
   that age?

7. **Relatives outside the window.** The SAP runs `make_epimight_tte` on everyone and then
   keeps the W3 probands, so older relatives still count. Does a relative who died or
   emigrated before 2008 count as an unaffected relative, or not at all? The kit counts
   a relative only if they have a row in the trait file (question 1), so the answer
   decides whether such relatives get a row.

8. **Who the CMD probands are.** In W3, CMD is estimated in the parents of the W3 index
   persons, with their siblings and parents as relatives. Are the probands every parent
   of someone born 1985 to 2005, each counted once? Which birth-year strata do they fall
   into? Would a birth range that covers the parent generation be close enough? It would
   also take in people with no children and parents of other cohorts. In W1 and W2, is
   CMD estimated in the index persons themselves?

## Phenotype definitions

9. **Main and secondary diagnoses.** The SAP (5.1) counts a hospital contact when the
   code is the main (primary) diagnosis or a secondary diagnosis, and the first such
   contact sets the age at onset. Should every country count secondary diagnoses the
   same way, given that the registers may record them differently and over different
   years? Should some traits count main diagnoses only, for example ones often recorded
   in passing, such as hypertension, obesity or dyslipidaemia? And should a
   main-diagnosis-only run be a sensitivity analysis? The kit can't tell the two apart:
   each site applies the rule when it builds the trait files (step 0).

## New in version 8

10. **The hierarchy and relatives.** Table 4 takes people with BD out of the MDD cohort,
    and people with SCZ out of the BD cohort. Does that apply to relatives too? With the
    trait's `filter_relatives` set, the kit drops those people as relatives as well;
    without it, a relative with BD and MDD still counts as an MDD-affected relative
    (`kit/nordicepimight/R/rules.R:73`).

11. **W1 h² in mental x CVD rg.** Table 7 says the parent-offspring rg uses h² estimates
    from W1 in each country. Does that hold for the W2 and W3 rg too, so that a W3 rg
    combines W3 cross-trait risks with W1 h²? EPIMIGHT computes rg from the h² of the
    same data, so mixing windows means passing W1's h² in from outside.

12. **Prevalence files.** Section 6.2 still asks for prevalence, but its list of files to
    return names only the two incidence files; the earlier draft also listed
    `{country}_lexisData_prevalence_YODx_{window}.tsv` and
    `{country}_lexisData_prevalence_YOB_{window}.tsv`. Should the prevalence files still
    be returned?
