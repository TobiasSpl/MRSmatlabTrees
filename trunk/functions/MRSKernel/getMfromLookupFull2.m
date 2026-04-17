function [Px,Mp,p] = getMfromLookupFull2(earth,loop,measure,B_comps_Px,ramp,n)

inkl = earth.inkl/360.0*2.0*pi;
decl = earth.decl/360.0*2.0*pi;

% Umrechnung von Kugelkoordinaten in kartesische
B0.x =   cos(inkl) * cos(-decl);
B0.y =   cos(inkl) * sin(-decl);
B0.z = + sin(inkl); % z positiv nach unten!

B0_vec = [B0.x;B0.y;B0.z];

Bpar = B_comps_Px.bpar;
Bper = (B_comps_Px.alpha - B_comps_Px.beta);

Imax = loop.PXcurrent*sum(loop.PXturns);
nq = length(measure.pm_vec);
nrec = size(measure.Ramp(1).Shape,1);

Px_changes = true;
if Px_changes
    for iq = 1:nq
        for irec = 1:nrec
            for i= 1:size(measure.PxLookup.Shape,1)
                diff(i) = sum(abs(measure.Ramp(iq).Shape(irec,1:end)-measure.PxLookup.Shape(i,:)),"all"); 
                %diff(i) = sum(abs(measure.Ramp(iq).Shape(irec,:)/max(measure.Ramp(iq).Shape(irec,:))-measure.PxLookup.Shape(i,:)/max(measure.PxLookup.Shape(i,:))),"all"); 
            end
            index(iq,irec) = find(diff==min(diff),1); %find closest ramp shape
            Imax(iq,irec) = max(measure.Ramp(iq).Shape(irec,:))*sum(loop.PXturns);
            if iq == 1 & irec == 1 & n == 1
                warning("Px current overwriten by data from measurement")
            end
            Px(irec,iq,:,:) = sqrt((Bper*Imax(iq,irec)/earth.erdt).^2 + (Bpar*Imax(iq,irec)/earth.erdt+1).^2);
        end
    end
else
    Px(:,:,:,:) = permute(sqrt((Bper*Imax/earth.erdt).^2 + (Bpar*Imax/earth.erdt+1).^2),[3,4,1,2]);
    index = ones(nq,nrec);
    Imax = index*Imax;
end
%[~,iBparmin] = find(min(B_comps_Px.bpar,[],"all")*max(Imax,[],"all") > measure.PxLookup.Bpar,1,"last");
%[~,iBparmax] = find(max(B_comps_Px.bpar,[],"all")*min(Imax,[],"all") < measure.PxLookup.Bpar,1,"first");
%if iBparmax-iBparmin <4; iBparmin = iBparmin-2; iBparmax = iBparmax+2; end
[~,iBpermin] = find(min((B_comps_Px.alpha - B_comps_Px.beta),[],"all")*min(Imax,[],"all") > measure.PxLookup.Bper,1,"last");
[~,iBpermax] = find(max((B_comps_Px.alpha - B_comps_Px.beta),[],"all")*max(Imax,[],"all") < measure.PxLookup.Bper,1,"first");
if iBpermax-iBpermin <4; iBpermin = iBpermin-2; iBpermax = iBpermax+2; end
%iBpermin = 1; iBpermax = length(measure.PxLookup.Bper);
iBparmin = 1; iBparmax = length(measure.PxLookup.Bpar); %Bpar can be negative, this causes issues with min max



