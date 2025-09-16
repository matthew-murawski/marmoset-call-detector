function tests = test_prewindow_labels
% end-to-end: synthesize audio, make one self onset at 10 s → roi = [5,10),
% plant a heard-like burst (7.0–7.2 s) and a ≥0.5 s quiet span (8.2–8.9 s),
% call scripts/run_label_prewindows.m programmatically, then check outputs.
    tests = functiontests(localfunctions);
end

function setupOnce(t)
    rng(7);  % reproducible

    % -- synth audio (12 s, fs=32000): low noise, one burst, one quiet run
    fs = 32000;
    dur_s = 12.0;
    tvec = (0:1/fs:dur_s-1/fs);

    % base noise floor
    x = 0.005 * randn(size(tvec));

    % heard-like burst: 8 kHz tone 200 ms with a hann envelope, at 7.0–7.2 s
    burst_on = 7.0; burst_off = 7.2;
    idx = tvec >= burst_on & tvec < burst_off;
    tone = sin(2*pi*8000*tvec(idx));
    env = hann(sum(idx)).';
    x(idx) = x(idx) + 0.2 * tone .* env;

    % quiet span: hard zero 0.7 s at 8.2–8.9 s (well inside roi and away from edges)
    q_on = 8.2; q_off = 8.9;
    x(tvec >= q_on & tvec < q_off) = 0;

    % -- temp file paths
    tmp = tempname;
    [tmpdir, base] = fileparts(tmp);
    if ~exist(tmpdir, 'dir')
        mkdir(tmpdir);
    end
    wav_path = fullfile(tmpdir, [base '_synth.wav']);
    out_heard_txt   = fullfile(tmpdir, [base '_heard.txt']);
    out_silence_txt = fullfile(tmpdir, [base '_silence.txt']);
    mat_path = fullfile(tmpdir, [base '_self.mat']);

    % -- write wav
    audiowrite(wav_path, x, fs, 'BitsPerSample', 16);

    % -- produced self onset at 10 s (off a bit later; exact off not used by roi)
    self_labels = [10.00, 10.30];
    save(mat_path, 'self_labels');

    % -- stash
    t.TestData.wav_path = wav_path;
    t.TestData.self_mat = mat_path;
    t.TestData.out_heard = out_heard_txt;
    t.TestData.out_silence = out_silence_txt;
end

function test_end_to_end_labels_in_roi(t)
    % -- call the runner as a function
    preT = 5;  % roi = [5,10)
    k_silence = 1.0;       % slightly permissive so the zeroed region is clearly 'quiet'
    min_sil_ms = 500;      % ≥ 0.5 s
    edge_ms = 120;

    [heardTbl, silenceTbl] = run_label_prewindows( ...
        t.TestData.wav_path, ...
        t.TestData.self_mat, ...
        t.TestData.out_heard, ...
        t.TestData.out_silence, ...
        'PreWindowSec', preT, ...
        'KSilence', k_silence, ...
        'MinSilenceMs', min_sil_ms, ...
        'SilenceEdgeMs', edge_ms);

    % -- files exist and are non-empty
    verifyTrue(t, isfile(t.TestData.out_heard));
    verifyTrue(t, isfile(t.TestData.out_silence));
    verifyGreaterThan(t, dir(t.TestData.out_heard).bytes, 0);
    verifyGreaterThan(t, dir(t.TestData.out_silence).bytes, 0);

    % -- basic table sanity
    verifyGreaterThanOrEqual(t, height(heardTbl), 1);
    verifyGreaterThanOrEqual(t, height(silenceTbl), 1);

    % -- parse the written audacity labels and assert they lie in [5,10)
    [H_on, H_off] = read_labels_file(t.TestData.out_heard);
    [S_on, S_off] = read_labels_file(t.TestData.out_silence);

    verifyTrue(t, all(H_on >= 5.0 & H_off <= 10.0));
    verifyTrue(t, all(S_on >= 5.0 & S_off <= 10.0));

    % -- ensure at least one silence ≥ 0.5 s
    S_dur = S_off - S_on;
    verifyTrue(t, any(S_dur >= 0.5 - 1e-6));
end

% ---- helpers (local to the test) ----

function [on, off] = read_labels_file(fname)
    % read audacity-style label file: start \t end \t label
    fid = fopen(fname, 'r');
    c = textscan(fid, '%f%f%s', 'Delimiter', '\t', 'MultipleDelimsAsOne', true);
    fclose(fid);
    if isempty(c{1})
        on = []; off = [];
    else
        on = c{1}; off = c{2};
    end
end