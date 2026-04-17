% caller for forward calculation of the surface NMR signal for
% arbitrary loop configurations
% B1-field calculation -> ellp. decomposition -> kernel integration
%
% [K, model] = MakeKernel(loop, model, measure, earth)
% INPUT
% structures loop, model measure earth from MRSKernel GUI or script
%
% OUTPUT
% K: kernel function as a function of z and pm_vec
% J: Jacobian for T1 Inversion
% postCalcB1: b-fields
%
% preCalcB1
function [K, J, model, postCalcB1,K3D] = MakeKernel(loop, model, measure, earth, gui_flag, preCalcB1)

if nargin < 5
    gui_flag=true;
    calcB1 = 1;
elseif nargin <6
    calcB1 = 1;
else
    calcB1 = 0;
    postCalcB1 = 0;
end


% default extra parameters used when running the MRSkernel GUI
makeK3Dzphir = measure.K3Dzphir; %generate z, phi and r Kernel
makeK3Dslices = measure.K3Dslices; %generate S-N and E-W slices through kernel

% the direction of the different B-fields
TXSign = 1;
RXSign = 1;
PXSign = loop.PXsign;

if ~isfield(loop,'PXdelay')
    loop.PXdelay=0;
end

measure.makeK3D = makeK3Dzphir || makeK3Dslices;


if ~measure.PX
% remove any entry from the Px loop arrays
    loop.PXsize = [];
    loop.PXturns = [];
end

%% timer figure
if gui_flag
    screensz = get(0,'ScreenSize');
    % check if there is already a info figure window open
    isfig = findobj('Type','Figure','Name','Info');
    if isempty(isfig)
        tmpgui.panel_controls.figureid = figure( ...
            'Position', [5 screensz(4)-150 350 100], ...
            'Name', 'Info', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Toolbar', 'none', ...
            'HandleVisibility', 'on');
        tmpgui.panel_controls.edit_status = uicontrol(...
            'Position', [0 0 350 75], ...
            'Style', 'text', ...
            'Parent', tmpgui.panel_controls.figureid, ...
            'Enable', 'on', ...
            'BackgroundColor', [0.94 0.94 0.94], ...
            'String', 'Idle...');
    else
        % reset info box;
        tmpgui.panel_controls.figureid = isfig;
        tmpgui.panel_controls.edit_status = get(isfig,'Children');
        set(tmpgui.panel_controls.edit_status,'String', 'Idle...');
    end
end

loop.Tx_sign = ones(loop.Tx_nz,1);
loop.Rx_sign = ones(loop.Rx_nz,1);
loop.Px_sign = ones(loop.Px_nz,1);

%% init stuff

nz = loop.Px_nz;
hz = loop.Px_zext;

if nz > 1
    loop.Px_coilpos = [];
    for i = 0:nz-1
        loop.Px_coilpos = [loop.Px_coilpos loop.Px_zoff-hz/2+i*hz/(nz-1)];
    end
else
    loop.Px_coilpos = loop.Px_zoff;
end

nz = loop.Tx_nz;
hz = loop.Tx_zext;

if nz > 1
    loop.Tx_coilpos = [];
    for i = 0:nz-1
        loop.Tx_coilpos = [loop.Tx_coilpos loop.Tx_zoff-hz/2+i*hz/(nz-1)];
    end
else
    loop.Tx_coilpos = loop.Tx_zoff;
end


nz = loop.Rx_nz;
hz = loop.Rx_zext;

if nz > 1
    loop.Rx_coilpos = [];
    for i = 0:nz-1
        loop.Rx_coilpos = [loop.Rx_coilpos loop.Rx_zoff-hz/2+i*hz/(nz-1)];
    end
else
    loop.Rx_coilpos = loop.Rx_zoff;
end

% z Discretization
[modelz,modelDz] = MakeZvecNloops(loop);
model.z = modelz;
model.Dz = modelDz;
model.nz = length(modelz); 


K = zeros(length(measure.pm_vec)*length(measure.taud), model.nz);
J = zeros(length(measure.pm_vec)*length(measure.taud), model.nz);


% local variables
loopshape = loop.shape;
loopsize = loop.size;
earthf = earth.f;
earthsm = earth.sm;
earthzm = earth.zm;
earthres = earth.res;

