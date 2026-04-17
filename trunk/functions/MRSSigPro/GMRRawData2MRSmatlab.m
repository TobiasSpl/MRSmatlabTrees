function fdata = GMRRawData2MRSmatlab(data,fdata,iq,irec,nq)

dofilter=1;
if dofilter
    % filtering causes some time cut at the beginnning of the record to
    % avoid artifact (currently 100 samples)
    % take into this into account 
    % resampling starts 100 samples --> dt = 100/fdata.header.fS
    % dphase = sin(2*pi*fT.*dt) ?!?!?
    % current approach: adapt timevector for QD to include deadtime
    
    % decimate from 50kHz sampling down to 10kHz to reduce data
    % filter definition
    FilterType = 'equiripple'; %'butter'
    Fs = fdata.header.fS;
    Apass = 1;
    Astop = 30;%50;
    Fpass = 3000;
    Fstop = 9000;%5000;


    switch FilterType
        case 'butter'
            if ~exist('buttord')
                % take filter coefficient from precalculation
                load('coefficient.mat')
                [dummy,ipass]   = find(passFreq <= Fpass,1,'last');
                [dummy,istop]   = find(stopFreq <= Fstop,1,'last');
                [dummy,isample] = find(sampleFreq <= Fs,1,'last');
                a = coeff.passFreq(ipass).stopFreq(istop).sampleFreq(isample).a;
                b = coeff.passFreq(ipass).stopFreq(istop).sampleFreq(isample).b;
            else
                [N,Fc]      = buttord(Fpass/(Fs/2), Fstop/(Fs/2), Apass, Astop);
                [b,a]       = butter(N, Fc);
            end
        case 'equiripple'
            filt = designfilt('lowpassfir','PassbandFrequency',Fpass,'StopbandFrequency',Fstop,'SampleRate',Fs,'StopbandAttenuation',Astop);
            a = 1; %all-zero (FIR) filter
            b = filt.Coefficients;
    end
    
    xspike = zeros(size(data.recordC1{1}.sig2)); xspike(1)=1i;
    fx     = mrs_filtfilt(b,a,xspike)';
    index  = find(abs(fx) > 0.01, 1, "last")+1;
    %index = 100;
    if ~exist('freqz')
        rate            = floor((Fs/2)/Fstop); % reduce rate ,i.e., re-samling -> use floor to get integer
        %rate            = (Fs/2)/Fstop(2); % reduce rate ,i.e., re-samling
    else
        [h,f] = freqz(b,a,1024,Fs);
        i = find(abs(h)<sqrt(0.5),1,"first");
        rate            = floor((Fs/2)/f(i));
    end
    fs              = Fs/rate;
    
    

    deadtime_import = (index)/Fs;
    if fdata.info.listening
        deadtime_listen = fdata.header.tau_p + fdata.header.PPDelay;
    else
        deadtime_listen = 0;
    end
    deadtime        = fdata.header.tau_dead + deadtime_import + deadtime_listen;
    
    if ~fdata.UserData(1).looptask==0; tmp.receiver(1).signal = mrs_filtfilt(b,a,data.recordC1{iq}.sig2);end
    if ~fdata.UserData(2).looptask==0; tmp.receiver(2).signal = mrs_filtfilt(b,a,data.recordC2{iq}.sig2);end
    if ~fdata.UserData(3).looptask==0; tmp.receiver(3).signal = mrs_filtfilt(b,a,data.recordC3{iq}.sig2);end
    if ~fdata.UserData(4).looptask==0; tmp.receiver(4).signal = mrs_filtfilt(b,a,data.recordC4{iq}.sig2);end
    if fdata.header.nrx == 8
        if ~fdata.UserData(5).looptask==0; tmp.receiver(5).signal = mrs_filtfilt(b,a,data.recordC5{iq}.sig2);end
        if ~fdata.UserData(6).looptask==0; tmp.receiver(6).signal = mrs_filtfilt(b,a,data.recordC6{iq}.sig2);end
        if ~fdata.UserData(7).looptask==0; tmp.receiver(7).signal = mrs_filtfilt(b,a,data.recordC7{iq}.sig2);end
        if ~fdata.UserData(8).looptask==0; tmp.receiver(8).signal = mrs_filtfilt(b,a,data.recordC8{iq}.sig2);end
    end
    
    % we only have one noise record per stack, so we can transfer it at any one nq
    if isfield(data,"noise") && nq==1
        nrx= fdata.header.nrx;
        for irx=1:nrx
            if ~fdata.UserData(irx).looptask==0
                tmp.receiver(irx).noise = mrs_filtfilt(b,a,data.noise{irx}.sig2);
                polyout.receiver(irx).std_raw(2) = std(data.noise{irx}.sig2,"omitnan");
            end
        end
    end
    
    for irx=1:fdata.header.nrx
        if ~fdata.UserData(irx).looptask==0
            polyout.receiver(irx).signal(1).V     = [];
            polyout.receiver(irx).signal(2).V     = tmp.receiver(irx).signal(index:rate:end-index).'; % 50 arises from filter spike test
            polyout.receiver(irx).signal(3).V     = [];
            polyout.receiver(irx).signal(4).V     = [];
            %polyout.receiver(irx).SampleFrequency = fdata.header.fS/rate;
            polyout.receiver(irx).signal(2).t     = (0:length(polyout.receiver(irx).signal(2).V)-1)/(fdata.header.fS/rate) + deadtime;     % time [s]
            if isfield(data,"noise") && nq==1
                polyout.receiver(irx).noise(2).V = tmp.receiver(irx).noise(index:rate:end-index).'; % 50 arises from filter spike test
                polyout.receiver(irx).noise(2).t = polyout.receiver(irx).signal(2).t;
            end
        end
    end
    
    switch fdata.header.sequenceID
        case 4
            if ~fdata.UserData(1).looptask==0; tmp.receiver(1).signal = mrs_filtfilt(b,a,data.recordC1{iq}.sig3);end
            if ~fdata.UserData(2).looptask==0; tmp.receiver(2).signal = mrs_filtfilt(b,a,data.recordC2{iq}.sig3);end
            if ~fdata.UserData(3).looptask==0; tmp.receiver(3).signal = mrs_filtfilt(b,a,data.recordC3{iq}.sig3);end
            if ~fdata.UserData(4).looptask==0; tmp.receiver(4).signal = mrs_filtfilt(b,a,data.recordC4{iq}.sig3);end
            if fdata.header.nrx == 8
                if ~fdata.UserData(5).looptask==0; tmp.receiver(5).signal = mrs_filtfilt(b,a,data.recordC5{iq}.sig3);end
                if ~fdata.UserData(6).looptask==0; tmp.receiver(6).signal = mrs_filtfilt(b,a,data.recordC6{iq}.sig3);end
                if ~fdata.UserData(7).looptask==0; tmp.receiver(7).signal = mrs_filtfilt(b,a,data.recordC7{iq}.sig3);end
                if ~fdata.UserData(8).looptask==0; tmp.receiver(8).signal = mrs_filtfilt(b,a,data.recordC8{iq}.sig3);end
            end
            
            % we only have one noise record per stack, so we can transfer it at any one nq
            if isfield(data,"noise") && nq==1
                nrx= fdata.header.nrx;
                for irx=1:nrx
                    if ~fdata.UserData(irx).looptask==0 
                        tmp.receiver(irx).noise = mrs_filtfilt(b,a,data.noise{irx}.sig3);
                        polyout.receiver(irx).std_raw(3) = std(data.noise{irx}.sig3,"omitnan");
                    end
                end
            end

            for irx=1:fdata.header.nrx
                if ~fdata.UserData(irx).looptask==0
                    polyout.receiver(irx).signal(3).V = tmp.receiver(irx).signal(index:rate:end-index).';
                    polyout.receiver(irx).signal(3).t = (0:length(polyout.receiver(irx).signal(3).V)-1)/(fdata.header.fS/rate) + deadtime;     % time [s]
                    if isfield(data,"noise") && nq==1
                        polyout.receiver(irx).noise(3).V = tmp.receiver(irx).noise(index:rate:end-index).'; % 50 arises from filter spike test
                        polyout.receiver(irx).noise(3).t = polyout.receiver(irx).signal(3).t;
                    end
                end
            end
        case {3,7}
            if ~fdata.UserData(1).looptask==0; tmp.receiver(1).signal = mrs_filtfilt(b,a,data.recordC1{iq}.sig4);end
            if ~fdata.UserData(2).looptask==0; tmp.receiver(2).signal = mrs_filtfilt(b,a,data.recordC2{iq}.sig4);end
            if ~fdata.UserData(3).looptask==0; tmp.receiver(3).signal = mrs_filtfilt(b,a,data.recordC3{iq}.sig4);end
            if ~fdata.UserData(4).looptask==0; tmp.receiver(4).signal = mrs_filtfilt(b,a,data.recordC4{iq}.sig4);end
            if fdata.header.nrx == 8
                if ~fdata.UserData(5).looptask==0; tmp.receiver(5).signal = mrs_filtfilt(b,a,data.recordC5{iq}.sig4);end
                if ~fdata.UserData(6).looptask==0; tmp.receiver(6).signal = mrs_filtfilt(b,a,data.recordC6{iq}.sig4);end
                if ~fdata.UserData(7).looptask==0; tmp.receiver(7).signal = mrs_filtfilt(b,a,data.recordC7{iq}.sig4);end
                if ~fdata.UserData(8).looptask==0; tmp.receiver(8).signal = mrs_filtfilt(b,a,data.recordC8{iq}.sig4);end
            end

            % we only have one noise record per stack, so we can transfer it at any one nq
            if isfield(data,"noise") && nq==1
                nrx= fdata.header.nrx;
                for irx=1:nrx
                    if ~fdata.UserData(irx).looptask==0
                        tmp.receiver(irx).noise = mrs_filtfilt(b,a,data.noise{irx}.sig4);
                        polyout.receiver(irx).std_raw(4) = std(data.noise{irx}.sig4,"omitnan");
                    end
                end
            end
            
            for irx=1:fdata.header.nrx
                if ~fdata.UserData(irx).looptask==0
                    polyout.receiver(irx).signal(4).V = tmp.receiver(irx).signal(100+rate:rate:end-rate-100).';
                    polyout.receiver(irx).signal(4).t = (0:length(polyout.receiver(irx).signal(4).V)-1)/(fdata.header.fS/rate) + deadtime;     % time [s]
                    if isfield(data,"noise") && nq==1
                        polyout.receiver(irx).noise(4).V = tmp.receiver(irx).noise(100+rate:rate:end-rate-100).'; % 50 arises from filter spike test
                        polyout.receiver(irx).noise(4).t = polyout.receiver(irx).signal(4).t;
                    end
                end
            end
    end
    
