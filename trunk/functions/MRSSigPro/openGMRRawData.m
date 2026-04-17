%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function rawData = openGMRRawData(header,rec)
% 
% function to read in GMR data
% a record (file) is separated into stack/or pulsemoment (depends on measurement scheme)
% for each channel
% calculate pulse moments
% calculate pulse phase
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function rawData = openGMRRawData(fdata,rec)

 
switch fdata.header.expUnt
    case 0
        if fdata.header.DAQversion<2.4 % ascii read in
            fid  = fopen([fullfile(fdata.header.path, fdata.header.filename) '_' num2str(rec)]);
            data = textscan(fid,'%n %n %n %n %n %n %n %n %n');
            fclose(fid);
        else % binary reader
            fpath = fdata.header.path;
            fname = [fdata.header.filename '_' num2str(rec) '.lvm'];
            if isfield(fdata.info, "isnoise")
                if fdata.info.isnoise
                    data  = mrs_readgmr_binary(fpath, fname, fdata.header.nrecords, fdata.header.fS); %full noise data
                else
                    if fdata.header.DAQversion<3.0
                        data  = mrs_readgmr_binary(fpath, fname, fdata.header.nrecords, fdata.header.fS); %+1 for one additional noise data-set
                    else
                        data  = mrs_readgmr_binary(fpath, fname, fdata.header.nrecords+1, fdata.header.fS); %+1 for one additional noise data-set
                    end
                end
            else
                data  = mrs_readgmr_binary(fpath, fname, fdata.header.nrecords + 1, fdata.header.fS); %+1 for one additional noise data-set
            end
            %figure; plot(data{1},data{3})
        end
    case 1
        if fdata.header.DAQversion<2.4 % ascii read in
            fid  = fopen([fullfile(fdata.header.path, fdata.header.filename) '_' num2str(rec)]);
            data = textscan(fid,'%n %n %n %n %n %n %n %n %n %n %n %n %n');
            fclose(fid);
        else
            fpath = fdata.header.path;
            fname = [fdata.header.filename '_' num2str(rec) '.lvm'];
            data  = mrs_readgmr_binary(fpath, fname, fdata.header.nrecords, fdata.header.fS);
        end
end


%% record properties
% circuit gain
% F_nmr = fdata.header.frequency;
% C     = fdata.header.capacitance;
% w     = 2*pi*F_nmr;
% L     = 1/(C*w^2);
% Z1    = 0.5 + 1i*0.5*w;
% Z2    = 1/(1i*0.0000016*w);
% Z3    = 1/((1/Z1) + (1/Z2));
% Z4    = 1 + 1i*w*L;
% circuit_gain = abs(Z3/(Z3 + Z4));

% gain  = fdata.header.preampgain*circuit_gain;
% switch fdata.header.TXversion
%     case 1
%         txgain = 1/150;
%     case {2,3}
%         txgain = 1/180;
% end

rawData.RXgain = fdata.header.gain_V;
rawData.TXgain = 1/fdata.header.gain_I;

% measurement scheme


