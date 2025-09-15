function tests = test_detect_frames
% unit tests for detect_frames.
% test 1: basic gating: only frames above both thresholds are active.
% test 2: mask exclusion zeros out otherwise-active frames.

    tests = functiontests(localfunctions);
end

function test_basic_gating(testCase)
    n = 12;

    % make simple constant rolling stats
    medE = ones(1, n) * 1.0;
    madE = ones(1, n) * 0.2;   % TE = 1.0 + kE*0.2
    medF = ones(1, n) * 1.0;
    madF = ones(1, n) * 0.1;   % TF = 1.0 + kF*0.1

    kE = 2.0;   % TE = 1.4
    kF = 1.5;   % TF = 1.15

    % features: mostly below threshold except select frames
    E = ones(1, n) * 1.2;      % below TE
    F = ones(1, n) * 1.05;     % below TF

    E(6) = 1.6;                % exceeds TE at frame 6 only
    F(6) = 1.30;               % exceeds TF at frame 6
    F(9) = 1.30;               % exceeds TF at frame 9 (but E(9) stays low)

    active = detect_frames(E, F, medE, madE, medF, madF, kE, kF);

    expected = false(1, n);
    expected(6) = true;        % only frame 6 clears both gates

    verifyClass(testCase, active, 'logical');
    verifySize(testCase, active, [1 n]);
    verifyEqual(testCase, active, expected);
end

function test_mask_exclusion(testCase)
    n = 10;

    medE = zeros(1, n);  madE = zeros(1, n) + 0.1;
    medF = zeros(1, n);  madF = zeros(1, n) + 0.1;
    kE = 5;  kF = 5;     % thresholds = 0.5

    % set two frames to exceed both thresholds
    E = zeros(1, n);  F = zeros(1, n);
    E([3 7]) = 0.8;    F([3 7]) = 0.9;

    % mask excludes frame 7
    mask = true(1, n);
    mask(7) = false;

    active = detect_frames(E, F, medE, madE, medF, madF, kE, kF, mask);

    expected = false(1, n);
    expected(3) = true;   % frame 7 is zeroed by mask

    verifyEqual(testCase, active, expected);
end
