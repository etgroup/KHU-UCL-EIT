function [BV,KHU]=khu_load(clean_flag,plot_flag)
%Imports data collected from KHU EIT mk2.5
%User points to the folder which contains the 1Scan.txt etc. files. Info
%regarding the injection channels, gain, frequency, current etc. is read
%from ProjectionTableSendLog.txt and EITScanSettings.txt if they exist. If
%these files are missing then the user can either point to the
%KHU_script_info***.mat made using khu_makepairwise.m OR point to a prt
%file and enter the rest manually. The data is then read and processed, all
%data is saved in raw format (unscaled, uncleaned) and scaled (corrected for
%gain) in the KHU structure. The output BV is dependent upon the clean
%flag, either case the data is also stored in BV_full. With the
%corresponding prt and prt_full.
% Inputs:
% clean flag - 1 for removing the data from the injection channels in the
% final BV and prt output (BV_full and prt_full are stored anyway)
% plot flag - 1 for plotting the data after collection, inlcuding across
% channel and across time, and some noise plots too
% Outputs:
% BV - the boundary voltages in Volts Comb x Scan, corrected for gain and
% cleaned if user asked
% KHU - output structure containing BV, prt BV_full, prt_full and the raw
% and scaled output voltages as well as scan info
%
% FILES SAVED
% Foldername-KHU.mat - has ALL the info stored in it read from the text
% files or inputted by the user along with all the data
% Foldername-ZZ.mat - JUST the mean boundary voltages for Zhous GUI
%
% Hopefully the last version (ha! at least until someone does something with mixed injections or non pairwise)
% by the pulchritudinous Jimmy


if exist('clean_flag','var') ==0
    disp('no cleaning flag given. cleaning anyway');
    clean_flag=1;
end

if exist('plot_flag','var') ==0
    disp('no plot flag given. plotting anyway');
    plot_flag=1;
end

%% user chooses directory
dirname=uigetdir('D:\KHUDATA','Pick the directory where the data is located');
if isempty(dirname)
    error('User Pressed Cancel');
end


%% find the scans in the folder

files=dir([dirname filesep '*Scan.txt']);

% check if there are scans actually found
if isempty(files)
    error('No scan files found!');
end
%below is necessary for handling 0Scan.txt and non contiguous file names
if strcmp(files(1,1).name,'0Scan.txt')==1
    files(1)=[];
end

%take names of files
namestrings={files.name};
%take just the scan numbers
scannumbersstr=strrep(namestrings,'Scan.txt','');
%convert into numbers
scans=cellfun(@str2num,scannumbersstr,'uniformoutput',1);
%sort into numerical order
[scans, scanidx]=sort(scans);

numfile=length(scans);

%% read the ProjTable and EITScanSettings

%check if the files exist and then load them if they do!

projfname=fullfile(dirname,'ProjectionTableSendLog.txt');
scansetfname=fullfile(dirname,'EITScanSetting.txt');

if exist(projfname,'file') ==2
    disp('Loading ProjectionTableSendLog');
    projtableout=khu_readprojtable(projfname);
    chn=projtableout.chn;
    gain_actual=projtableout.gain_actual;
    sources=projtableout.sources;
    sinks=projtableout.sinks;
    prt_full=makeprtfile([sources sinks],chn);
    [prt, keep_idx,rem_idx]=cleanprt(prt_full);
    frequency=projtableout.frequency{1,1};
    %just take the most common current amplitude
    amplitude_setting=mode(projtableout.current);
else
    disp('PROJECTIONTABLESENDLOG NOT FOUND!!! :0');
    projtableout=[];
end

if exist(scansetfname,'file') ==2
    disp('Loading EITScanSetting');
    scansettingout=khu_readscansetting(scansetfname);
    current_level=scansettingout.current_level;
else
    disp('EITSCANSETTING NOT FOUND!!! :0');
    scansettingout=[];
end


%% prompt user to decide what to do if the files are missing

