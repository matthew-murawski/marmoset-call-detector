function tests = test_detect_heard_and_silence_logic
% focus on silence logic: roi restriction, rim dilation, and min-duration behavior.
% this test avoids audio i/o by constructing synthetic frame times and masks.
    tests = functiontests(localfunctions);
end

function setupOnce(t)
    % synthetic frame grid: 0:0.01:10 s (hop = 10 ms)
    FP = struct();
    FP.t_frames = 0:0.01:10;
    FP.hop_s = 0.01;
    t.TestData.FP = FP;

    % produced (self) onsets → pre-windows with T=1 s
    % onsets at 5 and 9 s → rois [4,5) and [8,9)
    t.TestData.roi_windows = [4 5; 8 9];

    % self events near those onsets (tight)
    t.TestData.self_windows = [5.00 5.30; 9.00 9.20];

    % heard event inside the first roi
    t.TestData.heard_windows = [4.40 4.60];

    % a short quiet patch inside roi#1 (should be discarded by min duration)
    % and a long quiet patch inside roi#2 (should pass)
    t.TestData.quiet_true = [4.70 4.90; 8.20 8.90];

    % rim dilation radius = 10 frames = 100 ms
    t.TestData.rim_frames = 10;
end

function test_silence_respects_roi_and_rim_and_duration(t)
    FP = t.TestData.FP;

    % roi mask
    roi = build_roi_mask(t.TestData.roi_windows, FP);

    % self + heard masks, then rim dilation
    m_self  = windows_to_mask(t.TestData.self_windows, FP);
    m_heard = windows_to_mask(t.TestData.heard_windows, FP);
    rim0 = m_self | m_heard;
    rim = dilate_events_mask(rim0, t.TestData.rim_frames);

    % eligible = inside roi and away from rim
    eligible = roi & ~rim;

    % craft a 'quiet' boolean with two candidate runs
    quiet = false(size(FP.t_frames));
    qwin = t.TestData.quiet_true;
    quiet = quiet | windows_to_mask(qwin(1,:), FP);
    quiet = quiet | windows_to_mask(qwin(2,:), FP);

    % enforce eligibility (the orchestrator will do this before frames→events)
    quiet = quiet & eligible;

    % frames → events with min_silence_ms = 500 (0.5 s), merge 60 ms, no max
    min_ms = 500; merge_ms = 60; max_ms = inf;
    silence = frames_to_events(quiet, FP, min_ms, merge_ms, max_ms);

    % expect exactly one event (the long one in roi#2)
    verifyEqual(t, height(silence), 1);

    % check it lies fully within [8,9) and does not touch rim
    s_on = silence.on(1); s_off = silence.off(1);
    verifyGreaterThanOrEqual(t, s_on, 8.0);
    verifyLessThanOrEqual(t, s_off, 9.0);

    % ensure duration ≥ 0.5 s (with a little numerical slack)
    verifyGreaterThanOrEqual(t, silence.dur(1), 0.5 - 1e-6);

    % ensure the short [4.7,4.9] patch was rejected by duration rule
    verifyGreaterThanOrEqual(t, s_on, 8.0);

    % ensure rim actually bites near heard/self edges in roi#1
    % i.e., no silence event should start inside [4.3, 4.7] given 100 ms rim
    blocked = any(FP.t_frames >= 4.3 & FP.t_frames < 4.7 & (quiet(:).'));
    verifyFalse(t, blocked);
end

% --- local helpers (mirror minimal logic used by the main code) ---

function mask = windows_to_mask(win, FP)
    tf = FP.t_frames(:).';
    if isempty(win), mask = false(size(tf)); return; end
    if isvector(win), win = reshape(win,1,2); end
    mask = false(size(tf));
    for i = 1:size(win,1)
        on = win(i,1); off = win(i,2);
        mask = mask | (tf >= on & tf < off);
    end
end