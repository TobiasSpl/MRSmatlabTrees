function out = applyPxFIDcorrection(n,measure,earth,B_comps_Px,B_comps_Tx,B_comps_Rx,nturns,B1,df)

version = 1;


% standard header stuff
gamma = 0.267518*1e9;
pm_vec = measure.pm_vec(n)*nturns;
taup = measure.taup1;

Imax = pm_vec/taup;

inkl = earth.inkl/360.0*2.0*pi;
decl = earth.decl/360.0*2.0*pi;

% Umrechnung von Kugelkoordinaten in kartesische
B0.x =   cos(inkl) * cos(-decl);
B0.y =   cos(inkl) * sin(-decl);
B0.z = + sin(inkl); % z positiv nach unten!

switch version
    case 1
        % Mp (oriented in Px Bloch-frame -> B0 along z) with Bp towards
        MPxyz(:,:,1) = permute(measure.Mp.x1(n,:,:),[2,3,1]);
        MPxyz(:,:,2) = permute(measure.Mp.y1(n,:,:),[2,3,1]);
        MPxyz(:,:,3) = permute(measure.Mp.z1(n,:,:),[2,3,1]);
        %Phase Px -> Tx
        PhasePxTx = -angle(((B_comps_Px.b_1 .* B_comps_Tx.b_1 + B_comps_Px.b_2 .* B_comps_Tx.b_2 + B_comps_Px.b_3 .* B_comps_Tx.b_3) + (...
            (1i * B0.x * (B_comps_Px.b_2 .* B_comps_Tx.b_3 - B_comps_Px.b_3 .* B_comps_Tx.b_2)) + ...
            (1i * B0.y * (B_comps_Px.b_3 .* B_comps_Tx.b_1 - B_comps_Px.b_1 .* B_comps_Tx.b_3)) + ...
            (1i * B0.z * (B_comps_Px.b_1 .* B_comps_Tx.b_2 - B_comps_Px.b_2 .* B_comps_Tx.b_1)))));
        %Bloch z_vec
        v1 = repmat([0 0 1],[numel(PhasePxTx(:)) 1]);
        % get rotation matrices -> rotate around zunit with angle theta
        % this should rotate Tx towards y+
        RTx = getRotationMatrixFromAngleandAxis(PhasePxTx(:),v1);
        % rotation matrizes in the first 2 dimensions, followed by nphi and
        % nr dimension
        RTx2 = reshape(RTx,[3,3,size(PhasePxTx)]);
        % rotate all Mp vectors with RTx matrix
        % this leads to a Mp vector that has the correct phase angle to the
        % Tx-pulse axis y+
        % shift MP-vectors to first dimension and expand with empty dimension
        MPxyz2 = permute(MPxyz,[3 4 1 2]);
        % now we rotate: 3x3 rotation matrix multiplied with 3x1 MP-vector
        % for all nphi x nr positions of one layer
        Mp_rot = pagemtimes(RTx2,MPxyz2);
        if ~measure.applyBS % RWA
            switch measure.pulsesign
                case 1
                    flip = 0.5*gamma*pm_vec*(B_comps_Tx.alpha - B_comps_Tx.beta);
                    v2 = repmat([0 1 0],[numel(flip) 1]);
                    alpha = 0;
                case 2
                    flip = 0.5*gamma*pm_vec*(B_comps_Tx.alpha - B_comps_Tx.beta);
                    v2 = repmat([0 1 0],[numel(flip) 1]);
                    alpha = 0;
                case 3
                    flip = -0.5*gamma*pm_vec*(B_comps_Tx.alpha - B_comps_Tx.beta);
                    v2 = repmat([0 1 0],[numel(flip) 1]);
            end
            if sum(B_comps_Px.zeta,"all")> 0 %| sum(B_comps_Tx.zeta,"all")> 0 | sum(B_comps_Rx.zeta,"all")> 0
                warning("zeta")
            end
            % reshape flip angles
            f1 = reshape(flip,[numel(flip) 1]);
            %Pulse in y-direction
            if isfield(measure,"Txphase")
                alpha = measure.Txphase(n)-pi;%*-1;
            else
                alpha = -pi;
            end
            v2 = [ones(size(f1))*cos(alpha) ones(size(f1))*sin(alpha) zeros(size(f1))];
            %Pulse in x-direction
            %alpha = measure.Txphase(n)-pi;
            %v2 = [-ones(size(f1))*sin(alpha) -ones(size(f1))*cos(alpha) zeros(size(f1))];
            % get rotation matrices -> rotate around Tx-axis y+ with angle flip
            Rflip = getRotationMatrixFromAngleandAxis(f1,v2);
            % rotation matrizes in the first 2 dimensions, followed by nphi and
            % nr dimension
            Rflip2 = reshape(Rflip,[3,3,size(PhasePxTx)]);
            m_tmp = permute(pagemtimes(Rflip2,Mp_rot),[1 3 4 2]);
        else
            if isfield(measure,"TxLookup") %Pulse Mapping + Lookup table
                if isfield(measure,'Pulse')
                    phase = measure.Txphase(n)-pi/2;
                    %Shape = measure.Pulse(n).Shape/measure.pm_vec(n)*measure.taup1;
                    Shape = (measure.Pulse(n).Shape)/measure.pm_vec(n)*measure.taup1;
                    
                    len = min([length(Shape),length(measure.TxLookup.measure.Pulse(1).t)]);
                    for i= 1:length(measure.TxLookup.measure.Pulse)
                        diff(i) = sum(abs([Shape(1:len)]-[measure.TxLookup.measure.Pulse(i).Shape(1:len)]),"all");
                    end
                    nMap = find(diff==min(diff),1);
                    
                    %nMap = n;
                    %figure(947); plot(measure.Pulse(n).t,Shape); hold on; plot(measure.TxLookup.measure.Pulse(nMap).t,measure.TxLookup.measure.Pulse(nMap).Shape); hold off
                else
                    warning("no pulse shape found")
                    nMap = 1; %for sinuosoidal pulse we only need one shape
                end
                %we cut the lookup table to the necessary region to reduce calc times
                [~,iBparmin] = find(min(B_comps_Tx.bpar*Imax,[],"all") > measure.TxLookup.Bpar,1,"last");
                [~,iBparmax] = find(max(B_comps_Tx.bpar*Imax,[],"all") < measure.TxLookup.Bpar,1,"first");
                if iBparmax-iBparmin <4; iBparmin = iBparmin-2; iBparmax = iBparmax+2; end
                if isempty(iBparmax); iBparmax = length(measure.TxLookup.Bpar); end
                [~,iBpermin] = find(min((B_comps_Tx.alpha - B_comps_Tx.beta)*Imax,[],"all")> measure.TxLookup.Bper,1,"last");
                [~,iBpermax] = find(max((B_comps_Tx.alpha - B_comps_Tx.beta)*Imax,[],"all")< measure.TxLookup.Bper,1,"first");
                if iBpermax-iBpermin <4; iBpermin = iBpermin-2; iBpermax = iBpermax+2; end
                if isempty(iBpermax); iBpermax = length(measure.TxLookup.Bper); end
                %iBpermin = 1; iBpermax = length(measure.TxLookup.Bper);
                iBparmin = 1; iBparmax = length(measure.TxLookup.Bpar);
                Rflip2 = zeros(3,3,length(B1.phi),length(B1.r));
                for idim = 1:3 %M0 dimensions
                    for jdim = 1:3  %M dimensions
                        %Pulse in x-direction
                        %without cutting
                        %Rflip2(jdim,idim,:,:) =interp2(measure.TxLookup.Bpar,measure.TxLookup.Bper,squeeze(measure.TxLookup.M(nMap,idim,:,:,jdim)),-1*B_comps_Tx.bpar*Imax,1*(B_comps_Tx.alpha - B_comps_Tx.beta)*Imax,"linear",0); 
                        %with cutting, not 100% sure about the sign of Bpar
                        Rflip2(jdim,idim,:,:) = interp2(measure.TxLookup.Bpar(iBparmin:iBparmax),measure.TxLookup.Bper(iBpermin:iBpermax),squeeze(measure.TxLookup.M(nMap,idim,(iBpermin:iBpermax),(iBparmin:iBparmax),jdim)),-1*B_comps_Tx.bpar*Imax,1*(B_comps_Tx.alpha - B_comps_Tx.beta)*Imax,"linear",0);
                    end
                end
        
                if sum(Rflip2 == 0,"all") > 10
                    warning("TxLookup Table to small?")
                end
                m_tmp = permute(pagemtimes(Rflip2,Mp_rot),[1 3 4 2]);
            else
                error("Please calculate or load a pulse lookup table first.")
            end
        end
        m = complex(m_tmp(1,:,:),m_tmp(2,:,:));
        mz = m_tmp(3,:,:);
        % and reshape into original size
        m = squeeze(m);       
  