if isempty(projtableout) || isempty(scansettingout)
    
    %prompt user if they want to either enter protocol and projection
    %settings manually, or point to the .mat file made during
    %khu_makepairwise WHICH EVERYONE SHOULD TOTALLY BE USING
    manselect='Enter Manually';
    matselect='Point to KHU_script_info.mat';
    man_ans=questdlg('Settings files not found in directory! Either point towards the KHU_script_info*.mat file (generated by khu_makepairwise) or enter details manually','More details about recording required',matselect,manselect,manselect);
    
    if isempty(man_ans)
        error('User pressed cancel');
    end
    
    %if chosen to enter manually
    if strcmp(man_ans,manselect) == 1
        disp('Entering Data manually!');
        
        %if projtablefile is missing
        if isempty(projtableout)
            
            %ask user to point at .prt or .txt file with protocol in it
            disp('Projtablefile missing will ask for prt file');
            [prtfname, prtpath] = uigetfile({'*.txt;*.prt','Protocol Files (*.txt,*.prt)';}, 'Choose which Protocol file to load');
            if isequal(prtfname,0) || isequal(prtpath,0)
                error('user pressed cancel');
            else
                disp(['User selected ', fullfile(prtpath, prtfname)])
            end
            
            prt = importdata([prtpath prtfname]);
            
            %however, we need the full prt file to know which ones to
            %remove and we need to know the number of channels - this can
            %be found from the prt file
            
            [prt_full, chn, keep_idx, rem_idx]=makefullprt(prt);
            
            %the user still needs to say what the injection frequency, gain and current
            %was
            prompt={'Frequency (Hz) - ref only','Gain setting on MEASUREMENT channels','Gain setting on INJECTION channels','Current Setting in Projection File','Current Level Setting - Likely to be 0 unless rat or low freq stroke exp'};
            dlg_title='Please enter the relevant info for this dataset';
            def={'10000','10','10','400','0'};
            
            manualstuffs=inputdlg(prompt,dlg_title,1,def);
            
            if isempty(manualstuffs) ==1
                error('user pressed cancel');
            end
            
            frequency=sscanf(manualstuffs{1},'%f');
            gain_digital_m=sscanf(manualstuffs{2},'%f');
            gain_digital_i=sscanf(manualstuffs{3},'%f');
            amplitude_setting=sscanf(manualstuffs{4},'%f');
            current_level=sscanf(manualstuffs{5},'%f');
            
            %make gain vector based on settings for measurement and inj
            %chhannels
            gain_digital=ones(size(prt_full,1),1)*gain_digital_m;
            gain_digital(rem_idx)=gain_digital_i;
            %convert into actual gain
            gain_actual=gain_digital*(40/200);
        else
            %all the essential info form the EITScanSetting.txt is the
            %current level setting
            prompt={'Current Level Setting - Likely to be 0 unless rat or low freq stroke exp'};
            dlg_title='Please enter the relevant info for this dataset';
            def={'0'};
            
            manualstuffs=inputdlg(prompt,dlg_title,1,def);
            
            if isempty(manualstuffs) ==1
                error('user pressed cancel');
            end
            
            current_level=sscanf(manualstuffs{1},'%f');
        end
        
    else
        %user has chosen to point to a script info file
        [khumatfname, khumatpath]=uigetfile('.mat','Point to relevant KHU_script_info***.mat file');
        if isequal(khumatfname,0) || isequal(khumatpath,0)
            error('user pressed cancel');
        else
            disp(['User selected ', fullfile(khumatpath, khumatfname)])
        end
        
        load(fullfile(khumatpath,khumatfname));
        
        %get the right data from this struct
        prt_full=khu_settings.prt;
        [prt, keep_idx,rem_idx]=cleanprt(prt_full);
        gain_actual=khu_settings.gain_act;
        chn=khu_settings.script.setting.chn;
        current_level=khu_settings.script.setting.CurrentLevel;
        
        %incase the user points to a file where I *ahem* forgot to store
        %the settings in a normal way
        if isfield(khu_settings,'amp_setting')
            
            amplitude_setting=khu_settings.amp_setting;
        else
            %look at the cell_master which was the strings written to the
            %projection file for the amp setting
            
            %just assume its the same for each one
            str_temp=khu_settings.proj.cell_master(:,2,1);
            idx_temp=find(~strcmp(str_temp,'Null'),1);
            amplitude_setting=abs(sscanf(str_temp{idx_temp},'%d'));
            
        end
        
        %incase the user points to a file where I *ahem* forgot to store
        %the settings in a normal way
        if isfield(khu_settings,'frequency')
            
            frequency=khu_settings.frequency;
        else
            %look at the cell_master which was the strings written to the
            %projection file for the amp setting
            
            %just assume its the same for each one
            str_temp=khu_settings.proj.cell_master(:,3,1);
            idx_temp=find(~strcmp(str_temp,'Null'),1);
            frequency=(str_temp{idx_temp});
            
        end
        
        
    end
    
