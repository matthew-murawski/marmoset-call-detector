function tests = test_frame_params
% unit tests for frame_params (window/hop to frames and times).
tests = functiontests(localfunctions);
end

function test_known_small_case(t)
% known case: fs=1000 hz, win=20 ms, hop=10 ms, n_samples=100
    fs = 1000;
    win_ms = 20;
    hop_ms = 10;
    n_samples = 100;

    FP = frame_params(fs, win_ms, hop_ms, n_samples);

    % sample counts
    verifyEqual(t, FP.win_samp, 20);
    verifyEqual(t, FP.hop_samp, 10);

    % frame count: floor((100-20)/10)+1 = 9
    verifyEqual(t, FP.n_frames, 9);

    % t_frames properties
    verifyEqual(t, size(FP.t_frames), [1 9]);
    verifyEqual(t, FP.t_frames(1), 0.010, 'AbsTol', 1e-12);   % first center at 10 ms
    verifyEqual(t, FP.t_frames(end), 0.090, 'AbsTol', 1e-12); % last center at 90 ms
end

function test_edge_case_too_short(t)
% edge case: n_samples < win_samp -> zero frames and empty t_frames
    fs = 1000;
    win_ms = 20;
    hop_ms = 10;
    n_samples = 15;  % shorter than window

    FP = frame_params(fs, win_ms, hop_ms, n_samples);

    verifyEqual(t, FP.n_frames, 0);
    verifyEqual(t, size(FP.t_frames), [1 0]);
end
