function [ khu_script ] = khu_makescriptfile( outputfilename,proj,setting,calibration, comment )
%khu_makescriptfile Creates a correctly formatted script file with the
%settings given
%   Inputs are:
%   outputfilename - path of scriptfile to be written
%   proj.file - path of the projection file for the script to run. better if it is a relative path
%   proj.list - list of projections used from projection file
%   setting.chn - number of channels - either 16 or 32
%   setting.ave - number of averages - must be either 1 or power of 2 up to 2^6 =64
%   setting.delay - scan delay - 5 is default. PROBABLY BEST TO LEAVE THIS
%   DEFAULT
%   setting.freq - number of frequencies per projection. either 1 for
%   single, 2 for multiple, 3 for mixed injection
%   setting.TimeInfoHigh - high byte value for projection time this is
%   explained in the eit-nas/technical/khumk2.5 folder. gernated by
%   khu_projectiontime function
%   setting.TimeInfoMid - as above
%   setting.TimeInfoLow - so below
%   setting.InjDelayHigh - delay high byte, this is normally 0
%   setting.InjDelayLow - delay low byte, this is normally 60
%   setting.CurrentLevel - current level setting. 0 is normal, higher
%   integers remove that number of bits from the DAC output (thus half the
%   current amplitude)
%   calibration.dc - string either 'ON' or 'OFF' to toggle dc calibration
%   calibration.outputz - string either 'ON' or 'OFF' to toggle output impedance  calibration
%   calibration.outputz - string either 'ON' or 'OFF' to toggle output impedance  calibration
%   calibration.amplitude - string either 'ON' or 'OFF' to toggle ampltiude  calibration
%   calibration.voltmeter - string either 'ON' or 'OFF' to toggle voltmeter  calibration
%   calibration.voltmeter_prot - reference to voltmeter protocol file (default'2DNeighboring_mV.txt'); %spelling!
%   comment - string for any comments written to the file header
%% set up file
datestr=date;

%create input parser for 8bit integer
p_i=inputParser;
addRequired(p_i,'thing',@checkint);


%parse inputs
parse(p_i,setting.TimeInfoHigh);
parse(p_i,setting.TimeInfoMid);
parse(p_i,setting.TimeInfoLow);
parse(p_i,setting.InjDelayHigh);
parse(p_i,setting.InjDelayLow);
parse(p_i,setting.CurrentLevel);




%check channel number
chn_legit=[16 32];
if ismember(setting.chn,chn_legit) == 0
    error(['Number of Channels not legit please pick one of the following: ' num2str(chn_legit)])
end

%check number of averages
ave_legit=2.^(0:6);
if ismember(setting.ave,ave_legit) == 0
    error(['Number of Averages not legit please pick one of the following: ' num2str(ave_legit)])
end

%check number of freq
freq_legit=1:3;
if ismember(setting.freq,freq_legit) == 0
    error(['Number of frequencies not legit please pick one of the following: ' num2str(freq_legit)])
end


%% write file

fid=fopen(outputfilename,'w+');

%im doing this line by line because I am too simple to understand one
%massive line

fprintf(fid,'%%Date\t%s\r\n',datestr); %write date
fprintf(fid,'%%Comment :%s\r\n',[comment ' Autogenerated script']);%write comment
fprintf(fid,'#include "%s"\r\n',proj.file); % write include projection file line
fprintf(fid,'\r\n'); % write whitespace for some reason
fprintf(fid,'start\r\n'); %start file header
fprintf(fid,'\tsetting\r\n'); % setting header
fprintf(fid,'\t\tChannel\t\t%s\r\n',num2str(setting.chn)); %number of channels
fprintf(fid,'\t\tAverage\t\t%s\r\n',num2str(setting.ave)); %number of averages
fprintf(fid,'\t\tDelay\t\t%s\r\n',num2str(setting.delay)); %delay in ms POSSIBLY ONLY FOR 32 CHANNEL#
fprintf(fid,'\t\tFreq\t\t%s\r\n',num2str(setting.freq)); %number of frequencies
fprintf(fid,'\t\tTimeInfoHigh\t%s\r\n',num2str(setting.TimeInfoHigh)); %time info high byte
fprintf(fid,'\t\tTimeInfoMid\t%s\r\n',num2str(setting.TimeInfoMid)); %time info mid byte
fprintf(fid,'\t\tTimeInfoLow\t%s\r\n',num2str(setting.TimeInfoLow)); %time info low byte
fprintf(fid,'\t\tInjDelayHigh\t%s\r\n',num2str(setting.InjDelayHigh)); % inject delay high
fprintf(fid,'\t\tInjDelayLow\t%s\r\n',num2str(setting.InjDelayLow)); % inject delay high
fprintf(fid,'\t\tCurrentLevel\t%s\r\n',num2str(setting.CurrentLevel)); % current level setting
fprintf(fid,'\tstop\r\n'); %stop section indicator
fprintf(fid,'\tcalibration\r\n'); %calibration start header
fprintf(fid,'\t\tDCOffset\t%s\r\n',calibration.dc); %dc cal on or off
fprintf(fid,'\t\tOutputImpedance\t%s\r\n',calibration.outputz); %outz cal on or off
fprintf(fid,'\t\tAmplitude\t%s\r\n',calibration.amp); %amp cal on or off
fprintf(fid,'\t\tVoltmeter\t%s\r\n',calibration.voltmeter); %voltmeter cal on or off
fprintf(fid,'\t\tProtocol\t%s\r\n',calibration.voltmeter_prot); %protocol file for voltmeter cal
fprintf(fid,'\tstop\r\n'); %stop section indicator

fprintf(fid,'\tscan\r\n'); %scan section indicator
%create line for each projection
for ii=proj.list
    fprintf(fid,'\t\tprojection%s\r\n',num2str(proj.list(ii)));
end
fprintf(fid,'\tstop\r\n'); %stop section indicator
fprintf(fid,'end\r\n'); %end file header

fclose(fid);

khu_script.setting=setting;
khu_script.setting.date=datestr;
khu_script.setting.comment=comment;
khu_script.calibration=calibration;
khu_script.proj=proj;


end

function TF = checkint(x)
   TF = false;
   if ~isscalar(x)
       error('Input is not scalar');
   elseif ~isnumeric(x)
       error('Input is not numeric');
   elseif (x < 0)
       error('Input must be >= 0');
          elseif (x > 255)
       error('Input must be < 255');
   else
       TF = true;
   end
end

