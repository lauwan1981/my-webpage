# Terra active-valley margin study (v4)

MATLAB code for the simulations of the manuscript "柔性航天器闭环裕度竞争的活动低谷跟踪与整改方向判定"
(V5.3). It computes the weighted actuator-end return-difference diagnostic
f_W(ω) = σ_min(W_u⁻¹ F_u(jω) W_u) of a flexible spacecraft, finds and tracks every
frequency valley, locates and qualifies dominant switches of the active valley, validates
the one-sided directional derivatives, compares remediation screening rules, and writes
Tables 1 and 2, Figures 1 to 3 and the supplementary figures.

This version replaces `Terra_research_v3.m`. The review of v3 and the change plan are in
[REVIEW_AND_PLAN.md](REVIEW_AND_PLAN.md) (Chinese). A web page with the main results and all
figures is [index.html](index.html); it is served by GitHub Pages once Pages is enabled for
this repository.

## Requirements

- MATLAB R2015a or later, base MATLAB only. No toolbox is used (no Control System Toolbox,
  no Optimization Toolbox).
- The same code runs in GNU Octave. The archived results in `results_octave_full/` were
  produced with GNU Octave 10.3.0.
- All `.m` files are ASCII, so they read correctly with any MATLAB default character set
  (for example GBK on Chinese Windows).

## Running

```matlab
cd my-webpage                         % the folder that contains run_terra_study.m
results = run_terra_study('check');   % model self-checks only, a few seconds
results = run_terra_study('quick');   % smoke test of the whole pipeline, about 5 min
results = run_terra_study('full');    % publication run, about 15 min (Octave 10.3)
```

Each run writes a new folder `terra_results_v4_<yyyymmdd_HHMMSS>` (quick runs:
`terra_results_v4_quick_...`) in the current folder and never overwrites an earlier one.
Quick-mode numbers come from reduced grids and case lists. They are not publication data, and
the report says so.

Long runs can be paused and resumed:

```matlab
results = run_terra_study('full', struct('timeBudgetSeconds', 600));   % pauses at a checkpoint
results = run_terra_study('full', struct('resumeDirectory', results.outputDirectory));
```

A checkpoint is written after every step and every case. A run must be resumed with the same
interpreter, version and platform, because Table 2 compares wall times inside one run.
`results.isComplete` tells whether all steps finished.

To redraw the figures from saved results without recomputing:

```matlab
stored = load('results_octave_full/data/results.mat');
results = stored.results;
results.outputDirectory = 'replot';          % any writable folder
terra.plotStudyFigures(results);
```

## Outputs

| Path | Content |
| --- | --- |
| `report.txt` | All findings with their evidence level (exact, numerical, empirical, assumption) |
| `manifest.txt` | Interpreter, platform, every configuration value, list of produced files |
| `tables/tables.md` | Formatted Tables 1 and 2 with notes, ready for the manuscript |
| `tables/table1_cases.csv` | Table 1, every number |
| `tables/table2_dense_baseline.csv` | Table 2 per case: detection, errors, evaluations, times, tail bounds, crossover check |
| `tables/table2_switch_locations.csv` | Switch-location error of the method and of the dense baseline |
| `tables/remediation_cases.csv`, `remediation_summary.csv` | Decision of every screening rule per case, statistics per case family |
| `tables/path_valleys.csv`, `path_summary.csv`, `switches.csv` | Every valley on the parameter paths, envelopes, switch qualification |
| `tables/derivative_validation.csv`, `drift_risk.csv` | Secant checks of the one-sided derivatives, drift-risk table |
| `tables/stability.csv`, `model_comparison.csv`, `mode_removal_counterfactual.csv` | Exact-delay stability, full vs design model, single-mode removal |
| `figures/Fig1..Fig3, FigS1..FigS4` (`.png` 300 dpi and `.eps`) | Figures, 17.5 cm wide; `figure_captions.txt` holds the caption facts |
| `data/results.mat` | The complete results structure |
| `data/model_statespace.mat` | Raw state-space matrices, modal data and port definitions |

## Manuscript traceability

