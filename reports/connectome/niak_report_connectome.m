function [pipeline,opt] = niak_report_connectome(in,opt)
% Dashboard report for the r-maps generated by the connectome pipeline
%
% SYNTAX: [PIPE,OPT] = NIAK_REPORT_RMAP(IN,OPT)
%
% IN.PARAMS (string)
%   The name of a .mat file with two variables FILES_IN (the input files) and
%   OPT (the options), describing the parameters of the pipeline.
% IN.BACKGROUND (string) a brain volume to use as a background for each brain map.
% IN.INDIVIDUAL.(SEED).(SUBJECT) (string) an individual connectivity map, for a 
%   a given subject and seed.  
% IN.AVG.(SEED) (string) the average map associated with a seed. 
% IN.NETWORK (string)  a file name of a mask of brain networks (network I is filled 
%  with Is, 0 is for the background).
%
% OPT (structure) with the following fields:
%   FOLDER_OUT (string) the path where to store the results.
%   AVG.THRESH (scalar, default [-0.15 0.25]) if empty, does nothing. 
%     If a scalar, any value below threshold becomes transparent. If two values, 
%     anything between these two values become transparent. 
%   AVG.LIMITS (vector 1x2, default [-0.3 0.5]) the limits for the colormap. 
%     By defaut it is using [min,max]. If a string is specified, the function 
%     will implement an adaptative strategy.
%   IND.THRESH (scalar, default [-0.15 0.35]) if empty, does nothing. 
%     If a scalar, any value below threshold becomes transparent. If two values, 
%     anything between these two values become transparent. 
%   IND.LIMITS (vector 1x2, default [-0.5 0.8]) the limits for the colormap. 
%     By defaut it is using [min,max]. If a string is specified, the function 
%     will implement an adaptative strategy.
%   PSOM (structure) options for PSOM. See PSOM_RUN_PIPELINE.
%   FLAG_VERBOSE (boolean, default true) if true, verbose on progress.
%   FLAG_TEST (boolean, default false) if the flag is true, the pipeline will
%     be generated but no processing will occur.
%
%   This pipeline needs the PSOM library to run.
%   http://psom.simexp-lab.org/
%
% Copyright (c) Pierre Bellec
% Centre de recherche de l'Institut universitaire de griatrie de Montral, 2017.
% Maintainer : pierre.bellec@criugm.qc.ca
% See licensing information in the code.
% Keywords : visualization, montage, 3D brain volumes

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

%% Defaults

% Inputs
in = psom_struct_defaults( in , ...
    { 'params' , 'background' , 'individual' , 'average' , 'network' }, ...
    { NaN      , NaN          , NaN          , NaN       , NaN       });

%% Options
if nargin < 2
    opt = struct;
end
opt = psom_struct_defaults ( opt , ...
    { 'folder_out' , 'flag_test' , 'avg'    , 'ind'    , 'psom'   , 'flag_verbose' }, ...
    { NaN          , struct      , struct() , struct() , struct() , true           });

opt.ind = psom_struct_defaults( opt.ind , ...
    { 'thresh'     , 'limits'     }, ...
    { [-0.15 0.35] , [-0.5 0.8]   });

opt.avg = psom_struct_defaults( opt.avg , ...
    { 'thresh'   , 'limits'     }, ...
    { [-0.15 0.25] , [-0.3 0.5]   });
    
opt.folder_out = niak_full_path(opt.folder_out);
opt.psom.path_logs = [opt.folder_out 'logs' filesep];

%% Seed and subject lists
list_seed = fieldnames(in.individual);
list_subject = fieldnames(in.individual.(list_seed{1}));

%% Copy the report templates
pipeline = struct;
clear jin jout jopt
niak_gb_vars
path_template = [GB_NIAK.path_niak 'reports' filesep 'connectome' filesep 'templates' filesep ];
jin = niak_grab_folder( path_template , {'.git','rmap.html'});
jout = strrep(jin,path_template,opt.folder_out);
jopt.folder_out = opt.folder_out;
pipeline = psom_add_job(pipeline,'cp_report_templates','niak_brick_copy',jin,jout,jopt);

