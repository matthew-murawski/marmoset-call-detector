function heard = detect_heard_calls_v1(wav_path, self_labels, params)
% detect_heard_calls_v1
% orchestrate the v1 heard-call detector (reference-mic only).
% % this is a placeholder stub. real logic will be added in later prompts.

%
% inputs
%   wav_path: path to wav file (or audio/fs pair in later overload)
%   self_labels: nx2 [on off] or struct array with .on/.off (seconds)
%   params: struct of parameters (see readme; defaults in later steps)
%
% output
%   heard: events table (on/off/dur/confidence) with meta

%#ok<*INUSD>
heard = table();
end
