function tests = test_sanity
% test_sanity
% minimal unit test bootstrap to verify the harness is wired.
tests = functiontests(localfunctions);
end

function test_truth(~)
% simple always-true test
assert(true);
end