else %% read in data without filter
    
    rate=1;
    deadtime_import = 0;
    if fdata.info.listening
        deadtime_listen = fdata.header.tau_p + fdata.header.PPDelay;
    else
        deadtime_listen = 0;
    end
    deadtime        = fdata.header.tau_dead + deadtime_import + deadtime_listen;
    
    if ~fdata.UserData(1).looptask==0; tmp.receiver(1).signal = data.recordC1{iq}.sig2;end
    if ~fdata.UserData(2).looptask==0; tmp.receiver(2).signal = data.recordC2{iq}.sig2;end
    if ~fdata.UserData(3).looptask==0; tmp.receiver(3).signal = data.recordC3{iq}.sig2;end
    if ~fdata.UserData(4).looptask==0; tmp.receiver(4).signal = data.recordC4{iq}.sig2;end
    if fdata.header.nrx == 8
        if ~fdata.UserData(5).looptask==0; tmp.receiver(5).signal = data.recordC5{iq}.sig2;end
        if ~fdata.UserData(6).looptask==0; tmp.receiver(6).signal = data.recordC6{iq}.sig2;end
        if ~fdata.UserData(7).looptask==0; tmp.receiver(7).signal = data.recordC7{iq}.sig2;end
        if ~fdata.UserData(8).looptask==0; tmp.receiver(8).signal = data.recordC8{iq}.sig2;end
    end
    
    % we only have one noise record per stack, so we can transfer it at any one nq
    if isfield(data,"noise") && nq==1
        nrx= fdata.header.nrx;
        for irx=1:nrx
            if ~fdata.UserData(irx).looptask==0
                tmp.receiver(irx).noise = data.noise{irx}.sig2;
                polyout.receiver(irx).std_raw(2) = std(data.noise{irx}.sig2,"omitnan");
            end
        end
    end

    for irx=1:fdata.header.nrx
        if ~fdata.UserData(irx).looptask==0
            polyout.receiver(irx).signal(1).V     = [];
            polyout.receiver(irx).signal(2).V     = tmp.receiver(irx).signal.';
            polyout.receiver(irx).signal(3).V     = [];
            polyout.receiver(irx).signal(4).V     = [];
            %polyout.receiver(irx).SampleFrequency = fdata.header.fS;
            polyout.receiver(irx).signal(2).t     = (0:length(tmp.receiver(irx).signal)-1)/fdata.header.fS + deadtime;     % time [s]
            if isfield(data,"noise") && nq==1
                polyout.receiver(irx).noise(1).V     = [];
                polyout.receiver(irx).noise(2).t = polyout.receiver(irx).signal(2).t;
                polyout.receiver(irx).noise(3).V     = [];
                polyout.receiver(irx).noise(4).V     = [];
                polyout.receiver(irx).noise(2).V = tmp.receiver(irx).noise(:).'; % 50 arises from filter spike test
            end
        end
    end
    
    switch fdata.header.sequenceID
        case 4
            if ~fdata.UserData(1).looptask==0; tmp.receiver(1).signal = data.recordC1{iq}.sig3;end
            if ~fdata.UserData(2).looptask==0; tmp.receiver(2).signal = data.recordC2{iq}.sig3;end
            if ~fdata.UserData(3).looptask==0; tmp.receiver(3).signal = data.recordC3{iq}.sig3;end
            if ~fdata.UserData(4).looptask==0; tmp.receiver(4).signal = data.recordC4{iq}.sig3;end
            if fdata.header.nrx == 8
                if ~fdata.UserData(5).looptask==0; tmp.receiver(5).signal = data.recordC5{iq}.sig3;end
                if ~fdata.UserData(6).looptask==0; tmp.receiver(6).signal = data.recordC6{iq}.sig3;end
                if ~fdata.UserData(7).looptask==0; tmp.receiver(7).signal = data.recordC7{iq}.sig3;end
                if ~fdata.UserData(8).looptask==0; tmp.receiver(8).signal = data.recordC8{iq}.sig3;end
            end

            % we only have one noise record per stack, so we can transfer it at any one nq
            if isfield(data,"noise") && nq==1
                nrx= fdata.header.nrx;
                for irx=1:nrx
                    if ~fdata.UserData(irx).looptask==0
                        tmp.receiver(irx).noise = data.noise{irx}.sig3;
                        polyout.receiver(irx).std_raw(4) = std(data.noise{irx}.sig3,"omitnan");
                    end
                end
            end
            
            for irx=1:fdata.header.nrx
                if ~fdata.UserData(irx).looptask==0
                    polyout.receiver(irx).signal(3).V = tmp.receiver(irx).signal.';
                    polyout.receiver(irx).signal(3).t = (0:length(tmp.receiver(irx).signal)-1)/fdata.header.fS + deadtime;     % time [s]
                    if isfield(data,"noise") && nq==1
                        polyout.receiver(irx).noise(3).V = tmp.receiver(irx).noise(:).'; % 50 arises from filter spike test
                        polyout.receiver(irx).noise(3).t = polyout.receiver(irx).signal(3).t;
                    end
                end
            end
        case {3,7}
            if ~fdata.UserData(1).looptask==0; tmp.receiver(1).signal = data.recordC1{iq}.sig4;end
            if ~fdata.UserData(2).looptask==0; tmp.receiver(2).signal = data.recordC2{iq}.sig4;end
            if ~fdata.UserData(3).looptask==0; tmp.receiver(3).signal = data.recordC3{iq}.sig4;end
            if ~fdata.UserData(4).looptask==0; tmp.receiver(4).signal = data.recordC4{iq}.sig4;end
            if fdata.header.nrx == 8
                if ~fdata.UserData(5).looptask==0; tmp.receiver(5).signal = data.recordC5{iq}.sig4;end
                if ~fdata.UserData(6).looptask==0; tmp.receiver(6).signal = data.recordC6{iq}.sig4;end
                if ~fdata.UserData(7).looptask==0; tmp.receiver(7).signal = data.recordC7{iq}.sig4;end
                if ~fdata.UserData(8).looptask==0; tmp.receiver(8).signal = data.recordC8{iq}.sig4;end
            end
            
            % we only have one noise record per stack, so we can transfer it at any one nq
            if isfield(data,"noise") && nq==1
                nrx= fdata.header.nrx;
                for irx=1:nrx
                    if ~fdata.UserData(irx).looptask==0
                        tmp.receiver(irx).noise = data.noise{irx}.sig4;
                        polyout.receiver(irx).std_raw(4) = std(data.noise{irx}.sig4,"omitnan");
                    end
                end
            end

            for irx=1:fdata.header.nrx
                if ~fdata.UserData(irx).looptask==0
                    polyout.receiver(irx).signal(4).V = tmp.receiver(irx).signal.';
                    polyout.receiver(irx).signal(4).t = (0:length(tmp.receiver(irx).signal)-1)/fdata.header.fS + deadtime;     % time [s]
                    if isfield(data,"noise") && nq==1
                        polyout.receiver(irx).noise(4).V = tmp.receiver(irx).noise(:).'; % 50 arises from filter spike test
                        polyout.receiver(irx).noise(4).t = polyout.receiver(irx).signal(4).t;
                    end
                end
            end
    end
