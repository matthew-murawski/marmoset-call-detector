function tests = test_mask_plus_hysteresis
% tests for mask + hysteresis composition.
tests = functiontests(localfunctions);
end

function test_mask_blocks_frames_even_when_state_true(t)
% set up a short sequence with a high-energy/flux burst that spans masked frames

n = 20;
E = zeros(1,n);
F = zeros(1,n);

% make a burst on frames 5:8 that should trigger thresholds
E(5:8) = 3;
F(5:8) = 3;

% robust stats: simple constants
medE = zeros(1,n);
madE = ones(1,n);
medF = zeros(1,n);
madF = ones(1,n);

% thresholds
kE = 1; kF = 1;          % detection gates
kHighE = 1; kHighF = 1;  % hysteresis enter gates
kLow = 0.5;              % hysteresis low gate
release_frames = 2;

% mask out frames 6:7 (inside the burst)
mask = true(1,n);
mask(6:7) = false;

% compose the path
out = compose_mask_and_hyst(E, F, medE, madE, medF, madF, ...
    kE, kF, kHighE, kHighF, kLow, release_frames, mask);

% pre-masked thresholding should suppress candidates inside the mask
t.verifyFalse(out.active_raw(6), 'masked frame 6 should be suppressed pre-hysteresis');
t.verifyFalse(out.active_raw(7), 'masked frame 7 should be suppressed pre-hysteresis');

% hysteresis state spans frames 5:9 (given release_frames=2)
% regardless, final active must be false on masked frames
t.verifyFalse(out.active(6), 'masked frame 6 must not be active');
t.verifyFalse(out.active(7), 'masked frame 7 must not be active');

% and non-masked frames overlapping the state can be active
t.verifyTrue(out.active(5), 'unmasked frame at burst onset should be active');
t.verifyTrue(out.active(8), 'unmasked frame within burst should be active');
t.verifyTrue(out.state(9), 'state should persist one frame past burst before release');
end

function test_burst_fully_masked_no_active_inside(t)
% create a burst entirely inside mask=false; hysteresis may turn on,
% but no frames inside the mask may be active.

n = 20;
E = zeros(1,n); F = zeros(1,n);
E(12:14) = 3; F(12:14) = 3;

medE = zeros(1,n); madE = ones(1,n);
medF = zeros(1,n); madF = ones(1,n);

kE = 1; kF = 1;
kHighE = 1; kHighF = 1;
kLow = 0.5; release_frames = 2;

mask = true(1,n);
mask(12:14) = false;

out = compose_mask_and_hyst(E, F, medE, madE, medF, madF, ...
    kE, kF, kHighE, kHighF, kLow, release_frames, mask);

% nothing inside 12:14 may be active
t.verifyFalse(any(out.active(12:14)), 'fully masked burst must yield no active frames inside');

% hysteresis may carry state past the mask; first allowed frame after 14 can be active
% with the chosen release, state stays on through frame 15 then releases at 16
t.verifyTrue(out.state(15), 'state should still be on immediately after masked burst');
t.verifyTrue(out.active(15), 'first unmasked frame after burst can be active');
end

% --- helper to compose the path requested in the prompt ---
function out = compose_mask_and_hyst(E, F, medE, madE, medF, madF, ...
    kE, kF, kHighE, kHighF, kLow, release_frames, mask)

% detect candidates with pre-mask
active_raw = detect_frames(E, F, medE, madE, medF, madF, kE, kF, mask);

% run hysteresis purely from features and robust stats
state = apply_hysteresis(E, F, medE, madE, medF, madF, ...
    kHighE, kHighF, kLow, release_frames);

% enforce mask after hysteresis too
active = state & logical(mask(:)).';

out.active_raw = active_raw;
out.state = state;
out.active = active;
end