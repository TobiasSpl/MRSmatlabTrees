function [vHNC,iB] =  mrsSigPro_HNC(t,v,hSource,fT,fS,LPfilter,fastHNC,removeCof,iB)

if nargin < 9
    iB = 0;
end

ignore = 1:200; %ignore first 200 points to avoid fitting of transients

switch hSource % train
    case 1
        fH  = 90; % first nth-harmonic
        nH  = 75; % number of harmonics
        bfs = [16.6:.015:16.8]; % band to look for baseband
    case 2 %powerline 50 Hz
        fH  = 2; % first nth-harmonic
        nH  = 80; % number of harmonics
        bfs = [49.9:.015:50.1]; % band to look for baseband
    case 3 %powerline 60 Hz
        fH  = 20; % first nth-harmonic
        nH  = 40; % number of harmonics
        bfs = [59.9:.015:60.1]; % band to look for baseband
end

if ~fastHNC     % approach after Mueller-Petke et al. 2016 in GEOPHYSICS
    %% determine baseband via brute force search and parameter by matrix inversion  
    %% only one base frequency per run
    if ~iB
        for n=1:2
            e=[];
            fprintf(1,'%.1f',0.0)
            for ibf=1:length(bfs)
                iB     = bfs(ibf);
                f    = fH*iB + iB*[1:nH];
                e(ibf) = norm(v - HNM(t', v', f, fT, ignore).');
                fprintf(1, '\b\b\b');
                fprintf(1,'%.1f',round(10*n/2)/10)
            end
            fprintf(1, '\b\b\b');
            [~,b] = min(e);
            iB    = bfs(b);
            bfs = [iB-0.01:.001:iB+0.01];
        end
        disp(['base frequency estimated: ' num2str(iB)])
    else
        disp(['external base frequency used: ' num2str(iB)])
    end

    switch hSource
        case 6
            f = iB + [-20:1/t(end):20];
            if iB*2 < fT+LPfilter.fW+300
                f = [f iB*2+[-20:1/t(end):20]];
            end
        otherwise
            f    = fH*iB + iB*[1:nH];
    end
    
     
else % approach after Wang 2018 in GJI
    %% get the dictionary first
    global D16 D50 D60 D150 D690
    st = t';
    sr1=v';

    switch hSource
        case 1 % train
            if size(D16,1) ~= length(st)
                D16=[];
            end
            %if isempty(D16)==1   %create ditionary
                for ibf=1:length(bfs)
                    iB     = bfs(ibf);
                    f    = fH*iB + iB*[1:nH];
                    F    = repmat(f,length(st),1); 
                    T    = repmat(st,1,nH);                       
                    A    = [cos(T.*2.*pi.*F) sin(T.*2.*pi.*F)];
                    B    = sum(A,2);
                    B    = B./norm(B);
                    D16(:,ibf) = B;
                end
            %end
            D = D16;
        case 2 %powerline 50 Hz
            if size(D50,1) ~= length(st)
                D50=[];
            end
            %if isempty(D50)==1   %create ditionary
               for ibf=1:length(bfs)
                    iB     = bfs(ibf);
                    f    = fH*iB + iB*[1:nH];
                    F    = repmat(f,length(st),1); 
                    T    = repmat(st,1,nH);                       
                    A    = [cos(T.*2.*pi.*F) sin(T.*2.*pi.*F)];
                    B    = sum(A,2);
                    B    = B./norm(B);
                    D50(:,ibf) = B;
                end
            %end 
            D = D50;
        case 3 %powerline 60 Hz
            if size(D60,1) ~= length(st)
                D60=[];
            end
            %if isempty(D60)==1   %creat ditionary
                for ibf=1:length(bfs)
                    iB     = bfs(ibf);
                    f    = fH*iB + iB*[1:nH];
                    F    = repmat(f,length(st),1); 
                    T    = repmat(st,1,nH);                       
                    A    = [cos(T.*2.*pi.*F) sin(T.*2.*pi.*F)];
                    B    = sum(A,2);
                    B    = B./norm(B);
                    D60(:,ibf) = B;
                end
            %end
            D = D60;
    end
    
    if ~iB
        % search for the basic frequency
        ms = abs(sum(mscohere(sr1,D,hanning(1024),512,1024)));  %calculate coherence
        ms(ms<0.25) = 0;
        C= ms;
        iB = bfs(abs(C)==max(abs(C)));   %iB is the basic frequency
        disp(['B:    base frequency estimated: ' num2str(iB)])
        f    = fH*iB + iB*[1:nH];
    else
        %disp(['external base frequency used: ' num2str(iB)])
        f    = fH*iB + iB*[1:nH];
    end

end

% finally apply and check for cofrequencies
if removeCof
    signal_co = v - HNM(t', v', f, fT, ignore).';
    vHNC = signal_co-CFHNM(t',signal_co,fS,fT,iB,LPfilter);
else
    vHNC = v - HNM(t', v', f, fT, ignore).';
end

%{
figure(923)
hold off
plot(t,mrsSigPro_QD(v,t,fT,fS,1000,LPfilter))
hold on
plot(t,mrsSigPro_QD(vHNC,t,fT,fS,1000,LPfilter))
plot(t,mrsSigPro_QD(HNM(t', v', fH, nH, iB, fT).',t,fT,fS,1000,LPfilter))
legend
%}

function [ms,f,a,p] = HNM(time, signal, f, fT, ignore)
if nargin < 5
    ignore = [];
end
pick = ones(size(time));
pick(ignore) = 0;
pick = logical(pick);
% determine amplitude and phase for each frequeny by inversion
% the problem is overdetermined and linear so we do that directly
f(abs(f-fT)<5)=[]; % check if transmitter frequency is close to harmonic to avoid NMR cancelling
nH   = length(f);
F    = repmat(f,length(time),1);
T    = repmat(time,1,nH);
A    = [cos(T.*2.*pi.*F) sin(T.*2.*pi.*F)];
fit  = A(pick,:)\signal(pick);

a  = sqrt(fit(1:nH).^2 + fit(nH+1:end).^2);
p  = atan(fit(nH+1:end)./fit(1:nH));
ms = A*fit;


function [ms,f,a,p] = HNM_all(time, signal, fH, nH, iB, fT)
fH  = 20; % first nth-harmonic
nH  = 40; % number of harmonics
bfs = [49.9:.015:50.1]; % band to look for baseband
for ibf=1:length(bfs)
    iB     = bfs(ibf);
    f    = fH*iB + iB*[1:nH];
    F    = repmat(f,length(st),1);
    T    = repmat(st,1,nH);
    A    = [cos(T.*2.*pi.*F) sin(T.*2.*pi.*F)];
    B    = sum(A,2);
    B    = B./norm(B);
    D50(:,ibf) = B;
end



function [CFmodel]=CFHNM(time,signal_CO,fs,fL,iB,LPfilter)
%co-frequency harmonic model
nf = round(fL/iB);
fT = iB*nf;
fW = 200;
sigh = mrsSigPro_QD(signal_CO,time.',fT,fs,fW,LPfilter);

ini = [1e-8, 0.5, fL-fT, pi/4,0,0];
lb = [1e-10, 0.01, -50, -pi,-5e-6,-5e-6];
ub = [1e-5,1, 50, pi,5e-6,5e-6];

t = time;
t(isnan(sigh)) =[];
sigh(isnan(sigh)) =[];
sigh = sigh(t<=1);
t = t(t<=1);
[fitpar,~] = fitFID_CoF(t,sigh,lb,ini,ub);
e0_fit = fitpar(1);
t2s_fit = fitpar(2);
f0_fit = fitpar(3);
phi0_fit = fitpar(4);
af = fitpar(5)+1i*fitpar(6);
%realpart = e0_fit*cos(2*pi*f0_fit*t+phi0_fit).*exp(-t/t2s_fit) + fitpar(5);
%imagpart = e0_fit*sin(2*pi*f0_fit*t+phi0_fit).*exp(-t/t2s_fit) + fitpar(6);

%sigf = realpart + 1i*imagpart;
%abs(af)*1e9
CFmodel=abs(af)*cos(2*pi*iB*nf*time+angle(af))';