end


%% process values for this dataset
%get real current

current_pp=khu_amp_setting2uA(amplitude_setting,current_level);
current=current_pp/2;

%set keep_idx and rem_idx based on cleaning flag
if clean_flag==0;
    keep_idx=1:length(prt_full);
    rem_idx=[];
end





%% load the data in the scan files

disp('Loading data in scan files...');
if ~isequal(max(scans),numfile)
    disp([num2str(max(scans)-numfile) ': scans died to bring us this infomation']);
end

%scale data based on gain vector to get results in V

sf=1./((2^15).*gain_actual);

%for each scan load the data and stick in the correct matricies

if (isempty(str2num(frequency)))
    %is not a number then its a MIXED injection
    X_raw=zeros(size(prt_full,1)*3,numfile);
    sf=repmat(sf,3,1);
else
    X_raw=zeros(size(prt_full,1),numfile);
end

R_raw=zeros(size(X_raw));
Z_raw=zeros(size(X_raw));


X=zeros(size(X_raw));
R=zeros(size(X_raw));
Z=zeros(size(X_raw));
sat=zeros(size(X_raw));






%read all dem scans
for iScan=1:numfile
    filetemp=dlmread(fullfile(dirname,files(scanidx(iScan)).name));
    
    %raw values
    X_raw(:,iScan)=filetemp(:,4);
    R_raw(:,iScan)=filetemp(:,3);
    sat(:,iScan)=filetemp(:,2);
    Z_raw(:,iScan)=sqrt(R_raw(:,iScan).^2+X_raw(:,iScan).^2);
    
    %Voltages
    X(:,iScan)=X_raw(:,iScan).*sf;
    R(:,iScan)=R_raw(:,iScan).*sf;
    Z(:,iScan)=sqrt(R(:,iScan).^2+X(:,iScan).^2);
    
    
    
    
end



%% check for errors

% % sat should be only be 0 and 1
% legit=[0 1];
%
% if any(any(~ismember(sat,legit)))
%     warning('WEIRD DATA');
%         manselect='Enter Manually';
%     matselect='Point to KHU_script_info.mat';
%     man_ans=questdlg('Settings files not found in directory! Either point towards the KHU_script_info*.mat file (generated by khu_makepairwise) or enter details manually','More details about recording required',matselect,manselect,manselect);
%
%     if isempty(man_ans)
%         error('User pressed cancel');
%     end
%
%     %if chosen to enter manually
%     if strcmp(man_ans,manselect) == 1
%         disp('Entering Data manually!');
%
%
%
%







%% process all that stuff


%save the raw data in separate structure

KHU.raw.X=X_raw;
KHU.raw.Z=Z_raw;
KHU.raw.R=R_raw;
KHU.raw.keep_idx=keep_idx;
KHU.raw.rem_idx=rem_idx;

%keep all in new struct

KHU.scaled.X=X;
KHU.scaled.R=R;
KHU.scaled.Z=Z;
KHU.sat=sat;
KHU.gain=gain_actual;
KHU.sf=sf;
KHU.keep_idx=keep_idx;
KHU.rem_idx=rem_idx;


%now refer to everything as "data" as the mean of the channel as that is
%what we are used to elsewhere

