%% demo_prewindow_labeling_M93A_S102.m
% generate audacity labels for heard calls and clear silences inside 5 s pre-windows
% before each produced call onset, using the marmoset-call-detector repo.

% ————————————————————————————————————————————————————————————————
% setup: add the repo to your path and load any local paths config
% ————————————————————————————————————————————————————————————————

% ————————————————————————————————————————————————————————————————
% inputs: wav path and produced-call labels for the same session
% note: produced labels define the pre-window ROIs; use either .mat or .txt
% ————————————————————————————————————————————————————————————————
wav = '/Volumes/Zhao/JHU_Data/Recording_Colony_Neural/M93A/voc_M93A_c_S102.wav';

% option A — produced labels as MAT (Nx2 double named `self_labels`, seconds)
% produced = '/path/to/produced_self.mat';

% option B — produced labels as Audacity TXT (columns: start   end   label)
% produced = '/path/to/produced_self.txt';

% >>> set exactly one of these:
produced = '/Users/matt/Documents/GitHub/vocalization/data/labels/M93A_S102_produced.txt';  % ← change me (or swap to the .txt)

if ~exist(wav,'file')
    error('wav_not_found:check_path', 'wav not found:\n%s', wav);
end
if ~exist(produced,'file')
    error('produced_labels_not_found:check_path', 'produced labels not found:\n%s', produced);
end

% ————————————————————————————————————————————————————————————————
% outputs: write heard + silence label tracks
% ————————————————————————————————————————————————————————————————
out_dir = P.output_path;
out_heard   = fullfile(out_dir, 'detector/S102_heard.txt');
out_silence = fullfile(out_dir, 'detector/S102_silence.txt');

% ————————————————————————————————————————————————————————————————
% run: label heard + silence inside pre-windows (conservative profile)
% this calls scripts/run_label_prewindows.m → src/main/detect_heard_and_silence_prewindows.m
% ————————————————————————————————————————————————————————————————
prewin_sec = 5;  % [on - 5 s, on)

heard_params = struct( ...                 % conservative heard-call detector
    'kE', 4.0, ...                         % energy gate (higher = stricter)
    'kF', 3.5, ...                         % positive spectral flux gate
    'min_event_ms', 90, ...                % drop micro-events
    'release_frames', 3);                    % stickier exit
    % optionally, if your apply_hysteresis supports it: 'enter_frames', 2

% silence finder: inverted robust thresholds on same frame grid
ksilence       = 2.5;   % lower if you get too few silences (e.g., 2.0)
min_sil_ms     = 500;   % keep ≥ 0.5 s
merge_gap_ms   = 60;    % fuse short gaps between quiet runs
rim_edge_ms    = 120;   % exclude a safety rim around self/heard events

[heard_tbl, silence_tbl] = run_label_prewindows(wav, produced, out_heard, out_silence, ...
    'PreWindowSec', prewin_sec, ...
    'HeardParams',  heard_params, ...
    'KSilence',     ksilence, ...
    'MinSilenceMs', min_sil_ms, ...
    'MergeGapMs',   merge_gap_ms, ...
    'SilenceEdgeMs',rim_edge_ms);

% ————————————————————————————————————————————————————————————————
% summary: print a quick sanity check
% ————————————————————————————————————————————————————————————————
n_heard   = height(heard_tbl);
n_silence = height(silence_tbl);
fprintf('[ok] wrote labels:\n  heard   → %s  (n=%d)\n  silence → %s  (n=%d)\n', ...
    out_heard, n_heard, out_silence, n_silence);