switch fdata.header.sequenceID % 1: FID; 2: 90-90; 3: single Echo  ; 4: 4phase T1; 7: CPMG; 8: AHP ; 9: Prepolization FID
    case 1
        tprePulse = 50e-3; % fixed time before pulse                
        tPPramp  = 1E-3; % 1ms for ramp, not used here
        trecord   = 1; % GMR has alway 1s of data for FID
        time      = [0:1/fdata.header.fS:trecord-1/fdata.header.fS]; % time vector for one experiment 
        nex       = length(data{1})/length(time); % total number of experiments (either pulsemoments or stacks)
        
        %GMR uses full cycles and tuned circuits will resonate -> pulse length is longer than tau_p, show two additional oscillations
        tau_p_real = (ceil(fdata.header.tau_p*fdata.header.fT+2.5))/fdata.header.fT;

        % no need for floor but for some reason matlab creates non integer numbers 
        %pulse1_index  = floor([(1+tprePulse*fdata.header.fS):1:(1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS)]); % index to extract pulse
        pulse1_preindex = floor([(1 + tprePulse*fdata.header.fS)-20:1:(tprePulse*fdata.header.fS)]); %50 points at start to get baseline
        pulse1_index  = floor([(1 + tprePulse*fdata.header.fS-1):1:((tprePulse+tau_p_real)*fdata.header.fS)]); % index to extract pulse
        pulse2_index  = [];

        PPramp_index  = [];
        
        switch fdata.header.DAQversion
            case {3.13 3.14 3.15 3.16} % early time is no langer muted with zeros
                % start of record is tprePulse+pulse+deadtime
                % end of record: be carefull there are bleed pulses now
                % optional at the end -> cut 100ms at the end  
                FID1_index(1) = 1 + (tprePulse+fdata.header.tau_p + fdata.header.tau_dead)*fdata.header.fS; 
                FID1_index    = floor([FID1_index(1):1:length(time) - 0.1*fdata.header.fS]);
        
                FID2_index    = [];
            otherwise   % receiver channel contains zeros before channel is open
                FID1_index(1) = 4 + find(data{6}(5:length(time))~=0,1); % receiver channel contains zeros before channel is open
                FID1_index    = [FID1_index(1):1:length(time)];
        
                FID2_index    = [];
        end
        
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
%    case 3 % ! only for test purpose!!!!!!!!!!!!!!!!!!!!!!!!!
%         tprePulse  = 50e-3; % fixed time before pulse
%         Nrfpulses  = floor((1-tprePulse)/fdata.header.te);
%         trecord    = 1;
%         time       = [0:1/fdata.header.fS:trecord-1/fdata.header.fS]; % time vector for one experiment
%         nex        = length(data{1})/length(time); % total number of experiments (either pulsemoments or stacks)
%         fdata.header.te = 0.12;
%         
%         pulse1_index  = floor(tprePulse*fdata.header.fS + ...
%                         [1:1:(fdata.header.tau_p*fdata.header.fS)]); % index to extract puls
%         pulse2_index  = floor((tprePulse + fdata.header.te/2 - fdata.header.tau_p/2)*fdata.header.fS + ...
%                         [1:1:(2*fdata.header.tau_p)*fdata.header.fS]); % index to extract second pulse after time tau
%         
%         % handle the fid
%         FID2_index     = []; 
%         FID1_index(1)  = 4 + find(data{6}(5:length(time))~=0,1); % receiver channel contains zeros before channel is open
%         FID1_index    = [FID1_index(1):1:length(time)]; % echo is recorded until end of experiment  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    case 4
        switch fdata.header.DAQversion
            case {3.13 3.14 3.15 3.16}
                tprePulse  = 50e-3; % fixed time before pulse
            otherwise
                tprePulse  = 10e-3; % fixed time before pulse
        end
        tPPramp  = 1E-3; % 1ms for ramp, not used here
        trecord    = 1 + fdata.header.tau_d; % total time T1 for experiment: 1s plus tau
        time       = [0:1/fdata.header.fS:trecord-1/fdata.header.fS]; % time vector for one experiment 
        nex        = length(data{1})/length(time); % total number of experiments (either pulsemoments or stacks)
        
        %GMR uses full cycles and tuned circuits will resonate -> pulse length is longer than tau_p, show two additional oscillations
        tau_p_real = (ceil(fdata.header.tau_p*fdata.header.fT+2.0))/fdata.header.fT;

        % no need for floor but for some reason matlab creates non integer numbers 
        %pulse1_index  = floor([(1+tprePulse*fdata.header.fS):1:(1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS)]); % index to extract puls
        pulse1_preindex = floor([(1 + tprePulse*fdata.header.fS)-20:1:(tprePulse*fdata.header.fS)]); %20 points at start to get baseline
        pulse1_index  = floor([(1 + tprePulse*fdata.header.fS):1:((tprePulse+tau_p_real)*fdata.header.fS)]); % index to extract pulse
        pulse2_index  = fdata.header.tau_d*fdata.header.fS + pulse1_index; % index to extract second pulse after time tau
        

        %old code
        %pulse1_index  = floor([(1+tprePulse*fdata.header.fS):1:(1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS)]); % index to extract puls
        %pulse2_index = fdata.header.tau_d*fdata.header.fS + pulse1_index; % index to extract second pulse after time tau

        switch fdata.header.DAQversion
            case {3.13 3.14 3.15 3.16} % early time is no langer muted with zeros
                FID1_index(1) = floor(1 + (tprePulse+fdata.header.tau_p + fdata.header.tau_dead)*fdata.header.fS); 
                FID1_index    = [FID1_index(1):1:pulse2_index(1)-200]; %one point seems a before pulse seems a little short? [FID1_index(1):1:pulse2_index(1)-1];
                
                FID2_index(1) = floor(1 + (tprePulse+fdata.header.tau_p*2 + fdata.header.tau_dead*2+fdata.header.tau_d)*fdata.header.fS);
                FID2_index    = floor([FID2_index(1):1:length(time) - 0.1*fdata.header.fS]);
            otherwise   % receiver channel contains zeros before channel is open
                FID1_index(1)  = 4 + find(data{6}(5:length(time))~=0,1); % receiver channel contains zeros before channel is open
                FID1_index(2)  = pulse2_index(1) - find(flipud(data{6}(FID1_index(1):pulse2_index(1)-1))~=0,1); % receiver channel contains zeros after channel is closed
                FID1_index     = [FID1_index(1):1:FID1_index(2)];
        
                FID2_index(1) = FID1_index(end) + find(data{6}(FID1_index(end)+1:length(time))~=0,1); % receiver channel contains zeros before channel is open
                FID2_index    = [FID2_index(1):1:length(time)]; % second FID is recorded until end of experiment

        end

        PPramp_index  = [];

    case 7
        tprePulse  = 10e-3; % fixed time before pulse
        tPPramp  = 1E-3; % 1ms for ramp, not used here
        Nrfpulses  = floor((1-tprePulse)/fdata.header.te);
        trecord    = 1;
        time       = [0:1/fdata.header.fS:trecord-1/fdata.header.fS]; % time vector for one experiment
        nex        = length(data{1})/length(time); % total number of experiments (either pulsemoments or stacks)
        
        %GMR uses full cycles and tuned circuits will resonate -> pulse length is longer than tau_p, show two additional oscillations
        tau_p_real = (ceil(fdata.header.tau_p*fdata.header.fT+2.0))/fdata.header.fT;

        % no need for floor but for some reason matlab creates non integer numbers 
        %pulse1_index  = floor([(1+tprePulse*fdata.header.fS):1:(1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS)]); % index to extract puls
        pulse1_preindex = floor([(1 + tprePulse*fdata.header.fS)-20:1:(tprePulse*fdata.header.fS)]); %20 points at start to get baseline
        pulse1_index  = floor([(1 + tprePulse*fdata.header.fS):1:((tprePulse+tau_p_real)*fdata.header.fS)]); % index to extract pulse

        pulse2_index  = floor((tprePulse + fdata.header.te/2 - fdata.header.tau_p/2)*fdata.header.fS + ...
                        [1:1:(2*fdata.header.tau_p)*fdata.header.fS]); % index to extract second pulse after time tau
        
        % handle the fid 
        FID1_index(1)  = 4 + find(data{6}(5:length(time))~=0,1); % receiver channel contains zeros before channel is open
        FID1_index(2)  = pulse2_index(1) - find(flipud(data{6}(FID1_index(1):pulse2_index(1)-1))~=0,1); % receiver channel contains zeros after channel is closed
        FID1_index     = [FID1_index(1):1:FID1_index(2)];
        
        % handle the echo train as one record
        FID2_index(1) = FID1_index(end) + find(data{6}(FID1_index(end)+1:length(time))~=0,1); % receiver channel contains zeros before channel is open
        FID2_index    = [FID2_index(1):1:length(time)]; % echo is recorded until end of experiment
        
        PPramp_index  = [];
   
    case 8
        switch fdata.header.DAQversion % check for which DAQ versions and AHP this changed!!!
            case {2.99}
                tprePulse = 10e-3; % fixed time before pulse
                tPPramp  = 1E-3; % 1ms for ramp, not used here
            otherwise
                msgbox('check tprePulse'); return               
        end
  
        trecord   = 1; % GMR has alway 1s of data for FID
        time      = [0:1/fdata.header.fS:trecord-1/fdata.header.fS]; % time vector for one experiment 
        nex       = length(data{1})/length(time); % total number of experiments (either pulsemoments or stacks)

        %GMR uses full cycles and tuned circuits will resonate -> pulse length is longer than tau_p, show two additional oscillations
        tau_p_real = (ceil(fdata.header.tau_p*fdata.header.fT+2.0))/fdata.header.fT;

        % no need for floor but for some reason matlab creates non integer numbers 
        %pulse1_index  = floor([(1+tprePulse*fdata.header.fS):1:(1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS)]); % index to extract puls
        pulse1_preindex = floor([(1 + tprePulse*fdata.header.fS)-20:1:(tprePulse*fdata.header.fS)]); %20 points at start to get baseline
        pulse1_index  = floor([(1 + tprePulse*fdata.header.fS):1:((tprePulse+tau_p_real)*fdata.header.fS+10)]); % index to extract pulse
        pulse2_index  = [];
        
        FID1_index(1) = 4 + find(data{6}(5:length(time))~=0,1); % receiver channel contains zeros before channel is open
        FID1_index    = [FID1_index(1):1:length(time)];
        
        FID2_index    = [];
        PPramp_index  = [];
        
    case 9
        tprePulse = 50e-3; % fixed time before pulse
        tPPramp  = fdata.header.PPDelay; % time for ramp (ms)
        trecord   = 1; % GMR has alway 1s of data for FID
        time      = [0:1/fdata.header.fS:trecord-1/fdata.header.fS]; % time vector for one experiment 
        nex       = length(data{1})/length(time); % total number of experiments (either pulsemoments or stacks)

        %GMR uses full cycles and tuned circuits will resonate -> pulse length is longer than tau_p, show two additional oscillations
        tau_p_real = (ceil(fdata.header.tau_p*fdata.header.fT+0.5))/fdata.header.fT;

        % no need for floor but for some reason matlab creates non integer numbers 
        %pulse1_index  = floor([(1+tprePulse*fdata.header.fS):1:(1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS)]); % index to extract puls
        pulse1_preindex = floor([(1 + tprePulse*fdata.header.fS)-30:1:(tprePulse*fdata.header.fS)-1]); %20 points at start to get baseline
        pulse1_index  = floor([(1 + tprePulse*fdata.header.fS):1:((tprePulse+tau_p_real)*fdata.header.fS+10)]); % index to extract pulse
        pulse2_index  = [];
        % indices for prepol ramp
        PPramp_index  = [floor(1 + (tprePulse-tPPramp)*fdata.header.fS):1:(1 + tprePulse*fdata.header.fS)];
        PPramp_index = PPramp_index(PPramp_index>0);

        switch fdata.header.DAQversion
            case {3.13 3.14 3.15 3.16} % early time is no langer muted with zeros
                % start of record is tprePulse+pulse+deadtime
                % end of record: be carefull there are bleed pulse now
                % optional at the end -> cut 100ms at the end  
                FID1_index(1) = 1 + (tprePulse+fdata.header.tau_p + fdata.header.tau_dead)*fdata.header.fS;
                FID1_index    = floor([FID1_index(1):1:length(time) - 0.1*fdata.header.fS]);

                %FID1_index(1) = 1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS;
                %FID1_index    = floor([FID1_index(1):1:length(time) + (fdata.header.tau_dead- 0.1)*fdata.header.fS]);
        
                FID2_index    = [];
            otherwise   % receiver channel contains zeros before channel is open
                FID1_index(1) = 4 + find(data{6}(5:length(time))~=0,1); % receiver channel contains zeros before channel is open
                FID1_index    = [FID1_index(1):1:length(time)];
        
                FID2_index    = [];
        end
    case 10
        tprePulse = 50e-3; % fixed time before pulse
        tPPramp  = fdata.header.PPDelay; % time for ramp (ms)

        trecord   = 1; % GMR has alway 1s of data for FID
        time      = [0:1/fdata.header.fS:trecord-1/fdata.header.fS]; % time vector for one experiment 
        nex       = length(data{1})/length(time); % total number of experiments (either pulsemoments or stacks)

        %GMR uses full cycles and tuned circuits will resonate -> pulse length is longer than tau_p, show two additional oscillations
        tau_p_real = (ceil(fdata.header.tau_p*fdata.header.fT+2.0))/fdata.header.fT;

        % no need for floor but for some reason matlab creates non integer numbers 
        %pulse1_index  = floor([(1+tprePulse*fdata.header.fS):1:(1 + (tprePulse+fdata.header.tau_p)*fdata.header.fS)]); % index to extract puls
        pulse1_preindex = floor([(1 + tprePulse*fdata.header.fS):1:(tprePulse*fdata.header.fS)]); %20 points at start to get baseline
        pulse1_index  = floor([(1 + tprePulse*fdata.header.fS):1:((tprePulse+tau_p_real)*fdata.header.fS+10)]); % index to extract pulse
        pulse2_index  = [];
        
        PPramp_index  = floor([(1+(tprePulse-tPPramp)*fdata.header.fS):1:(1 + (tprePulse)*fdata.header.fS)]);
        PPramp_index = PPramp_index(PPramp_index>0);

        switch fdata.header.DAQversion
            case {3.13 3.14 3.15 3.16} % early time is no langer muted with zeros
                % start of record is tprePulse+pulse+deadtime
                % end of record: be carefull there are bleed pulse now
                % optional at the end -> cut 100ms at the end  
                FID1_index(1) = 1 + (tprePulse+fdata.header.tau_p + fdata.header.tau_dead)*fdata.header.fS; 
                FID1_index    = floor([FID1_index(1):1:length(time) - 0.1*fdata.header.fS]);
        
                FID2_index    = [];
            otherwise   % receiver channel contains zeros before channel is open
                FID1_index(1) = 4 + find(data{6}(5:length(time))~=0,1); % receiver channel contains zeros before channel is open
                FID1_index    = [FID1_index(1):1:length(time)];
        
                FID2_index    = [];
        end
    otherwise
        error('unknown pulse sequence')
        msgbox('unknown pulse sequence')