BV_full=Z;

%if user wants data cleaned then remove injetion channels in BV
if clean_flag==1;
    BV=BV_full(keep_idx,:);
else
    BV=BV_full;
end

%variable for mean boundary voltage for Zhou Zhous gui only
V=mean(BV,2);

%store data info
info.current_level=current_level;
info.amplitude_setting=amplitude_setting;
info.current=current;
info.current_pp=current_pp;
info.prt_full=prt_full;
info.prt=prt;
info.gain_actual=gain_actual;
info.chn=chn;
info.frequency=frequency;
info.projtableout=projtableout;
info.scansettingout=scansettingout;
info.dateimported=date;

KHU.info=info;

%get the name for the new files
k=strfind(dirname,filesep);
newnamestr=dirname(k(end)+1:end);


%calculate noise for plotting

%scaled by BV "legacy" plot style
tempnoise.sc.real=std(R(keep_idx,:),0,2)./mean(R(keep_idx,:),2);
tempnoise.sc.imag=std(X(keep_idx,:),0,2)./mean(X(keep_idx,:),2);
tempnoise.sc.abs=std(Z(keep_idx,:),0,2)./mean(Z(keep_idx,:),2);

%the more intuitive non scaled style
tempnoise.real=std(R(keep_idx,:),0,2);
tempnoise.imag=std(X(keep_idx,:),0,2);
tempnoise.abs=std(Z(keep_idx,:),0,2);

KHU.tempnoise=tempnoise;


%used

save(fullfile(dirname,[newnamestr, '-KHU_Data']), 'KHU','info','BV_full','BV','prt_full','prt')

save(fullfile(dirname,[newnamestr, '-ZZ']), 'V');



if plot_flag ==1
    
    figure
    plot(BV')
    xlabel('Scan Number')
    ylabel('V')
    
    figure
    plot(BV)
    xlabel('Combination')
    ylabel('V')
    
    figure
    plot(tempnoise.abs)
    xlabel('Combination')
    ylabel('Standard deviation in V')
    
    figure;hist((tempnoise.sc.abs*100),50)
    % title('Histogram of St Dev. divided by mean for UCL data')
    title('Histogram of St Dev. divided by mean for KHU data')
    xlabel('Standard Deviation/mean (%)')
    %     xlim([0 5])
    
    figure
    plot(mean(BV,2),(tempnoise.abs),'o')
    xlabel('Mean V')
    ylabel('Standard deviation in channel V')
    
end
disp('All done!');
end

function [ scansettingout ] = khu_readscansetting( fname )
%Reads the file contained info about the scan settings made by Bishal. This
%file only exists in datasets after July 2014 AND if the scan stops
%properly
%
%% auto generated matlab code

%Initialize variables.
% fname = 'C:\Users\Jimbles\Dropbox\PHD\Chapter 3\KHU MK2.5\EITScanSetting.txt';
delimiter = '\t';
% Read columns of data as strings:
% For more information, see the TEXTSCAN documentation.
formatSpec = '%s%s%[^\n\r]';
% Open the text file.
fileID = fopen(fname,'r');
% Read columns of data according to format string.
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter,  'ReturnOnError', false);
% Close the text file.
fclose(fileID);

% Convert the contents of columns containing numeric strings to numbers.
% Replace non-numeric strings with NaN.
raw = [dataArray{:,1:end-1}];
numericData = NaN(size(dataArray{1},1),size(dataArray,2));

% Converts strings in the input cell array to numbers. Replaced non-numeric
% strings with NaN.
rawData = dataArray{2};
for row=1:size(rawData, 1);
    % Create a regular expression to detect and remove non-numeric prefixes and
    % suffixes.
    regexstr = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
    try
        result = regexp(rawData{row}, regexstr, 'names');
        numbers = result.numbers;
        
        % Detected commas in non-thousand locations.
        invalidThousandsSeparator = false;
        if any(numbers==',');
            thousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
            if isempty(regexp(thousandsRegExp, ',', 'once'));
                numbers = NaN;
                invalidThousandsSeparator = true;
            end
        end
        % Convert numeric strings to numbers.
        if ~invalidThousandsSeparator;
            numbers = textscan(strrep(numbers, ',', ''), '%f');
            numericData(row, 2) = numbers{1};
            raw{row, 2} = numbers{1};
        end
    catch me
    end