| Manuscript item | Functions | Outputs |
| --- | --- | --- |
| 2.1 model, loop broken at the actuator command, F_u, F_y | `buildSpacecraftModel`, `buildPlantModel`, `evaluateLoopChannels`, `evaluateLoopResponse`, `evaluateMeasurementEndDiagnostic` | report section 3 |
| 2.1(3) design model and residual dynamics, E_res | `selectDesignModes`, `analyzeModelComparison` | Figure 1, `model_comparison.csv` |
| 2.2 actuator scaling W_u (primary and alternate) | `applyActuatorScaling`, `buildDiagnosticKernel` | Figures 1, 2 |
| 3.1 valley discovery, branches, switches | `discoverFrequencyValleys`, `brentMinimize`, `trackValleyBranches`, `locateDominantSwitches` | Figure 2, `switches.csv` |
| 3.2 one-sided derivatives d±, D±, R±, screening rules | `computeSingularValueSensitivity`, `computeEnvelopeSensitivity`, `computeReturnDifferenceDerivative`, `computeDriftRisk` | `drift_risk.csv`, Table 1 |
| 3.3 independent dense baseline, equal error, cost | `runIndependentReference`, `compareWithDenseBaseline`, `compareSwitchLocations` | Table 2, Figure S1 |
| 4.1 predeclared cases, exact-delay stability | `createCaseDefinitions`, `assessClosedLoopStability`, `computeCommonDelayMargin`, `computeDelaySystemRoots`, `computeTailBounds` | `stability.csv`, Figure S2(b) |
| 4.2 Table 1, Figure 3, engineering outputs | `runShowcaseExperiments`, `evaluateResponseMetrics`, `simulateDisturbanceResponse`, `guaranteedMultiloopMargins` | Table 1, Figure 3 |
| 4.3 secant validation, residual-dynamics levels | `validateDirectionalDerivatives`, `analyzeRemediationCase` | Figure 2(c, d), Figure S3, report sections 5 and 7 |
| Remediation comparison (all rules, equal budgets) | `analyzeRemediationCase`, `selectVerifiedMove`, `summarizeRemediation` | Figure S2(a), `remediation_*.csv` |
| Residual-mode path (third cantilever mode ±20 %) | `scanParameterPath`, `trackValleyBranches` | Figure S4 |
| Self-checks before any result | `verifyModelConsistency` | report section 2 |

## Code organisation

- `run_terra_study.m`: entry point. Everything else is in the package `+terra`, called as
  `terra.<function>`.
- `defaultConfiguration.m`: the single place for every physical value, tolerance, case list,
  figure setting and requirement, with units in the field names. `applyRunMode.m` holds the
  reduced quick-mode values and `validateConfiguration.m` rejects invalid values before any
  computation. `units.m` and `outputFormats.m` hold the unit factors and printing precisions.
- Model and evaluation: `build*`, `evaluate*`, `computeControllerGains`,
  `create*Context`, `withPlant`, `withController`.
- Search and paths: `discoverFrequencyValleys`, `runAdaptiveDiscovery`, `brentMinimize`,
  `goldenSectionMinimize`, `fzeroTolerance`, `scanParameterPath`, `trackValleyBranches`,
  `locateDominantSwitches`.
- Stability: `assessClosedLoopStability`, `computeCommonDelayMargin`,
  `computeDelaySystemRoots`, `chebyshevDifferentiationMatrix`, `computeTailBounds`.
- Study steps and outputs: `runStudy` (steps, checkpoints), `write*`, `plot*`, `export*`.

## Numerical choices

- **Modal model.** The cantilever damping of the source makes the system damping
  non-classical, so the plant is expanded in complex system modes. The design model keeps the
  coupled modes up to 30 rad/s, which makes G_full = G_des + G_res exact (self-check
  1.9e-16).
- **Exact delay.** The common-delay margin τ_dm comes from the unit-modulus crossings of the
  eigen-loci of L(jω), with analytic tail bounds that certify the search band. The rightmost
  roots come from a Chebyshev collocation of the delay line (orders 24 and 48), refined by a
  bordered Newton iteration on M(λ)v = 0.
- **Refinement.** `terra.brentMinimize` replaces `fminbnd`. MATLAB's `fminbnd` adds
  sqrt(eps)·|x| to its tolerance (about 5e-8 at log(37 rad/s)), Octave's adds only 2·eps·|x|.
  The same call would therefore give different switch locations and secant errors on the two
  platforms. The own implementation gives the same eps-limited accuracy on both.
- **Root tolerances.** MATLAB's `fzero` applies `TolX` relative to max(|x|, 1).
  `terra.fzeroTolerance` converts the declared absolute tolerances (1e-11 deg, 1e-16 s,
  1e-12 rad/s) so that they hold on both platforms.
