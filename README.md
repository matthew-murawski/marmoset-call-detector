# marmoset-call-detector

a small matlab toolbox to detect **heard** marmoset calls from multi-channel wav recordings using a reference-mic-only approach. v1 combines a band-limited log-stft (25 ms / 10 ms), energy + positive spectral flux, robust rolling thresholds, a two-state hysteresis gate, duration/gap constraints with micro-gap merging, and a self-mask to exclude the subject’s own calls. results can be exported as audacity label tracks.

## quickstart
- requires **matlab r2022b+** (signal processing toolbox recommended).
- clone or unzip this repo, open matlab at the repo root, then run:

```matlab
startup
```

## minimal usage example (stub)
```matlab
% example paths/labels are placeholders for now
wav_path = 'example.wav';               % your multi-channel wav file
self_labels = [1.2 2.0;  5.0 5.5];      % [on off] in seconds (nx2)

params = struct(); % use defaults for now; more fields added later

heard = detect_heard_calls_v1(wav_path, self_labels, params);
% 'heard' will be a table with on/off/dur/confidence and meta fields (in later steps)
```

run tests at any time with:
```matlab
startup; results = runtests; assertSuccess(results)
```