end


%% read data
for nn=1:nex
    rawData = transferData(data,rawData,fdata,pulse1_index + (nn-1)*length(time),time(pulse1_index)-tprePulse,...
                                              pulse1_preindex + (nn-1)*length(time),...
                                              pulse2_index + (nn-1)*length(time),time(pulse2_index)-tprePulse,...
                                              FID1_index + (nn-1)*length(time),...
                                              FID2_index + (nn-1)*length(time),...
                                              PPramp_index + (nn-1)*length(time),time(PPramp_index)-tprePulse+tPPramp,...
                                              nn,fdata.header.nrecords);
end

%if noise measurement has been included transfer noise data to noise cell array
if nex>fdata.header.nrecords
    rawData.q1(fdata.header.nrecords + 1)=[];
    rawData.q1old(fdata.header.nrecords + 1)=[];
    if fdata.header.sequenceID == 4 %additional sig3 if T1 Measurement
        if ~fdata.UserData(1).looptask==0;
            rawData.noise{1}.sig3 = rawData.recordC1{nex}.sig3;
        end
        if ~fdata.UserData(2).looptask==0;
            rawData.noise{2}.sig3 = rawData.recordC2{nex}.sig3;
        end
        if ~fdata.UserData(3).looptask==0;
            rawData.noise{3}.sig3 = rawData.recordC3{nex}.sig3;
        end
        if ~fdata.UserData(4).looptask==0;
            rawData.noise{4}.sig3 = rawData.recordC4{nex}.sig3;
        end
        if fdata.header.expUnt
            if ~fdata.UserData(5).looptask==0;
                rawData.noise{5}.sig3 = rawData.recordC5{nex}.sig3;
            end
            if ~fdata.UserData(6).looptask==0;
                rawData.noise{6}.sig3 = rawData.recordC6{nex}.sig3;
            end
            if ~fdata.UserData(7).looptask==0;
                rawData.noise{7}.sig3 = rawData.recordC7{nex}.sig3;
            end
            if ~fdata.UserData(8).looptask==0;
                rawData.noise{8}.sig3 = rawData.recordC8{nex}.sig3;
            end
        end
    end
    %normal sig2
    if ~fdata.UserData(1).looptask==0; 
        rawData.noise{1}.sig2 = rawData.recordC1{nex}.sig2;
        rawData.recordC1(nex) = [];
    end
    if ~fdata.UserData(2).looptask==0;
        rawData.noise{2}.sig2 = rawData.recordC2{nex}.sig2;
        rawData.recordC2(nex) = [];
    end
    if ~fdata.UserData(3).looptask==0;
        rawData.noise{3}.sig2 = rawData.recordC3{nex}.sig2;
        rawData.recordC3(nex) = [];
    end
    if ~fdata.UserData(4).looptask==0;
        rawData.noise{4}.sig2 = rawData.recordC4{nex}.sig2;
        rawData.recordC4(nex) = [];
    end
    if fdata.header.expUnt
        if ~fdata.UserData(5).looptask==0;
            rawData.noise{5}.sig2 = rawData.recordC5{nex}.sig2;
            rawData.recordC5(nex) = [];
        end
        if ~fdata.UserData(6).looptask==0;
            rawData.noise{6}.sig2 = rawData.recordC6{nex}.sig2;
            rawData.recordC6(nex) = [];
        end
        if ~fdata.UserData(7).looptask==0;
            rawData.noise{7}.sig2 = rawData.recordC7{nex}.sig2;
            rawData.recordC7(nex) = [];
        end
        if ~fdata.UserData(8).looptask==0;
            rawData.noise{8}.sig2 = rawData.recordC8{nex}.sig2;
            rawData.recordC8(nex) = [];
        end
    end
