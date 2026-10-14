# Open questions for collaborators

The kit made a choice on each of these. The answers may change it.

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
