%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Script for reproducibly generating MATLAB PREP artifacts via CI %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Author: Austin Hurst


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Step 0: Initialize MATLAB environment for running PREP %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Load settings from settings.m file
run('settings.m');

% Load EEGLAB and MATLAB PREP
addpath(eeglab_path);
addpath(genpath(matprep_path));
eeglab nogui;

% Install BIOSIG package for reading EDF/BDF files
plugin_askinstall('Biosig', [], true);
warning('off');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Step 1: Load raw data into EEGLAB and prepare for PREP %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    
% Actually read in data
pretty_header(['Processing ' filename]);
EEG = pop_biosig(filename);
EEG = eeg_checkset(EEG);
EEG.name = filename;
    
% Update PREP parameters using channel count and sample rate
eeg_channels = 1:EEG.nbchan;
params.referenceChannels = eeg_channels;
params.evaluationChannels = eeg_channels;
params.rereferencedChannels = eeg_channels;
params.detrendChannels = eeg_channels;
params.lineNoiseChannels = eeg_channels;
params.lineFrequencies = powerline_hz:powerline_hz:EEG.srate/2;

% Fix channel names so that montage loads correctly
for n = eeg_channels
    % Strip trailing '.'s from the channel names
    tmp = strrep(EEG.chanlocs(n).labels, '.', '');
    % Fix channel capitalization (i.e., all-caps except z)
    tmp = strrep(upper(tmp), 'Z', 'z');
    % Write fixed label back to EEG object
    EEG.chanlocs(n).labels = tmp;
end

% Add montage to dataset
EEG = pop_chanedit(EEG, 'lookup', montage_path);
EEG = eeg_checkset(EEG);

% Prepare for PREP (copy/pasted from PREP internals)
EEG.etc.noiseDetection = ...
    struct(...
        'name', params.name, ...
        'version', getPrepVersion, ...
        'originalChannelLabels', [], ...
        'errors', [], ...
        'boundary', [], ...
        'detrend', [], ...
        'lineNoise', [], ...
        'reference', [], ...
        'postProcess', [], ...
        'interpolatedChannelNumbers', [], ...
        'removedChannelNumbers', [], ...
        'stillNoisyChannelNumbers', [], ...
        'fullReferenceInfo', false ...
    );
EEG.data = double(EEG.data);   % Don't monkey around -- get into double
EEG.etc.noiseDetection.originalChannelLabels = {EEG.chanlocs.labels};
defaults = getPrepDefaults(EEG, 'general');
[params, errors] = checkPrepDefaults(params, params, defaults);
if ~isempty(errors)
    error('prepPipeline:GeneralDefaultError', ['|' sprintf('%s|', errors{:})]);
end
defaults = getPrepDefaults(EEG, 'boundary');
[boundaryOut, errors] = checkPrepDefaults(params, struct(), defaults);
EEG.etc.noiseDetection.boundary = boundaryOut;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Step 2: Actually run all components of the PREP pipeline %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Remove trend prior to cleanline
fprintf('\n\n=== Removing Trends Pre-CleanLine... ===\n\n');
[EEGNew, detrend] = removeTrend(EEG, params);
EEG.etc.noiseDetection.detrend = detrend;
defaults = getPrepDefaults(EEG, 'detrend');
params = checkPrepDefaults(detrend, params, defaults);

% Perform cleanline on data and put trend back
fprintf('\n\n=== Performing CleanLine... ===\n\n');
[EEGClean, lineNoise] = removeLineNoise(EEGNew, params);
EEG.etc.noiseDetection.lineNoise = lineNoise;
lineChannels = lineNoise.lineNoiseChannels;
EEG.data(lineChannels, :) = ...
    EEG.data(lineChannels, :) ...
    - EEGNew.data(lineChannels, :) ...
    + EEGClean.data(lineChannels, :);
clear EEGNew;
 
% Perform robust re-referencing on data
fprintf('\n\n=== Performing Robust Referencing... ===\n\n');
[EEG, referenceOut] = performReference(EEG, params);

% Save detailed internal PREP details to a .mat
prep_info = EEG.etc;
prep_info.noiseDetection.reference = referenceOut;
prep_info.noiseDetection.fullReferenceInfo = true;
prep_info.noiseDetection.interpolatedChannelNumbers = ...
    referenceOut.interpolatedChannels.all;
prep_info.noiseDetection.stillNoisyChannelNumbers = ...
    referenceOut.noisyStatistics.noisyChannels.all;
save([artifact_dir sep 'matprep_info'], 'prep_info');
pretty_header([filename ' complete!']);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Define helper functions at the bottom of the file %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Function for printing pretty headers/footers in MATLAB scripts
function [] = pretty_header(content);
    header = ['### ' content ' ###'];
    header_pad = join(repmat('#', 1, strlength(header)), '');
    fprintf(['\n' header_pad '\n']);
    fprintf([header '\n']);
    fprintf([header_pad '\n\n']);
end