for iq = 1:nq
    for irec = 1:nrec
        %we cut the lookup table to the necessary region to reduce calc times
        for jdim = 1:2  %M dimensions
            M(irec,iq,:,:,jdim) = interp2(measure.PxLookup.Bpar(iBparmin:iBparmax),measure.PxLookup.Bper(iBpermin:iBpermax),squeeze(measure.PxLookup.M(index(iq,irec),(iBpermin:iBpermax),(iBparmin:iBparmax),jdim)),Bpar*Imax(iq,irec),Bper*Imax(iq,irec),"linear",0);
            %M(irec,iq,:,:,jdim) = interp2(measure.PxLookup.Bpar,measure.PxLookup.Bper,squeeze(measure.PxLookup.M(index(iq,irec),:,:,jdim)),Bpar*Imax(iq,irec),Bper*Imax(iq,irec),"linear",0);
        end
        M(irec,iq,:,:,3) = interp2(measure.PxLookup.Bpar(iBparmin:iBparmax),measure.PxLookup.Bper(iBpermin:iBpermax),squeeze(measure.PxLookup.M(index(iq,irec),(iBpermin:iBpermax),(iBparmin:iBparmax),3)),Bpar*Imax(iq,irec),Bper*Imax(iq,irec),"linear",1); %extrapolate to 1 for z
        %M(irec,iq,:,:,3) = interp2(measure.PxLookup.Bpar,measure.PxLookup.Bper,squeeze(measure.PxLookup.M(index(iq,irec),:,:,3)),Bpar*Imax(iq,irec),Bper*Imax(iq,irec),"linear",1); %extrapolate to 1 for z
    end
end

if sum(M == 0,"all") > 10 | sum(M == 1,"all") > 10
    warning("PxLookup Table to small?")
end

Mvec = permute(sum(Px.*M,1)/nrec,[2,3,4,5,1]);
Px = vecnorm(Mvec,2,4);
M = Mvec./Px;

% oriented in Bloch-frame (B0 along z) with Bp towards original xy
Mp.x2 = M(:,:,:,1);
Mp.y2 = M(:,:,:,2);
Mp.z2 = M(:,:,:,3);

%M = permute(pagemtimes(getRotationMatrixFromAngleandAxis(phases,permute(repmat([0;0;1],[1,size(phases)]),[2,3,1])),permute(M,[4,5,2,3,1])),[5,3,4,1,2]); %radial lab System



PXdelay = 0;% 3E-3;% loop.PXdelay - (lookup.odeparam.rampparam.Tramp-ramp.time);
%if PXdelay > 0
    if strcmp(ramp.name,'midi')
        % MIDI "bug" 1 sample offset
        dt_off = -1;
        t_delay = PXdelay + dt_off/50e3;
    else
        t_delay = PXdelay;
    end    
    % final x-y-offset of Mp
    %x = cos(earth.w_rf*t_delay);
    %y = sin(earth.w_rf*t_delay);
    % phase angle alpha
    %alpha = atan2(y,x);
    alpha = -mod(earth.w_rf*t_delay,2*pi); %same as above but less difficult
    % manual phase offset [deg]
    %alpha_off = -45;%125;
    alpha_off = 0;%125;
    alpha = alpha + deg2rad(alpha_off);

    if alpha ~= 0
        R = getRotationMatrixFromAngleandAxis(alpha,[0 0 1]);
        M = permute(M,[4,5,1,2,3]);
        M = pagemtimes(R,M);
        M = permute(M,[3,4,5,1,2]);

    end
%elseif PXdelay < 0
%    error("Ramp delay to short, check if calculated ramp time and input are the same")
%end

% oriented in Bloch-frame (B0 along z) with Bp towards x
Mp.x1 = M(:,:,:,1);
Mp.y1 = M(:,:,:,2);
Mp.z1 = M(:,:,:,3);



%Mp.theta = theta;

switch measure.pulsesign
    case 1 %standart: only adiabatic component of M0, +y pulse
        % within the Bloch simulation, per definition B0 points into direction of
        % zunit [0 0 1]; therefore the effective component of Mp that gets excited
        % after the PP switch-off is the z-component of MpI (parallel to B0)
        % this is the easiest implementation even if not 100% correct
        % see Hiller et al. 2020, GJI
        Px = Px.*M(:,:,3);
    case 2 %+: full M0 vector, -y pulse
        Px = Px;
    case 3 %-: full M0 vector, +y pulse
        Px = Px;
end

% the adiabatic quality p is defined as the projection of the direction of
% Mp onto the direction of B0 (dot(MpI,zunit)/norm(zunit))
% hence p is simply the normalized z-component of MpI
p = M(:,:,:,3);
Mp.p = p;
end