end

% Split data into numeric and cell columns.
rawNumericColumns = raw(:, 2);
rawCellColumns = raw(:, 1);


% Create output variable
EITScanSetting = raw;
% Clear temporary variables
clearvars filename delimiter formatSpec fileID dataArray ans raw numericData rawData row regexstr result numbers invalidThousandsSeparator thousandsRegExp me rawNumericColumns rawCellColumns;

%% interpret this mess

scansettingout.current_level=EITScanSetting{5,2};
scansettingout.averages=EITScanSetting{4,2};
scansettingout.gain=EITScanSetting{3,2};
scansettingout.AmplitudeSetting=EITScanSetting{2,2};

end

function [ ProjTableOut ] = khu_readprojtable( fname )
%Decyphers the projection table file stored in the same folder as the data
%   gets the projection, current, frequency etc.
%% read in textfile - autogenerated from uiimport

% Initialize variables.
% fname =  'F:\KHU VISIT STICK DUMP\[FINAL_NEWFPGA_32CH]EIT_Mark255_[Lower Current Level]\Debug\Test\ProjectionTableSendLog.txt';
delimiter = '\t';
startRow = 2;

formatSpec = '%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%[^\n\r]';

% Open the text file.
fileID = fopen(fname,'r');

% Read columns of data according to format string.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

% Close the text file.
fclose(fileID);

%Allocate imported array to column variable names
ProjIndex = dataArray{:, 1};
ChIndex = dataArray{:, 2};
ChInfo = dataArray{:, 3};
ChCtrl = dataArray{:, 4};
InjFreq = dataArray{:, 5};
Amp1High = dataArray{:, 6};
Amp1Low = dataArray{:, 7};
Amp2High = dataArray{:, 8};
Amp2Low = dataArray{:, 9};
Gain1 = dataArray{:, 10};
AcqGap = dataArray{:, 11};
AcqCNTHigh = dataArray{:, 12};
AcqCntLow = dataArray{:, 13};
TotalDMFreq = dataArray{:, 14};
DM1 = dataArray{:, 15};
DM2 = dataArray{:, 16};
DM3 = dataArray{:, 17};

% Clear temporary variables
clearvars filename delimiter startRow formatSpec fileID dataArray ans;
%% process dat shit
errormsg='Something is weird in the file: ';
% find the number of channels
legit_chn=[16 32];

if ismember(max(ChIndex+1),legit_chn)
    chn=max(ChIndex+1);
else
    error([errormsg 'channel number']);
end

%find the number of projections
if (max(ProjIndex)+1) ~= length(ProjIndex)/chn
    error([errormsg 'projection number']);
else
    Nproj=max(ProjIndex+1);
end

%frequency lookup table
freqs={'11.25','56.25','112.5','1125','5625','11250','56250','112500','247500','450000','NULL','NULL','NULL','NULL','NULL','NULL','MIXED1','MIXED2','MIXED3','MIXED4'};

%preallocate dat shit
sources=zeros(Nproj,1);
sinks=zeros(size(sources));
gain_digital=zeros(Nproj*chn,1);
current=zeros(size(sources));
frequency=cell(size(sources));
frequency_setting=zeros(size(sources));

%load data for each projection
for iProj = 1:Nproj
    Proj_idx=find(ProjIndex == iProj-1);
    src=find(ChCtrl(Proj_idx) == 2,1);
    snk=find(ChCtrl(Proj_idx) == 3,1);
    frq=InjFreq(Proj_idx(src));
    crnt_hi=Amp1High(Proj_idx(src));
    crnt_lo=Amp1Low(Proj_idx(src));
    gn=Gain1(Proj_idx);
    %convert bits into DAC value
    crnt=bin2dec([dec2bin(crnt_hi,2) dec2bin(crnt_lo,8)]);
    
    sources(iProj)=src;
    sinks(iProj)=snk;
    frequency_setting(iProj)=frq;
    frequency{iProj}=freqs{frq+1};
    gain_digital(Proj_idx)=gn;
    gain_actual(Proj_idx)=khu_gain_dig2act(gn);
    current(iProj)=crnt;
