classdef test_dilate_events_mask < matlab.unittest.TestCase
    % tests for dilate_events_mask: 1-d logical dilation by a frame radius

    methods (Test)
        function single_impulse_expands_symmetrically(testCase)
            n = 25;
            i = 10;
            r = 4;
            m = false(1,n);
            m(i) = true;

            d = dilate_events_mask(m, r);

            expm = false(1,n);
            expm(max(1,i-r):min(n,i+r)) = true;

            testCase.assertEqual(d, expm, 'single impulse dilation mismatch');
        end

        function separated_runs_do_not_merge_when_gap_large(testCase)
            n = 40;
            r = 3;
            m = false(1,n);
            idx1 = 6;   % run 1 center
            idx2 = 31;  % run 2 center (gap > 2*r so they should not merge)
            m([idx1 idx2]) = true;

            d = dilate_events_mask(m, r);

            expm = false(1,n);
            expm(max(1,idx1-r):min(n,idx1+r)) = true;
            expm(max(1,idx2-r):min(n,idx2+r)) = true;

            testCase.assertEqual(d, expm, 'separated runs merged unexpectedly');
        end

        function radius_zero_is_identity(testCase)
            n = 30;
            m = false(1,n);
            m([3 5 10 29]) = true;

            d = dilate_events_mask(m, 0);

            testCase.assertEqual(d, m, 'radius 0 must return identical mask');
        end
    end
end