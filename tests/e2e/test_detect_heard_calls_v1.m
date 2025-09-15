function tests = test_detect_heard_calls_v1
% e2e test for detect_heard_calls_v1 on a synthetic 30 s track.
% background noise + 3 heard (7 khz) tone bursts + 2 self bursts elsewhere.
% asserts:
%   - exactly the 3 heard events are recovered (count match)
%   - on/off within ±20 ms of ground truth
%   - no detected events overlap self-masked windows (with default padding)

    tests = functiontests(localfunctions);
end

function setupOnce(t)
    % add helpers path
    here = fileparts(mfilename('fullpath'));
    helpers = fullfile(here, '..', 'helpers');
    t.applyFixture(matlab.unittest.fixtures.PathFixture(helpers));
end

function test_e2e_synthetic_track(t)
    % -- make synthetic data and ground truth
    [x, fs, self_labels, heard_truth] = make_synthetic_track();

    % -- call detector with defaults (params struct empty)
    input_struct = struct('x', x, 'fs', fs);
    heard = detect_heard_calls_v1(input_struct, self_labels, struct());

    % sanity: table shape and confidence present
    t.verifyClass(heard, 'table');
    t.verifyTrue(all(ismember({'on','off','dur','confidence'}, heard.Properties.VariableNames)));

    % -- check event count
    t.verifyEqual(height(heard), size(heard_truth,1), ...
        'detector must return exactly the planted heard events');

    % -- match detected to truth by nearest onset and assert timing within ±20 ms
    tol = 0.020; % seconds
    det_on  = heard.on(:);
    det_off = heard.off(:);

    used = false(height(heard),1);
    for i = 1:size(heard_truth,1)
        [~, j] = min(abs(det_on - heard_truth(i,1)));
        t.verifyFalse(used(j), 'duplicate match on detected event');
        used(j) = true;

        t.verifyLessThanOrEqual(abs(det_on(j)  - heard_truth(i,1)), tol, 'onset outside tolerance');
        t.verifyLessThanOrEqual(abs(det_off(j) - heard_truth(i,2)), tol, 'offset outside tolerance');
    end

    % -- assert no detected event overlaps padded self windows
    pre_pad_ms  = 30;
    post_pad_ms = 100;
    pad = [pre_pad_ms, post_pad_ms] / 1000;

    % build padded exclusion windows
    if isempty(self_labels)
        excl = zeros(0,2);
    elseif isnumeric(self_labels)
        excl = [max(0, self_labels(:,1)-pad(1)), self_labels(:,2)+pad(2)];
    else
        on  = arrayfun(@(s)s.on,  self_labels(:));
        off = arrayfun(@(s)s.off, self_labels(:));
        excl = [max(0, on-pad(1)), off+pad(2)];
    end

    for k = 1:height(heard)
        % any overlap?
        overlaps = any( (heard.on(k)  < excl(:,2)) & ...
                        (heard.off(k) > excl(:,1)) );
        t.verifyFalse(overlaps, 'event overlaps a self-masked window');
    end

    % -- confidence sanity: in [0,1]
    t.verifyGreaterThanOrEqual(min(heard.confidence), 0 - 1e-12);
    t.verifyLessThanOrEqual(max(heard.confidence), 1 + 1e-12);
end