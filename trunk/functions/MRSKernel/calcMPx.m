function [Px,Mp,p] = calcMPx(earth,loop,measure,B_comps_Px,ramp,n)

inkl = earth.inkl/360.0*2.0*pi;
decl = earth.decl/360.0*2.0*pi;

% Umrechnung von Kugelkoordinaten in kartesische
B0.x = cos(inkl) * cos(-decl);
B0.y = cos(inkl) * sin(-decl);
B0.z = + sin(inkl); % z positiv nach unten!


%Shape(1,:) = downsample(measure.Ramp(1).Shape(1,:),5);
%t = downsample(measure.Ramp(1).t,5);
%warning("Downsampled ramp")

if isfield(measure,"Ramp")
    Shape = measure.Ramp(1).Shape;
    t = measure.Ramp(1).t;
else
    t = linspace(0:1E-5,loop.PXramptime+loop.PXdelay)';
    Shape = getPxRamp(1,t,loop.PXramptime,loop.PXramp)';
end

nrec = size(Shape,1);

for iRamp = 1:nrec
    %prepare BLOCHUS
    pyBLOCHUSinput.B0=B0;
    pyBLOCHUSinput.iq=iRamp-1; %-1 because of python
    pyBLOCHUSinput.Imax=1;
    pyBLOCHUSinput.earth=earth;
    pyBLOCHUSinput.TxSign = 1;
    phase = 0;
    figure(457); 
    hold on;
    plot(t,Shape(iRamp,:),"LineWidth",1.5,"Color","black"); xlabel("{\itt} / ms");ylabel("{\itI}_{eff} / A");
    hold off;
    %measure.Pulse(iRamp).Shape = (Shape - mean(Shape(end-20:end)))/max(Shape - mean(Shape(end-20:end))); %zero with average at end
    %measure.Pulse(iRamp).Shape = ((Shape)/(max(Shape))-3.2E-4)*1/(1-3.2E-4);
    measure.Pulse(iRamp).Shape = Shape(iRamp,:)/(max(Shape(iRamp,:)));
    measure.Pulse(iRamp).t = t;

    pyBLOCHUSinput.phase = 0;
    measure.parallelM0 = true;
    if isfield(measure,"TxLookup")
        measure = rmfield(measure,"TxLookup");
    end
    if isfield(measure,"PxLookup")
        measure = rmfield(measure,"PxLookup");
    end
    pyBLOCHUSinput.measure=measure;

    Threshold4Blochus=0;
    path2py = which('MRS_python_BLOCHUS7.py'); %<- version using full Pulseshape
    
    Imax = loop.PXcurrent*sum(loop.PXturns);
    Bpar = B_comps_Px.bpar*Imax;
    Bper = (B_comps_Px.alpha - B_comps_Px.beta)*Imax;
    if isequal(size(Bpar),size(Bper))
        B1.x = (Bper'*sin(inkl) * cos(-decl)+Bpar'*cos(inkl))'* cos(-decl);
        B1.y = (Bper'*sin(inkl) * sin(-decl)+Bpar'*cos(inkl))'* sin(-decl);
        B1.z = (Bpar'*sin(inkl) + Bper'*cos(inkl) *-1 * cos(-decl))';
        B1.phi = zeros (size(Bper,1));
        B1.r = zeros (size(Bper,2))';
    else
        B1.x = repmat(Bper'*sin(inkl) * cos(-decl),[size(Bpar)])+repmat(Bpar'*cos(inkl),[size(Bper)])'* cos(-decl);
        B1.y = repmat(Bper'*sin(inkl) * sin(-decl),[size(Bpar)])+repmat(Bpar'*cos(inkl),[size(Bper)])'* sin(-decl);
        B1.z = repmat(Bpar'*sin(inkl),[size(Bper)])' + repmat(Bper'*cos(inkl) *-1 * cos(-decl),[size(Bpar)]);
        B1.phi = zeros(size(Bper));
        B1.r = zeros(size(Bpar))';
    end

    pyBLOCHUSinput.B1 = B1; % currently not working with complex B1 because JSON does not want imagninary parts
    pyBLOCHUSinput.pick=ones(size(B1.x));

    ratio = sqrt(B1.x.^2+B1.y.^2+B1.z.^2)/earth.erdt;
    pick4Blochus = max(ratio>Threshold4Blochus,[],1);
    M0 = [0,0,0];
    pyBLOCHUSinput.M0 = M0;
    if sum(pick4Blochus,'all') >0
        %pyBLOCHUSinput.pick=repmat(pick4Blochus',[size(Bpar)])';
        encodedJSON=jsonencode(pyBLOCHUSinput);
        JSONFILE_name= sprintf('BLOCHUS_input.json');
        file=fopen(fullfile(fileparts(path2py), JSONFILE_name),'w');
        fprintf(file, encodedJSON);
        fclose(file);
        cmdcommand = strcat("powershell python ","'", path2py,"'");
        [status,BLOCHUS_out] = system(cmdcommand, '-echo');

        %read the output
        JSONFILE_name= sprintf('BLOCHUS_output.json');
        file=fopen(fullfile(fileparts(path2py), JSONFILE_name),'r');
        str=char(fread(file,inf)');
        fclose(file);
        results = jsondecode(str);
        %results = jsondecode(BLOCHUS_out);
        if isfield(results,'MM')
            MM3D = results.MM;
        end
        if isfield(results,'t')
            TT = results.t;
        end
    else
        results.M = 0;
    end
    
    %stitch together
    M(iRamp,:,:,:) = results.M;
    Px(iRamp,:,:) = sqrt((Bper/earth.erdt).^2 + (Bpar/earth.erdt+1).^2);
end

Mvec = permute(sum(Px.*M,1)/nrec,[2,3,4,5,1]);
Px = vecnorm(Mvec,2,3);
M = Mvec./Px;

% oriented in Bloch-frame (B0 along z) with Bp towards original xy
Mp.x2 = repmat(permute(M(:,:,1),[4,1,2,3]),size(measure.pm_vec'));
Mp.y2 = repmat(permute(M(:,:,2),[4,1,2,3]),size(measure.pm_vec'));
Mp.z2 = repmat(permute(M(:,:,3),[4,1,2,3]),size(measure.pm_vec'));

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

% oriented in Bloch-frame (B0 along z) with Bp towards x
Mp.x1 = repmat(permute(M(:,:,1),[4,1,2,3]),size(measure.pm_vec'));
Mp.y1 = repmat(permute(M(:,:,2),[4,1,2,3]),size(measure.pm_vec'));
Mp.z1 = repmat(permute(M(:,:,3),[4,1,2,3]),size(measure.pm_vec'));



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
p = M(:,:,3);
Mp.p = p;
end

