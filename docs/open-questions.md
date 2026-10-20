# Open questions for collaborators

Questions 1 to 5 are about choices in the kit and the shared plan; the answers may change
them. Questions 6 to 8 ask how to read the SAP's W2 window
(`SAP_Scandinavian_Genealogy.md`, sections 4.2 and 6.3). The kit needs the
answers before it can support that window. Question 9 is about how sites build the
trait files.

1. **Which relatives count.** A relative counts only if they have a row in the trait
   file, after any relatives' follow-up window. Someone without a row is unobserved,
   not unaffected. Is that what `make_epimight_tte` intends?

2. **Parents, aunts and uncles, grandparents.** The kit finds them from the pedigree, so
   an uncle younger than his nephew is still his uncle (ADR 0003). EPIMIGHT's registry
   SQL and `make_epimight_tte`'s `vertical = "older"` use birth order instead. Which
   should the kit use?

3. **One study population.** Every trait file must list the same people, and someone
   excluded from a trait keeps a censored row. Do your registers need different people
   per trait?

4. **Rename haemorrhagic stroke from `HS` to `HST`.** In
   `Definitions/Phenotype_list.tsv`, haemorrhagic stroke is abbreviated `HS`, the same
   code the kit uses for half siblings. The kit keeps the two apart, but tables and plots
   that show both are easy to misread. Could the abbreviation become `HST`? The shared
   plan (`plan/traits.tsv`, `plan/analyses.tsv`) will follow.

5. **Which multiple-birth pairs leave full siblings.** The SAP removes same-multiple-birth
   pairs from full siblings (4.1). The kit now does this itself (ADR 0005): pedsum puts
   full siblings born at most a day apart into one multiple-birth set, and the kit leaves
   every pair from one set out of `FS`. Both people stay probands and every other kind of
   relative. Is every pair right, or only same-sex pairs? The SAP gives MZ twins as the
   reason, and opposite-sex twins cannot be MZ, so they could stay in as full siblings.
   Same-sex pairs include both MZ and DZ twins, and the registers may not say which.

## The W2 window

6. **Where follow-up starts.** W2 observes everyone from 1 January 2008 and censors at 31
   December 2021, but EPIMIGHT measures age from birth and has no delayed entry, so the
   SAP estimates per birth year. What age does a W2 proband's follow-up start at? Is a
   proband who died or emigrated before 2008 left out, or kept with status 2 or 0 at
   that age?

7. **Relatives outside the window.** The SAP runs `make_epimight_tte` on everyone and then
   keeps the W2 probands, so older relatives still count. Does a relative who died or
   emigrated before 2008 count as an unaffected relative, or not at all? The kit counts
   a relative only if they have a row in the trait file (question 1), so the answer
   decides whether such relatives get a row.

8. **Who the CMD probands are.** In W2 and W3, CMD is estimated in the parents of the W2
   index persons, with their siblings and parents as relatives. Are the probands every
   parent of someone born 1985 to 2005, each counted once? Which birth-year strata do
   they fall into? Would a birth range that covers the parent generation be close
   enough? It would also take in people with no children and parents of other cohorts.

## Phenotype definitions

9. **Main and secondary diagnoses.** The SAP (section 5) counts a hospital contact when
   the code is the main (primary) diagnosis or a secondary diagnosis, and the first such
   contact sets the age at onset. Should every country count secondary diagnoses the
   same way, given that the registers may record them differently and over different
   years? Should some traits count main diagnoses only, for example ones often recorded
   in passing, such as hypertension, obesity or dyslipidaemia? And should a
   main-diagnosis-only run be a sensitivity analysis, as W3 is for inpatient diagnoses?
   The kit can't tell the two apart: each site applies the rule when it builds the
   trait files (step 0).