%% Write a text description of the pipeline parameters
clear jin jout jopt
jin = in.params;
jout.list_subject = [opt.folder_out 'summary' filesep 'listSubject.js'];
jout.list_run = [opt.folder_out 'summary' filesep 'listRun.js'];
jout.files_in = [opt.folder_out 'summary' filesep 'filesIn.js'];
jout.summary = [opt.folder_out 'summary' filesep 'pipeSummary.js'];
jopt.list_subject = list_subject;
pipeline = psom_add_job(pipeline,'params','niak_brick_connectome_params2report',jin,jout,jopt);

% background image
jname = 'background';
clear jin jout jopt
jin.source = in.background;
jin.target = in.background;
jout.montage = [opt.folder_out 'img' filesep 'template.jpg'];
jopt.colormap = 'gray';
jopt.limits = 'adaptative';
jopt.nb_color = 256;
jopt.quality = 90;
pipeline = psom_add_job(pipeline,jname,'niak_brick_montage',jin,jout,jopt);

% network image
jname = 'network';
clear jin jout jopt
jin.source = in.network;
jin.target = in.background;
jout.montage = [opt.folder_out 'img' filesep 'network.png'];
jout.colormap = [opt.folder_out 'img' filesep 'network_cm.png'];
jout.quantization = [opt.folder_out 'img' filesep 'network.mat'];
net_quantization = jout.quantization;
jopt.colormap = 'jet';
jopt.nb_color = Inf;
jopt.thresh = 1;
pipeline = psom_add_job(pipeline,jname,'niak_brick_montage',jin,jout,jopt);

% Individual images
list_overlay = struct();
for ll = 1:length(list_seed)
    for ss = 1:length(list_subject)
        seed = list_seed{ll};
        subject = list_subject{ss};
        jname = ['img_rmap_' seed '_' subject];
        clear jin jout jopt
        jin.source = in.individual.(seed).(subject);
        jin.target = in.background;
        jout.montage = [opt.folder_out 'img' filesep jname '.png'];
        list_overlay.(seed).(subject) = jout.montage;
        if (ll==1)&&(ss==1)
            jout.quantization = [opt.folder_out 'img' filesep 'ind_quantization.mat'];
            jout.colormap = [opt.folder_out 'img' filesep 'ind_colormap.png'];
            ind_quantization = jout.quantization;
            ind_colormap = jout.colormap;
        else
            jout.quantization = 'gb_niak_omitted';
            jout.colormap = 'gb_niak_omitted';
        end
        jopt.limits = opt.ind.limits;
        jopt.thresh = opt.ind.thresh;
        jopt.colormap = 'hot_cold';
        jopt.nb_color = 256;
        pipeline = psom_add_job(pipeline,jname,'niak_brick_montage',jin,jout,jopt);
    end
end

% Individual images
list_avg = struct();
for ll = 1:length(list_seed)
    seed = list_seed{ll};
    jname = ['img_avg_' seed];
    clear jin jout jopt
    jin.source = in.average.(seed);
    jin.target = in.background;
    jout.montage = [opt.folder_out 'img' filesep jname '.png'];
    list_avg.(seed) = jout.montage;
    if (ll==1)
        jout.quantization = [opt.folder_out 'img' filesep 'avg_quantization.mat'];
        jout.colormap = [opt.folder_out 'img' filesep 'avg_colormap.png'];
        avg_quantization = jout.quantization;
        avg_colormap = jout.colormap;
    else
        jout.quantization = 'gb_niak_omitted';
        jout.colormap = 'gb_niak_omitted';
    end
    jopt.limits = opt.avg.limits;
    jopt.thresh = opt.avg.thresh;
    jopt.colormap = 'hot_cold';
    jopt.nb_color = 256;
    pipeline = psom_add_job(pipeline,jname,'niak_brick_montage',jin,jout,jopt);
end

% Generate the connectome report
clear jin jout jopt
jin.individual = ind_quantization;
jin.average    = avg_quantization;
jin.network    = net_quantization;
jout.rmap = [opt.folder_out 'rmap.html'];
jout.network = [opt.folder_out 'summary' filesep 'listNetwork.js'];
jopt.label_network = list_seed;
jopt.label_subject = list_subject;
pipeline = psom_add_job(pipeline,'rmap_report','niak_brick_report_connectome',jin,jout,jopt);

if ~opt.flag_test
    psom_run_pipeline(pipeline,opt.psom);
end