- **Dense baseline.** A plain log grid with no refinement, from a doubling ladder
  1000·2^k. The smallest rung that detects every reference valley and reaches the
  band-minimum error target 1e-6 (the decision tolerance) is used. The reference evaluator is
  the state-space resolvent with golden-section refinement on 32000 points.
- **Switch qualification.** Root of b_i − b_j, both branch valleys resolved by a full-band
  search, third valley strictly higher (beyond the error bounds), transversal crossing,
  observed swap of the lowest branch, non-degenerate interior valleys.

## Declared assumptions

These are not given by the source model and are stated in the report:

- rated torque 1 N m per axis (primary W_u); alternate W_u = diag(1, 0.8, 1.2);
- design-model cutoff 30 rad/s, no static correction;
- sensor noise intensities treated as two-sided (variance = Φ/π ∫₀^∞ |T|² dω);
- continuous-time controller with an exact transport delay (no sampling or zero-order hold);
- the drive angle is studied over 0 to 180 deg, because the model is 180-degree periodic in the
  drive angle (checked numerically, 3.7e-15).

## Archived results (`results_octave_full/`, GNU Octave 10.3.0, 898 s)

- Nominal (0 deg, 10 ms): b = 0.70677 at 1.2456 rad/s, stable with the exact delay,
  τ_dm = 115.6 ms. The margin is set by a unit-modulus crossing of a loop eigenvalue at
  9.41 rad/s in the flexible-mode region, not by the rigid-body crossover.
- 90 deg: b = 0.67241 at 37.890 rad/s, a residual-mode valley that the design model does not
  contain (design model: 0.70375 at 1.225 rad/s).
- Confirmed switches: 47.70957° and 137.72840° (angle), 11.94162 ms (delay), 31.0062 rad/s
  (third cantilever mode). On the delay path b < 2/3 from 17 ms to 30 ms.
- Remediation, 26 cases, top-2 budget: branch-aware 26/26 optimum, spectrum-aware 26/26,
  literal active-set rule 16/26, single-crossover 2/26. Held-out structural cases:
  branch-aware 6/6 at both budgets.
- Table 2: 140/140 valleys detected by both methods; maximum band-minimum error 3.3e-16
  (method) and 7.8e-7 (dense); median 1941 versus 32000 evaluations (wall time 380 versus
  486 ms in Octave); switch-location error at most 1.5e-12 deg and 1.1e-16 s (method)
  versus up to 7.3e-4 deg and 8.5e-10 s (dense).
- Requirement violations: hub inertia ×0.8 (b ≈ 0.649) and third mode ×0.8 at 90 deg
  (b = 0.628). At 20 ms the best single move (rolloff_z +5) raises b from 0.631 to
  0.657, still below 2/3.

## Coding conventions

- Descriptive names with units (`delaySeconds`, `rolloffFrequencyRadiansPerSecond`); no
  single-letter variables.
- No unexplained literals in the analysis code: values live in `defaultConfiguration`,
  `units` or `outputFormats`, or are named local constants with a comment.
- Every function and local function has an H1 line and a help block (inputs, outputs, units,
  references).
- R2015a compatibility: no implicit expansion (`repmat` or outer products instead), no
  `string`/`contains`/`newline`/`isfile`, no indexing into function-call results, and no
  `fprintf` value lists that can contain empty strings (MATLAB drops empty arguments).

## References

1. F. Sanfedino, D. Alazard, E. Kassarian, F. Somers, "Satellite dynamics toolbox library: a
   tool to model multi-body space systems for robust control synthesis and analysis",
   IFAC-PapersOnLine 56(2):9153–9160, 2023, arXiv:2303.15872. Source of the structural model,
   requirements, sensors and noise data (Table 1 and Section 3.1).
2. N. A. Lehtomaki, N. R. Sandell, M. Athans, "Robustness results in linear-quadratic Gaussian
   based multivariable control designs", IEEE TAC 26(1):75–93, 1981 (guaranteed margins from
   σ_min).
3. D. Breda, S. Maset, R. Vermiglio, "Pseudospectral differencing methods for characteristic
   roots of delay differential equations", SIAM J. Sci. Comput. 27(2):482–495, 2005.
4. A. Ruhe, "Algorithms for the nonlinear eigenvalue problem", SIAM J. Numer. Anal.
   10(4):674–689, 1973.
5. R. P. Brent, Algorithms for Minimization without Derivatives, Prentice-Hall, 1973.
6. L. N. Trefethen, Spectral Methods in MATLAB, SIAM, 2000.
