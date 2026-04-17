function [x0,Dx,x1] = MakeXvec(a,z,dz,rmax,n)

%-> Tobias optionaler Parameter nmin, Anzahl der Mindestpunkte im Inneren,
%alle anderen Punktzahlen werden daraus berechnet
if nargin<5
    n=60;
end

%Tobias static
static=true;

if static
    LMIN_IN=a/2000;
else
    LMIN_IN  = min(dz/10,a/100);
end
LMAX_OUT = max(a*3,rmax);

if static
    NLAY_IN=ceil(n/4);
else
    if z > a
        NLAY_IN = ceil(n/8);
    elseif z > a/5
        NLAY_IN = ceil(n/6);
    else
        NLAY_IN = ceil(n/4);
    end
end


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
LMAX_IN = a/4; % the last point inside the loop (at center)

% sample vector inside and outside of the right loop side
[SAMP_IN,f2_IN,A,B] = sinhSample(LMIN_IN,LMAX_IN,NLAY_IN);
%extend to first using same discretisatrion but in reverse order
SAMP_IN= [SAMP_IN flip(a/2-SAMP_IN(1:end-1))];
Dx_IN = SAMP_IN(2:end)-SAMP_IN(1:end-1);
%if the two loops are to close together or if there are to many points in
%this region the sinhSample returns weird values with very small or even
%negativ distances dx
%therefore: repeat with smaller starting distance if dx < LMIN_IN2
while min(Dx_IN)<LMIN_IN*0.99999 || any(isnan(SAMP_IN))
    LMIN_IN=LMIN_IN/2;
    assert(LMIN_IN>0,'this should never happen')
    [SAMP_IN,f_IN,A,B] = sinhSample(LMIN_IN,LMAX_IN,NLAY_IN+1);
    %extend to second loop using same discretisatrion but in reverse order
    SAMP_IN= [SAMP_IN flip(a/2-SAMP_IN(1:end-1))];
    Dx_IN = SAMP_IN(2:end)-SAMP_IN(1:end-1);
end

NLAY_OUT = NLAY_IN*2+2;

% choose increase method
% 'lin' | 'exp'
increase_type = 'lin';
if static
    increase_type = 'none';
end
% minimum outer radius
min_val = LMAX_OUT;
% maximum outer radius
max_val = LMAX_OUT*5;
% maximum depth
max_z = LMAX_OUT/2;
switch increase_type
    case 'lin'
        % linearly increasing outer radius
        tmpR = (max_val-min_val)/max_z .* z + min_val;
    case 'exp'
        % exponentially increasing outer radius
        tmpR = min_val.*exp(z./(max_z./2));
    case 'none'
        tmpR = (min_val+max_val)/2;
end
% new sampling point distribution
[SAMP_OUT,~,~,~] = sinhSample(LMIN_IN,tmpR,NLAY_OUT+1);

SAMP=[SAMP_IN(1:end-1) SAMP_OUT+a/2];


% SAMP_OUT(1) = [];
SAMP_av = (SAMP(2:end)+SAMP(1:end-1))/2;
Dx = (SAMP(2:end)-SAMP(1:end-1))';
x0 = SAMP_av';
x1 = SAMP';

plot_Dx=false;
if plot_Dx
    figure(394)
    plot(SAMP_av, Dx);
    set(gca, 'YScale', 'log');
    xlim([0 a*2]);
end
end

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
end