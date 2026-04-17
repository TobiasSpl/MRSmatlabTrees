function [x0,Dx] = MakeXvecNloops(a,n)

%optional parameter nmin, min number of inner points, used for calculation of total number of points
if nargin<2
    n=100;
    %n=200;
end

a = unique(round(a,3));
a = min(a); %smallest coil diameter = tree diameter
N = length(a);
%{
if length(a) > 1
    warning("coils should be same size")
end
%}
NLAY_IN=n/N; 

%initiate


LMIN_IN=a(1)/1000;
[SAMP_IN,Dx_IN]=inDisc(a,N,LMIN_IN,NLAY_IN);

%if the two loops are to close together or if there are to many points in
%this region the sinhSample returns weird values with very small or even
%negativ distances dx
%therefore: start over with smaller starting distance if dx < LMIN_IN
if ~isempty(Dx_IN) & ~isempty(SAMP_IN)
while min(Dx_IN)<LMIN_IN*0.99999 || any(isnan(SAMP_IN))
    LMIN_IN=LMIN_IN/2;
    [SAMP_IN,Dx_IN]=inDisc(a,N,LMIN_IN,NLAY_IN);
end
end

SAMP=SAMP_IN;


% SAMP_OUT(1) = [];
SAMP_av = (SAMP(2:end)+SAMP(1:end-1))/2;
Dx = (SAMP(2:end)-SAMP(1:end-1))';
x0 = SAMP_av';

plot_Dx=false;
if plot_Dx
    figure(756)
    plot(x0, Dx,"Marker","*");
    hold on
    xline(a/2)
    hold off
    set(gca, 'YScale', 'log');
    xlabel("r / m")
    ylabel("dr / m")
end


function [SAMP_IN,Dx_IN]=inDisc(a,N,LMIN_IN,NLAY_IN)
SAMP_IN = [];
Dx_IN = [];
for i = 1:N
    %=============================================================
    % Discritization using sinh function
    % Input:
    %  a	       square loop side
    %  LMIN_IN     first sample close to wire
    %  NLAY_IN     number of samples inside the loop (between wire and center)
    %  LMAX_OUT    maximum discretization limit outside the loop
    %  Output:
    %  x_vec       vector of discrete points from loop center to outside limit.
    %=============================================================
    if i == 1
        LMAX_IN = a(i)/2; % the last point inside the loop (between loop and center)
        % sample vector inside and outside of the right loop side
        [SAMP_IN_tmp,f2_IN,A,B] = sinhSample(LMIN_IN,LMAX_IN,NLAY_IN);
    else
        LMAX_IN = (a(i)-a(i-1))/4;
        % sample vector inside and outside of the right loop side
        [SAMP_IN_tmp,f2_IN,A,B] = sinhSample(LMIN_IN,LMAX_IN,round(NLAY_IN/2));
    end

    SAMP_IN_tmp = SAMP_IN_tmp(SAMP_IN_tmp < LMAX_IN);
    %extend to first using same discretisatrion but in reverse order
    if i == 1
        SAMP_IN_tmp= [flip(LMAX_IN-SAMP_IN_tmp(1:end))];
    else
        SAMP_IN_tmp= [SAMP_IN_tmp(1:end) flip(LMAX_IN*2-SAMP_IN_tmp(1:end-1))];
    end
    Dx_IN_tmp = SAMP_IN_tmp(2:end)-SAMP_IN_tmp(1:end-1);
    if i == 1
        SAMP_IN = [SAMP_IN SAMP_IN_tmp];
    else
        SAMP_IN = [SAMP_IN SAMP_IN_tmp(2:end)+a(i-1)/2];
    end
    Dx_IN = [Dx_IN Dx_IN_tmp];
end


% f2_x = [fliplr(f2IN_R) f2OUT_R]';

% figure(500);cla;
% plot(x0,ones(size(x0)),'o');

function [SAMP,f2,A,B] = sinhSample(LMIN,LMAX,NLAY)
%=================================================================
%  Discretization using sinh function
%  Input:
%  ======
%  LMIN		the first sample line
%  LMAX 	the last sample line
%  NLAY		Number of sampling
%  Output:
%  =======
%  SAMP 	Sampling vector
%  f2       Vector of ABcosh(Bi) values
%  A,B      Coefficients
%=================================================================
N1 = NLAY-1; % n=NLAY-1
N2 = NLAY-2;
L0 = LMAX/LMIN;
FAC = L0^(1/N2); % initial asymptotic factor f
F2 = 1/(FAC*FAC); % f^-2
% compute asymptotic value f to determine A and B
for i = 1:10
    LL = L0*(1-F2)/(1-F2^N1); % LL = y = f^(n-1)
    FAC = LL^(1/N2); % f
    F2 = 1/(FAC*FAC);
end

% define A and B
SAMP = zeros(1,NLAY); % check shavad
f2 = zeros(1,NLAY);

B = log(FAC);
A = LMIN/sinh(B);

for in = 1:NLAY
    SAMP(1,in) = A*sinh(B*(in-1));
    f2(1,in) = A*B*cosh(B*(in-1));
end