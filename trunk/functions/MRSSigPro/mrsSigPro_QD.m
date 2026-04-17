function [V,t] = mrsSigPro_QD(v,t,fT,fS,fW,LPfilter)
% 
% Quadrature detection of NMR signal. The real-valued input signal,
%   v = v0*cos(wL+phi),
% is converted into its complex-valued  quadrature signal, 
%   V = v0*( cos[(wL-wT)*t + phi] - 1i*sin[(wL-wT)*t + phi] ).
% 
% Input:
%   v  - voltage (real) = v0*cos(wL+phi)
%   t  - time
%   fT - transmitter reference frequency
%   fS - sampling
%   fW - filterwidth
% 
% Output:
%   V - voltage (complex) = v0*( cos[(wL-wT)*t + phi] - 1i*sin[(wL-wT)*t + phi] )
% 
% Jan Walbrecker, 27oct2010
% MMP 08 Apr 2011
% JW  19 aug 2011
% =========================================================================

% create filter here, needed if old allready processed data is loaded (LPfilter is a struct and not a Filter in old version)
if isstruct(LPfilter)
    %if isfield(LPfilter,"fW")
        FilterType = 'equiripple';
        %FilterType = 'butter';
        switch FilterType
            case 'butter_old'
                if ~exist('buttord') % get coefficients from file
                    % Since we use mrs_makefilter for either loading or calculating the coefficients there is no
                    % need to check here again.
                    [dummy,ipass]   = find(LPfilter.passFreq <= fW,1,'last');
                    [dummy,istop]   = find(LPfilter.stopFreq <= 3*fW,1,'last'); %<-- this might be checked if this is a good default, I think so.
                    [dummy,isample] = find(LPfilter.sampleFreq <= fS,1,'last');
                    a = LPfilter.coeff.passFreq(ipass).stopFreq(istop).sampleFreq(isample).a;
                    b = LPfilter.coeff.passFreq(ipass).stopFreq(istop).sampleFreq(isample).b;
                else
                    % filter definition
                    Apass       = 1;     % Passband Ripple (dB)
                    Astop       = 50;    % Stopband Attenuation (dB)
                    Fpass       = [fW];   % Passband Frequency
                    Fstop       = [3*fW];  % Stopband Frequency
                    % Calculate the order from the parameters using BUTTORD.
                    [N,Fc] = buttord(Fpass/(fS/2), Fstop/(fS/2), Apass, Astop);
                    % using standard filter that allows for filtfilt
                    [b,a]       = butter(N, Fc);
                end
            case 'butter'
                Astop = 50;
                Fpass = fW;
                Fstop = 3*fW;
                LPfilter = designfilt('lowpassiir', 'PassbandFrequency',Fpass,'StopbandFrequency',Fstop,'SampleRate',fS,'StopbandAttenuation',Astop);
            case 'equiripple'
                Astop = 50;%fW/5; %I get an initial transient if the stopband attenuation is not low enough, depends somehow on filterwidth. equiripple needs higher stopband attenuation? roughly 1/5 of filter width? 
                Fpass = fW;
                Fstop = 3*fW;
                LPfilter = designfilt('lowpassfir', 'PassbandFrequency',Fpass,'StopbandFrequency',Fstop,'SampleRate',fS,'StopbandAttenuation',Astop);
                %used for MRS_filtfilt
                %a = 1; %all-zero (FIR) filter
                %b = filt.Coefficients;
        end
    %end
end

if LPfilter ~= -1
    % Synchronous detection via hilbert, low-pass and filtfilt
    v(isnan(v)) = 0; %overwrite NaNs
    hv          = mrs_hilbert(v);
    ehv         = hv.*exp(-1i*2*pi*fT.*t);
    V           = filtfilt(LPfilter,ehv);
    %V = ehv;
    
    % eliminate spikes that can be modeled as a spike response
    if 0
        xspike  = zeros(1000,1); xspike(500)=1;
        fx      = filtfilt(LPfilter,xspike);
        [ix,ipR] = max(abs(xcorr(real(V),fx)));
        [ix,ipI] = max(abs(xcorr(imag(V),fx)));
        
        xspikeR  = zeros(size(ehv)); xspikeR(ipR+500-length(t)) = 1;
        fxR      = filtfilt(LPfilter,xspikeR);
        vxR      = fxR.'\real(V).';
        vxI      = fxR.'\imag(V).';
        
        xsR = zeros(size(ehv)); xsR(ipR+500-length(t)) = vxR;
        xsI = zeros(size(ehv)); xsI(ipI+500-length(t)) = vxI;
        
        fxR = filtfilt(LPfilter,xsR);
        fxI = filtfilt(LPfilter,xsI);
        
        V = complex(real(V)-fxR, imag(V)-fxI);
    end

    % Check for transients at the beginning and end of time series due to
    % filter artefact --> use spike test to determine 
    % I would set to zero here for display purposes 
    % and delete afterwards when save the stacked data
    xspike = zeros(size(ehv)); xspike(1)=1i;
    fx     = filtfilt(LPfilter,xspike);
    index  = find(abs(fx) > 0.01, 1 ,"last");
    V(1:index) = nan;
    V(end-index:end)=nan;
    %V=V*exp(1i*pi*0.2);
    
    %{
    resample = floor(fS / (fW*3)); % stopFreq: fW*3
    V = V(resample:resample:end-resample);
    t = t(resample:resample:end-resample);
    %}
else    % data are already quadrature (NUMISpoly)
    V = v;
end
         

%% testing hilbert and filtfilt phase preservation
% figure
% T    = 0.00;
% dt   = 1/50000;
% t    = [0:dt:.1];
% f    = 2000;
% 
% y = 1.*cos(2*pi*f*t - 0*pi/2).*exp(-t/0.2);
% y = y + 0.05*randn(size(y));
% 
% Fs          = 1/diff(t(1:2));
% Fpass       = [500];   % Passband Frequency
% Fstop       = [1500];  % Stopband Frequency
% Apass       = 1;     % Passband Ripple (dB)
% Astop       = 50;    % Stopband Attenuation (dB)
% [N,Fc]      = buttord(Fpass/(Fs/2), Fstop/(Fs/2), Apass, Astop);
% [b,a]       = butter(N, Fc);
% 
% hy          = hilbert(y);
% ehy         = hy.*exp(-1i*2*pi*f.*t);
% fy          = filtfilt(b,a,ehy);
% 
% plot(t,real(fy),'b')
% hold on
% plot(t,imag(fy),'r')
% hold off
% title(num2str(mean(angle(fy))))