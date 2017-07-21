function [status, error, cond] = run_lvl1(subDat, subjectDir, analysisID, batchDir,...
    execTAG, TR, funcFormat, acTAG, rpTAG, hpf, brainMask)

%% Setup

status = [];
error = [];
cond = [];

% Create level 1 dir in subject folder
lvl1Dir = [subjectDir '/' subDat.name '/analysis/' analysisID];
try
    mkdir(lvl1Dir);
catch
end

if exist([lvl1Dir 'SPM.mat'], 'file')
    disp([lvl1Dir 'SPM.mat already exists']);
    error = [lvl1Dir 'SPM.mat already exists'];
    status = 0;
    return
end

% Start SPM
spm12_path;
spm('defaults','fmri');   % initiatizes SPM defaults for fMRI modality
spm_jobman('initcfg');    % initializes job configurations

%% Organize task data (EDIT this section to match your task)
try
    load(subDat.behavPath)
    output = output;
    
    % Sanity check subject ID
    if str2double(output(1).subjID) == subDat.ID
    else
        status = 0;
        error = 'subject IDs dont match';
        return
    end
    
    % Find sleep condition
    if any(strcmp({output.condition}, 'ID'))
        prompt = 'ID';
    elseif any(strcmp({output.condition}, 'YS'))
        prompt = 'YS';
    end
    cond = prompt;
    
    %%% Find condition timing
    for r = 1:length(subDat.rpPath)
        % Sleep
        inds = find([output.run] == r & strcmp({output.condition}, prompt)); % Run A
        sleep_ons(:,r) = [output(inds).trialOnset];
        sleep_dur(:,r) = [output(inds).trialDuration];
        
        % Control
        inds = find([output.run] == r & strcmp({output.condition}, 'control')); % Run A
        control_ons(:,r) = [output(inds).trialOnset];
        control_dur(:,r) = [output(inds).trialDuration];
        
        % Filler
        inds = find([output.run] == r & strcmp({output.condition}, 'filler')); % Run A
        filler_ons(:,r) = [output(inds).trialOnset];
        filler_dur(:,r) = [output(inds).trialDuration];
    end
catch
    status = 0;
    error = 'error organizing task data';
    return
end


%% Make matlabbatch (EDIT this section to match your task)

% Design specification
try
    % Directory where to save outputs
    matlabbatch{1}.spm.stats.fmri_spec.dir{1} = lvl1Dir;
    
    % Timing
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1;
    
    % Params
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    matlabbatch{1}.spm.stats.fmri_spec.cvi = ['AR(' num2str(acTAG) ')'];
    
    % Session-specific design info
    for r = 1:length(subDat.rpPath)
        % Scans
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).scans = subDat.funcPath{1,r};
        
        % Conditions
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(1).name = 'sleep';
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(1).onset = sleep_ons(:,r);
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(1).duration = sleep_dur(:,r);
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(1).tmod = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(1).orth = 0;
        
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(2).name = 'control';
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(2).onset = control_ons(:,r);
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(2).duration = control_dur(:,r);
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(2).tmod = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(2).orth = 0;
        
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(3).name = 'filler';
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(3).onset = filler_ons(:,r);
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(3).duration = filler_dur(:,r);
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(3).tmod = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(3).orth = 0;
        
        % Additional session-specific params
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi = {''};
        if rpTAG == 1
            matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi_reg{1} = subDat.rpPath{1,r};
        else
            matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi_reg{1} = {''};
        end
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).hpf = hpf;
    end
    matlabbatch{1}.spm.stats.fmri_spec.mask{1} = brainMask;
catch
    status = 0;
    error = 'error making design specification';
    return
end

% Design Estimation
matlabbatch{2}.spm.stats.fmri_est.spmmat{1} = fullfile(lvl1Dir, 'SPM.mat');
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

% Contrast Manager
matlabbatch{3}.spm.stats.con.spmmat{1} = fullfile(lvl1Dir,'SPM.mat');

matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'sleep';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.convec = [1 0 0];
matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'bothsc'; % 'bothsc'  

matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'control';
matlabbatch{3}.spm.stats.con.consess{2}.tcon.convec = [0 1 0];
matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = 'filler';
matlabbatch{3}.spm.stats.con.consess{3}.tcon.convec = [0 0 1];
matlabbatch{3}.spm.stats.con.consess{3}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{4}.tcon.name = 'sleep-control';
matlabbatch{3}.spm.stats.con.consess{4}.tcon.convec = [1 -1 0];
matlabbatch{3}.spm.stats.con.consess{4}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{5}.tcon.name = 'sleep-filler';
matlabbatch{3}.spm.stats.con.consess{5}.tcon.convec = [1 0 -1];
matlabbatch{3}.spm.stats.con.consess{5}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{6}.tcon.name = 'control-filler';
matlabbatch{3}.spm.stats.con.consess{6}.tcon.convec = [0 1 -1];
matlabbatch{3}.spm.stats.con.consess{6}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{7}.tcon.name = 'sleep+control-filler';
matlabbatch{3}.spm.stats.con.consess{7}.tcon.convec = [.5 .5 -1];
matlabbatch{3}.spm.stats.con.consess{7}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{8}.tcon.name = 'sleep-control+filler';
matlabbatch{3}.spm.stats.con.consess{8}.tcon.convec = [1 -.5 -.5];
matlabbatch{3}.spm.stats.con.consess{8}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{9}.tcon.name = 'sleep+control';
matlabbatch{3}.spm.stats.con.consess{9}.tcon.convec = [.5 .5 0];
matlabbatch{3}.spm.stats.con.consess{9}.tcon.sessrep = 'bothsc';

matlabbatch{3}.spm.stats.con.consess{10}.tcon.name = 'control+filler';
matlabbatch{3}.spm.stats.con.consess{10}.tcon.convec = [0 .5 .5];
matlabbatch{3}.spm.stats.con.consess{10}.tcon.sessrep = 'bothsc';



%% Run Job
% Save matlabbatch
time_stamp = datestr(now,'yyyymmdd_HHMM');   % timestamp is a function name, hence the _ in time_stamp
filename = [batchDir '/' subDat.name '_' analysisID '_' time_stamp '.mat'];
save(filename,'matlabbatch');

% Run matlabbatch
if execTAG
    spm_jobman('run',matlabbatch);
    status = 1;
    error = [];
else
    status = 0;
    error = 'ExecTAG set to 0';
end