%%
% run loop over all layers
if gui_flag
    set(tmpgui.panel_controls.edit_status,'String',...
        ['start calculating ' num2str(model.nz) ' layers']);
    drawnow;
end

%model.dphi = 2*pi/45;
model.dphi = 2*pi/180;
%model.dphi = 2*pi/360; 
model.phi=[0:model.dphi:2*pi - model.dphi]';
K3D=struct();

t_total = tic;
for n = 1:model.nz
    t_z = tic;
    
    if calcB1 % calculate new B1 field and save as postCalcB1
        %% B-fields        
        switch loopshape
            case {1} % separated tx/rx in inloop (centered) setup --> fast calculation possible
                sizes = [min(loop.size), min(loop.Rxsize), min(loop.PXsize), loop.Treesize];
                [r, Dr] = MakeXvecNloops(sizes);
                model.r = r;
                model.Dr = Dr;
                
                [B1,dh] = make_Bcloop(modelz(n),loop.size,loop.turns,loop.Tx_zoff,loop.Tx_zext,loop.Tx_nz,loop.Tx_sign,earth,model);
                [B2,~] = make_Bcloop(modelz(n),loop.Rxsize,loop.Rxturns,loop.Rx_zoff,loop.Rx_zext,loop.Rx_nz,loop.Rx_sign,earth,model);
                if measure.PX
                    [Bpre,~] = make_Bcloop(modelz(n),loop.PXsize,loop.PXturns/sum(loop.PXturns),loop.Px_zoff,loop.Px_zext,loop.Px_nz,loop.Px_sign,earth,model); %Px turns go into PP factor
                    Bpre = applyBfieldSign(Bpre,PXSign);
                end
                switch measure.pulsesign
                    case 1% only uses adiabatic component so TX direction does not matter
                        TXSign = 1;
                        RXSign = 1;
                    case 2
                        TXSign = -1;
                        RXSign = 1;
                    case 3
                        TXSign = 1;
                        RXSign = -1;
                end

                B1 = applyBfieldSign(B1,TXSign);
                B2 = applyBfieldSign(B2,RXSign);
        end
        if n==1
            model.r=r; %carefull: r changes with z if static is not used
            model.Dr=Dr;
            %preallocate K3
            if makeK3Dzphir || makeK3Dslices
                K3=zeros(length(measure.pm_vec),length(model.phi),length(model.r),model.nz);
            end
        end
        
        %% elliptic decomposition
        switch loopshape
            case {1}
                % first check if Px is used
                if measure.PX
                    % now check pulsetype
                    switch measure.pulsetype
                        case 3 % imperfect PP-ramp switch-off as Tx
                            % Tx struct is "used" for Px data
                            B_comps_Tx = 0;
                            [B_comps_Px, B0] = EllipDecompInLoop(earth,Bpre);
                        otherwise
                            % "normal" Tx and Px
                            [B_comps_Tx, B0] = EllipDecompInLoop(earth,B1);
                            [B_comps_Px, ~] = EllipDecompInLoop(earth,Bpre);
                    end
                else % no PX-loop
                    % "normal" Tx
                    [B_comps_Tx, B0] = EllipDecompInLoop(earth,B1);
                    % no Px
                    B_comps_Px = 0;
                end
                % "normal" Rx
                [B_comps_Rx, ~] = EllipDecompInLoop(earth, B2);
        end
        
        %% pre-polarization
        if measure.PX
            % calculate enhanced magnetization Mp
            % either with a Px switch-off ramp
            if loop.usePXramp
                rampopts.name = loop.PXramp;
                rampopts.time = loop.PXramptime;
                if isfield(measure,"PxLookup")
                    [Pxfactor,measure.Mp,~] = getMfromLookupFull2(earth,loop,measure,B_comps_Px,rampopts,n);
                else
                    [Pxfactor,measure.Mp,~] = calcMPx(earth,loop,measure,B_comps_Px,rampopts,n);
                end
                measure.Pxfactor = Pxfactor;
            else
                % or as ideal Px factor
                pre = loop.PXcurrent*sum(loop.PXturns);
                Pxfactor = abs(sqrt((earth.erdt*B0.x + pre*Bpre.x).^2 + ...
                    (earth.erdt*B0.y + pre*Bpre.y).^2 + ...
                    (earth.erdt*B0.z + pre*Bpre.z).^2)./earth.erdt);
                
                %xyz1 and xyz2 are both in Bloch-frame -> ideal PP only z direction
                measure.Mp.x1(n,:,:) = 0 * Pxfactor;
                measure.Mp.y1(n,:,:) = 0 * Pxfactor;
                measure.Mp.z1(n,:,:) = 1 * Pxfactor;
    
                measure.Mp.x2(n,:,:) = 0 * Pxfactor;
                measure.Mp.y2(n,:,:) = 0 * Pxfactor;
                measure.Mp.z2(n,:,:) = 1 * Pxfactor;
                measure.Pxfactor = Pxfactor;
            end
            postCalcB1(n).Pxfactor = Pxfactor;
        else
            % if Px is switched-off, the Px factor is simply 1
            Pxfactor = ones(size(B0.x));
            postCalcB1(n).Pxfactor = Pxfactor;
            %xyz1 and xyz2 are both in Bloch-frame -> without PP only z direction
            measure.Mp.x1(n,:,:) = 0 * Pxfactor;
            measure.Mp.y1(n,:,:) = 0 * Pxfactor;
            measure.Mp.z1(n,:,:) = 1 * Pxfactor;

            measure.Mp.x2(n,:,:) = 0 * Pxfactor;
            measure.Mp.y2(n,:,:) = 0 * Pxfactor;
            measure.Mp.z2(n,:,:) = 1 * Pxfactor;
        end

    else % use pre-calculated B-fields preCalcB1
        switch loopshape
            case {1} % inloop
                msgbox('no yet implemented')
        end
        %% pre-polarization
        Pxfactor = preCalcB1(n).Pxfactor;
    end
    % if T1 for double pulse kernel is given
    if  measure.pulsesequence == 2
        if isfield(earth,'T1')
            earth.T1cl = earth.T1(n);
        else
            earth.T1cl = 0.1;
        end
    end

    %% get the kernel
    switch loopshape
        case {1}
            %%
            if makeK3Dzphir || makeK3Dslices % separate Kernels || NS EW slices
                K3(:,:,:,n)=IntegrateK1DInLoop(measure, earth, B_comps_Px, B_comps_Tx, B_comps_Rx,...
                    Pxfactor, dh, modelDz(n), 1, B1, B2)*293/earth.temp;
            else % 1D
                K(:,n) = IntegrateK1DInLoop(measure, earth, B_comps_Px, B_comps_Tx, B_comps_Rx,...
                Pxfactor, dh, modelDz(n), 1, B1, B2)*293/earth.temp; %one Tx turn because B1 fields have already been added in field generation step
                % get the Jacobian for T1
                if  measure.pulsesequence == 2 % T1 kernel
                    J(:,n) = IntegrateJ1DInLoop(measure, earth, B_comps_Tx, B_comps_Rx, ...
                        Pxfactor, dh, modelDz(n), 1)*293/earth.temp;
                else
                    J(:,n) = 0;
                end
            end
            postCalcB1 = [];
    end
    
    % calc time approximation:
    tnow = toc(t_total);
    tavg = toc(t_z);
    trem = tavg*(model.nz-n);
    if gui_flag
        set(tmpgui.panel_controls.edit_status,'String',...
            {['Calculation of layer ',num2str(n),' out of ',num2str(model.nz),' done.'],...
            ['Elapsed time: ',sprintf('%4.2f',tnow),'s'],...
            ['Remaining time: ',sprintf('%4.2f',trem),'s']});
        drawnow;
    end
end
if gui_flag
    close(tmpgui.panel_controls.figureid);
end

if makeK3Dzphir
    K=squeeze(sum(K3,[2 3]));
    K3D.Kphi=squeeze(sum(K3,[3 4]));
    K3D.Kr=squeeze(sum(K3,[2 4]));
end

if makeK3Dslices
    K=squeeze(sum(K3,[2 3]));
    nphi = length(model.phi);
    K3D.KsliceNS=[squeeze(flip(K3(:,1,:,:),3)) squeeze(K3(:,round(nphi*1/2)+1,:,:))]; %north at 1°, south at 181°
    K3D.KsliceEW=[squeeze(flip(K3(:,round(nphi*1/4)+1,:,:),3)) squeeze(K3(:,round(nphi*3/4)+1,:,:))]; %east at 91°, west at 271°
end

end