end

function rawData = transferData(data,rawData,fdata,pulse1_index,pulse1_time,pulse1_preindex,pulse2_index,pulse2_time,FID1_index,FID2_index,PPramp_index,PPramp_time,nexp,nrecords)                   
switch fdata.header.sequenceID % 1: FID; 2: 90-90; 3:  ; 4: 4phase T1; 7: CPMG; 8:AHP 9: Prepolization FID
    case {1}
        % second pulse
        rawData.q2(nexp)       = 0;
        rawData.q2phase(nexp)  = 0;
        
        % first pulse
        rawData.timepulse   = pulse1_time;
        rawData.pulseI1{nexp}  = data{2}(pulse1_index);
        if ~min(pulse1_preindex > 0) %happens in noise measurements
            rawData.pulsepreI1{nexp} = [];
            rawData.zeroTx = 0;
        else
            rawData.pulsepreI1{nexp}  = data{2}(pulse1_preindex);
            rawData.zeroTx = mean(data{2}(pulse1_preindex)); %Take mean of first 20 points as baseline voltage
        end

        rawData.pulseI2{nexp}  = data{3}(pulse1_index);

        % calculate pulse moments and phase of first puls
        % older version
        % ref                 = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
        % rawData.q1(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulseI1{nexp}.^2))*sqrt(2)*fdata.header.tau_p + ...
        %                                           sqrt(mean(rawData.pulseI2{nexp}.^2))*sqrt(2)*fdata.header.tau_p)/2;
       
        % changed for GMR Flex! - channel 3 is empfty| not empty but prepol
        % ramp
        % check if no problem occur for older
        % rawData.q1(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulseI1{nexp}.^2))*sqrt(2)*fdata.header.tau_p + ...
        %                                           sqrt(mean(rawData.pulseI1{nexp}.^2))*sqrt(2)*fdata.header.tau_p)/2;
        % does not work nicely
        % use hilbert to get enveloppe and integrate
        % use hilbert to get enveloppe and integrate
        [rawData.q1(nexp),rawData.q1phase(nexp),rawData.q1old(nexp)] = HilbertEnvelope(rawData.pulseI1{nexp},pulse1_time,fdata.header.fT,fdata.header.fS,fdata.header.tau_p,rawData.TXgain,rawData.zeroTx);
        ishift = ceil(tshift*fdata.header.fS); %the pulse rings for high qs, we shift the aquired signal by the difference between the center of mass and taup/2, disabled in HilbertEnvelope function because it is unstable
        if nexp > nrecords %noise measurement
            rawData.tshift(nexp) = 0; %the time shift should not matter for the noise measurement, nonetheless we remove it here
        else
            rawData.tshift(nexp) = ishift/fdata.header.fS;
        end
        % first 4 data channels
        if ~fdata.UserData(1).looptask==0; 
            rawData.recordC1{nexp}.sig2 = data{6}(FID1_index+ishift)./rawData.RXgain;
        end
        if ~fdata.UserData(2).looptask==0; 
            rawData.recordC2{nexp}.sig2 = data{7}(FID1_index+ishift)./rawData.RXgain;
        end
        if ~fdata.UserData(3).looptask==0; 
            rawData.recordC3{nexp}.sig2 = data{8}(FID1_index+ishift)./rawData.RXgain;
        end
        if ~fdata.UserData(4).looptask==0; 
            rawData.recordC4{nexp}.sig2 = data{9}(FID1_index+ishift)./rawData.RXgain;
        end
        % second set of 4 data channels
        if fdata.header.expUnt
            if ~fdata.UserData(5).looptask==0;
                rawData.recordC5{nexp}.sig2 = data{10}(FID1_index+ishift)./rawData.RXgain;
            end
            if ~fdata.UserData(6).looptask==0;
                rawData.recordC6{nexp}.sig2 = data{11}(FID1_index+ishift)./rawData.RXgain;
            end
            if ~fdata.UserData(7).looptask==0;
                rawData.recordC7{nexp}.sig2 = data{12}(FID1_index+ishift)./rawData.RXgain;
            end
            if ~fdata.UserData(8).looptask==0;
                rawData.recordC8{nexp}.sig2 = data{13}(FID1_index+ishift)./rawData.RXgain;
            end
        end
    case 4
        % second pulse
        rawData.timepulse   = pulse2_time;
        rawData.pulse2I1{nexp}  = data{2}(pulse2_index);
        rawData.pulse2I2{nexp}  = data{3}(pulse2_index);
        % calculate pulse moments and phase of second puls
        % older version
        % ref                    = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
        % rawData.q2(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulse2I1{nexp}.^2))*sqrt(2)*fdata.header.tau_p + ...
        %                                           sqrt(mean(rawData.pulse2I2{nexp}.^2))*sqrt(2)*fdata.header.tau_p)/2;
        % rawData.q2phase(nexp)  = median(angle(mrs_hilbert(rawData.pulse2I1{nexp}).*ref.'));  
        ref                 = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
        rawData.q2(nexp)    = 1/rawData.TXgain *  sum(abs(mrs_hilbert(rawData.pulse2I1{nexp}).*ref.'))/size(pulse1_index,2)*fdata.header.tau_p;
        rawData.q2phase(nexp)  = median(angle(mrs_hilbert(rawData.pulse2I1{nexp}).*ref.'));

        % first pulse
        rawData.timepulse   = pulse1_time;
        rawData.pulseI1{nexp}  = data{2}(pulse1_index);
        rawData.pulseI2{nexp}  = data{3}(pulse1_index);
        % calculate pulse moments and phase of first puls
        % ref                    = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
        % rawData.q1(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulseI1{nexp}.^2))*sqrt(2)*fdata.header.tau_p + ...
        %                                           sqrt(mean(rawData.pulseI2{nexp}.^2))*sqrt(2)*fdata.header.tau_p)/2;
        % rawData.q1phase(nexp)  = median(angle(mrs_hilbert(rawData.pulseI1{nexp}).*ref.'));                                    
        ref                 = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
        rawData.q1(nexp)    = 1/rawData.TXgain *  sum(abs(mrs_hilbert(rawData.pulseI1{nexp}).*ref.'))/size(pulse1_index,2)*fdata.header.tau_p;
        rawData.q1phase(nexp)  = median(angle(mrs_hilbert(rawData.pulseI1{nexp}).*ref.'));

        % first 4 data channels
        if ~fdata.UserData(1).looptask==0; 
            rawData.recordC1{nexp}.sig2 = data{6}(FID1_index)./rawData.RXgain;
            rawData.recordC1{nexp}.sig3 = data{6}(FID2_index)./rawData.RXgain;
        end
        if ~fdata.UserData(2).looptask==0; 
            rawData.recordC2{nexp}.sig2 = data{7}(FID1_index)./rawData.RXgain;
            rawData.recordC2{nexp}.sig3 = data{7}(FID2_index)./rawData.RXgain;
        end
        if ~fdata.UserData(3).looptask==0; 
            rawData.recordC3{nexp}.sig2 = data{8}(FID1_index)./rawData.RXgain;
            rawData.recordC3{nexp}.sig3 = data{8}(FID2_index)./rawData.RXgain;
        end
        if ~fdata.UserData(4).looptask==0; 
            rawData.recordC4{nexp}.sig2 = data{9}(FID1_index)./rawData.RXgain;
            rawData.recordC4{nexp}.sig3 = data{9}(FID2_index)./rawData.RXgain;
        end
        % second set of 4 data channels
        if fdata.header.expUnt
            if ~fdata.UserData(5).looptask==0;
                rawData.recordC5{nexp}.sig2 = data{10}(FID1_index)./rawData.RXgain;
                rawData.recordC5{nexp}.sig3 = data{10}(FID2_index)./rawData.RXgain;
            end
            if ~fdata.UserData(6).looptask==0;
                rawData.recordC6{nexp}.sig2 = data{11}(FID1_index)./rawData.RXgain;
                rawData.recordC6{nexp}.sig3 = data{11}(FID2_index)./rawData.RXgain;
            end
            if ~fdata.UserData(7).looptask==0;
                rawData.recordC7{nexp}.sig2 = data{12}(FID1_index)./rawData.RXgain;
                rawData.recordC7{nexp}.sig3 = data{12}(FID2_index)./rawData.RXgain;
            end
            if ~fdata.UserData(8).looptask==0;
                rawData.recordC8{nexp}.sig2 = data{13}(FID1_index)./rawData.RXgain;
                rawData.recordC8{nexp}.sig3 = data{13}(FID2_index)./rawData.RXgain;
            end
        end
    case {3,7}
        % first pulse
        rawData.timepulse      = pulse1_time;
        rawData.pulseI1{nexp}  = data{2}(pulse1_index);
        rawData.pulseI2{nexp}  = data{3}(pulse1_index);
        % calculate pulse moments and phase of first puls
        ref                    = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
        rawData.q1(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulseI1{nexp}.^2))*sqrt(2)*fdata.header.tau_p + ...
                                                   sqrt(mean(rawData.pulseI2{nexp}.^2))*sqrt(2)*fdata.header.tau_p)/2;
        rawData.q1phase(nexp)  = median(angle(mrs_hilbert(rawData.pulseI1{nexp}).*ref.')); 
        
        % second pulse
        rawData.timepulse       = pulse2_time;
        rawData.pulse2I1{nexp}  = data{2}(pulse2_index);
        rawData.pulse2I2{nexp}  = data{3}(pulse2_index);
        % calculate pulse moments and phase of second puls
        ref                    = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
        rawData.q2(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulse2I1{nexp}.^2))*sqrt(2)*2*fdata.header.tau_p + ...
                                                   sqrt(mean(rawData.pulse2I2{nexp}.^2))*sqrt(2)*2*fdata.header.tau_p)/2;
        rawData.q2phase(nexp)  = median(angle(mrs_hilbert(rawData.pulse2I1{nexp}).*ref.'));                                   

        % first 4 data channels
        if ~fdata.UserData(1).looptask==0; 
            rawData.recordC1{nexp}.sig2 = data{6}(FID1_index)./rawData.RXgain;
            rawData.recordC1{nexp}.sig4 = data{6}(FID2_index)./rawData.RXgain;
        end
        if ~fdata.UserData(2).looptask==0; 
            rawData.recordC2{nexp}.sig2 = data{7}(FID1_index)./rawData.RXgain;
            rawData.recordC2{nexp}.sig4 = data{7}(FID2_index)./rawData.RXgain;
        end
        if ~fdata.UserData(3).looptask==0; 
            rawData.recordC3{nexp}.sig2 = data{8}(FID1_index)./rawData.RXgain;
            rawData.recordC3{nexp}.sig4 = data{8}(FID2_index)./rawData.RXgain;
        end
        if ~fdata.UserData(4).looptask==0; 
            rawData.recordC4{nexp}.sig2 = data{9}(FID1_index)./rawData.RXgain;
            rawData.recordC4{nexp}.sig4 = data{9}(FID2_index)./rawData.RXgain;
        end
        % second set of 4 data channels
        if fdata.header.expUnt
            if ~fdata.UserData(5).looptask==0;
                rawData.recordC5{nexp}.sig2 = data{10}(FID1_index)./rawData.RXgain;
                rawData.recordC5{nexp}.sig4 = data{10}(FID2_index)./rawData.RXgain;
            end
            if ~fdata.UserData(6).looptask==0;
                rawData.recordC6{nexp}.sig2 = data{11}(FID1_index)./rawData.RXgain;
                rawData.recordC6{nexp}.sig4 = data{11}(FID2_index)./rawData.RXgain;
            end
            if ~fdata.UserData(7).looptask==0;
                rawData.recordC7{nexp}.sig2 = data{12}(FID1_index)./rawData.RXgain;
                rawData.recordC7{nexp}.sig4 = data{12}(FID2_index)./rawData.RXgain;
            end
            if ~fdata.UserData(8).looptask==0;
                rawData.recordC8{nexp}.sig2 = data{13}(FID1_index)./rawData.RXgain;
                rawData.recordC8{nexp}.sig4 = data{13}(FID2_index)./rawData.RXgain;
            end
        end
    case 8 % adiabatic half-passage (AHP)
        % second pulse
        rawData.q2(nexp)       = 0;
        rawData.q2phase(nexp)  = 0;
        
%         pulse1_index = pulse1_index+50;
        
        % first pulse
        rawData.timepulse       = pulse1_time;
        rawData.pulseI1{nexp}   = data{2}(pulse1_index);
        rawData.pulseI2{nexp}   = data{3}(pulse1_index);

        % estimate Hilbert of pulse
        
        % extend record of pulse by 1ms to avoid artifacts 
        N_long = 50; % 50 = 1ms 
        % make long index
        pulse1_index_long = [min(pulse1_index)-N_long:1:max(pulse1_index)+N_long];
        % make new time vector
%         dt                  = pulse1_time(2)-pulse1_time(1);
%         rawData.timepulse   = 0:dt:(length(pulse1_index)+N_long)*dt;
        
        % save current envelop and clip ends
        temp_I1a = mrs_hilbert(data{2}(pulse1_index_long));
        I1a = temp_I1a(N_long+1:end-N_long); % clip to original pulse length
        temp_I1b = mrs_hilbert(data{3}(pulse1_index_long));  
        I1b = temp_I1b(N_long+1:end-N_long); % clip to original pulse length  
        
        rawData.recordI1{nexp}      = (abs(I1a)+abs(I1b))./2./rawData.TXgain; % currently used in kernel calculation    
        
        if 0
        figure(10)
        clf
        plot(pulse1_time, rawData.pulseI1{nexp},'g-'); hold on
        plot(rawData.timepulse, abs(I1a),'r-'); hold on     
        plot(rawData.timepulse, abs(I1b),'b-'); hold on  
        plot(rawData.timepulse, abs(rawData.recordI1{nexp}),'k-'); hold on            
        end

        % save max current instead of pm, Use average over last 5ms i.e. 250 samples
        rawData.maxI1(nexp)    = mean(rawData.recordI1{nexp}(end-250:end)); 
        rawData.q1(nexp)       = rawData.maxI1(nexp); % not TRUE!! only used for convenient processing/sorting!!!

        
        % calculate pulse moments and phase of first puls
         ref                    = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
%         rawData.q1(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulseI1{nexp}.^2))*sqrt(2)*fdata.header.tau_p + ...
%                                                    sqrt(mean(rawData.pulseI2{nexp}.^2))*sqrt(2)*fdata.header.tau_p)/2;
         rawData.q1phase(nexp)  = median(angle(I1a(end-50:end).*ref(end-50:end).'));       % estimate the phase for the last 50 point (1ms)
         
            
        % first 4 data channels
        if ~fdata.UserData(1).looptask==0; 
            rawData.recordC1{nexp}.sig2 = data{6}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(2).looptask==0; 
            rawData.recordC2{nexp}.sig2 = data{7}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(3).looptask==0; 
            rawData.recordC3{nexp}.sig2 = data{8}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(4).looptask==0; 
            rawData.recordC4{nexp}.sig2 = data{9}(FID1_index)./rawData.RXgain;
        end
        % second set of 4 data channels
        if fdata.header.expUnt
            if ~fdata.UserData(5).looptask==0;
                rawData.recordC5{nexp}.sig2 = data{10}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(6).looptask==0;
                rawData.recordC6{nexp}.sig2 = data{11}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(7).looptask==0;
                rawData.recordC7{nexp}.sig2 = data{12}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(8).looptask==0;
                rawData.recordC8{nexp}.sig2 = data{13}(FID1_index)./rawData.RXgain;
            end
        end        
    case {9} %FID with Prepol
        % second pulse
        rawData.q2(nexp)       = 0;
        rawData.q2phase(nexp)  = 0;
        
        % first pulse
        rawData.timepulse   = pulse1_time;
        rawData.pulseI1{nexp}  = data{2}(pulse1_index);
        %check other channels for induction during pulse
        %rawData.pulseI1inPP{nexp} = data{3}(pulse1_index);
        %rawData.pulseI1inRx1{nexp} = data{6}(pulse1_index);
        %rawData.pulseI1inRx2{nexp} = data{7}(pulse1_index);
        rawData.zeroTx = mean(data{2}(pulse1_preindex)); %Take mean of first 20 points as baseline voltage
        rawData.zeroPP{nexp}  = mean(data{3}(FID1_index(end-100:end))); %Take the last 100 Points of measurement to find the baseline for the PP current
        rawData.rampPP{nexp}  = data{3}(PPramp_index)-rawData.zeroPP{nexp};
        

        Px_scal_fac=26.5; %[A/V] scaling factor from Cristina McLaughlin

        % use hilbert to get enveloppe and integrate
        [rawData.q1(nexp),rawData.q1phase(nexp),rawData.q1old(nexp)] = HilbertEnvelope(rawData.pulseI1{nexp},pulse1_time,fdata.header.fT,fdata.header.fS,fdata.header.tau_p,rawData.TXgain,rawData.zeroTx);

        % first 4 data channels
        if ~fdata.UserData(1).looptask==0; 
            rawData.recordC1{nexp}.sig2 = data{6}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(2).looptask==0; 
            rawData.recordC2{nexp}.sig2 = data{7}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(3).looptask==0; 
            rawData.recordC3{nexp}.sig2 = data{8}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(4).looptask==0; 
            rawData.recordC4{nexp}.sig2 = data{9}(FID1_index)./rawData.RXgain;
        end
        % second set of 4 data channels
        if fdata.header.expUnt
            if ~fdata.UserData(5).looptask==0;
                rawData.recordC5{nexp}.sig2 = data{10}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(6).looptask==0;
                rawData.recordC6{nexp}.sig2 = data{11}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(7).looptask==0;
                rawData.recordC7{nexp}.sig2 = data{12}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(8).looptask==0;
                rawData.recordC8{nexp}.sig2 = data{13}(FID1_index)./rawData.RXgain;
            end
        end
    case 10 % adiabatic half-passage (AHP) with Prepol
        % second pulse
        rawData.q2(nexp)       = 0;
        rawData.q2phase(nexp)  = 0;
        
%         pulse1_index = pulse1_index+50;
        
        % first pulse
        rawData.timepulse       = pulse1_time;
        rawData.pulseI1{nexp}   = data{2}(pulse1_index);
        rawData.pulseI2{nexp}   = data{3}(pulse1_index);
        rawData.rampPP{nexp}  = data{3}(PPramp_index);

        % estimate Hilbert of pulse
        
        % extend record of pulse by 1ms to avoid artifacts 
        N_long = 50; % 50 = 1ms 
        % make long index
        pulse1_index_long = [min(pulse1_index)-N_long:1:max(pulse1_index)+N_long];
        % make new time vector
%         dt                  = pulse1_time(2)-pulse1_time(1);
%         rawData.timepulse   = 0:dt:(length(pulse1_index)+N_long)*dt;
        
        % save current envelop and clip ends
        temp_I1a = mrs_hilbert(data{2}(pulse1_index_long));
        I1a = temp_I1a(N_long+1:end-N_long); % clip to original pulse length
        temp_I1b = mrs_hilbert(data{3}(pulse1_index_long));  
        I1b = temp_I1b(N_long+1:end-N_long); % clip to original pulse length  
        
        rawData.recordI1{nexp}      = (abs(I1a)+abs(I1b))./2./rawData.TXgain; % currently used in kernel calculation    
        
        if 0
        figure(10)
        clf
        plot(pulse1_time, rawData.pulseI1{nexp},'g-'); hold on
        plot(rawData.timepulse, abs(I1a),'r-'); hold on     
        plot(rawData.timepulse, abs(I1b),'b-'); hold on  
        plot(rawData.timepulse, abs(rawData.recordI1{nexp}),'k-'); hold on            
        end

        % save max current instead of pm, Use average over last 5ms i.e. 250 samples
        rawData.maxI1(nexp)    = mean(rawData.recordI1{nexp}(end-250:end)); 
        rawData.q1(nexp)       = rawData.maxI1(nexp); % not TRUE!! only used for convenient processing/sorting!!!

        
        % calculate pulse moments and phase of first puls
         ref                    = exp(-1i*2*pi*fdata.header.fT.*rawData.timepulse);
%         rawData.q1(nexp)       = 1/rawData.TXgain*(sqrt(mean(rawData.pulseI1{nexp}.^2))*sqrt(2)*fdata.header.tau_p + ...
%                                                    sqrt(mean(rawData.pulseI2{nexp}.^2))*sqrt(2)*fdata.header.tau_p)/2;
         rawData.q1phase(nexp)  = median(angle(I1a(end-50:end).*ref(end-50:end).'));       % estimate the phase for the last 50 point (1ms)
         
            
        % first 4 data channels
        if ~fdata.UserData(1).looptask==0; 
            rawData.recordC1{nexp}.sig2 = data{6}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(2).looptask==0; 
            rawData.recordC2{nexp}.sig2 = data{7}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(3).looptask==0; 
            rawData.recordC3{nexp}.sig2 = data{8}(FID1_index)./rawData.RXgain;
        end
        if ~fdata.UserData(4).looptask==0; 
            rawData.recordC4{nexp}.sig2 = data{9}(FID1_index)./rawData.RXgain;
        end
        % second set of 4 data channels
        if fdata.header.expUnt
            if ~fdata.UserData(5).looptask==0;
                rawData.recordC5{nexp}.sig2 = data{10}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(6).looptask==0;
                rawData.recordC6{nexp}.sig2 = data{11}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(7).looptask==0;
                rawData.recordC7{nexp}.sig2 = data{12}(FID1_index)./rawData.RXgain;
            end
            if ~fdata.UserData(8).looptask==0;
                rawData.recordC8{nexp}.sig2 = data{13}(FID1_index)./rawData.RXgain;
            end
        end
end