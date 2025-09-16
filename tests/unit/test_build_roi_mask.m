function tests = test_build_roi_mask
% tests for build_roi_mask: single window, multi-window, clipping, empty windows
tests = functiontests(localfunctions);
end

function FP = makeFP()
% tiny frame grid helper: 0:0.01:0.50 (51 frames)
t = 0:0.01:0.50;
FP = struct('t_frames', t, 'n_frames', numel(t));
end

function test_single_window_closed_open(testCase)
% one window [0.10 0.20] → include t in [0.10, 0.20)
FP = makeFP();
windows = [0.10 0.20];

mask = build_roi_mask(windows, FP);

verifyTrue(testCase, islogical(mask));
verifyTrue(testCase, isrow(mask));
verifyEqual(testCase, numel(mask), FP.n_frames);

expected = false(1, FP.n_frames);
expected(11:20) = true; % indices for 0.10..0.19, since t(11)=0.10
verifyEqual(testCase, mask, expected);
verifyEqual(testCase, sum(mask), 10);
end

function test_two_windows_with_gap(testCase)
% two windows with a gap between them
FP = makeFP();
windows = [0.05 0.08; 0.12 0.14];

mask = build_roi_mask(windows, FP);

expected = false(1, FP.n_frames);
expected(6:8) = true;   % 0.05, 0.06, 0.07
expected(13:14) = true; % 0.12, 0.13
verifyEqual(testCase, mask, expected);
verifyEqual(testCase, sum(mask), 5);
end

function test_window_exceeding_bounds_clips(testCase)
% window partially before start should clip to timeline
FP = makeFP();
windows = [-1 0.03];

mask = build_roi_mask(windows, FP);

expected = false(1, FP.n_frames);
expected(1:3) = true; % 0.00, 0.01, 0.02
verifyEqual(testCase, mask, expected);
verifyEqual(testCase, sum(mask), 3);
end

function test_empty_windows_returns_all_true(testCase)
% empty windows → keep everything
FP = makeFP();
windows = []; %#ok<NASGU>

mask = build_roi_mask(windows, FP);

verifyTrue(testCase, all(mask));
verifyEqual(testCase, numel(mask), FP.n_frames);
verifyTrue(testCase, isrow(mask));
end