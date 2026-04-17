function proclog = mrsSigPro_stack(gui,fdata,proclog)
% function proclog = mrsSigPro_stack(gui,fdata,proclog)
% 
% stack receiver channels, cut QD artefacts (filter) and adapt dead time
% delete reference channels
% 
% Jan Walbrecker
% ed. 29sep2011 JW
% ed. 06oct2011 MMP
% =========================================================================    
mrs_setguistatus(gui,1,'STACKING...')

% Replace rxinfo with signal receivers only (task==1)
proclog.rxinfo = fdata.info.rxinfo([fdata.info.rxinfo(:).task]==1);
proclog.header = fdata.header;

% Remove old stacked data (if present)
if isfield(proclog.Q,'rx');
    proclog.Q=rmfield(proclog.Q,'rx');       
end

nq  = length(fdata.Q);           % number of pulse moments
nrx = length(fdata.info.rxinfo); % number of ALL receivers

% parameters for quadrature detection
fT = fdata.Q(1).rec(1).info.fT;             % transmitter freq
fS = fdata.Q(1).rec(1).info.fS;             % sampling freq
fW = proclog.LPfilter.PassbandFrequency;    % filter width

nrec = length(fdata.Q(1).rec);
pc     = zeros(nq,nrec);

stacking = questdlg('Records with which phase should be stacked?','Stacking Phase','all','plus','minus','all');

