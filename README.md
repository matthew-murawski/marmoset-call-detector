# marmoset-call-detector (v1)

detect “heard” marmoset calls (produced by conspecifics) from colony recordings using a simple DSP pipeline:

1. read wav (reference mic only)
2. log-STFT (hann, 25 ms / 10 ms) in 5–12 kHz
3. features: band-limited energy + positive spectral flux
4. rolling robust thresholds (median + MAD)
5. 2-state hysteresis (enter on high E/F; exit when both fall below low gate for N frames)
6. self-mask exclusion (pad around own calls)
7. frames → events (min duration, micro-gap merge, cap max)
8. export to Audacity labels

## quick start

```matlab
startup;  % adds paths
heard = detect_heard_calls_v1('/path/to/rec.wav', self_labels, struct());  % defaults
export_audacity_labels('/path/to/heard_labels.txt', heard, 'heard');


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
