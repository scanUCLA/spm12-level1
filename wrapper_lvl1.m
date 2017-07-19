%% User-editable parameters

% Path of study
studyDir='/space/raid8/data/lieber/MINERVA2/nondartel';

% Path of directory in which subjects' folders live
subjectDir='/space/raid8/data/lieber/MINERVA2/nondartel/data';

% What would you like to name the analysis? (folder will be automatically created in subject's analysis folder)
analysisID = 'RED_170426';

% Where to save SPM batches
batchDir = '/space/raid8/data/lieber/MINERVA2/nondartel/level1/RED_170426/batches';

% What pattern should be used for finding subject folders? (use wildcards)
subName = 'SLEEP_*';

% What pattern should be used for finding functional folders? (use wildcards)
runName = {'BOLD_Reddit_A_*', 'BOLD_Reddit_B_*'};

% What are the first char(s) in your functional images? (use wildcards)
funcName = 'swBOLD_Reddit_*';

% Skip subjects (write their directory names)
skipSubs = {}; % Use the full subject's folder name in single quotes e.g.: {'w001' 'w002'}

% Do specific subjects (write their directory names)
doSubs = {};  % Use the full subject's folder name in single quotes e.g.: {'w001' 'w002'}

% Location of task data (will have to edit rest of code if you have this)
taskDatExist = 1; % 1=yes, 0=no
taskDatPath = '/space/raid8/data/lieber/MINERVA2/fMRI_Tasks/Reddit_Task/data';
%taskDatName = 'MINERVA2Output_subj*_STRUCT.mat';

% % Customizable SPM design/estimation parameters:
% TR = 2; % What is your TR (in secs)
% funcFormat = 2; % What format are your functional images in? 1=3D img/hdr, 2=4D nii
% acTAG = 0; % autocorrelation correction: 0=no, 1=yes
% rpTAG = 1; % include motion regressors: 0=no, 1=yes
% hpf = 128; % high-pass filter (in secs)
% brainmask = '/home/kevin/Documents/MATLAB/spm12/toolbox/FieldMap/brainmask.nii'; % Mask for the analysis:

%% Set-up subjects

% % Make directory in which to save job files
% batchDir = sprintf('%s/scripts/level1/gratitude/%s/batches',studyDir,analysisID);
% try
%     mkdir(batchDir);
% catch
% end

spm('defaults','fmri');   % initiatizes SPM defaults for fMRI modality
spm_jobman('initcfg');    % initializes job configurations

% Find all subject folders and their functional image paths
d = dir([subjectDir '/' subName]);
subInfo = struct;
for ii = 1:length(d)
    subInfo(ii).ID = str2double(d(ii).name(7:9));
    subInfo(ii).name = d(ii).name;
    subInfo(ii).funcPath = [];
    subInfo(ii).rpPath = [];
    subInfo(ii).behavPath = [];
    subInfo(ii).status = NaN;
    subInfo(ii).error = [];
    
    try
        for r = 1:length(runName)
            % Have to do this because SPM is insane
            runDir = dir([subjectDir '/' d(ii).name '/raw/' runName{r}]);
            rpPath = strtrim(ls([subjectDir '/' d(ii).name '/raw/' runName{r} '/rp_' runName{r} '.txt']));
            [vols, ~] = spm_select('ExtFPList', [subjectDir '/' d(ii).name '/raw/' runDir.name], funcName, Inf);
            
            % Save volumes, rpPath in subInfo struct
            subInfo(ii).funcPath{r} = cellstr(strcat(vols));
            subInfo(ii).rpPath{r} = rpPath;
        end
        
        
        subInfo(ii).status = NaN;
        subInfo(ii).error = 'Not run yet';
    catch
        subInfo(ii).status = 0;
        subInfo(ii).error = 'functionals/rp file not found';
    end
    try
        behavPath = strtrim(ls([taskDatPath '/MINERVA2Output_subj' d(ii).name(7:9) '_STRUCT.mat']));
        subInfo(ii).behavPath = behavPath;
    catch
        subInfo(ii).status = 0;
        subInfo(ii).error = [subInfo(ii).error ' & task behavioral data not found'];
    end    
end
        
% Do only specified subjects
if ~isempty(doSubs)
    % Check if subjects exist
    notExist = find(~ismember(doSubs, {subInfo.name}));
    if ~isempty(notExist)
        error(['ERROR: subjects ' doSubs{notExist} ' could not be found!']);
    end
    
    % Reduce subInfo to specified subjects
    inds = find(ismember({subInfo.name}, doSubs));
    subInfo = subInfo(inds);
end

% Skip specified subjects
if ~isempty(skipSubs)
    disp(['Skipping subjects ' skipSubs]);
    inds = find(~ismember({subInfo.name}, skipSubs));
    subInfo = subInfo(inds);
end

% Check if all remaining subjects have functionals
disp('Finding task directories and functional files...');
noFunc = 0;
for ii = 1:length(subInfo)
    if isempty(subInfo(ii).funcPath)
        warning(['functionals for ' subInfo(ii).name ' could not be found!']);
        noFunc = 1;
    else
        disp(['Adding functionals for ' subInfo(ii).name]);
    end
end
% Continue and skip those without functionals?
if noFunc == 1
    disp(' ');
    disp('WARNING: functionals for some subject(s) could not be found (see warnings above)...');
    disp(' ');
    continueStr = input('Continue and skip subjects without functionals? (1=yes, 0=no): ');
    
    if continueStr == 1
        disp('Continuing, skipping subjects without functionals...');
    else
        error('ERROR: all subjects require functional files, check their directories');
    end
end

% Check if remaining subs have behav task data (edit this to match your data!)
if taskDatExist
    disp('Finding behavioral data from task...');
    noBehav = 0;
    for ii = 1:length(subInfo)
        if isempty(subInfo(ii).behavPath)
            warning(['behavioral data for ' subInfo(ii).name ' could not be found!']);
            noBehav = 1;
        else
            disp(['Adding behavioral data for ' subInfo(ii).name]);
        end
    end
    disp(' ');
    if noBehav == 1
        % Continue and skip those without task data?
        disp(' ');
        disp('WARNING: task data for the above subject(s) could not be found (see "subInfo" variable)...');
        disp(' ');
        continueStr = input('Continue and skip subjects without task data? (1=yes, 0=no): ');
        if continueStr == 1
            disp('Continuing, skipping subjects without task data...');
        else
            error('ERROR: all subjects require task data, check their directories');
        end
    else
        disp('Task data found for all subjects!');
    end 
end

%% Make and run batches
%pool = parpool('local', 12);
for s = 1:length(subInfo)
    if subInfo(s).status == 0 % Skip subjects or not
        disp(['Skipping subject ' subInfo(s).name ': ' subInfo(s).error]);
    else
        disp(['Running subject ' subInfo(s).name]);
        try           
            % Run subject
            [subInfo(s).status, subInfo(s).error, subInfo(s).cond] = run_lvl1(subInfo(s), subjectDir, analysisID, batchDir);
            if subInfo(s).status == 1
                disp(['subject ' subInfo(s).name ' successful']);
            elseif subInfo(s).status == 0
                disp([subInfo(s).error ' for ' subInfo(s).name]);
            end
        catch % Error
            subInfo(s).status = 0;
            subInfo(s).error = 'Unexpected error in run function';
            disp(['Unexpected ERROR on subject ' subInfo(s).name]);
        end
    end
end
%delete(pool);

% Save SubInfo struct
date = datestr(now,'yyyymmdd_HHMM');
filename = [batchDir '/subInfo_' date '.mat'];
save(filename,'subInfo');



