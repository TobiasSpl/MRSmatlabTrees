function [fdata,proclog] = mrsSigPro_NCGetTransfer(fdata,proclog,refChannel,detectChannel)

if ~isnan(refChannel)
    if ~isnan(detectChannel)
%         switch fdata.info.device
% MMP
% noise records are no longer used since NC can be based on the record
% itself thats the same for both GMR and Numis
%             case 'GMR'               
                niQ = mrsSigPro_GetGMRZeroPuls(fdata);
                if ~isempty(niQ)
                    for iirx=1:length(detectChannel)
                        for iiq = 1:length(niQ)
                            for iirec = 1:length(fdata.Q(iiq).rec)
                                detectKeep((iiq-1)*length(fdata.Q(iiq).rec) + iirec) = ...
                                     mrs_getkeep(proclog,iiq,iirec,detectChannel(iirx),2);
                                detection((iiq-1)*length(fdata.Q(iiq).rec) + iirec).P1 =  ...
                                    fdata.Q(iiq).rec(iirec).rx(detectChannel(iirx)).sig(2).v1;                               
                                for rc=1:length(refChannel)
                                    referenceKeep(rc,(iiq-1)*length(fdata.Q(iiq).rec) + iirec) = ...
                                        mrs_getkeep(proclog,iiq,iirec,detectChannel(iirx),2);
                                    reference((iiq-1)*length(fdata.Q(iiq).rec) + iirec).R1(rc,:) =  ...
                                        fdata.Q(iiq).rec(iirec).rx(refChannel(rc)).sig(2).v1;
                                end
                            end
                        end
                        detection((sum(referenceKeep)+detectKeep)==0)=[]; %  include only if all (detection and reference) are set keep 
                        reference((sum(referenceKeep)+detectKeep)==0)=[];
                        

                        t        = fdata.Q(1).rec(1).rx(detectChannel(iirx)).sig(2).t0;
                        freqMax  = 1/2/(t(2)-t(1));
                        freqSpec = linspace(0,2*freqMax, length(t));

                        % save TF to proclog
                        proclog.NC.rx(detectChannel(iirx)).sig(2).TF = mrsSigPro_FFTMultiChannelTransfer(reference,detection);
                        proclog.NC.rx(detectChannel(iirx)).sig(2).niref = refChannel;
                        proclog.NC.rx(detectChannel(iirx)).sig(2).niQ = niQ;
                        proclog.NC.rx(detectChannel(iirx)).sig(2).nirec = ones(1,length(fdata.Q(iiq).rec));
                        proclog.NC.rx(detectChannel(iirx)).sig(2).freqSpec = freqSpec;
                        
                        figure(250+iirx);
%                       plot(freqSpec,abs(fdata.Q(1).rec(1).rx(detectChannel(iirx)).sig(2).transfer));xlim([1500 2500]);
                        hold off
                        for iref=1:length(refChannel)
                            plot(freqSpec,real(proclog.NC.rx(detectChannel(iirx)).sig(2).TF(:,iref)),'DisplayName',sprintf('ref = %d',refChannel(iref))');
                            hold on
                        end
                        xline(fdata.header.fT,':','DisplayName','f_L')
                        xlim([1000 3000]);
                        title(sprintf('rx = %d',detectChannel(iirx)));
                        xlabel('f / Hz')
                        ylabel('TF')
                        l=legend;
                        hold off
                    end
                    
                    if fdata.Q(1).rec(1).rx(detectChannel(1)).sig(3).recorded
                        clear detection reference detectKeep referenceKeep
                        for iirx=1:length(detectChannel)
                            for iiq = 1:length(niQ)
                                for iirec = 1:length(fdata.Q(iiq).rec)
                                    detectKeep((iiq-1)*length(fdata.Q(iiq).rec) + iirec) = ...
                                        mrs_getkeep(proclog,iiq,iirec,detectChannel(iirx),3);
                                    detection((iiq-1)*length(fdata.Q(iiq).rec) + iirec).P1 =  ...
                                        fdata.Q(iiq).rec(iirec).rx(detectChannel(iirx)).sig(3).v1;
                                    for rc=1:length(refChannel)
                                        referenceKeep(rc,(iiq-1)*length(fdata.Q(iiq).rec) + iirec) = ...
                                            mrs_getkeep(proclog,iiq,iirec,detectChannel(iirx),3);
                                        reference((iiq-1)*length(fdata.Q(iiq).rec) + iirec).R1(rc,:) =  ...
                                            fdata.Q(iiq).rec(iirec).rx(refChannel(rc)).sig(3).v1;
                                    end
                                end
                            end
                            detection((sum(referenceKeep)+detectKeep)==0)=[]; %  include only if all (detection and reference) are set keep
                            reference((sum(referenceKeep)+detectKeep)==0)=[];
                            
                            
                            % save TF to proclog
                            proclog.NC.rx(detectChannel(iirx)).sig(3).TF = mrsSigPro_FFTMultiChannelTransfer(reference,detection);
                            proclog.NC.rx(detectChannel(iirx)).sig(3).niref = refChannel;
                            proclog.NC.rx(detectChannel(iirx)).sig(3).niQ = niQ;
                            proclog.NC.rx(detectChannel(iirx)).sig(3).nirec = ones(1,length(fdata.Q(iiq).rec));         
                            
                        end
                    end
                    
                else
                    msgbox('no transfer calculation possible')
                end

    else
        msgbox('enter at least one detection channel')
    end
else
    msgbox('enter at least one reference channel')
end
       