end

%% REARRANGE FOR MRSmatlab format -----------------------------------------
fdata.Q(nq).q  = data.q1(iq); 
fdata.Q(nq).q2 = data.q2(iq);
fdata.Q(nq).rec(irec).info.fT = fdata.header.fT;         % transmitter frequency
fdata.Q(nq).rec(irec).info.fS = fdata.header.fS/rate;         % sampling frequency

% save Pulse Shape to reevaluate later
fdata.Q(nq).rec(irec).pulse1 = data.pulseI1{iq};
fdata.header.TXgain = data.TXgain;

% save ramp shape for measurements with prepol 
switch fdata.info.sequence
    case {9,10}
        fdata.Q(nq).rec(irec).rampPP(:) = data.rampPP{iq};
        %fdata.Q(nq).qPx = data.qPx(iq);
end


% save pulse shape and make df vector for AHP 
if fdata.info.sequence==8
    tmp.recordI1                   = mrs_filtfilt(b,a,data.recordI1{iq});
%     fdata.Q(nq).rec(irec).tx.I     = tmp.recordI1(100+rate:rate:end-rate-100).'; % 50 arises from filter spike test
    fdata.Q(nq).rec(irec).tx.I     = tmp.recordI1(rate:rate:end-rate).'; % do not clip pulse record
    fdata.Q(nq).rec(irec).tx.t_pulse = (0:length(fdata.Q(nq).rec(irec).tx.I)-1)/(fdata.header.fS/rate);
    startdf = fdata.info.txinfo.Fmod.startdf; % make df-shape
    enddf   = fdata.info.txinfo.Fmod.enddf; 
    shape   = fdata.info.txinfo.Fmod.shape;
    fdata.Q(nq).rec(irec).tx.df = Funfmod(fdata.Q(nq).rec(irec).tx.t_pulse, startdf, enddf, shape); % save df-shape   
