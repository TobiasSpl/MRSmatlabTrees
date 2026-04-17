function [K,Mall] = IntegrateK1DInLoop(measure, earth, B_comps_Px, B_comps_Tx, B_comps_Rx, Px, dh, dz, nturns, B1, B2)
%========================================================
% Curie Formula: M0 = [N*gamma^2*hq^2/(4*K*T)]*B0 = CF*B0
% gamma = 0.267518*1e9;
% N     = 6.692*1e+28;         % [/m^3]
% hq    = 1.054571628*1e-34;   % Planck's constant/2*pi [J.s]
% K     = 1.3805*1e-23;        % Boltzmann's constant  [J/K]
% T     = 293;                 % absolute temperature  [K]
% CF = N*gamma^2*hq^2/(4*K*T);
%=========================================================

% Inloop configuration demands separated loop kernel calculation
% toDo: implement all other parameter such as frequency offset, T1
% Tobias toDo: 
% -paralelize over q as well because data transfer takes a lot of time
% -reduce transfered data to the minimum


gamma = 0.267518*1e9;
pm_vec = measure.pm_vec*nturns;
pm_vec_2ndpulse = measure.pm_vec_2ndpulse*nturns;


%Imax_vec = measure.Imax_vec*nturns; % used for off-res excitation instead of pm_vec
taup = measure.taup1;
Imax_vec = pm_vec/taup;


inkl = earth.inkl/360.0*2.0*pi;
decl = earth.decl/360.0*2.0*pi;

% Umrechnung von Kugelkoordinaten in kartesische
B0.x =   cos(inkl) * cos(-decl);
B0.y =   cos(inkl) * sin(-decl);
B0.z = + sin(inkl); % z positiv nach unten!
B0_vec = [B0.x,B0.y,B0.z];

% check if the full 3d kernel is generated
if measure.makeK3D
    KParts = struct;
end

switch measure.pulsesequence
    case 1 %'FID' % single pulse kernel
        switch measure.pulsetype
            case 1 % single standard pulse (including off-resonance)
                if measure.makeK3D
                    K = zeros([length(pm_vec),size(dh)]);
                else
                    K = zeros(length(pm_vec),1);
                end

                for n = 1:length(pm_vec)                   
                    df    = measure.df;
                    measure.usePxFIDcorr = true;
                    if measure.usePxFIDcorr
                        % perform the excitation "by hand" and account for Mpp components not
                        % parallel to B0 after the Px switch-off
                        
                        % --- Bloch-Siegert correction ---
                        
                        out = applyPxFIDcorrection(n,measure,earth,...
                            B_comps_Px,B_comps_Tx,B_comps_Rx,nturns,B1,df);
                        
                        K_part0 = squeeze(out.K_part0 * Px(n,:,:));
                        K_part1 = out.K_part1;
                        K_part2 = out.K_part2;
                        K_part3 = out.K_part3;
                        Mall = out.Mall;
                    else
                        theta = atan2(0.5*gamma*pm_vec(n)/taup*(B_comps_Tx.alpha - B_comps_Tx.beta),(2*pi*df));
                        flip_eff = sqrt((0.5*gamma*pm_vec(n)*(B_comps_Tx.alpha - B_comps_Tx.beta)).^2 + ...
                            (2*pi*df*taup).^2 );
                        
                        % m = sin(theta) .* cos(theta) .* (1-cos(flip)) + ...
                        %     1i*(sin(theta) .* sin(flip));
                        m = sin(flip_eff) .* sin(theta) + ...
                            1i*(-1)*sin(theta).*cos(theta) .* (cos(flip_eff) - 1);
                        
                        K_part0 = gamma * earth.erdt^2 * 3.29e-3 * Px;
                    
                        % normal InLoop/SepLoop-Code (5.21)
                        K_part1 = B_comps_Tx.e_zeta .* m;
                        
                        K_part2 = B_comps_Rx.e_zeta .* (B_comps_Rx.alpha + B_comps_Rx.beta);
                        
                        K_part3 = ((B_comps_Rx.b_1 .* B_comps_Tx.b_1 + B_comps_Rx.b_2 .* B_comps_Tx.b_2 + B_comps_Rx.b_3 .* B_comps_Tx.b_3) + (...
                            (1i * B0.x * (B_comps_Rx.b_2 .* B_comps_Tx.b_3 - B_comps_Rx.b_3 .* B_comps_Tx.b_2)) + ...
                            (1i * B0.y * (B_comps_Rx.b_3 .* B_comps_Tx.b_1 - B_comps_Rx.b_1 .* B_comps_Tx.b_3)) + ...
                            (1i * B0.z * (B_comps_Rx.b_1 .* B_comps_Tx.b_2 - B_comps_Rx.b_2 .* B_comps_Tx.b_1))));
                    end
                        
                    if measure.makeK3D
                        KParts(n).KP0 = K_part0;
                        KParts(n).KP1 = K_part1;
                        KParts(n).KP2 = K_part2;
                        KParts(n).KP3 = K_part3;
                        KParts(n).K = K_part0 .* K_part1 .* K_part2 .* K_part3 .*dh*dz;
                        K(n,:,:) = K_part0 .* K_part1 .* K_part2 .* K_part3 .*dh*dz;
                    else
                        K(n,:) = sum(sum(K_part0 .* K_part1 .* K_part2 .* K_part3 .*dh*dz));
                        %K(n,:) = sum(sum(K_part0 .* (B_comps_Rx.s1.*M(:,:,1)+1i*B_comps_Rx.s2.*M(:,:,2)).*dh*dz));
                    end
                end
        end
end
return
end
