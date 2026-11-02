# Table 1. Predeclared cases (one model and controller version)

| Case | Controller | Active valley omega* (rad/s) | b_Omega / spectral gap | D+ / D- (parameter, h) | Closed loop (exact delay) | Pointing / command |
| --- | --- | --- | --- | --- | --- | --- |
| Full model, nominal | unchanged | 1.2456 | 0.70677 / 0.0104 | -7.25e-05 / +7.25e-05 (panel_angle, 5) | stable_exact_delay; max Re -0.0299 1/s; tau_dm 115.6 ms (remaining 105.6 ms) | APE ratio 0.56; noise jitter 78.7 urad; step peak 216 urad; noise torque 0.264 N m; peak/rated 0.042 |
| Design model, same controller | unchanged | 1.2458 | 0.70683 / 0.0104 | -7.47e-05 / +7.47e-05 (panel_angle, 5) | stable_exact_delay; max Re -0.0299 1/s; tau_dm 115.6 ms (remaining 105.6 ms) | APE ratio 0.56; noise jitter 78.7 urad; step peak 216 urad; noise torque 0.265 N m; peak/rated 0.042 |
| Physical perturbation | unchanged | 37.8896 | 0.67241 / 0.309 | -0.000489 / +0.000489 (panel_angle, 5) | stable_exact_delay; max Re -0.0312 1/s; tau_dm 108.1 ms (remaining 98.1 ms) | APE ratio 0.56; noise jitter 78.7 urad; step peak 216 urad; noise torque 0.265 N m; peak/rated 0.041 |
| Feasible adjustment (physical) | rolloff_y -5 | 37.8625 | 0.68259 / 0.298 | -0.000487 / +0.000487 (panel_angle, 5); rolloff_y: -0.00549 / +0.00549 | stable_exact_delay; max Re -0.0312 1/s; tau_dm 102.6 ms (remaining 92.6 ms) | APE ratio 0.56; noise jitter 79.0 urad; step peak 216 urad; noise torque 0.261 N m; peak/rated 0.041 |
| Delay perturbation | unchanged | 22.6004 | 0.63143 / 0.293 | -0.0188 / +0.0188 (loop_delay, 0.002) | stable_exact_delay; max Re -0.0299 1/s; tau_dm 115.6 ms (remaining 95.6 ms) | APE ratio 0.56; noise jitter 79.2 urad; step peak 217 urad; noise torque 0.267 N m; peak/rated 0.043 |
| Feasible adjustment (delay) | rolloff_z +5 | 22.6234 | 0.65650 / 0.268 | -0.0188 / +0.0188 (loop_delay, 0.002); rolloff_z: +0.026 / -0.026 | stable_exact_delay; max Re -0.0299 1/s; tau_dm 115.6 ms (remaining 95.6 ms) | APE ratio 0.56; noise jitter 79.2 urad; step peak 216 urad; noise torque 0.267 N m; peak/rated 0.043 |

Notes. Model: Sanfedino F, Alazard D, Kassarian E, Somers F. Satellite dynamics toolbox library: a tool to model multi-body space systems for robust control synthesis and analysis. IFAC-PapersOnLine 56(2):9153-9160, 2023 (arXiv:2303.15872), Table 1 and Section 3.1. Plant order 18 (full) / 14 (design); closed loop 36 states plus exact delay. Band Omega = [0.1, 100] rad/s. Loop broken at the actuator command u. Primary W_u = diag([1 1 1]) (rated torque), alternate W_u = diag([1 0.8 1.2]). Truncation: Retain coupled (system) flexible modes whose undamped natural frequency does not exceed the cutoff; remove the others; no static correction. Controller V5.4 (continuous time, delay 10 ms nominal). Disk-margin requirement b >= 0.6667 (gamma = 1.50). Spectral gap = sigma_2 - sigma_min at omega*. D+- = h * one-sided envelope derivative.

# Table 2. Equal-error comparison with the dense baseline

| Quantity | Adaptive method | Plain dense grid (equal error) |
| --- | --- | --- |
| Valleys detected / reference | 140 / 140 | 140 / 140 |
| Extra (spurious) valleys | 0 | 0 |
| Max band-minimum error | 3.33e-16 | 7.82e-07 |
| Grid points | 1500 + modal points | median 32000 (range 1000-256000); target missed in 0 cases |
| Median f_W evaluations | 1941 | 32000 (median ratio 16.5) |
| Median wall time (ms) | 380.1 | 485.5 (median ratio 1.3) |
| Median fixed model-build time (ms, shared) | 9.4 | 9.4 |
| Max switch-location error | panel_angle 8.67e-13 deg; panel_angle 1.48e-12 deg; loop_delay 1.08e-16 s; mode3_frequency 4.65e-13 rad/s | panel_angle 7.29e-04 deg; panel_angle 3.86e-05 deg; loop_delay 8.48e-10 s; mode3_frequency 1.10e-04 rad/s |
| Band edges certified by tail bounds | 26 / 26 cases | 26 / 26 cases |

Single main crossover check (reported alongside): misses the active valley in 16 of 26 cases; largest margin overestimate 0.1066.

Software/hardware: GNU Octave 10.3.0 on x86_64-conda-linux-gnu; processor: not exposed; logical processors: not exposed. Method and dense times are medians of 3 repeats on this machine (the model build is timed once); they are not portable speed claims.