end

% kernel parts
K_part0 = gamma * earth.erdt^2 * 3.29e-3;

% normal InLoop/SepLoop-Code (5.21)
K_part1 = B_comps_Tx.e_zeta .* m;

K_part2 = B_comps_Rx.e_zeta .* (B_comps_Rx.alpha + B_comps_Rx.beta);

K_part3 = ((B_comps_Rx.b_1 .* B_comps_Tx.b_1 + B_comps_Rx.b_2 .* B_comps_Tx.b_2 + B_comps_Rx.b_3 .* B_comps_Tx.b_3) + (...
    (1i * B0.x * (B_comps_Rx.b_2 .* B_comps_Tx.b_3 - B_comps_Rx.b_3 .* B_comps_Tx.b_2)) + ...
    (1i * B0.y * (B_comps_Rx.b_3 .* B_comps_Tx.b_1 - B_comps_Rx.b_1 .* B_comps_Tx.b_3)) + ...
    (1i * B0.z * (B_comps_Rx.b_1 .* B_comps_Tx.b_2 - B_comps_Rx.b_2 .* B_comps_Tx.b_1))));

out.m = m;
if exist("mz","var")
    out.mz = squeeze(mz);
end
out.K_part0 = K_part0;
out.K_part1 = K_part1;
out.K_part2 = K_part2;
out.K_part3 = K_part3;
out.Mall = m_tmp;

return