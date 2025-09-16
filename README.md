# marmoset-call-detector (v1)

Detect “heard” marmoset calls (produced by conspecifics) from colony recordings using a simple, robust DSP pipeline in MATLAB. The v1 approach is intentionally non-ML and fast: we work on the **reference mic** only, compute a **band‑limited log‑STFT**, extract **band energy** and **positive spectral flux**, apply **rolling robust thresholds** (median + MAD), gate activity with a **2‑state hysteresis**, exclude **self‑vocalization** regions, and convert active frames into events with basic duration/gap rules. Results can be exported as **Audacity labels** for quick human QC.

## features (v1)
- reference‑mic detection (defaults to ch2 if present; configurable)
- hann STFT at 25 ms / 10 ms focused on 5–12 kHz
- features: band energy + positive spectral flux
- rolling robust baselines (median & MAD) over long windows
- 2‑state hysteresis (sticky) to suppress chatter
- minimum duration, micro‑gap merging, and max‑length capping
- self‑mask around your own vocalizations (pre/post pad)
- audacity label export for rapid review

> roadmap: v1.1 (optional) adds “overlap rescue” heuristics; v2 explores learned models once v1 baselines are solid.

---

## requirements
- **MATLAB R2022b+**
- **Signal Processing Toolbox** (for `spectrogram`) is **recommended**. If missing, consider installing it or replacing STFT with an equivalent base‑MATLAB implementation.
- macOS/Windows/Linux supported. CI uses GitHub Actions with `mathworks/setup-matlab`.

## install
```matlab
% from the repo root
startup;   % adds src/, scripts/, and external/* to your path and makes a few folders
```
If you have machine‑specific data paths, add a `config/paths_local.m` that returns a struct `P` with fields you use (e.g., `P.data_MAT`). The project does not require it for basic usage.

---

## quick start
```matlab
startup;

% load or define your self labels in seconds (Nx2 [on off], double)
% self_labels = [12.34 12.90; 33.10 33.30; ...];

params = struct();  % use defaults (see table below; you can override any field)
heard = detect_heard_calls_v1('/path/to/rec.wav', self_labels, params);

% export to audacity label track
export_audacity_labels(heard, '/path/to/heard_labels.txt', 'Label','heard');
```

Or use the runner script (convenience wrapper):
```matlab
run_detect_heard_calls('/path/to/rec.wav', '/path/to/self_labels.mat', '/path/to/heard_labels.txt');
% the MAT must contain Nx2 double named `self_labels` in seconds
```

---

## pre-window labeling (conservative)

This mode restricts analysis to **pre-windows** right before each produced (self) onset. For each produced onset `on_i`, we define an ROI window  
**ROI_i = [on_i − T, on_i)** with default **T = 5 s**.  
Inside these ROIs we (a) run the heard-call detector with a conservative profile, and (b) find **clear silences** (≥ 0.5 s) on the same frame grid, *away from event edges*.

### how to run

Use the runner to generate **two** Audacity tracks (heard + silence). Produced labels can be a `.mat` (with `self_labels` as Nx2 `[on off]` in seconds, or a struct array with `.on/.off`) **or** an Audacity `.txt`.

**MAT produced labels**
```matlab
startup;

wav = '/path/to/rec.wav';
mat = '/path/to/produced_self.mat';    % contains Nx2 `self_labels` in seconds
out_heard   = '/path/to/heard_labels.txt';
out_silence = '/path/to/silence_labels.txt';

[heard, silence] = run_label_prewindows(wav, mat, out_heard, out_silence, ...
    'PreWindowSec', 5, ...
    'HeardParams', struct( ...
        'kE', 4.0, ...
        'kF', 3.5, ...
        'min_event_ms', 90, ...
        'release_frames', 3 ...
        ... % optionally: 'enter_frames', 2  % if your build of apply_hysteresis supports it
    ), ...
    'KSilence', 2.0, ...
    'MinSilenceMs', 500, ...
    'MergeGapMs', 60, ...
    'SilenceEdgeMs', 120);
```

