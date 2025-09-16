function out = run_detect_heard_calls(session_or_wav, out_txt, varargin)
% run heard-call detection and export an audacity label track.
%
% usage (simple, backward-compatible):
%   run_detect_heard_calls('path/to/refmic.wav', 'heard_labels.txt')
%
% usage (pre-window mode using produced labels):
%   run_detect_heard_calls('path/to/refmic.wav', 'heard_labels.txt', ...
%       'ProducedLabels', 'produced_labels.txt', ...   % audacity .txt OR MAT with Nx2 double 'self_labels'
%       'PreWindowSec', 5, ...
%       'Conservative', true)
%
% what this does
% - if 'ProducedLabels' is provided, we build roi_windows = [on_i - T, on_i)
%   with T = PreWindowSec (default 5 s), clipped at >= 0. these windows are
%   passed to detect_heard_calls_v1 via params.roi_windows (safe no-op if
%   your v1 doesn't yet use them).
% - if 'Conservative' is true, we tighten entry + thresholds to reduce false positives:
%     params.kE = 4.0;            % higher energy k
%     params.kF = 4.0;            % higher positive spectral flux k
%     params.min_event_ms = 100;  % longer minimum duration (ms)
%     params.release_frames = 4;  % longer to release (stickier off)
%     params.enter_frames  = 2;   % require >=2 frames above high to enter
%
% notes
% - this function preserves the original simple usage; you can ignore the new args.
% - export call order is (events_table, out_txt, ...); label is set to 'heard'.

% -------------------- parse args
p = inputParser;
p.FunctionName = mfilename;

addRequired(p, 'session_or_wav');   % string path to wav (preferred) or session-like struct if your v1 supports it
addRequired(p, 'out_txt', @(x)ischar(x)||isstring(x));

addParameter(p, 'ProducedLabels', '', @(x)ischar(x)||isstring(x));
addParameter(p, 'PreWindowSec', 5.0, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p, 'Conservative', false, @(x)islogical(x)||ismember(x,[0 1]));
addParameter(p, 'Params', struct(), @isstruct);  % optional passthrough

parse(p, session_or_wav, out_txt, varargin{:});
args = p.Results;

% -------------------- load produced labels if provided
roi_windows = [];
self_labels = [];  % Nx2 [on off] for self mask usage in v1 (if used there)

if ~isempty(args.ProducedLabels)
    [self_on, self_off] = read_produced(args.ProducedLabels);
    if ~isempty(self_on)
        T = args.PreWindowSec;
        roi_windows = [max(0, self_on - T), self_on];
        self_labels = [self_on, self_off];
    end
end

% -------------------- build params (compose caller-supplied Params)
params = args.Params;

% pass roi windows if present
if ~isempty(roi_windows)
    params.roi_windows = roi_windows;  %#ok<STRNU>  % safe if v1 ignores it (keeps backward-compat)
end

% conservative overrides
if args.Conservative
    params.kE = 4.0;
    params.kF = 4.0;
    params.min_event_ms = 100;
    params.release_frames = 4;
    params.enter_frames  = 2;
end

% -------------------- call the detector
% keep the original behavior: you can pass a wav path string directly
heard = detect_heard_calls_v1(args.session_or_wav, self_labels, params);

% -------------------- export to audacity labels (correct arg order)
export_audacity_labels(heard, args.out_txt, 'Label', 'heard');

% optional return
if nargout>0
    out = struct('heard', heard, 'roi_windows', roi_windows, 'params', params);
end

end

% ======================================================================
% helpers
% ======================================================================

function [on, off] = read_produced(path)
% read produced labels from either an audacity .txt or a MAT with Nx2 'self_labels'.
% returns column vectors 'on' and 'off' in seconds. empty if nothing found.

    path = char(path);
    on = []; off = [];
    
    if endsWith(lower(path), '.txt')
        % prefer using the repo's helper if available
        try
            P = audacity_labels_to_phrases(path);
            if isstruct(P) && isfield(P,'on') && isfield(P,'off')
                on = P.on(:);
                off = P.off(:);
                return;
            end
        catch %#ok<CTCH>
            % fall back to a minimal reader
        end
        [on, off] = local_read_audacity_min(path);
        
    elseif endsWith(lower(path), '.mat')
        S = load(path);
        if isfield(S,'self_labels') && isnumeric(S.self_labels) && size(S.self_labels,2)>=2
            on  = S.self_labels(:,1);
            off = S.self_labels(:,2);
        else
            warning('run_detect_heard_calls:NoSelfLabels', ...
                'mat file lacked Nx2 ''self_labels''; ignoring produced labels.');
        end
    else
        warning('run_detect_heard_calls:UnknownProducedFormat', ...
            'unknown produced-labels format: %s', path);
    end
end

function [on, off] = local_read_audacity_min(txt)
% minimal audacity .txt reader: expects start<TAB>stop<TAB>label
    fid = fopen(txt, 'r');
    if fid<0
        warning('run_detect_heard_calls:OpenFailed', 'could not open %s', txt);
        on = []; off = [];
        return;
    end
    C = textscan(fid, '%f%f%[^\n\r]', 'Delimiter', '\t', 'CollectOutput', true);
    fclose(fid);
    if isempty(C{1})
        on = []; off = [];
    else
        on  = C{1}(:,1);
        off = C{1}(:,2);
    end
end