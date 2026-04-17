function [q,phase,q_old] = HilbertEnvelope(pulse,time,fT,fS,taup,gain,zero)
if nargin < 8
    zero = 0;
end

ref = exp(-1i*2*pi*fT.*time);
filter = true;
if filter
    load('coefficient.mat')
    %F1 low Pass
    Fpass       = [fT*2];   % Passband Frequency
    Fstop       = [fT*5];  % Stopband Frequency
    Apass       = 1;     % Passband Ripple (dB)
    Astop       = 50;    % Stopband Attenuation (dB)
    [dummy,ipass]   = find(passFreq <= Fpass,1,'last');
    [dummy,istop]   = find(stopFreq <= Fstop,1,'last');
    [dummy,isample] = find(sampleFreq <= fS,1,'last');
    a = coeff.passFreq(ipass).stopFreq(istop).sampleFreq(isample).a;
    b = coeff.passFreq(ipass).stopFreq(istop).sampleFreq(isample).b;
    q_old = 1/gain*sum(abs(mrs_hilbert(pulse).*ref.'))/fS;
    q = 1/gain * sum(abs(mrs_hilbert( mrs_filtfilt(b,a,pulse-zero) ).*ref.'))/fS;
    signal = mrs_hilbert( mrs_filtfilt(b,a,pulse-zero) ).*ref.'; %signal for phase estimation
else
    q = 1/gain * sum(abs(mrs_hilbert(pulse).*ref.'))/fS;
    signal = mrs_hilbert( pulse ).*ref.';
end
start_at = 0.5/fT;
stop_at = floor(taup*fT)/fT*0.95;
signal_cut = signal(time>start_at & time<stop_at); %use mean without first period and without everything that comes after the full oscillations
%phase = angle(signal_mean)
%unwrap should decrease std of phase. For very noisy pulses unwrap causes phases over multiple 2*pi intervals, therefore we need to change the unwrap tolerance
tol=1.5*pi:0.01*pi:2*pi;
for itol=1:length(tol)
    phase_std(itol) = std(unwrap(angle(signal_cut),tol(itol)));
end
[~,itol] = min(phase_std);

phase = - pi/2 - mean(unwrap(angle(signal_cut),tol(itol))); %-pi/2 is needed to use the phase in the kernel calc
if phase < -pi
    phase = phase + 2*pi;
end
if phase > pi
    phase = phase - 2*pi;
end

end