**Audacity `.txt` produced labels**
```matlab
startup;

wav = '/path/to/rec.wav';
txt = '/path/to/produced_self.txt';    % start	end	label
out_heard   = '/path/to/heard_labels.txt';
out_silence = '/path/to/silence_labels.txt';

[heard, silence] = run_label_prewindows(wav, txt, out_heard, out_silence, ...
    'PreWindowSec', 5, ...
    'HeardParams', struct('kE',4.0,'kF',3.5,'min_event_ms',90,'release_frames',3), ...
    'KSilence', 2.0, 'MinSilenceMs', 500, 'SilenceEdgeMs', 120);
```
> note: the runner calls `src/main/detect_heard_and_silence_prewindows.m`, which builds the ROIs, runs `detect_heard_calls_v1` inside them, dilates an edge “rim” around self/heard events (`dilate_events_mask`), and then finds quiet frames with `detect_quiet_frames`.  
> labels are written with `export_audacity_labels(events, out_txt, 'Label', <name>)`.

### recommended conservative profile (heard)

These settings trade recall for fewer false positives:
- `kE = 4.0`, `kF = 3.5`
- `min_event_ms = 90` (or a touch higher if you see micro-events)
- `release_frames = 3` (stickier exit)
- *(optional)* `enter_frames = 2` in `apply_hysteresis` if your build supports multi-frame entry; otherwise default single-frame entry is used.

### additional parameters (pre-window workflow)

| name              | default | units   | where it lives                                          | notes                                                                                          |
|-------------------|---------|---------|---------------------------------------------------------|------------------------------------------------------------------------------------------------|
| `PreWindowSec`    | 5       | s       | `run_label_prewindows` arg                              | length of each ROI: `[on − T, on)`                                                            |
| `KSilence`        | 2.5     | —       | `detect_heard_and_silence_prewindows`                   | “quiet” if both features fall **below** `median − K·MAD` (uses energy + pos. spectral flux)   |
| `MinSilenceMs`    | 500     | ms      | `detect_heard_and_silence_prewindows`                   | minimum silence duration (keep ≥ 0.5 s)                                                        |
| `MergeGapMs`      | 60      | ms      | `detect_heard_and_silence_prewindows`                   | merge adjacent quiet runs separated by < this gap                                              |
| `SilenceEdgeMs`   | 120     | ms      | `detect_heard_and_silence_prewindows`                   | radius of “rim” to exclude around **self or heard** events                                     |
| `MaxSilenceMs`    | ∞       | ms      | `detect_heard_and_silence_prewindows`                   | cap silence lengths if desired                                                                 |
| `HeardParams.*`   | —       | —       | forwarded into `detect_heard_calls_v1`                  | e.g., `kE`, `kF`, `min_event_ms`, `release_frames`, *(optionally)* `enter_frames`             |
| `roi_windows`     | —       | s pairs | `detect_heard_calls_v1` (optional param, Nx2 `[on off]`) | detector only runs where ROI mask is **true** (composed with the self-mask on the frame grid) |

---

## parameters

These are the main knobs for v1. Defaults aim to be conservative but practical for typical colony room acoustics. You can pass a partial `params` struct; missing fields are filled with defaults inside the detector.

| name                | default        | units   | meaning / notes                                                                 |
|---------------------|----------------|---------|----------------------------------------------------------------------------------|
| `bandpass`          | `[5e3,12e3]`   | Hz      | analysis band for STFT features (marmoset energy concentrated here)             |
| `win_ms`            | `25`           | ms      | STFT window (hann)                                                               |
| `hop_ms`            | `10`           | ms      | STFT hop                                                                         |
| `rolling_sec`       | `60`           | s       | window for rolling median + MAD (per‑frame robust baselines)                    |
| `kE`                | `3.5`          | —       | high‑gate multiplier for energy                                                  |
| `kF`                | `3.0`          | —       | high‑gate multiplier for positive spectral flux                                  |
| `k_low`             | `2.0`          | —       | low‑gate multiplier (exit when **both** E and F < med + k_low * MAD)            |
| `release_frames`    | `2`            | frames  | number of consecutive low frames required to exit call state                     |
| `min_event_ms`      | `70`           | ms      | drop events shorter than this                                                    |
| `merge_gap_ms`      | `50`           | ms      | merge adjacent events separated by gaps shorter than this                        |
| `max_event_ms`      | `4000`         | ms      | cap overly long events (truncate)                                                |
| `pre_pad_ms`        | `30`           | ms      | self‑mask pre‑pad around own vocalizations                                       |
| `post_pad_ms`       | `100`          | ms      | self‑mask post‑pad                                                               |
| `ref_channel_index` | *(optional)*   | index   | reference mic channel (defaults to 2 if present; otherwise 1)                    |