end

%% stick in the output struc
ProjTableOut.sources=sources;
ProjTableOut.sinks=sinks;
ProjTableOut.frequency_setting=frequency_setting;
ProjTableOut.frequency=frequency;
ProjTableOut.gain_digital=gain_digital;
ProjTableOut.gain_actual=gain_actual';
ProjTableOut.current=current;
ProjTableOut.chn=chn;
ProjTableOut.NProj=Nproj;

end

function prt_mat=makeprtfile(inj_pairs,chn)

%given the injection channels, creates the full protocol file including
%measurements on injection channels

%voltage measurements
vp=(1:chn)';
vm=circshift(vp,1);

prt_mat=[];
for iii=1:size(inj_pairs,1)
    temp=[repmat(inj_pairs(iii,:),chn,1) vp vm];
    
    prt_mat=[prt_mat ; temp];
end

end



function [prt, keep_idx,rem_idx]=cleanprt(prt_full)
%for a full protocol, removes measurements on injection channels and
%returns cleaned protocol, keep and remove indecs

prt=prt_full;
rem_idx=[];
chn=max(max(prt));
for iPrt = 1:size(prt,1)
    if any(ismember(prt_full(iPrt,1:2),prt(iPrt,3:4))) ==1
        rem_idx=[rem_idx,iPrt];
    end
end
keep_idx=setdiff(1:length(prt_full),rem_idx);
prt(rem_idx,:)=[];
end

function [prt_full,chn,keep_idx,rem_idx]=makefullprt(prt)
%from a cleaned prt file, creates the full protocl and finds remove and
%keep indexes

%find the unique pairs of injections
[C, IA, IC]=unique(prt(:,1:2),'rows');
temparray=sortrows([IA C]);
inj_unique=temparray(:,2:end);

%channels can either be 16 or 32, so if any number is prt is
%bigger than 16 then use 32.

if any(any(prt >16))
    disp('32 Channel Protocol Detected');
    chn=32;
else
    disp('16 Channel Protocol Detected');
    chn=16;
end

prt_full=makeprtfile(inj_unique,chn);
[~,keep_idx,rem_idx]=cleanprt(prt_full);
end
function [ gain_actual ] = khu_gain_dig2act( gain_digital )
%khu_gain_dig2act converts digital value gain setting in projection files
%to the actual gain. Assumes range is 1-255;
%

% keep value in range
gain_digital(gain_digital < 1) =1;
gain_digital(gain_digital > 255 ) =255;


gain_actual=gain_digital*(40/200);


end

function [ amplitude_pp ] = khu_amp_setting2uA( ampsetting,currentlevel )
%khu_amp_setting2uA converts the settings in projection file and current
%level into uA peak to peak
%   amp setting - value 0 to 1024 in projection file
%   current level - value in script file, incease of 1 means 1 bit removed
%   from DAC and thus half current ampltiude

% this is copied from the separate.m to make khu_load a standalone file -
% bad practice I know...

%% check variables

if exist('currentlevel','var') ==0;
    disp('Using current level 0');
    currentlevel=0;
end



%check amplitude
if (ampsetting > 0 && ampsetting <= 1024) == 0
    error('Incorrect amplitude setting, must be between 1 and 1024')
end

if (currentlevel >= 0 && currentlevel < 16) == 0
    error('Incorrect current level setting, must be between 0 and 16');
end

%% calculate range of values
% current from DAC
I_max=31.66/(2^currentlevel);
I_min=8.66/(2^currentlevel);
I_dac=(I_max-I_min)/(1024)*ampsetting+I_min;

%voltage before HCP
V_dac=I_dac*0.0980;

%current from HCP
amplitude_pp=413.33*V_dac;


end



