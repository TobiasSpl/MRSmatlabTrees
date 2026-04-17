function [x0,Dx] = MakeZvecNloops(loop,n)

%optional parameter nmin, min number of inner points, used for calculation of total number of points
if nargin<3
    n=400;
end

z_pos = [loop.Px_coilpos,loop.Rx_coilpos,loop.Tx_coilpos];

shift = max([loop.size,loop.Rxsize,loop.PXsize])*2;

a = unique(round(z_pos,3))+shift;
N = length(a);

[a,i] = sort(a);

NLAY_IN=ceil(n/((N+1)*2)); 

%initiate


LMIN_IN=shift/2000;
[SAMP_IN,Dx_IN]=inDisc(a,N,LMIN_IN,NLAY_IN);

%if the two loops are to close together or if there are to many points in
%this region the sinhSample returns weird values with very small or even
%negativ distances dx
%therefore: start over with smaller number of points per segment and than reduce starting distance if dx < LMIN_IN
%{
if ~isempty(Dx_IN) & ~isempty(SAMP_IN)
while min(Dx_IN)<LMIN_IN*0.99999 || any(isnan(SAMP_IN))
    if NLAY_IN > 5
        NLAY_IN = round(NLAY_IN/2);
    else
        LMIN_IN=LMIN_IN/2;
    end
    
    [SAMP_IN,Dx_IN]=inDisc(a,N,LMIN_IN,NLAY_IN);
end
end
%}

NLAY_OUT = (n -length(SAMP_IN)) / 2; %max(NLAY_IN*2,10);
% new sampling point distribution
[SAMP_OUT,~,~,~] = sinhSample(LMIN_IN,shift,NLAY_OUT+1);

SAMP=[-flip(SAMP_OUT)+a(1) SAMP_IN(1:end-1) SAMP_OUT+a(end)];
SAMP = SAMP-shift;


% SAMP_OUT(1) = [];
SAMP_av = (SAMP(2:end)+SAMP(1:end-1))/2;
Dx = (SAMP(2:end)-SAMP(1:end-1))';
x0 = SAMP_av';

plot_Dx=false;
if plot_Dx
    figure(757)
    plot(x0, Dx,"Marker","*");
    hold on
    xline(z_pos)
    hold off
    set(gca, 'YScale', 'log');
    xlabel("z / m")
    ylabel("dz / m")
end


function [SAMP_IN,Dx_IN]=inDisc(a,N,LMIN_IN,NLAY_IN)
SAMP_IN = [];
Dx_IN = [];
for i = 2:N
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
    else
        LMAX_IN = (a(i)-a(i-1))/2;
    end
    
    % sample vector inside and outside of the right loop side
    NLAY_IN_TMP = NLAY_IN;
    LMIN_IN_TMP = LMIN_IN;
    [SAMP_IN_tmp,f2_IN,A,B] = sinhSample(LMIN_IN,LMAX_IN,NLAY_IN);
    repeat= 0;
    while isinf(B) | A<0 | isnan(A)
        repeat = repeat +1;
        if NLAY_IN_TMP > 6
            NLAY_IN_TMP = round(NLAY_IN_TMP/1.2);
            if repeat == 1
                NLAY_IN = round(NLAY_IN*1.2); %move discretization to other inter coil spaces
            end
        else
            LMIN_IN_TMP = LMIN_IN_TMP/2;
        end
        [SAMP_IN_tmp,f2_IN,A,B] = sinhSample(LMIN_IN_TMP,LMAX_IN,NLAY_IN_TMP);
    end
    %extend to first using same discretisatrion but in reverse order
    SAMP_IN_tmp= [SAMP_IN_tmp(1:end) flip(LMAX_IN*2-SAMP_IN_tmp(1:end-1))];
    Dx_IN_tmp = SAMP_IN_tmp(2:end)-SAMP_IN_tmp(1:end-1);
    if i == 1
        SAMP_IN = [SAMP_IN SAMP_IN_tmp];
    else
        SAMP_IN = [SAMP_IN SAMP_IN_tmp(2:end)+a(i-1)];
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
for i = 1:100
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