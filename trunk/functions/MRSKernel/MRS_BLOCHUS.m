function  [M,TT,MM3D] = MRS_BLOCHUS(B0,B1,pm,earth,measure)
data = MRS_BLOCHUS_loadDefaults;
Minit = [0 0 1];
Tsim = measure.taup1;

% parameter needed for the ODE solver
% simulation type [string]
odeparam.type = 'pulse_MRS';
% equilibrium magnetization [A/m]
odeparam.M0 = data.basic.M0(:);
% longitudinal relaxation time T1 [s]
odeparam.T1 = 1000;
% transversal relaxation time T2 [s]
odeparam.T2 = 1000;
% gyromagnetic ratio [rad/s/T]
odeparam.gamma = data.basic.gamma; 
% primary (Earth's) magnetic field B0 [T]
odeparam.B0 = earth.w_rf/data.basic.gamma;

% ODE solver error tolerance
tol = 1e-9;
% ODE solver options
options = odeset('RelTol',tol,'AbsTol',[tol tol tol]);

% time the calculation
t0 = tic;
            
data.basic.Minit = Minit;

            
% excitation pulse parameter
% relaxation during pulse [0/1]
odeparam.RDP = data.pulse.RDP;
% pulse length [s]
odeparam.Ttau = measure.taup1;
% pulse type [string]
pulseparam.PulseType = data.pulse.Type;
% gyromagnetic ratio [rad/s/T]
pulseparam.gamma = odeparam.gamma;
% Larmor frequency [rad/s]
pulseparam.omega0 = getOmega0(odeparam.gamma,odeparam.B0);
% pulse frequency modulation [struct]
pulseparam.fmod.PulseType = 'free';
pulseparam.fmod.shape = 'const';
pulseparam.fmod.t = 0:1/50000:measure.taup1;
pulseparam.fmod.t0 = 0;
pulseparam.fmod.t1 = measure.taup1;
pulseparam.fmod.v0 = measure.df;
pulseparam.fmod.v1 = measure.df;
pulseparam.fmod.A = data.pulse.DFA;
pulseparam.fmod.B = data.pulse.DFB;

% pulse current modulation [struct]
pulseparam.Imod.PulseType = 'free';
pulseparam.Imod.shape = data.pulse.Imode;
pulseparam.Imod.useQ = 0;
pulseparam.Imod.Q = data.pulse.Q;
pulseparam.Imod.Qdf = data.pulse.Qdf;
pulseparam.Imod.t = 0:1/50000:measure.taup1;
pulseparam.Imod.t0 = 0;
pulseparam.Imod.t1 = measure.taup1;
pulseparam.Imod.v0 = 1;
pulseparam.Imod.v1 = 1;
pulseparam.Imod.A = data.pulse.IA;
pulseparam.Imod.B = data.pulse.IB;



% if the discrete MIDI pulses are used add the corresponding
% data
if isfield(data,'pulse_MIDI')
    % MIDI pulse data [struct]
    pulseparam.MIDI = data.pulse_MIDI;
end

% auxiliary pulse phase [rad]
pulseparam.phi = 0;
% pulse axis [string]
pulseparam.PulseAxis = '+y';
% pulse polarization [string]
pulseparam.PulsePolarization = data.pulse.Polarization;
% add the pulse parameter to the ode parameter struct

TTmax=[0];

%inkl = earth.inkl/360.0*2.0*pi;
%decl = earth.decl/360.0*2.0*pi;
        
vecB0=[B0.x,B0.y,B0.z];
% the rotation matrix R0 rotates B0 to zunit (z+)
R0 = RotationFromTwoVectors([B0.x B0.y B0.z],[0 0 1]);

for iphi=1:length(B1.phi)
    for ir=1:length(B1.r)
        
        vecB1 = [B1.x(iphi,ir);B1.y(iphi,ir);B1.z(iphi,ir)] *pm/measure.taup1;
        [theta,sgn] = getAngleBetweenVectors(vecB1,vecB0);
        B1_lab=norm(vecB1)*[sin(theta), 0, cos(theta)]; % perpendicular field projected along +x-direction
        
        %{
        B1_vox = [B1.x(iphi,ir);B1.y(iphi,ir);B1.z(iphi,ir)] *pm/measure.taup1;
        B1_vox = (R0*B1_vox);
        %rotate xy component so that pulse rotation is around y-axis
        b1_xy=[B1_vox(1),B1_vox(2),0]/norm([B1_vox(1),B1_vox(2),0]);
        R1=RotationFromTwoVectors(b1_xy,[-1 0 0]);
        B1_lab2 = (R1*B1_vox)';

        %B1_vox = B1_vox .* [1 1 -1];
        %}

        % pulse amplitude [T]
        pulseparam.Amp = B1_lab(1);
        %pulseparam.PulsePolarization = 'linear';
        odeparam.pulseparam = pulseparam;
        switch data.pulse.Type
            case {'MIDI_OR','MIDI_AP'}
                % if Tsim > Ttau extend the discrete time steps
                % this is needed because for the discrete pulses
                % specific time steps are fed into the solver
                Tsim = unique([data.pulse_MIDI.t;(0:1/50e3:Tsim)']);
                [TT,MM] = ode45(@(t,m) fcn_BLOCHUS_ode(t,m,odeparam),Tsim,Minit,options);
            otherwise
                [TT,MM] = ode45(@(t,m) fcn_MRS_BLOCHUS_ode(t,m,odeparam,B1_lab,earth.inkl,earth.w_rf,measure.df*2*pi,B1.phi(1,iphi)),[0 Tsim],Minit,options);
        end
        %rotate by phi
        %MM = squeeze(pagemtimes(repmat(getRotationMatrixFromAngleandAxis(-B1.phi(1,iphi)+pi,[0,0,1]),1,1,length(MM)),permute(MM,[2 3 1])))';
        
        n(iphi,ir)=length(MM);
        MM3D(iphi,ir,1:length(MM),:)=MM;
        TT3D(iphi,ir,1:length(TT))=TT;
        if length(TT)>length(TTmax)
            TTmax=TT;
        end
    end
end

TT=TTmax;

for iphi=1:length(B1.phi)
    for ir=1:length(B1.r)
        for idim=1:3
            MM3D(iphi,ir,:,idim)=interp1(squeeze(TT3D(iphi,ir,1:n(iphi,ir))),squeeze(MM3D(iphi,ir,1:n(iphi,ir),idim)),TT);
        end
    end
end

M=squeeze(MM3D(:,:,end,:));

% save data
data.results.basic.T = TT;
data.results.basic.M = MM;