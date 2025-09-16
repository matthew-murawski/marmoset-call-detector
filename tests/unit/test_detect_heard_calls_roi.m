function tests = test_detect_heard_calls_roi
% roi integration tests for detect_heard_calls_v1:
%  - excluding roi removes a clear event
%  - including roi restores detection
tests = functiontests(localfunctions);
end

function [x, fs, ev_on, ev_off, self_labels] = make_clip()
% 2 s mono clip with a strong 7 khz tone burst at ~1.0–1.2 s
rng(0);
fs = 48000;
dur = 2.0;
n = round(dur*fs);
t = (0:n-1).' / fs;

% low background + one heard event (strong tone)
x = 0.005*randn(n,1);
ev_on  = 1.00;
ev_off = 1.20;
amp    = 0.25;
f0     = 7000;                 % inside default band [5–12 khz]
idx = (t >= ev_on) & (t < ev_off);
x(idx) = x(idx) + amp*sin(2*pi*f0*t(idx));

% a self label elsewhere (shouldn't matter for these tests)
self_labels = [0.30 0.45];
end

function params = easy_params()
% slightly easier thresholds and shorter rolling window for a 2 s clip
params = struct( ...
    'bandpass', [5e3, 12e3], ...
    'win_ms', 25, ...
    'hop_ms', 10, ...
    'rolling_sec', 0.5, ...
    'kE', 2.5, ...
    'kF', 2.0, ...
    'k_low', 1.5, ...
    'release_frames', 2, ...
    'min_event_ms', 70, ...
    'merge_gap_ms', 40, ...
    'max_event_ms', 2000, ...
    'pre_pad_ms', 30, ...
    'post_pad_ms', 100 ...
    );
end

function test_roi_excludes_event_region(testCase)
[x, fs, ev_on, ev_off, self_labels] = make_clip();
P = easy_params();

% roi excludes [0.9, 1.3] where the event lives
P.roi_windows = [0.00 0.80; 1.40 2.00];

heard = detect_heard_calls_v1(struct('x', x, 'fs', fs), self_labels, P);

verifyClass(testCase, heard, 'table');
verifyTrue(testCase, all(ismember({'on','off','dur','confidence'}, heard.Properties.VariableNames)));

% expect zero events when roi excludes the true burst window
verifyEqual(testCase, height(heard), 0);
end

function test_roi_includes_event_region_allows_detection(testCase)
[x, fs, ev_on, ev_off, self_labels] = make_clip();
P = easy_params();

% roi includes the event region
P.roi_windows = [ev_on - 0.05, ev_off + 0.05];

heard = detect_heard_calls_v1(struct('x', x, 'fs', fs), self_labels, P);

verifyGreaterThanOrEqual(testCase, height(heard), 1);

% optional sanity: at least one event overlaps [ev_on, ev_off]
if ~isempty(heard)
    overlaps = any( (heard.on < ev_off) & (heard.off > ev_on) );
    verifyTrue(testCase, overlaps);
end
end