end

% timing parameters
fdata.Q(nq).rec(irec).info.timing.tau_p1    = fdata.header.tau_p;
fdata.Q(nq).rec(irec).info.timing.tau_dead1 = deadtime;
fdata.Q(nq).rec(irec).info.timing.tau_dead_importfilter = deadtime_import;
fdata.Q(nq).rec(irec).info.timing.tau_d     = fdata.header.tau_d;
fdata.Q(nq).rec(irec).info.timing.tau_e     = fdata.header.te;
fdata.Q(nq).rec(irec).info.timing.tau_p2    = fdata.header.tau_p;
fdata.Q(nq).rec(irec).info.timing.tau_dead2 = deadtime;

% generator phase 
fdata.Q(nq).rec(irec).info.phases.phi_gen(1)   = 0; % rad
fdata.Q(nq).rec(irec).info.phases.phi_gen(2)   = data.q1phase(iq); % rad
fdata.Q(nq).rec(irec).info.phases.phi_gen(3)   = 0;
fdata.Q(nq).rec(irec).info.phases.phi_gen(4)   = 0; % rad

switch fdata.info.sequence
    case 4
        fdata.Q(nq).rec(irec).info.phases.phi_gen(3)   = data.q2phase(iq); % rad
    case 7
        fdata.Q(nq).rec(irec).info.phases.phi_gen(4)   = data.q2phase(iq); % rad
        fdata.Q(nq).rec(irec).info.timing.tau_p2       = 2*fdata.header.tau_p;
