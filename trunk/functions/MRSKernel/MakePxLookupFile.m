function [PxLookup] = MakePxLookupFile(measure,earth)

if isfield(measure,'PxLookup')
    measure = rmfield(measure,{'PxLookup'});
end

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


if decl ~= 0
    warning("Declination not yet implemented for Px Lookup")
end

colors=[0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250; 0.4940 0.1840 0.5560; 0.4660 0.6740 0.1880; 0.3010 0.7450 0.9330; 0.6350 0.0780 0.1840; 0 0 1; 0 1 0; 1 0 0; 1 1 0; 0 1 1; 1 0 1; 0.5 0.5 0.5];

t_total = tic;
nRamp = 0;

multiramp = true;
if multiramp
    nileave = measure.nileaves;
    nrec = measure.nrec;
    nq = length(measure.Ramp); %until here: used for interleavewise separation of Ramps to average closest ramps together
    nsep = 2; %additional separation

    Shape = zeros(nileave*nrec*nsep,size(measure.Ramp(1).Shape(1,:),2));
    
    for irec = 1:nrec
        for iileave = 1:nileave
            qstart = nileave - (iileave-1);
            for isep = 1:nsep
                for iq = qstart+(isep-1)*nq/nsep:nileave:isep*nq/nsep
                    if ~any(isnan(measure.Ramp(iq).Shape))
                        Shape((irec-1)*nileave*nsep+(iileave-1)*nsep+isep,:) = Shape((irec-1)*nileave*nsep+(iileave-1)*nsep+isep,:) + measure.Ramp(iq).Shape(irec,:);
                    end
                end
            end
        end
    end
    nRamp = nq/nileave/nsep;
    Shape = Shape/nRamp;
    %}
    %{
    for irec = 1:nrec %1:size(measure.Ramp(iq).Shape,1)
        for iq = 1:nq
            Shape((irec-1)*nq + iq,:) = measure.Ramp(iq).Shape(irec,:);
        end
    end
    %}
    
    t = measure.Ramp(1).t;
else
    Shape(1,:) = measure.Ramp(1).Shape(1,:),5;
    t = measure.Ramp(1).t,5;
    %Shape(1,:) = downsample(measure.Ramp(1).Shape(1,:),5);
    %t = downsample(measure.Ramp(1).t,5);
    %warning("Downsampled ramp")
end

for iRamp = 1:size(Shape,1)
    %prepare BLOCHUS
    pyBLOCHUSinput.B0=B0;
    pyBLOCHUSinput.iq=iRamp-1; %-1 because of python
    pyBLOCHUSinput.Imax=1;
    pyBLOCHUSinput.earth=earth;
    pyBLOCHUSinput.TxSign = 1;
    phase = 0;

    measure.Pulse(iRamp).Shape = Shape(iRamp,:)/(max(Shape(iRamp,:)));
    measure.Pulse(iRamp).t = t;

    pyBLOCHUSinput.phase = 0;
    measure.parallelM0 = true;
    pyBLOCHUSinput.measure=measure;

    Threshold4Blochus=0;
    path2py = which('MRS_python_BLOCHUS7.py'); %<- version using full Pulseshape

    Bper = [-1*logspace(4,-2,200)*earth.erdt, logspace(-2,4,200)*earth.erdt];
    Bpar = [-1*logspace(4,-2,200)*earth.erdt, logspace(-2,4,200)*earth.erdt];

    B1.x = repmat(Bper'*sin(inkl) * cos(-decl),[size(Bpar)])+repmat(Bpar'*cos(inkl),[size(Bper)])'* cos(-decl);
    B1.y = repmat(Bper'*sin(inkl) * sin(-decl),[size(Bpar)])+repmat(Bpar'*cos(inkl),[size(Bper)])'* sin(-decl);
    B1.z = repmat(Bpar'*sin(inkl),[size(Bper)])' + repmat(Bper'*cos(inkl) *-1 * cos(-decl),[size(Bpar)]);
    B1.phi = zeros(size(Bper));
    B1.r = zeros(size(Bpar))';

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
    PxLookup.M(iRamp,:,:,:) = results.M;

    % calc time approximation:
    tnow = toc(t_total);
    tavg = tnow/(iRamp);%toc(t_z);
    trem = tavg*(size(Shape,1)-iRamp);
    if gui_flag
        set(tmpgui.panel_controls.edit_status,'String',...
            {['Calculation of Ramp ',num2str(iRamp),' out of ',num2str(size(Shape,1)),' done.'],...
            ['Elapsed time: ',sprintf('%4.2f',tnow),'s'],...
            ['Remaining time: ',sprintf('%4.2f',trem),'s']});
        drawnow;
    end
end

if gui_flag
    close(tmpgui.panel_controls.figureid);
end

PxLookup.measure = measure;
PxLookup.earth = earth;
PxLookup.Bper = Bper;
PxLookup.Bpar = Bpar;
PxLookup.Shape = Shape;
fprintf(1,'Px lookup table created\n');