for iQ=1:nq % all pulse moments
    nrec = length(fdata.Q(iQ).rec);   % number of recordings (can be different for each q if recording was interrupted)
    iirx = 0;
    for irx=1:nrx % all receivers
        if fdata.info.rxinfo(irx).task == 1 % if channel is receiver            
            iirx = iirx + 1;
            for isig=1:4 % all signals
                if fdata.Q(iQ).rec(1).rx(irx).sig(isig).recorded % if SIG recorded 
                    nt = inf;
                    for iirec = 1:nrec
                        if nt > length(fdata.Q(iQ).rec(iirec).rx(irx).sig(isig).t1) 
                            t    = fdata.Q(iQ).rec(iirec).rx(irx).sig(isig).t1; % [s]
                            nt = length(t);
                        end
                    end
                    if ~isfield(fdata.header,"fS_org")
                        fdata.header.fS_org = fdata.header.fS;
                    end
                    t_pulse = (0:length(fdata.Q(iQ).rec(1).pulse1)-1)/(fdata.header.fS_org); %[0:1/fdata.header.fS_org:fdata.header.tau_p, fdata.header.tau_p];
                    if fdata.header.sequenceID == 9 %if sequence with PP
                        t_ramp = (0:length(fdata.Q(iQ).rec(1).rampPP)-1)/(fdata.header.fS_org);
                    end
                    
                    % assemble stack
                    v_all  = zeros(nrec,nt);
                    u_all = []; %assembled with cat, needed for resample
                    %u_all  = zeros(nrec,length(t));
                    pulse_all = zeros(nrec,length(t_pulse));
                    if fdata.header.sequenceID == 9 %if sequence with PP
                        ramp_all = zeros(nrec,length(t_ramp));
                    end

                    phases = zeros(1,nrec);
                    keep   = zeros(1,nrec);
                    for iirec = 1:nrec
                        v_all(iirec,:) = fdata.Q(iQ).rec(iirec).rx(irx).sig(isig).v1(1:nt);
                        pulse_all(iirec,1:length(t_pulse)) = fdata.Q(iQ).rec(iirec).pulse1(1:length(t_pulse));
                        if fdata.header.sequenceID == 9 %if sequence with PP
                            ramp_all(iirec,1:length(t_ramp)) = fdata.Q(iQ).rec(iirec).rampPP;
                        end
                        keep(iirec) = mrs_getkeep(proclog,iQ,iirec,irx,isig);
                        if strcmp(fdata.info.device,'GMR')
                            if sign(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(isig)) == 0
                                % do nothing - phi_gen is set to 0 for
                                % prepreocessed GMR files
                                phases(iirec) = 0;
                            else     
                                switch isig
                                    case 2 % FID                                        
                                        v_all(iirec,:)  = v_all(iirec,:).*sign(sin(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(2)))*-1;
                                        pulse_all(iirec,:) = pulse_all(iirec,:).*sign(sin(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(2)))*-1;
                                        if stacking == "minus" & keep(iirec);
                                            keep(iirec) = sin(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(2))*-1 > 0;
                                        elseif stacking == "plus" & keep(iirec);
                                            keep(iirec) = sin(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(2))*-1 < 0 ;
                                        end
                                        if sign(sin(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(2)))*-1 ~= sign(cos(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(2)))
                                            %warning("phase close to \pm pi/2, check for phase jumps")
                                        end


                                        pc(iQ,iirec) = keep(iirec);

                                    case 3 % 2nd FID (T1)
                                        %does not work if phase of one pulse is close to 0
                                        v_all(iirec,:)  = v_all(iirec,:).*sign(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(isig)); 
                                        %pulse_all(iirec,:) = pulse_all(iirec,:).*sign(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(isig));
                                        
                                    case 4 % Echo (T2)
                                        v_all(iirec,:)  = v_all(iirec,:).*sign(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(2));
                                    
                                end
                                
                                % force appropriate sign for phase
                                % correction (timing phase)
                                if sign(fdata.Q(iQ).rec(iirec).info.phases.phi_gen(isig)) == 1
                                    phases(iirec) = fdata.Q(iQ).rec(iirec).info.phases.phi_gen(isig);
                                else
                                    phases(iirec) = fdata.Q(iQ).rec(iirec).info.phases.phi_gen(isig) + pi;
                                end                                
                                
                                if nrec > 1
                                    %u_all(iirec,:)  = mrsSigPro_QD(v_all(iirec,:),t,fT,fS,fW,proclog.LPfilter);
                                    u_all = cat(1,u_all,mrsSigPro_QD(v_all(iirec,:),t,fT,fS,fW,proclog.LPfilter)); %assembled with cat, needed for resample
                                end
                            end    
                        end
                        if strcmp(fdata.info.device,'NUMISpoly') % MMP: this is not ready yet! phases!
                            if nrec > 1
                                u_all(iirec,:)  = mrsSigPro_QD(v_all(iirec,:),t,fT,fS,fW,proclog.LPfilter);
                            end
                        end
                    end
                    
                    V  = sum(v_all(keep==1,:),1)/size(v_all(keep==1,:),1);
                    
                    Pulse = sum(pulse_all(keep==1,:),1)/size(pulse_all(keep==1,:),1);
                    if fdata.header.sequenceID == 9 %if sequence with PP
                        Ramp = sum(ramp_all(keep==1,:),1)/size(ramp_all(keep==1,:),1);
                        recs = 1:nrec;
                        for irec = recs(keep==1)
                            Ramp_all(sum(keep(1:irec)),:) = ramp_all(irec,:)* 26.5; %[A/V] scaling factor;
                        end
                    end
                    %calculate q again with stacked pulse signals, import
                    %of pulse2 not yet implemented
                    if isig == 2
                        proclog.Q(iQ).q_old = proclog.Q(iQ).q;
                        [proclog.Q(iQ).q,phase_all] = HilbertEnvelope(Pulse,t_pulse',fdata.header.fT,fdata.header.fS_org,fdata.header.tau_p,fdata.header.TXgain,true);
                    end
                    
                    % delete nan from QD and get data error after stacking
                    if nrec > 1
                        u_all(isnan(u_all))=0;
                        E  = complex((std(real(u_all(keep==1,:)),1))/sqrt(size(v_all(keep==1,:),1)),... 
                                     (std(imag(u_all(keep==1,:)),1))/sqrt(size(v_all(keep==1,:),1))); 
                    else % don't do this for stacked data (GMR preproc) - cannot calculate std for stack
                        E = zeros(size(v_all));
                    end
                    
                    % get phase for phase correction
                    phase = fdata.Q(iQ).rec(1).info.phases;
                    if strcmp(fdata.info.device,'GMR')
                        % get average generator phase for this pulsemoment
                        % phase.phi_gen(isig) = mean(phases);
                        % use generator phase from stacked pulses
                        phase.phi_gen(isig) = phase_all;
                    end
                        
                    % get QD signal for stacked signal
                    u = mrsSigPro_QD(V,t,fT,fS,fW,proclog.LPfilter);
                    U = u;
                    %U = mrs_signalphasecorrection(u,phase,isig,fdata.info.device);
                
                    % Get new dead time after QD (zeros in envelope) and
                    % resampling index (resampling due to filter)
                    zwerg = t(isnan(U(1:round(end/2))));
                    index = length(zwerg)+1;

                    [h,f] = freqz(proclog.LPfilter,1024,fS);
                    i = find(abs(h)<sqrt(0.5),1,"first");
                    rate = floor((fS/2)/f(i)); %Nyquist theorem, cutoff freq: f(i) (-3dB)
                                       
                    % assemble all information
                    proclog.Q(iQ).timing.tau_dead1            = t(index); %time vector already shifted by taudead from instrument and import filter
                    proclog.Q(iQ).rx(iirx).sig(isig).t        = t(index:rate:end-index) - t(index);
                    proclog.Q(iQ).rx(iirx).sig(isig).V        = U(index:rate:end-index);
                    proclog.Q(iQ).rx(iirx).sig(isig).E        = E(index:rate:end-index);
                    proclog.Q(iQ).rx(iirx).sig(isig).recorded = 1;

                    proclog.Q(iQ).phase = phase_all;
                    proclog.Q(iQ).pulse = Pulse/fdata.header.TXgain;
                    proclog.Q(iQ).pulse_time = t_pulse;
                    if fdata.header.sequenceID == 9 %if sequence with PP
                        proclog.Q(iQ).ramp = Ramp * 26.5; %[A/V] scaling factor from Cristina McLaughlin
                        proclog.Q(iQ).ramp_all = Ramp_all;
                        proclog.Q(iQ).ramp_time = t_ramp;
                    end
                    if isig==4
                        proclog.Q(iQ).rx(iirx).sig(isig).nE = round(max(proclog.Q(1).rx(1).sig(4).t)/proclog.Q(1).timing.tau_e);
                        echotimes = proclog.Q(1).timing.tau_e/2-proclog.Q(1).timing.tau_p2/2-proclog.Q(1).timing.tau_dead1;
                        for iE=2:proclog.Q(iQ).rx(iirx).sig(isig).nE
                            echotimes=[echotimes echotimes(iE-1) + proclog.Q(1).timing.tau_e];
                        end
                        proclog.Q(iQ).rx(iirx).sig(isig).echotimes = echotimes;
                    end
                    
                else
                    proclog.Q(iQ).rx(iirx).sig(isig).recorded = 0;
                end
            end
        else
            % skip if not a signal channel
        end
    end
end
mrs_setguistatus(gui,0)

