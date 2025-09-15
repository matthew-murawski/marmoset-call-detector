function tests = test_apply_hysteresis
% unit tests for apply_hysteresis (2-state hysteresis on E/F features).
tests = functiontests(localfunctions);
end

function test_basic_entry_exit(t)
    n = 30;
    % features: quiet baseline then a clear burst well above high gates
    E = zeros(1, n);
    F = zeros(1, n);
    E(6:14) = 3.1;  % above highE (3.0 if mad=1, med=0)
    F(6:14) = 2.6;  % above highF (2.5 if mad=1, med=0)
    % after the burst, both stay below low gates for 3 frames to force exit
    E(15:18) = 0.5; F(15:18) = 0.5;

    % thresholds (constant over time)
    medE = 0; madE = 1;
    medF = 0; madF = 1;
    kHighE = 3.0; kHighF = 2.5; kLow = 1.0;
    release_frames = 3;

    state = apply_hysteresis(E, F, medE, madE, medF, madF, kHighE, kHighF, kLow, release_frames);

    % expected: enter on frame 6; remain in call through frame 16;
    % exit on frame 17 (the 3rd consecutive below-low frame).
    exp = false(1, n);
    exp(6:16) = true;

    verifyEqual(t, state, logical(exp), 'state trajectory mismatch');
    verifyTrue(t, isrow(state) && islogical(state), 'state must be a logical row vector');
    % exactly one enter (+1) and one exit (-1)
    delta = diff([false state]);  % prepend a 0 for edge diff
    verifyEqual(t, sum(delta == 1), 1);
    verifyEqual(t, sum(delta == -1), 1);
end

function test_no_chatter_boundary_and_strict_conditions(t)
    n = 25;
    E = zeros(1, n);
    F = zeros(1, n);

    % prelude: E spikes alone > high but F does not -> must NOT enter
    E(2:3) = 4.0;  % > highE later defined as 3.5
    F(2:3) = 0.0;  % stays low

    % proper entry: both exceed high at 5:10
    E(5:12) = 4.0; F(5:12) = 3.8;

    % hover near low: create short dips below low but not long enough to release
    % low gates will be at 1.0; craft patterns to avoid 3 consecutive below-both until the end
    E(13) = 0.8; F(13) = 0.8;   % below both (count=1)
    E(14) = 1.2; F(14) = 0.8;   % E above low -> reset
    E(15) = 0.7; F(15) = 0.7;   % below (count=1)
    E(16) = 0.9; F(16) = 0.9;   % below (count=2)
    E(17) = 1.1; F(17) = 0.9;   % E above low -> reset
    % finally produce 3 consecutive below-both to exit at frame 20
    E(18:20) = 0.6; F(18:20) = 0.6;

    medE = 0; madE = 1;
    medF = 0; madF = 1;
    kHighE = 3.5; kHighF = 3.0; kLow = 1.0;
    release_frames = 3;

    state = apply_hysteresis(E, F, medE, madE, medF, madF, kHighE, kHighF, kLow, release_frames);

    % expected: no entry during frames 2:3; enter at 5; no chatter during 13:17;
    % exit on frame 20, so frames 5:19 should be true.
    exp = false(1, n);
    exp(5:19) = true;

    verifyEqual(t, state, logical(exp));
    % only two transitions total
    delta = diff([false state]);
    verifyEqual(t, sum(delta == 1), 1);
    verifyEqual(t, sum(delta == -1), 1);
end
