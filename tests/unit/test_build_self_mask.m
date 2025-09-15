function tests = test_build_self_mask
% unit tests for build_self_mask.
% test 1: numeric Nx2 labels produce expected mask holes (with clipping and invalid ignored).
% test 2: struct .on/.off input yields identical mask as numeric input.
% test 3: empty cases (no labels, zero frames).

    tests = functiontests(localfunctions);
end

function test_numeric_labels_map_to_frames(testCase)
    % frame centers at 0:0.1:0.9  (10 frames)
    FP.t_frames = 0:0.1:0.9;
    FP.n_frames = numel(FP.t_frames);

    % intervals:
    % [0.1,0.3]   → frames at 0.1,0.2,0.3 → idx 2,3,4
    % [0.75,0.95] → frames at 0.8,0.9     → idx 9,10 (clipped to timeline)
    % [-1,0.05]   → frame at 0.0          → idx 1 (clip)
    % [0.5,0.5]   → invalid (off<=on)     → ignored
    L = [
        0.10  0.30;
        0.75  0.95;
       -1.00  0.05;
        0.50  0.50
    ];

    mask = build_self_mask(L, FP);

    expected = true(1, FP.n_frames);
    expected([1,2,3,4,9,10]) = false;

    verifyClass(testCase, mask, 'logical');
    verifySize(testCase, mask, [1 FP.n_frames]);
    verifyEqual(testCase, mask, expected);
end

function test_struct_input_equivalence(testCase)
    FP.t_frames = 0:0.1:0.9;
    FP.n_frames = numel(FP.t_frames);

    L_numeric = [
        0.10  0.30;
        0.75  0.95;
       -1.00  0.05
    ];

    L_struct(1).on = 0.10; L_struct(1).off = 0.30;
    L_struct(2).on = 0.75; L_struct(2).off = 0.95;
    L_struct(3).on = -1.0; L_struct(3).off = 0.05;

    m1 = build_self_mask(L_numeric, FP);
    m2 = build_self_mask(L_struct, FP);

    verifyEqual(testCase, m1, m2);
end

function test_empty_inputs_return_all_true(testCase)
    % case 1: no labels
    FP.t_frames = 0:0.1:0.9;
    FP.n_frames = numel(FP.t_frames);
    m = build_self_mask([], FP);
    verifyTrue(testCase, all(m));
    verifySize(testCase, m, [1 FP.n_frames]);

    % case 2: zero frames
    FP2.t_frames = zeros(1,0);
    FP2.n_frames = 0;
    m2 = build_self_mask([], FP2);
    verifySize(testCase, m2, [1 0]);
end
