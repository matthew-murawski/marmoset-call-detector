function tests = test_read_audio
% test_read_audio  unit tests for read_audio.m
%
% these tests synthesize small signals, write temp wavs, and exercise both
% the path and struct input modes, as well as default channel logic and errors.

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% add tests/helpers to the path for make_sine
    here = fileparts(mfilename('fullpath'));
    helpers = fullfile(here, '..', 'helpers');
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(helpers));
end

function test_path_input_with_explicit_channel(testCase)
% write a stereo wav and load channel 1 explicitly
    fs = 16000;
    dur = 0.05; % 50 ms
    t1 = make_sine(fs, dur, 440, 0.1);
    t2 = make_sine(fs, dur, 880, 0.2);
    X = [t1, t2];

    tmp = [tempname, '.wav'];
    audiowrite(tmp, X, fs);

    [x, fs_out] = read_audio(tmp, 1);

    verifyEqual(testCase, fs_out, double(fs));
    verifySize(testCase, x, [size(X,1), 1]);
    verifyLessThan(testCase, max(abs(x - double(t1))), 1e-12);
end

function test_struct_input_defaults_to_ch2_when_stereo(testCase)
% provide struct input without channel; expect channel 2 chosen
    fs = 22050;
    dur = 0.04;
    t1 = make_sine(fs, dur, 300, 0.05);
    t2 = make_sine(fs, dur, 600, 0.15);
    S.x = [t1, t2];
    S.fs = fs;

    [x, fs_out] = read_audio(S);

    verifyEqual(testCase, fs_out, double(fs));
    verifySize(testCase, x, [size(S.x,1), 1]);
    verifyLessThan(testCase, max(abs(x - double(t2))), 1e-12);
end

function test_mono_defaults_to_ch1(testCase)
% mono input should return the sole channel
    fs = 8000;
    dur = 0.03;
    t = make_sine(fs, dur, 250, 0.1);
    S.x = t;     % Nx1
    S.fs = fs;

    [x, fs_out] = read_audio(S);

    verifyEqual(testCase, fs_out, double(fs));
    verifySize(testCase, x, [numel(t), 1]);
    verifyLessThan(testCase, max(abs(x - double(t))), 1e-12);
end

function test_error_on_empty_data(testCase)
% empty struct input should throw the specified error
    S.x = [];
    S.fs = 16000;

    verifyError(testCase, @() read_audio(S), 'read_audio:invalidInput');
end