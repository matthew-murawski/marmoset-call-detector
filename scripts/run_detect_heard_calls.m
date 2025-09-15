function run_detect_heard_calls(wav_path, self_labels_path, out_txt)
% run_detect_heard_calls
% minimal runner: load self labels, build default params, run detection, export labels.
%
% usage:
%   run_detect_heard_calls(wav_path, self_labels_path, out_txt)
%
% examples (edit paths for your machine):
%   % wav_path = '/path/to/colony_recording.wav';
%   % self_labels_path = '/path/to/self_labels.mat';  % contains Nx2 double 'self_labels' in seconds
%   % out_txt = '/path/to/heard_labels.txt';
%   % run_detect_heard_calls(wav_path, self_labels_path, out_txt);

    % --- basic arg checking
    if nargin ~= 3
        error('run_detect_heard_calls:invalidArgs', ...
            ['expected 3 inputs: wav_path, self_labels_path (MAT with Nx2 double ''self_labels''),' ...
             ' and out_txt.']);
    end
    if ~(ischar(wav_path) || isstring(wav_path))
        error('run_detect_heard_calls:invalidArgs', 'wav_path must be a char or string.');
    end
    if ~(ischar(self_labels_path) || isstring(self_labels_path))
        error('run_detect_heard_calls:invalidArgs', 'self_labels_path must be a char or string.');
    end
    if ~(ischar(out_txt) || isstring(out_txt))
        error('run_detect_heard_calls:invalidArgs', 'out_txt must be a char or string.');
    end

    wav_path = char(wav_path);
    self_labels_path = char(self_labels_path);
    out_txt = char(out_txt);

    % --- load self labels (Nx2 double seconds) from MAT file
    if ~exist(self_labels_path, 'file')
        error('run_detect_heard_calls:fileNotFound', 'self_labels_path not found: %s', self_labels_path);
    end
    S = load(self_labels_path);
    if ~isfield(S, 'self_labels')
        error('run_detect_heard_calls:missingVar', ...
            'file %s does not contain variable ''self_labels''.', self_labels_path);
    end
    self_labels = S.self_labels;
    if ~(isnumeric(self_labels) && ismatrix(self_labels) && size(self_labels,2) == 2)
        error('run_detect_heard_calls:badLabels', ...
            'self_labels must be an Nx2 numeric matrix of [on off] times in seconds.');
    end

    % --- build default params (from the spec)
    params = struct();
    params.bandpass        = [5e3, 12e3];
    params.win_ms          = 25;
    params.hop_ms          = 10;
    params.rolling_sec     = 60;
    params.kE              = 3.5;
    params.kF              = 3.0;
    params.k_low           = 2.0;
    params.release_frames  = 2;
    params.min_event_ms    = 70;
    params.merge_gap_ms    = 50;
    params.max_event_ms    = 4000;
    params.pre_pad_ms      = 30;
    params.post_pad_ms     = 100;
    params.t_end           = 300;
    % params.ref_channel_index = [];  % optional; leave unset to use detector default

    % --- run detection
    heard = detect_heard_calls_v1_chunked(wav_path, self_labels, params);

    % --- export to audacity labels
    export_audacity_labels(heard, out_txt);

    % --- print a short summary
    n_events = 0;
    total_dur = 0;
    if istable(heard) && ~isempty(heard)
        n_events = height(heard);
        if any(strcmp('dur', heard.Properties.VariableNames))
            total_dur = nansum(heard.dur);
        elseif all(ismember({'on','off'}, heard.Properties.VariableNames))
            total_dur = nansum(heard.off - heard.on);
        end
    end
    fprintf('heard events: %d, total duration: %.3f s\n', n_events, total_dur);
end