function Bp = getPxRamp(Bmax,t,Tramp,ramp);

Tslope = Tramp/2;
Bstar = Bmax/10;

tramp = t(t>0);
tconst = t(t<=0);

switch ramp
    case 'exp' % exponential
        Bp = Bmax .* exp(-tramp/Tslope);
        Bp = [ones(size(tconst))*Bmax; Bp];
    case 'linexp' % linear + exponential
        Bp = getLinExpAmp(Bmax,Bstar,Tslope,tramp);
        Bp = [ones(size(tconst))*Bmax; Bp];
    case 'halfcos' % half cosine
        Bp = Bmax .* (0.5+(cos(pi*tramp./Tramp)./2));
        Bp = [ones(size(tconst))*Bmax; Bp];
    case 'lin' % linear
        Bp = Bmax.*(1-tramp./Tramp);
        Bp = [ones(size(tconst))*Bmax; Bp];
    otherwise
        error("Ramp shape not defined")
end

function Bp = getLinExpAmp(Bmax,Bstar,T,t)
% linear + exponential ramp after:
% Conradi et al., 2017, Journal of Magnetic Resonance 281, p.241-245
% https://doi.org/10.1016/j.jmr.2017.06.001

if numel(t)>1
    % linear part
    Bplin = (-Bmax/T)*t + Bmax;
    % exponential part
    Bpexp = exp(-t /(Bstar*T/Bmax));
    % find change
    index = find(abs(Bplin-Bstar)==min(abs(Bplin-Bstar)),1,'first');
    % merge the lin- and exp-part and scale the amplitude of the exp-part
    % to that of the lin-part at the switch-over time t(index)
    scale_point = Bplin(index)/Bpexp(index);
    % in case something goes south due to very small numbers set the
    % amplitude to 0
    if isinf(scale_point) || isnan(scale_point)
        scale_point = 0;
    end
    % the final amplitude vector
    Bp = [Bplin(1:index-1); scale_point * Bpexp(index:end)];
else
    % linear part
    Bplin = (-Bmax/T)*t + Bmax;
    % exponential part
    Bpexp = exp(-t /(Bstar*T/Bmax));
    % Bstar time tstar
    tstar = (Bstar-Bmax)/(-Bmax/T);
    % amplitude at tstar for scaling
    Btstar = exp(-tstar /(Bstar*T/Bmax));
    % apply
    if t<tstar
        Bp = Bplin;
    else
        Bp = (Bstar/Btstar) * Bpexp;
    end
end