> tip: start with defaults; if you get too many micro‑events, raise `min_event_ms` a bit and/or increase `release_frames`. If you miss quiet calls, consider lowering `kE`/`kF` slightly.

---

## evaluating quality

We recommend **event‑level** precision/recall/F1 with a time tolerance. A predicted event matches a ground‑truth event if **both** onset and offset are within ±Δ of the true boundaries.

Suggested tolerances:
- Δ = **±25 ms** (strict)
- Δ = **±50 ms** (lenient)

From counts of **TP**, **FP**, **FN**:
- `precision = TP / (TP + FP)`
- `recall    = TP / (TP + FN)`
- `F1        = 2 * (precision * recall) / (precision + recall)`

Sanity on synthetic fixtures should show boundary errors within ≤ hop (10 ms). For real recordings, expect a few manual trims/merges; track **“edits per minute”** post‑export to estimate human effort.

---

## exporting to Audacity

1. run detection and export:
   ```matlab
   heard = detect_heard_calls_v1('/path/rec.wav', self_labels, struct());
   export_audacity_labels(heard, '/path/heard_labels.txt', 'Label','heard');
   ```
2. in Audacity: **File → Import → Labels…** and select the `.txt`.
3. ensure the project rate matches the WAV’s sample rate (bottom‑left).
4. use the label track to step through events for rapid QC.

---

## benchmarking

A tiny harness is included to gauge runtime on your machine:
```matlab
benchmark_one_clip
```
It synthesizes a 60 s clip, runs the detector, and prints:
```
benchmark_one_clip: dur=60.0 s, elapsed=XX.XXX s, x_rt=Y.YYx
```
Where `x_rt = duration / elapsed`. On developer machines (when the `CI` environment variable is **absent**), it asserts `x_rt >= 1`. In CI, the assertion is skipped.

---

## running tests

```matlab
startup;
results = runtests;
assertSuccess(results);
```
The CI workflow runs the same command on each push/PR.

---

## repo layout (updated)

```
src/
  io/               % read_audio, export_audacity_labels
  preprocess/       % frame_params, compute_stft_logmag, rolling_stats
  features/         % band_energy, spectral_flux_pos
  detect/           % build_self_mask, build_roi_mask, apply_hysteresis, dilate_events_mask, detect_quiet_frames, frames_to_events
  main/             % detect_heard_calls_v1, detect_heard_and_silence_prewindows
scripts/            % run_detect_heard_calls, run_label_prewindows, benchmark_one_clip
tests/              % unit + e2e tests
config/             % optional local paths config (paths_local.m)
docs/               % optional documentation
```

---

## troubleshooting

- **“Undefined function 'spectrogram'”**: install **Signal Processing Toolbox** or replace the STFT with a base‑MATLAB equivalent. Tests for STFT‑dependent modules will fail without it.
- **CI failures on GitHub Actions**: ensure the workflow references `mathworks/setup-matlab@v2` and that your repo has no private dependencies.
- **No detections / too many detections**: tweak `kE`/`kF` (sensitivity), `min_event_ms`, and `release_frames`; confirm `ref_channel_index` points to the reference mic.

---

## changes

**Added**
- `scripts/run_label_prewindows.m` — convenience entry point that writes **heard** and **silence** label tracks for ROI pre-windows.
- `src/main/detect_heard_and_silence_prewindows.m` — orchestrates ROI building, conservative heard detection, edge-rim exclusion, and quiet detection.
- `src/detect/build_roi_mask.m` — frame-grid mask from `[on off]` windows.
- `src/detect/dilate_events_mask.m` — 1-D logical dilation helper for edge safety.
- `src/detect/detect_quiet_frames.m` — “quiet” frame detection via inverted robust thresholds.

**Modified**
- `src/main/detect_heard_calls_v1.m` — accepts optional `roi_windows` and composes it with the self-mask.
- `src/detect/apply_hysteresis.m` — supports optional `enter_frames` (defaults to 1-frame entry for backward compatibility).

**Tests/Docs**
- Unit + e2e tests for ROI/silence pipeline, plus this README section documenting the workflow.

---

## license
MIT — see `LICENSE`.

## citation
If this project helped your work, please cite the repository and your release tag/version.
