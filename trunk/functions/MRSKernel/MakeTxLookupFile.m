function [TxLookup] = MakeTxLookupFile(measure,earth)

if isfield(measure,'TxLookup')
    measure = rmfield(measure,{'TxLookup'});
end

gui_flag = true;

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

inkl = earth.inkl/360.0*2.0*pi;
decl = earth.decl/360.0*2.0*pi;

% Umrechnung von Kugelkoordinaten in kartesische
B0.x = cos(inkl) * cos(-decl);
B0.y = cos(inkl) * sin(-decl);
B0.z = + sin(inkl); % z positiv nach unten!

pm_vec = measure.pm_vec;
taup = measure.taup1;
Imax_vec = pm_vec/taup;

iq_show = [];

if ~isempty(iq_show)
    fh = findobj( 'Type', 'Figure', 'Name', 'TxLookups' );
    if isempty(fh)
        h.mainfig = figure('Name','TxLookups','units','normalized', 'OuterPosition',[0 0 1 1]);
    else
        h.mainfig = fh;
        clf(h.mainfig)
    end
    h.tabgroup = uitabgroup(h.mainfig, 'Position', [.0 .0 1 1]);
    ntabs = length(iq_show);
    for iq = 1:ntabs
        h.tab(iq) = uitab(h.tabgroup, 'Title', int2str(iq_show(iq)));
    end
end

if decl ~= 0
    warning("Declination not yet implemented for Pulse File")
end

if gui_flag
    set(tmpgui.panel_controls.edit_status,'String',...
        ['start calculating ' num2str(length(measure.Pulse)) ' pulse shapes']);
    drawnow;
end

Bper = [-1*logspace(1,-3,150)*earth.erdt,-1E-10,1E-10,logspace(-3,1,150)*earth.erdt];
Bpar = [-1*logspace(1,-3,150)*earth.erdt,-1E-10,1E-10,logspace(-3,1,150)*earth.erdt];

t_total = tic;

for iq = 1:length(measure.Pulse)
    %prepare BLOCHUS
    pyBLOCHUSinput.B0=B0;
    pyBLOCHUSinput.iq=iq-1; %-1 because of python
    pyBLOCHUSinput.Imax=1;
    pyBLOCHUSinput.earth=earth;
    pyBLOCHUSinput.TxSign = 1;
    phase = 0;

    if isfield(measure,'Txphase')
        phase = phase + measure.Txphase(iq)-pi/2; %set phase from field data for MRSKernel calc, for pyBLOCHUS this information is included in the pulse shapes
        Idealt = [[measure.Pulse(iq).t(measure.Pulse(iq).t<measure.taup1)]'; measure.taup1];
        IdealShape = -cos(earth.w_rf*Idealt-phase); IdealShape(Idealt>measure.taup1) = 0;
        %measure.Pulse(iq).Shape = measure.Pulse(iq).Shape/Imax_vec(iq);
        measure.Pulse(iq).Shape = (measure.Pulse(iq).Shape - mean(measure.Pulse(iq).Shape(end-10:end)))/Imax_vec(iq); %zero with average at end
        %measure.Pulse(iq).Shape(1:length(Idealt)) = IdealShape;
        %figure(457); plot(measure.Pulse(iq).t,measure.Pulse(iq).Shape,"LineWidth",1.5); hold on; plot(Idealt,IdealShape,"LineWidth",1.5); xline(taup); hold off
        %xlabel("{\itt} / ms");ylabel("{\itI}_{eff} / A");
        %measure.Pulse(iq).t = Idealt;
        %measure.Pulse(iq).Shape = IdealShape;
    end
    pyBLOCHUSinput.phase = phase;
    pyBLOCHUSinput.measure=measure;

    Threshold4Blochus=0;
    path2py = which('MRS_python_BLOCHUS7.py'); %<- version using full Pulseshape
    
    B1.x = repmat(Bper'*sin(inkl) * cos(-decl),[size(Bpar)])+repmat(Bpar'*cos(inkl),[size(Bper)])'* cos(-decl);
    B1.y = repmat(Bper'*sin(inkl) * sin(-decl),[size(Bpar)])+repmat(Bpar'*cos(inkl),[size(Bper)])'* sin(-decl);
    B1.z = repmat(Bpar'*sin(inkl),[size(Bper)])' + repmat(Bper'*cos(inkl) *-1 * cos(-decl),[size(Bpar)]);
    B1.phi = zeros(size(Bper));
    B1.r = zeros(size(Bpar))';

    pyBLOCHUSinput.B1 = B1; % currently not working with complex B1 because JSON does not want imagninary parts
    pyBLOCHUSinput.pick=ones(size(B1.x));

    ratio = sqrt(B1.x.^2+B1.y.^2+B1.z.^2)/earth.erdt;
    pick4Blochus = max(ratio>Threshold4Blochus,[],1);
    
    if ismember(iq,iq_show)
        i = find(iq_show == iq);
        wall(i)=tiledlayout(4,4,'Padding','none','TileSpacing','compact','Parent',h.tab(i),'TileIndexing', 'columnmajor');
    end
    for idim = 1:3
        t_z = tic;
        M0 = [0 0 0];
        M0(idim) = 1;
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
        TxLookup.M(iq,idim,:,:,:) = results.M;
        if ismember(iq,iq_show)
            i = find(iq_show == iq);
            for jdim = 1:3
                nexttile(wall(i))
                contourf(Bpar/earth.erdt,Bper/earth.erdt,results.M(:,:,jdim))
            end
            nexttile(wall(i))
            contourf(Bpar/earth.erdt,Bper/earth.erdt,squeeze(vecnorm(results.M(:,:,:),2,3)))
        end
        % calc time approximation:
        tnow = toc(t_total);
        tavg = tnow/(idim+(iq-1)*3);%toc(t_z);
        trem = tavg*(length(measure.Pulse)*3-(idim+(iq-1)*3));
        if gui_flag
            set(tmpgui.panel_controls.edit_status,'String',...
                {['Calculation of Pulse',num2str(iq),' out of ',num2str(length(measure.Pulse)),' done.'],...
                ['Elapsed time: ',sprintf('%4.2f',tnow),'s'],...
                ['Remaining time: ',sprintf('%4.2f',trem),'s']});
            drawnow;
        end
    end
    if ismember(iq,iq_show)
        for jdim = 1:3
            nexttile(wall(i))
            contourf(Bpar/earth.erdt,Bper/earth.erdt,squeeze(vecnorm(TxLookup.M(iq,:,:,:,jdim),2,2)))
        end
    end

end

if gui_flag
    close(tmpgui.panel_controls.figureid);
end

TxLookup.measure = measure;
TxLookup.earth = earth;
TxLookup.Bper = Bper;
TxLookup.Bpar = Bpar;

fprintf(1,'Tx lookup table created\n');