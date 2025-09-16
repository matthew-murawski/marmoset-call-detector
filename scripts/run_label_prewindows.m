function [heard, silence] = run_label_prewindows(wav_path, produced_labels_path, out_heard_txt, out_silence_txt, varargin)
% run_label_prewindows
% detect heard calls and conservative silences inside pre-windows before each
% produced onset, then export two audacity label tracks for quick qc.
%
% usage (function)
% [heard, silence] = run_label_prewindows('sess.wav', 'produced.mat', ...
%     'sess_heard.txt', 'sess_silence.txt', ...
%     'PreWindowSec', 5, 'KSilence', 2.0, 'MinSilenceMs', 500, 'SilenceEdgeMs', 120, ...
%     'HeardParams', struct('kE',4.0,'kF',3.5));  % example conservative profile
%
% usage (script-like from command window)
% run_label_prewindows('sess.wav','produced_labels.txt','heard.txt','silence.txt');
%
% inputs
%   wav_path             : path to wav file
%   produced_labels_path : path to produced labels (.txt audacity, or .mat with Nx2 self_labels)
%   out_heard_txt        : output audacity labels path for heard
%   out_silence_txt      : output audacity labels path for silence
%
% name-value options (forwarded as appropriate)
%   'PreWindowSec'   (default 5)
%   'HeardParams'    (struct; forwarded to detect_heard_calls_v1; roi set here)
%   'KSilence'       (default 2.5)
%   'MinSilenceMs'   (default 500)
%   'MergeGapMs'     (default 60)
%   'SilenceEdgeMs'  (default 120)
%   'MaxSilenceMs'   (default inf)
%
% notes
% - comments are kept lower-case and minimal by project style.

    % -- parse args
    p = inputParser;
    p.addRequired('wav_path', @(s)ischar(s)||isstring(s));
    p.addRequired('produced_labels_path', @(s)ischar(s)||isstring(s));
    p.addRequired('out_heard_txt', @(s)ischar(s)||isstring(s));
    p.addRequired('out_silence_txt', @(s)ischar(s)||isstring(s));
    p.addParameter('PreWindowSec', 5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('HeardParams', struct(), @(s)isstruct(s)||isempty(s));
    p.addParameter('KSilence', 2.5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MinSilenceMs', 500, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MergeGapMs', 60, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('SilenceEdgeMs', 120, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MaxSilenceMs', inf, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.parse(wav_path, produced_labels_path, out_heard_txt, out_silence_txt, varargin{:});
    opt = p.Results;

    % -- load produced/self labels
    self_labels = load_self_labels(opt.produced_labels_path);

    % -- run orchestrator
    [heard, silence] = detect_heard_and_silence_prewindows( ...
        opt.wav_path, self_labels, ...
        'PreWindowSec', opt.PreWindowSec, ...
        'HeardParams', opt.HeardParams, ...
        'KSilence', opt.KSilence, ...
        'MinSilenceMs', opt.MinSilenceMs, ...
        'MergeGapMs', opt.MergeGapMs, ...
        'SilenceEdgeMs', opt.SilenceEdgeMs, ...
        'MaxSilenceMs', opt.MaxSilenceMs);

    % -- write audacity label files (explicit labels for clarity)
    export_audacity_labels(heard,   opt.out_heard_txt,   'Label', 'heard');
    export_audacity_labels(silence, opt.out_silence_txt, 'Label', 'silence');

    % -- short summary to console
    h_dur = sum(heard.dur, 'omitnan');
    s_dur = sum(silence.dur, 'omitnan');
    fprintf('[run_label_prewindows] heard:   %d events, total %.2f s -> %s\n', ...
        height(heard), h_dur, string(opt.out_heard_txt));
    fprintf('[run_label_prewindows] silence: %d events, total %.2f s -> %s\n', ...
        height(silence), s_dur, string(opt.out_silence_txt));
end

% --- helpers ---

function L = load_self_labels(path_in)
    % accept .mat with Nx2 self_labels or audacity .txt (start/end/label)
    path_in = string(path_in);
    if endsWith(lower(path_in), ".mat")
        S = load(path_in);
        if isfield(S, 'self_labels')
            L = coerce_labels(S.self_labels);
        elseif isfield(S, 'phrases')
            L = struct_to_labels(S.phrases);
        else
            % try a common alternative
            fn = fieldnames(S);
            if ~isempty(fn) && isstruct(S.(fn{1}))
                L = struct_to_labels(S.(fn{1}));
            else
                error('run_label_prewindows:BadMat', ...
                    'mat file must contain Nx2 self_labels or a struct array with .on/.off.');
            end
        end
    else
        % assume audacity txt
        try
            phrases = audacity_labels_to_phrases(path_in);
            L = struct_to_labels(phrases);
        catch
            % minimal fallback parser: start\tend\tlabel
            [on, off] = read_labels_txt_basic(path_in);
            L = [on(:) off(:)];
        end
    end
    if isempty(L) || size(L,2)~=2
        error('run_label_prewindows:EmptyLabels', 'no valid produced labels found.');
    end
end

function L = coerce_labels(A)
    if isnumeric(A) && size(A,2)==2
        L = double(A);
    elseif isstruct(A)
        L = struct_to_labels(A);
    else
        error('run_label_prewindows:BadLabels', 'unsupported label container.');
    end
end

function L = struct_to_labels(S)
    if isempty(S), L = zeros(0,2); return; end
    if all(isfield(S, {'on','off'}))
        on  = arrayfun(@(s) double(s.on),  S(:));
        off = arrayfun(@(s) double(s.off), S(:));
        L = [on(:) off(:)];
    elseif all(isfield(S, {'eventStartTime','eventStopTime'}))
        on  = arrayfun(@(s) double(s.eventStartTime),  S(:));
        off = arrayfun(@(s) double(s.eventStopTime),   S(:));
        L = [on(:) off(:)];
    else
        error('run_label_prewindows:StructLabels', 'struct must have .on/.off or .eventStartTime/.eventStopTime');
    end
end

function [on, off] = read_labels_txt_basic(fname)
    fid = fopen(fname, 'r');
    if fid<0, error('run_label_prewindows:OpenTxt', 'cannot open: %s', fname); end
    C = textscan(fid, '%f%f%s', 'Delimiter', '\t', 'MultipleDelimsAsOne', true);
    fclose(fid);
    on = C{1}; off = C{2};
end