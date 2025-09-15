function tests = test_rolling_stats
% unit tests for rolling_stats (median + MAD).
% test 1: robustness to a spike vs mean/std.
% test 2: edge handling (clipped windows) for first/last frames.
% test 3: empty input returns empty outputs.

    tests = functiontests(localfunctions);
end

function test_robust_to_spike_vs_mean_std(testCase)
    % vector with a strong spike in the middle
    X = [1 2 100 3 4];
    k = 5;  % full window (center uses all frames)

    [med, mad] = rolling_stats(X, k);

    % rolling mean/std for comparison (centered, endpoints shrink)
    mu  = movmean(X, k, 'Endpoints','shrink');
    sig = movstd(X,  k, 'Endpoints','shrink');

    % at the center frame, mean is dragged up by the spike; median resists
    i = 3;
    verifyEqual(testCase, med(i), 3);             % median of [1 2 100 3 4] is 3
    verifyGreaterThan(testCase, mu(i), med(i));   % mean > median due to spike

    % MAD is small compared to std in this spiky window
    % compute expected MAD at center by hand:
    % deviations from median 3 are [2 1 97 0 1] → median = 1 → MAD = 1*1.4826
    verifyEqual(testCase, mad(i), 1*1.4826, 'AbsTol', 1e-12);
    verifyGreaterThan(testCase, sig(i), mad(i));  % std >> MAD here
end

function test_edge_windows_clipped_first_last(testCase)
    % check that edges use clipped windows [i-w, i+w] within bounds
    X = [1 2 100 3 4];
    k = 5;               % w = 2
    [med, mad] = rolling_stats(X, k);

    % i = 1 → window [1..3] → median([1 2 100]) = 2
    verifyEqual(testCase, med(1), 2);
    % MAD at i=1: deviations from 2 in [1 2 100] are [1 0 98] → median=1 → *1.4826
    verifyEqual(testCase, mad(1), 1*1.4826, 'AbsTol', 1e-12);

    % i = 5 → window [3..5] → median([100 3 4]) = 4
    verifyEqual(testCase, med(5), 4);
    % MAD at i=5: deviations from 4 in [100 3 4] are [96 1 0] → median=1 → *1.4826
    verifyEqual(testCase, mad(5), 1*1.4826, 'AbsTol', 1e-12);
end

function test_empty_input_returns_empty(testCase)
    X = zeros(1,0);
    [med, mad] = rolling_stats(X, 3);
    verifySize(testCase, med, [1 0]);
    verifySize(testCase, mad, [1 0]);
end