classdef test_detect_quiet_frames < matlab.unittest.TestCase
    % tests for detect_quiet_frames: marks frames quiet when both features
    % fall below (median + k_silence * mad) within the mask.

    methods (Test)
        function marks_exact_quiet_segment(testCase)
            % craft features with a clear low segment
            n = 100;
            E = 1.1*ones(1,n);
            F = 2.2*ones(1,n);

            quiet_idx = 31:80;           % 50 frames (~0.5 s if hop=10 ms)
            E(quiet_idx) = 0.2;
            F(quiet_idx) = 0.3;

            medE = 1.0;  madE = 0.2;
            medF = 2.0;  madF = 0.5;
            k_silence = 0;               % threshold at median

            mask = true(1,n);

            quiet = detect_quiet_frames(E, F, medE, madE, medF, madF, k_silence, mask);

            % shape and type
            testCase.assertEqual(size(quiet), [1 n], 'quiet must be a 1×N row');
            testCase.assertClass(quiet, 'logical', 'quiet must be logical');

            % exact segment must be quiet, others not
            expected = false(1,n);
            expected(quiet_idx) = true;
            testCase.assertEqual(quiet, expected, 'quiet frames mismatch expected segment');
        end

        function nans_are_not_quiet(testCase)
            % nan in inputs should force non-quiet at those frames
            n = 40;
            E = 0.2*ones(1,n);
            F = 0.3*ones(1,n);
            E(20) = NaN;  F(25) = NaN;

            medE = 1.0;  madE = 0.2;
            medF = 2.0;  madF = 0.5;
            k_silence = 0;
            mask = true(1,n);

            quiet = detect_quiet_frames(E, F, medE, madE, medF, madF, k_silence, mask);

            testCase.assertFalse(quiet(20), 'nan in E should not be marked quiet');
            testCase.assertFalse(quiet(25), 'nan in F should not be marked quiet');
            testCase.assertTrue(all(quiet(setdiff(1:n, [20 25]))), ...
                'all other frames should be quiet under these values');
        end

        function respects_mask(testCase)
            % masked-out frames should never be quiet
            n = 30;
            E = 0.2*ones(1,n);
            F = 0.3*ones(1,n);

            medE = 1.0;  madE = 0.2;
            medF = 2.0;  madF = 0.5;
            k_silence = 0;

            mask = true(1,n);
            mask(10:15) = false;

            quiet = detect_quiet_frames(E, F, medE, madE, medF, madF, k_silence, mask);

            testCase.assertFalse(any(quiet(10:15)), 'masked frames must be false');
            testCase.assertTrue(all(quiet(setdiff(1:n,10:15))), 'unmasked frames should be quiet');
        end
    end
end