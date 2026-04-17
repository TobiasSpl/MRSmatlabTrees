function [fdata,proclog] = mrsSigPro_DelHarmonic(fdata,proclog,hSource,removeCof,fastHNC, iQ,irec,irx,isig,iB)

switch fdata.info.sequence
    case 4 %T1 90-90
    if iQ > 0
    mask = [ones(size(fdata.Q(iQ).rec(irec).rx(irx).sig(2).v1))*isig==2 ones(size(fdata.Q(iQ).rec(irec).rx(irx).sig(3).v1))*isig==3];
    t  = [fdata.Q(iQ).rec(irec).rx(irx).sig(2).t1 fdata.Q(iQ).rec(irec).rx(irx).sig(3).t1+fdata.header.tau_d+fdata.header.tau_p+fdata.header.tau_dead]; % [s]
    v  = [fdata.Q(iQ).rec(irec).rx(irx).sig(2).v1 fdata.Q(iQ).rec(irec).rx(irx).sig(3).v1]; % [V]
    fT = fdata.Q(iQ).rec(irec).info.fT;
    else %noise measurement
        mask = [ones(size(fdata.noise.rec(irec).rx(irx).sig(2).v1))*isig==2 ones(size(fdata.noise.rec(irec).rx(irx).sig(3).v1))*isig==3];
        t  = [fdata.noise.rec(irec).rx(irx).sig(2).t1 fdata.noise.rec(irec).rx(irx).sig(3).t1];
        v  = [fdata.noise.rec(irec).rx(irx).sig(2).v1 fdata.noise.rec(irec).rx(irx).sig(3).v1];
        fT = fdata.Q(1).rec(irec).info.fT;
    end
    otherwise
    if iQ > 0
        mask = ones(size(fdata.Q(iQ).rec(irec).rx(irx).sig(isig).v1))*isig==2;
        t  = fdata.Q(iQ).rec(irec).rx(irx).sig(isig).t1; % [s]
        v  = fdata.Q(iQ).rec(irec).rx(irx).sig(isig).v1; % [V]
        fT = fdata.Q(iQ).rec(irec).info.fT;
    else %noise measurement
        mask = ones(size(fdata.noise.rec(irec).rx(irx).sig(isig).v1));
        t  = fdata.noise.rec(irec).rx(irx).sig(isig).t1;
        v  = fdata.noise.rec(irec).rx(irx).sig(isig).v1;
        fT = fdata.Q(1).rec(irec).info.fT;
    end
end

fS = fdata.Q(1).rec(1).info.fS;

%hSource = 6;

if hSource == 6
    u = mrsSigPro_QD(v,t,fT,fS,proclog.LPfilter.fW,proclog.LPfilter);
    u(isnan(u))=0;
    a = mod(length(u),2); % check for even number of samples for fft
    [freq_range,spec] = mrs_sfft(t(1:end-a),u(1:end-a));
    fmin = -1000;imin = find(freq_range>fmin,1,"first");
    fmax = 500;imax = find(freq_range>fmax,1,"first");
    freq_range = freq_range(imin:imax);
    %[~,imax]=max(abs(spec(imin:imax)));
    [~,imax]=max(movsum(abs(spec(imin:imax)),10));
    [vHNC,iB] = mrsSigPro_HNC(t,v,hSource,fT,fS,proclog.LPfilter,fastHNC,removeCof,fT+freq_range(imax));
else
    [vHNC,iB] = mrsSigPro_HNC(t,v,hSource,fT,fS,proclog.LPfilter,fastHNC,removeCof);
end

if iQ > 0
    fdata.Q(iQ).rec(irec).rx(irx).bf=iB;
else
    fdata.noise.rec(irec).rx(irx).bf=iB;
end

%%%transfer to fdata
if iQ > 0
    fdata.Q(iQ).rec(irec).rx(irx).sig(isig).v1 = vHNC(mask);
    switch fdata.info.sequence
            case 4
                if isig == 2; osig=3;
                else; osig=2;
                end
                fdata.Q(iQ).rec(irec).rx(irx).sig(osig).v1 = vHNC(~logical(mask));
    end
else
    fdata.noise.rec(irec).rx(irx).sig(isig).v1 = vHNC(logical(mask));
    switch fdata.info.sequence
        case 4
            if isig == 2; osig=3;
            else; osig=2;
            end
            fdata.noise.rec(irec).rx(irx).sig(osig).v1 = vHNC(~logical(mask));
    end
end

% create log entry
proclog.event(end+1,:) = [2 iQ irec irx isig hSource iB 0];