end

% amplifier phase 
fdata.Q(nq).rec(irec).info.phases.phi_amp = 0; % rad

fdata.Q(nq).rec(irec).info.phases.phi_timing(1:4) = (+200e-6-fdata.header.tau_p-deadtime)*2*pi*fdata.header.fT ; 

irx = 0;
for ipolyrx  = 1:length(polyout.receiver)
    if ~isempty(polyout.receiver(ipolyrx).signal) % if connected
        irx = irx + 1;
        for isig = 1:length(polyout.receiver(ipolyrx).signal)
            if ~isempty(polyout.receiver(ipolyrx).signal(isig).V) % if recorded
                fdata.Q(nq).rec(irec).rx(irx).sig(isig).recorded = 1;
                fdata.Q(nq).rec(irec).rx(irx).sig(isig).t1 = ...
                    polyout.receiver(ipolyrx).signal(isig).t;
                fdata.Q(nq).rec(irec).rx(irx).sig(isig).v1 = ...
                    polyout.receiver(ipolyrx).signal(isig).V - mean(polyout.receiver(ipolyrx).signal(isig).V);
                % backup for undo:
                fdata.Q(nq).rec(irec).rx(irx).sig(isig).t0 = fdata.Q(nq).rec(irec).rx(irx).sig(isig).t1;
                fdata.Q(nq).rec(irec).rx(irx).sig(isig).v0 = fdata.Q(nq).rec(irec).rx(irx).sig(isig).v1;
                % noise
                if isfield(data,"noise") && nq==1
                    fdata.noise.rec(irec).rx(irx).sig(isig).t1 = polyout.receiver(ipolyrx).noise(isig).t;
                    fdata.noise.rec(irec).rx(irx).sig(isig).v1 = polyout.receiver(ipolyrx).noise(isig).V - mean(polyout.receiver(ipolyrx).noise(isig).V);
                    fdata.noise.rec(irec).rx(irx).sig(isig).v0 = fdata.noise.rec(irec).rx(irx).sig(isig).v1;
                    fdata.noise.rec(irec).rx(irx).sig(isig).std_raw = polyout.receiver(irx).std_raw(isig);
                    fdata.noise.rec(irec).rx(irx).sig(isig).std_raw_sqrtn = polyout.receiver(irx).std_raw(isig)/sqrt(size([polyout.receiver(ipolyrx).noise.t],2));
                end
            else
                fdata.Q(nq).rec(irec).rx(irx).sig(isig).recorded = 0;
                fdata.Q(nq).rec(irec).rx(irx).sig(isig).v1 = [];
            end
        end
     end
end
%fdata.info.rxtask = zeros(1,irx); % initialize rx task



