function tests = test_frames_to_events
% tests for frames_to_events (runs→min/merge/max and time conversion).
tests = functiontests(localfunctions);
end

function setupOnce(t)
% common frame grid: 10 ms hop, 50 frames (0.00..0.49 s)
t.TestData.n = 50;
t.TestData.hop_s = 0.01;
t.TestData.t_frames = (0:t.TestData.n-1) * t.TestData.hop_s;
t.TestData.FP = struct('t_frames', t.TestData.t_frames, 'hop_s', t.TestData.hop_s);
end

function test_short_blips_removed(t)
FP = t.TestData.FP;
hop_s = t.TestData.hop_s;
n = t.TestData.n;

active = false(1,n);
% run1: 2 frames (20 ms) -> should be dropped when min_event_ms = 30
active(6:7) = true;
% run2: 3 frames (30 ms) -> equal to threshold; keep (spec says < is dropped)
active(20:22) = true;

min_event_ms  = 30;
merge_gap_ms  = 15;
max_event_ms  = 4000;

E = frames_to_events(active, FP, min_event_ms, merge_gap_ms, max_event_ms);
t.verifySize(E, [1 3], 'only the 30 ms run should remain');

% expected on/off using t_frames and hop
on_exp  = FP.t_frames(20);
off_exp = FP.t_frames(22) + hop_s;  % 3 frames => 3*hop
t.verifyEqual(E.on, on_exp, 'AbsTol', 1e-12);
t.verifyEqual(E.off, off_exp, 'AbsTol', 1e-12);
t.verifyEqual(E.dur, off_exp - on_exp, 'AbsTol', 1e-12);
end

function test_small_gaps_merged(t)
FP = t.TestData.FP;
hop_s = t.TestData.hop_s;
n = t.TestData.n;

active = false(1,n);
% first run: frames 10:14 (5 frames -> 50 ms)
active(10:14) = true;
% gap: frame 15 is false (gap = 1 hop = 10 ms)
% second run: frames 16:18 (3 frames -> 30 ms)
active(16:18) = true;

min_event_ms = 10;   % allow both runs
merge_gap_ms = 15;   % 10 ms gap < 15 ms -> merge
max_event_ms = 4000; % no truncation

E = frames_to_events(active, FP, min_event_ms, merge_gap_ms, max_event_ms);
t.verifySize(E, [1 3], 'runs should merge into a single event');

on_exp  = FP.t_frames(10);
off_exp = FP.t_frames(18) + hop_s; % merged off extends through second run
dur_exp = off_exp - on_exp;        % includes internal 10 ms gap

t.verifyEqual(E.on,  on_exp,  'AbsTol', 1e-12);
t.verifyEqual(E.off, off_exp, 'AbsTol', 1e-12);
t.verifyEqual(E.dur, dur_exp, 'AbsTol', 1e-12);
end

function test_long_event_truncated(t)
FP = t.TestData.FP;
n = t.TestData.n;

active = false(1,n);
% long run: 200 frames would exceed n=50; instead make 180 ms within our grid
% create 40 frames (0.4 s) and truncate with max_event_ms=150 ms
active(5:44) = true;  % 40 frames -> 0.40 s

min_event_ms = 10;
merge_gap_ms = 10;
max_event_ms = 150;    % cap at 0.150 s

E = frames_to_events(active, FP, min_event_ms, merge_gap_ms, max_event_ms);
t.verifySize(E, [1 3], 'single event should remain');

on_exp  = FP.t_frames(5);
off_exp = on_exp + 0.150;  % truncated
t.verifyEqual(E.on,  on_exp, 'AbsTol', 1e-12);
t.verifyEqual(E.off, off_exp, 'AbsTol', 1e-12);
t.verifyEqual(E.dur, 0.150,  'AbsTol', 1e-12);
end

function test_empty_input_returns_empty_table(t)
FP = t.TestData.FP;
n = t.TestData.n;

active = false(1,n);
E = frames_to_events(active, FP, 30, 20, 4000);

t.verifyClass(E, 'table');
t.verifyEqual(E.Properties.VariableNames, {'on','off','dur'});
t.verifyEqual(height(E), 0);
end