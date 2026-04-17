function gui = mrsInvQT_plotData(gui,idata,RunToPlot)
if nargin<3;
    k=1;
else
    k=RunToPlot;
end
scaleV=1e9;
% plot data
screensz = get(0,'ScreenSize');
if isvalid(gui.fig_data)
    set(0,'currentFigure',gui.fig_data)
else
    gui.fig_data = figure( ...
            'Position', [5+355+405 screensz(4)-800 500 720], ...
            'Name', 'MRS QT Inversion - Data', ...
            'NumberTitle', 'off', ...
            'Toolbar', 'figure', ...
            'HandleVisibility', 'on');
end
% figure(gui.fig_data);
clf;
[Q,T] = meshgrid(idata.data.q, idata.data.t + idata.data.effDead);

%idata.data.dcube = abs(idata.data.dcube).*exp(1i*(angle(idata.data.dcube) - idata.para.instPhase));

switch idata.para.dataType
    case 1 % amplitudes
        subplot(3,2,1)
                %pcolor(idata.data.t + idata.data.effDead, idata.data.q, abs(idata.data.dcube)*scaleV)
                imagesc(abs(idata.data.dcube)*scaleV)
                a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                axis ij; shading flat
                set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                if length(idata.data.q) > 2
                    set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                    %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                else
                    set(gca,'yticklabel',"")
                end
                %set(gca,'yscale','log','xscale','log')
                colorbar
                title('abs(observed voltages) /nV')
                ylabel('{\itq} / As'); xlabel('{\itt} / s'); 
                maxZ = max(max(abs(idata.data.dcube.'))); if maxZ==0; maxZ=eps;end
                set(gca,'clim',([-maxZ/10 maxZ]*1.05*scaleV));
    case 2 % rotated complex
        subplot(3,2,1)
%                 pcolor(idata.data.t + idata.data.effDead, idata.data.q, real(idata.data.dcube)*scaleV)
                imagesc(real(idata.data.dcube)*scaleV)
                a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                axis ij; shading flat
                set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                if length(idata.data.q) > 2
                    set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                    %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                else
                    set(gca,'yticklabel',"")
                end
%                 set(gca,'yscale','log','xscale','log')
                colorbar
                title('real(observed voltages) /nV')
                ylabel('{\itq} / As'); xlabel('{\itt} / s'); 
        subplot(3,2,2)
                ErrorWImag = imag(idata.data.dcube)./idata.data.ecube;
%                 pcolor(idata.data.t + idata.data.effDead, idata.data.q, ErrorWImag)
                imagesc(ErrorWImag)
                a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                axis ij; shading flat
                set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                if length(idata.data.q) > 2
                    set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                    %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                else
                    set(gca,'yticklabel',"")
                end
%                 set(gca,'yscale','log','xscale','log')
                colorbar
                ylabel('{\itq} / As'); xlabel('{\itt} / s'); 
                title('imaginary/error')
                title([ 'error weighted imaginary part (chi^2 = ' ...
                         num2str(sqrt(sum(sum(ErrorWImag.^2)))/sqrt(numel(ErrorWImag))) ')'])
    case 3 % complex
        subplot(3,2,1)
%                 pcolor(idata.data.t + idata.data.effDead, idata.data.q, real(idata.data.dcube)*scaleV)
                imagesc(real(idata.data.dcube)*scaleV)
                a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                axis ij; shading flat
                set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                if length(idata.data.q) > 2
                    set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                    %set(gca,'yticklabel',sprintf("%.1E",idata.data.q(get(gca,'ytick'))))
                else
                    set(gca,'yticklabel',"")
                end
%                 set(gca,'yscale','log','xscale','log')
                maxZ = max(max(real(idata.data.dcube.'))); if maxZ==0; maxZ=eps;end
                minZ = min(min(real(idata.data.dcube.'))); if minZ==0; minZ=-eps;end
                set(gca,'clim',([minZ maxZ]*1.05*scaleV));
                colorbar
                title('real(observed voltages) /nV')
                ylabel('{\itq} / As'); xlabel('{\itt} / s'); 
        subplot(3,2,2)
%                 pcolor(idata.data.t + idata.data.effDead, idata.data.q, imag(idata.data.dcube)*scaleV)
                imagesc(imag(idata.data.dcube)*scaleV)
                a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                axis ij; shading flat
                set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                if length(idata.data.q) > 2
                    set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                    %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                else
                    set(gca,'yticklabel',"")
                end
%                 set(gca,'yscale','log','xscale','log')
                maxZ = max(max(imag(idata.data.dcube.')));if maxZ==0; maxZ=eps;end
                minZ = min(min(imag(idata.data.dcube.')));if minZ==0; minZ=-eps;end
                set(gca,'clim',([minZ maxZ]*1.05*scaleV));
                colorbar
                title('imaginary(observed voltages) /nV')
                ylabel('{\itq} / As'); xlabel('{\itt} / s'); 
end

% plot inversion results if exist
if isfield(idata,'inv1Dqt')
    if isfield(idata.inv1Dqt,'solution')
        idata.inv1Dqt = rmfield(idata.inv1Dqt,'solution');
    end
    % check which modelspace is selected
    switch idata.para.modelspace
        case 1 %smooth-multi
            if isfield(idata.inv1Dqt,'smoothMulti')
                idata.inv1Dqt.solution = idata.inv1Dqt.smoothMulti.solution ;
                idata.inv1Dqt.decaySpecVec = idata.inv1Dqt.smoothMulti.decaySpecVec;
                idata.inv1Dqt.z = idata.inv1Dqt.smoothMulti.z;
                idata.inv1Dqt.t = idata.inv1Dqt.smoothMulti.t;
            else
                return
            end            
        case 2 %smooth-mono
            if isfield(idata.inv1Dqt,'smoothMono')
                idata.inv1Dqt.solution = idata.inv1Dqt.smoothMono.solution ;
                idata.inv1Dqt.z = idata.inv1Dqt.smoothMono.z;
                idata.inv1Dqt.t = idata.inv1Dqt.smoothMono.t;
            else
                return
            end
        case 3 %block-mono
            if isfield(idata.inv1Dqt,'blockMono')
                idata.inv1Dqt.solution = idata.inv1Dqt.blockMono.solution ;
                idata.inv1Dqt.z = idata.inv1Dqt.blockMono.z;
                idata.inv1Dqt.t = idata.inv1Dqt.blockMono.t;
            else
                return
            end
    end
    if length(idata.data.d)==length(idata.inv1Dqt.solution(1).d)
        switch length(idata.para.regVec)
            case 1
                dcube     = reshape(idata.inv1Dqt.solution(k).d ,length(idata.data.q),length(idata.inv1Dqt.t));
                dcube     = abs(dcube).*exp(1i*(angle(dcube) + idata.para.instPhase));
                switch idata.para.modelspace
                    case 1       
                        M         = reshape(idata.inv1Dqt.solution(1).m_est,length(idata.inv1Dqt.z),length(idata.inv1Dqt.decaySpecVec));
                        if size(idata.inv1Dqt.solution,2) > 1
                            for i=1:size(idata.inv1Dqt.solution,2)
                                M_array(:,:,i) = reshape(idata.inv1Dqt.solution(i).m_est,length(idata.inv1Dqt.z),length(idata.inv1Dqt.decaySpecVec));
                            end
                        end
                        decaycube = repmat(idata.inv1Dqt.decaySpecVec,size(M,1),1);                        
                        % water content extrapolation
                        %M         = M.*exp(idata.data.effDead./decaycube);
                        M         = M;
                    case 2
                        %T2        = idata.inv1Dqt.solution(k).T2;
                        %W         = idata.inv1Dqt.solution(k).w.*exp(idata.data.effDead./T2);
                        %W         = idata.inv1Dqt.solution(k).w;
                    case 3
%                         T2    = [idata.inv1Dqt.solution(k).T2(1) idata.inv1Dqt.solution(k).T2];
%                         W     = [idata.inv1Dqt.solution(k).w(1) idata.inv1Dqt.solution(k).w];
%                         Depth = [0 cumsum(idata.inv1Dqt.solution(k).thk) max(idata.inv1Dqt.z)];
                        
                end
            otherwise
        end
        % data fit
        set(0,'currentFigure',gui.fig_data)
        %figure(gui.fig_data)
        switch idata.para.dataType
            case 1 % amplitudes
                subplot(3,2,3)
                    ErrorW = (abs(idata.data.dcube)-abs(dcube))./idata.data.ecube;
%                     pcolor(idata.data.t + idata.data.effDead, idata.data.q, abs(dcube)*scaleV)
                    imagesc(abs(dcube)*scaleV)
                    a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                    axis ij; shading flat
                    set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                    if length(idata.data.q) > 2
                        set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                        %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                    else
                        set(gca,'yticklabel',"")
                    end
%                     set(gca,'yscale','log','xscale','log')
                    colorbar
                    title('abs(simulated voltages) /nV')
                    ylabel('{\itq} / As'); xlabel('{\itt} / s');
                    maxZ = max(max(abs(idata.data.dcube.')));
                    set(gca,'clim',([-maxZ/10 maxZ]*1.05*scaleV));
                    if length(idata.inv1Dqt.t) == length(idata.data.t)
                        subplot(3,2,5)
                        imagesc(ErrorW)
                        a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                        set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                        if length(idata.data.q) > 2
                            set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                            %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                        else
                            set(gca,'yticklabel',"")
                        end
                        axis ij; shading flat;colorbar
                        %set(gca,'Xscale','log','Yscale','log');
                        title([ 'error weighted data fit (chi^2 = ' ...
                        num2str(sqrt(sum(sum(ErrorW.^2)))/sqrt(numel(ErrorW))) ')'])
                        ylabel('q/A.s');xlabel('t/s');
                    end
                
            case 2 % rotated complex
                subplot(3,2,3)
                    ErrorW = (real(idata.data.dcube)-abs(dcube))./idata.data.ecube;
%                     pcolor(idata.data.t + idata.data.effDead, idata.data.q, abs(dcube)*scaleV)
                    imagesc(abs(dcube)*scaleV)
                    a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                    axis ij; shading flat
                    set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                    if length(idata.data.q) > 2
                        set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                        %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                    else
                        set(gca,'yticklabel',"")
                    end
%                     set(gca,'yscale','log','xscale','log')
                    colorbar
                    title('real(simulated voltages) /nV')
                    ylabel('{\itq} / As'); xlabel('{\itt} / s'); 
                    maxZ = max(max(abs(idata.data.dcube.')));
                    set(gca,'clim',([-maxZ/10 maxZ]*1.05*scaleV));
                    if length(idata.inv1Dqt.t) == length(idata.data.t)
                        subplot(3,2,5)
%                         pcolor(idata.data.t+idata.data.effDead,idata.data.q,ErrorW)
                        imagesc(ErrorW)
                        a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                        set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                        if length(idata.data.q) > 2
                            set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                            %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                        else
                            set(gca,'yticklabel',"")
                        end
                        axis ij; shading flat;colorbar
%                         set(gca,'Xscale','log','Yscale','log');
                        title([ 'error weighted data fit (chi^2 = ' ...
                        num2str(sqrt(sum(sum(ErrorW.^2)))/sqrt(numel(ErrorW))) ')'])
                        ylabel('q/A.s');xlabel('t/s');
                    end
                    
            case 3 % complex               
                subplot(3,2,3)
                    ErrorW = (real(idata.data.dcube)-real(dcube))./idata.data.ecube;
%                     pcolor(idata.data.t + idata.data.effDead, idata.data.q, real(dcube)*scaleV)
                    imagesc(real(dcube)*scaleV)
                    a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                    axis ij; shading flat
                    set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                    if length(idata.data.q) > 2
                        set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                        %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                    else
                        set(gca,'yticklabel',"")
                    end
%                     set(gca,'yscale','log','xscale','log')
                    colorbar
                    title('real(simulated voltages) /nV')
                    ylabel('{\itq} / As'); xlabel('{\itt} / s');
                    
                    maxZ = max(max(real(idata.data.dcube.')));
                    minZ = min(min(real(idata.data.dcube.')));
                    set(gca,'clim',([minZ maxZ]*1.05*scaleV));
                    if length(idata.inv1Dqt.t) == length(idata.data.t)
                        subplot(3,2,5)
%                         pcolor(idata.data.t+idata.data.effDead,idata.data.q,ErrorW)
                        imagesc(ErrorW)
                        a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                        axis ij; shading flat;colorbar
                        set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                        if length(idata.data.q) > 2
                            set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                            %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                        else
                            set(gca,'yticklabel',"")
                        end
                        title([ 'error weighted data fit (chi^2 = ' ...
                        num2str(sqrt(sum(sum(ErrorW.^2)))/sqrt(numel(ErrorW))) ')'])
%                         set(gca,'Xscale','log','Yscale','log');
                        ylabel('q/A.s');xlabel('t/s');
                    end
                subplot(3,2,4)
                    ErrorW = (imag(idata.data.dcube)-imag(dcube))./idata.data.ecube;
%                     pcolor(idata.data.t + idata.data.effDead, idata.data.q, imag(dcube)*scaleV)
                    imagesc(imag(dcube)*scaleV)
                    a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                    axis ij; shading flat
                    set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                    if length(idata.data.q) > 2
                        set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                        %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                    else
                        set(gca,'yticklabel',"")
                    end
%                     set(gca,'yscale','log','xscale','log')
                    colorbar
                    title('imag(simulated voltages) /nV')
                    ylabel('{\itq} / As'); xlabel('{\itt} / s');
                    maxZ = max(max(imag(idata.data.dcube.')));
                    minZ = min(min(imag(idata.data.dcube.')));
                    set(gca,'clim',([minZ maxZ]*1.05*scaleV));
                    if length(idata.inv1Dqt.t) == length(idata.data.t)
                        subplot(3,2,6)
%                         pcolor(idata.data.t+idata.data.effDead,idata.data.q,ErrorW)
                        imagesc(ErrorW)
                        a=get(gca,'xtick');a(a<1)=[];a=unique(floor(a));set(gca,'xtick',a)
                        set(gca,'xticklabel',num2str(0.01*round(100*(idata.data.effDead + idata.data.t(get(gca,'xtick')).'))))
                        if length(idata.data.q) > 2
                            set(gca,'yticklabel',compose('%.1E',idata.data.q(get(gca,'ytick'))))
                            %set(gca,'yticklabel',num2str(0.01*round(100*idata.data.q(get(gca,'ytick')))))
                        else
                            set(gca,'yticklabel',"")
                        end
                        axis ij; shading flat;colorbar
%                         set(gca,'Xscale','log','Yscale','log');
                        title([ 'error weighted data fit (chi^2 = ' ...
                        num2str(sqrt(sum(sum(ErrorW.^2)))/sqrt(numel(ErrorW))) ')'])
                        ylabel('q/A.s');xlabel('t/s');
                    end
                    
        end
        
        % estimated model
        % determine max. penetration depth cummalative kernel --> auken et al. ???
        cumK = (abs(cumsum(fliplr(idata.kernel.K*0.3),2))); % cumulative sensitivity, i.e. halfspace from bottom with 0.3 water content change 
        for iq=1:size(cumK,1)
            dummy       = idata.kernel.z(length(idata.kernel.z)+1-find(cumK(iq,:) > 2*mean(idata.data.estack),1));
            if ~isempty(dummy)
                penMaxZvec(iq) = dummy;
            else
                penMaxZvec(iq) = 0;
            end
        end
        penMaxZ = max(penMaxZvec);
        if isempty(penMaxZ); penMaxZ = idata.inv1Dqt.z(end);end;

        if isvalid(gui.fig_model)
            set(0,'currentFigure',gui.fig_model)
        else
            gui.fig_model = figure( ...
                'Position', [5+355 screensz(4)-800 400 720], ...
                'Name', 'MRS QT Inversion - Model', ...
                'NumberTitle', 'off', ...
                'Toolbar', 'figure', ...
                'HandleVisibility', 'on');
        end
        
        patches = true;

        %figure(gui.fig_model);
        clf;
        YL = [0 idata.para.maxDepth];
        switch idata.para.modelspace
            case 1
                logmeanT2 = exp(sum(M.*log(decaycube),2)./sum(M,2));
                subplot(1,10,1:6)
                    if length(idata.inv1Dqt.z) >1
                        z_vec = idata.inv1Dqt.z(1)/2 + [-idata.inv1Dqt.z(1)/2 idata.inv1Dqt.z];
                        contourf(idata.para.decaySpecVec,z_vec,[M;M(end,:)],100,"LineStyle","none")
                        %pcolor(idata.para.decaySpecVec,z_vec,[M;M(end,:)])
                        hold on
                        if patches & size(idata.inv1Dqt.solution,2) > 4
                            T2_std = std(sum(M_array.*log(decaycube),2)./sum(M_array,2),0,3);
                            T2_mean = mean(sum(M_array.*log(decaycube),2)./sum(M_array,2),3);
                            [T2up,z] = stairs(exp(T2_mean(1:end-1)+T2_std(1:end-1)),idata.inv1Dqt.z(1:end-1)');
                            [T2low,z] = stairs(exp(T2_mean(1:end-1)-T2_std(1:end-1)),idata.inv1Dqt.z(1:end-1)');
                            verts = [T2up(1),0;T2up, z; flipud(T2low), flipud(z);T2low(1),0;];
                            verts(verts<0) = 0;
                            faces = 1:1:size(verts,1);
                            patch('Faces',faces,'Vertices',verts,...
                                            'FaceColor',[0.6 0.6 0.6],...
                                            'FaceAlpha',0.25,'EdgeColor','none',...
                                            'DisplayName','mean (std)');
                            hold on
                        end
                        stairs([logmeanT2(1); logmeanT2(1:end-1)],[0 idata.inv1Dqt.z(1:end-1)],"Color","red")
                        hold off
                        cc=colorbar;set(get(cc,'YLabel'),'String', 'Partial water content/ m^3/m^3')
                        set(cc,'Location','westoutside')
                        clim([0 max(M(1:end-2,:),[],'all')])
                        ylim([YL])
                    else
                        plot(idata.para.decaySpecVec,M)
                        xline(logmeanT2)
                    end
                    axis ij;box on;shading flat;
                    set(gca,'Xscale','log');
                    set(gca,'layer','top')
                    xlabel('{\itT}_2^*/ s');ylabel('Depth/ m')
                    
                %{
                subplot(1,5,4)
                    stairs([logmeanT2(1); logmeanT2],[0 idata.inv1Dqt.z])
                    axis ij; set(gca,'Xscale','lin'); grid on
                    set(gca,'Xminorgrid','off'); box on
                    xlabel('Decay time T_2^*/ s')
                    ylim([YL])
                %}
                
                subplot(1,10,7:10)
                tw = sum(M,2);

                if patches & size(idata.inv1Dqt.solution,2) > 4
                    w_std = std([idata.inv1Dqt.solution(:).w],1,2);
                    w_mean = mean([idata.inv1Dqt.solution(:).w],2);
                    [wup,z] = stairs(w_mean + w_std,idata.inv1Dqt.z');
                    [wlow,z] = stairs(w_mean - w_std,idata.inv1Dqt.z');
                    verts = [wup(1),0;wup, z; flipud(wlow), flipud(z);wlow(1),0;];
                    verts(verts<0) = 0;
                    faces = 1:1:size(verts,1);
                    patch('Faces',faces,'Vertices',verts,...
                                    'FaceColor',[0.6 0.6 0.6],...
                                    'FaceAlpha',0.75,'EdgeColor','none',...
                                    'DisplayName','mean (std)');
                    hold on
                    stairs([tw(1); tw],[0 idata.inv1Dqt.z])
                    hold off
                    axis ij; grid on
                    xlabel('Water content/ m^3/m^3')
                    xlim([idata.para.lowerboundWater min(idata.para.upperboundWater,1.3)])
                    ylim([YL])
                    yticklabels([])
                else
                    stairs([tw(1); tw],[0 idata.inv1Dqt.z])
                    axis ij; grid on
                    xlabel('Water content/ m^3/m^3')
                    xlim([idata.para.lowerboundWater min(idata.para.upperboundWater,1.3)])
                    ylim([YL])
                    yticklabels([])
                end
            case 2
                subplot(1,5,1:2)
                        hold off
                subplot(1,5,4:5)
                        hold off
                patches = true;
                if patches & size(idata.inv1Dqt.solution,2) > 4
                    w_std = std([idata.inv1Dqt.solution(:).w],1,2);
                    w_mean = mean([idata.inv1Dqt.solution(:).w],2);
                    T2_std = std([idata.inv1Dqt.solution(:).T2],1,2);
                    T2_mean = mean([idata.inv1Dqt.solution(:).T2],2);
                    subplot(1,5,1:2)
                        [T2up,z] = stairs(T2_mean + T2_std,idata.inv1Dqt.z');
                        [T2low,z] = stairs(T2_mean - T2_std,idata.inv1Dqt.z');
                        verts = [T2up(1),0;T2up, z; flipud(T2low), flipud(z);T2low(1),0;];
                        verts(verts<1E-6) = 1E-6;
                        faces = 1:1:size(verts,1);
                        patch('Faces',faces,'Vertices',verts,...
                                        'FaceColor',[0.6 0.6 0.6],...
                                        'FaceAlpha',0.75,'EdgeColor','none',...
                                        'DisplayName','mean (std)');
                        hold on
                        stairs([T2_mean(1); T2_mean],[0 idata.inv1Dqt.z],'k','Linewidth',2)
                        axis ij; set(gca,'Xscale','log'); grid on
                        set(gca,'Xminorgrid','off');
                        xlabel('Decay time T_2^* /s')
                        ylim([YL])
                        xlim([idata.para.lowerboundT2 max([idata.para.upperboundT2 1])])
                        hold off
                    subplot(1,5,4:5)
                        [wup,z] = stairs(w_mean + w_std,idata.inv1Dqt.z');
                        [wlow,z] = stairs(w_mean - w_std,idata.inv1Dqt.z');
                        verts = [wup(1),0;wup, z; flipud(wlow), flipud(z);wlow(1),0;];
                        verts(verts<0) = 0;
                        faces = 1:1:size(verts,1);
                        patch('Faces',faces,'Vertices',verts,...
                                        'FaceColor',[0.6 0.6 0.6],...
                                        'FaceAlpha',0.75,'EdgeColor','none',...
                                        'DisplayName','mean (std)');
                        hold on
                        stairs([w_mean(1); w_mean],[0 idata.inv1Dqt.z],'k','Linewidth',2)
                        axis ij; grid on
                        xlabel('Water content / m^3/m^3')
                        xlim([idata.para.lowerboundWater idata.para.upperboundWater])
                        ylim([YL])
                        hold off
                else
                for irun = 1:length(idata.inv1Dqt.solution)
%                     if idata.inv1Dqt.solution(irun).dnorm < 1.05
                    T2        = abs(idata.inv1Dqt.solution(irun).T2);
                    %W         = idata.inv1Dqt.solution(k(irun)).w.*exp(idata.data.effDead./T2);
                    W         = abs(idata.inv1Dqt.solution(irun).w);
                    subplot(1,5,1:2)
                        if irun==1
                            stairs([T2(1); T2],[0 idata.inv1Dqt.z],'k','Linewidth',2)
                        else
                            stairs([T2(1); T2],[0 idata.inv1Dqt.z],'Color',[.6 .6 .6])
                        end
                        hold on
                        plot([idata.para.lowerboundT2 max([idata.para.upperboundT2 1])],[penMaxZ penMaxZ],'--k','Color',[.8 .8 .8],'Linewidth',2)
                        plot([0.1 0.1],[YL],'--','Color',[.8 .8 .8],'Linewidth',1);
                        axis ij; set(gca,'Xscale','log'); grid on
                        set(gca,'Xminorgrid','off');
                        xlabel('Decay time T_2^* /s')
                        ylim([YL])
                        xlim([idata.para.lowerboundT2 max([idata.para.upperboundT2 1])])
                    subplot(1,5,4:5)
                        if irun==1
                            stairs([W(1); W],[0 idata.inv1Dqt.z],'k','Linewidth',2)
                        else
                            stairs([W(1); W],[0 idata.inv1Dqt.z],'Color',[.6 .6 .6])
                        end
                        hold on
                        plot([idata.para.lowerboundWater idata.para.upperboundWater],[penMaxZ penMaxZ],'--k','Color',[.8 .8 .8],'Linewidth',2)
                        plot([0.1 0.1],[YL],'--','Color',[.8 .8 .8],'Linewidth',1);
                        %plot(W,idata.inv1Dqt.z)
                        axis ij; grid on
                        xlabel('Water content / m^3/m^3')
                        xlim([idata.para.lowerboundWater idata.para.upperboundWater])
                        ylim([YL])
%                     end
                end
                end
                
            case 3
                chi2plot = str2num(get(gui.para.minModelUpdate,'String')); % misfit limit for model to be plotted 
                misfit   = [];
                subplot(1,5,1:2)
                        hold off
                subplot(1,5,4:5)
                        hold off
                for irun = length(idata.inv1Dqt.solution):-1:1
                    if idata.inv1Dqt.solution(irun).dnorm < chi2plot
                        T2     = [idata.inv1Dqt.solution(irun).T2(1) idata.inv1Dqt.solution(irun).T2];
                        W      = [idata.inv1Dqt.solution(irun).w(1) idata.inv1Dqt.solution(irun).w];
                        Depth  = [0 cumsum(idata.inv1Dqt.solution(irun).thk) max(idata.inv1Dqt.z)];
                        misfit = [idata.inv1Dqt.solution(irun).dnorm misfit];
                        subplot(1,5,1:2)
                            if irun==1
                                stairs(T2,Depth,'k','Linewidth',2)
                            else
                                stairs(T2,Depth,'Color',[.6 .6 .6])
                            end
                            hold on
                            plot([idata.para.lowerboundT2 max([idata.para.upperboundT2 1])],[penMaxZ penMaxZ],'--k','Color',[.8 .8 .8],'Linewidth',2)
                            axis ij; set(gca,'Xscale','log'); grid on
                            set(gca,'Xminorgrid','off');
                            xlabel('Decay time T_2^* /s')
                            ylim([YL])
                            xlim([idata.para.lowerboundT2 max([idata.para.upperboundT2 1])])
                        subplot(1,5,4:5)
                            if irun==1
                                stairs(W,Depth,'k','Linewidth',2)
                            else
                                stairs(W,Depth,'Color',[.6 .6 .6])
                            end
                            hold on
                            plot([idata.para.lowerboundWater idata.para.upperboundWater],[penMaxZ penMaxZ],'--k','Color',[.8 .8 .8],'Linewidth',2)
                            axis ij; grid on
                            xlabel('Water content / m^3/m^3')
                            xlim([idata.para.lowerboundWater idata.para.upperboundWater])
                            ylim([YL])
                
                    end
                end
                figure(100); plot(misfit,'x'); title('distribution of misfit for all models'); ylabel('chi^2'); xlabel('run');
        end
        
    end
end
drawnow


