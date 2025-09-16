function tests = test_apply_hysteresis_enter_hold
% tests for stricter entry via enter_frames
tests = functiontests(localfunctions);
end

function test_single_frame_high_does_not_enter_when_enter2(testCase)
% exactly 1 high frame; enter_frames=2 → no entry
n = 20;
E = zeros(1, n); F = zeros(1, n);
E(10) = 3; F(10) = 3;              % single spike above high

medE = 0; madE = 1; medF = 0; madF = 1;
kHighE = 2; kHighF = 2; kLow = 0; release_frames = 1;

state = apply_hysteresis(E, F, medE, madE, medF, madF, ...
    kHighE, kHighF, kLow, release_frames, 'enter_frames', 2);

verifyTrue(testCase, islogical(state));
verifyTrue(testCase, isrow(state));
verifyEqual(testCase, numel(state), n);
verifyFalse(testCase, any(state));  % never enters
end

function test_two_consecutive_high_enters_on_second_frame(testCase)
% two consecutive high frames; enter_frames=2 → enter on 2nd, hold until exit rule
n = 20;
E = zeros(1, n); F = zeros(1, n);

% high on frames 10-11
E(10:11) = 3; F(10:11) = 3;

% above low but below high to maintain state (frames 12-13)
E(12:13) = 0.1; F(12:13) = 0.1;

% drop to below low at 14 to trigger immediate exit with release_frames=1
% (zeros already below low with kLow=0)

medE = 0; madE = 1; medF = 0; madF = 1;
kHighE = 2; kHighF = 2; kLow = 0; release_frames = 1;

opts = struct('enter_frames', 2);
state = apply_hysteresis(E, F, medE, madE, medF, madF, ...
    kHighE, kHighF, kLow, release_frames, opts);

expected = false(1, n);
expected(11:13) = true;   % enters at 11 (second high), holds through 13, exits at 14

verifyEqual(testCase, state, expected);
end