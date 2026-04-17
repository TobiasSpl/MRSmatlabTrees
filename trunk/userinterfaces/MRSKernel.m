function kfile = MRSKernel(sounding_pathdirfile)

kfig = findobj('Name', 'MRS Kernel');
if ~isempty(kfig)
    delete(kfig)
end

if nargin > 0  % i.e. command comes from MRSWorkflow
    standalone = 0;
else
    standalone = 1;
end

proclog = struct();
if nargin > 0  % i.e. command comes from MRSWorkflow
    % set path; execute initialize
    kfile = '';
    kpath = '';
    Initialize();
    kdata = createData();
    gui   = createInterface();
    % activate Quit and save
    child = get(gui.QuitMenu,'Children');
    set(child(2),'Enable','on')
else
    kfile = -1;
    kdata = createData();
    gui   = createInterface();
end

    function kdata = createData()
        kdata = get_defaults();     
        if isfield(proclog, 'Q')
            kdata.loop.shape  = proclog.txinfo.looptype;
            kdata.loop.size   = proclog.txinfo.loopsize; % be careful circular loop size is diameter
            kdata.loop.turns = proclog.txinfo.loopturns;
            kdata.loop.size   = proclog.rxinfo.loopsize; % be careful circular loop size is diameter
            kdata.loop.turns = proclog.rxinfo.loopturns;
            kdata.measure.pm_vec = [];
            kdata.measure.pm_vec_2ndpulse = [];
            for m = 1:length(proclog.Q)
                kdata.measure.pm_vec(m) = proclog.Q(m).q;
            end
            kdata.earth.f         = proclog.Q(1).fT;
        end
        kdata.model.zmax      =  1.5*kdata.loop.size;
        kdata.model.z_space   =  1;
        kdata.model.nz        =  4*length(kdata.measure.pm_vec);
        kdata.model.sinh_zmin =  kdata.loop.size/500;
        kdata.model.LL_dzmin  =  kdata.loop.size/500; 
        kdata.model.LL_dzmax  =  kdata.loop.size/50;
        kdata.model.LL_dlog   =  kdata.loop.size/5;
        kdata.model           =  MakeZvec(kdata.model);
        kdata.earth.w_rf      =  kdata.earth.f*2*pi;
        kdata.earth.erdt      =  kdata.earth.w_rf/kdata.gammaH;
    end

    function gui = createInterface()
        % Create the user interface for the application and return a
        % structure of handles for global use.
        gui = struct();
        % Open a window and add some menus
        gui.Window = figure( ...
            'Name', 'MRS Kernel', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Toolbar', 'none', ...
            'HandleVisibility', 'on' );
        
        pos    = get(gui.Window,'Position');
        posout = get(gui.Window,'OuterPosition');
        frame = posout - pos;
        scrsize = get(0,'ScreenSize');
        set(gui.Window,'Position',[5 scrsize(4)-560 1000 500])
        
        % + File menu
        gui.QuitMenu = uimenu(gui.Window,'Label','Quit');
        uimenu(gui.QuitMenu, ...
            'Label', 'Save and Quit','Enable','off',...
            'Callback', @onSaveAndQuit);
        uimenu(gui.QuitMenu,...
            'Label','Quit without saving',...
            'Callback',@onQuitWithoutSave);
        
        % + File menu
        gui.FileMenu = uimenu(gui.Window,'Label','File');
        gui.ImportMenu = uimenu(gui.Window,'Parent',gui.FileMenu,'Label','Import Parameter');
        uimenu(gui.ImportMenu,'Label','from field data','Callback', @loadData);
        uimenu(gui.ImportMenu,'Label','from existing kernel','Callback', @loadKernel);
        uimenu(gui.Window,'Parent',gui.FileMenu,'Label','Save Kernel as','Callback',@onSaveK,'Enable','off');
                
        % + Kernel menu
        gui.KernelMenu = uimenu(gui.Window,'Label','Kernel');
        uimenu(gui.KernelMenu,'Label','Make','Callback', @makeK);
        uimenu(gui.KernelMenu,'Label','Show kernel','Callback',@viewK,'Enable','off');

        % + Help menu
        gui.helpMenu = uimenu(gui.Window,'Label','Help');
        uimenu(gui.helpMenu,'Label','Documentation','Callback',@onHelp);
        
        set(gui.Window,'CloseRequestFcn',@onQuit)
               
        % create boxes for the parameters
        b = uiextras.HBox('Parent',gui.Window);
        
        % + Loop parameters
        %loopw = [85 65];
        loopw = [85 -1];
        %uiloopp  = uiextras.BoxPanel('Parent', b, 'Title', 'Loop');
        %uiloopv  = uiextras.VBox('Parent', uiloopp);
        
        uiloop1 = uiextras.VBox('Parent', b);
        uiloopp = uiextras.BoxPanel('Parent',uiloop1,'Title','Tx / Rx Loop');
        uiloopv = uiextras.VBox('Parent', uiloopp,'Padding',3,'Spacing',3);

        uilooph0 = uiextras.HBox( 'Parent', uiloopv);
        gui.TreeSizeString = uicontrol('Style', 'Text', ...
            'Parent', uilooph0, ...
            'String', 'Tree Diameter [m]');
        gui.TreeSize = uicontrol('Style', 'Edit', ...
            'Parent', uilooph0, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.size), ...
            'Callback', @onLoopSize);
        set(uilooph0, 'Sizes', [150 -1])
        
        uilooph1 = uiextras.HBox('Parent',uiloopv);
        uicontrol('Style','Text','Parent',uilooph1,'String','Loop shape');
        gui.LoopShape = uicontrol('Style', 'popupmenu', ...
            'Parent', uilooph1, ...
            'String', {'InLoop'},...
            'Value', 1, ...
            'Callback', @onLoopShape);
        set(uilooph1, 'Sizes', [150 -1])
        
        uilooph2 = uiextras.HBox( 'Parent', uiloopv);
        gui.LoopSizeString = uicontrol('Style', 'Text', ...
            'Parent', uilooph2, ...
            'String', 'Diameter [m]');
        gui.LoopSizeTx = uicontrol('Style', 'Edit', ...
            'Parent', uilooph2, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.size), ...
            'Callback', @onLoopSize);
        gui.LoopSizeRx = uicontrol('Style', 'Edit', ...
            'Parent', uilooph2, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.size), ...
            'Callback', @onLoopSize);
        set(uilooph2, 'Sizes', [150 -1 -1])
        
        uilooph3 =  uiextras.HBox( 'Parent', uiloopv);
        gui.LoopTurnsString = uicontrol('Style', 'Text', ...
            'Parent', uilooph3, ...
            'String', '# Turns (Tx / Rx)');
        gui.LoopTurnsTx = uicontrol('Style', 'Edit', ...
            'Parent', uilooph3, ...
            'String', num2str(kdata.loop.turns), ...
            'Callback', @onLoopTurns);
        gui.LoopTurnsRx = uicontrol('Style', 'Edit', ...
            'Parent', uilooph3, ...
            'String', num2str(kdata.loop.Rxturns), ...
            'Callback', @onLoopTurns);
        set(uilooph3, 'Sizes', [150 -1 -1])
        
        % set all hbox heights
        set(uiloopv, 'Sizes', [24 26 26 26]);
        %<-Tobias
        
        % Pre-polarization loop parameters:
        uilooppre  = uiextras.BoxPanel('Parent', uiloop1, 'Title', 'Prepolarisation Loop');
        uiloopprev  = uiextras.VBox('Parent', uilooppre,'Padding',3,'Spacing',3);
        
        uilooph11 =  uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
        uicontrol('Style', 'Text', 'Parent', uilooph11, 'String', 'Px pulse on / off');
        gui.PXcheck = uicontrol('Style', 'popupmenu', ...
            'Parent', uilooph11, ...
            'Enable', 'on', ...
            'String', {'off', 'on',},...
            'Value', kdata.measure.PX+1, ...
            'Callback', @onPXcheck);
        set(uilooph11, 'Sizes', [150 -1]);
        
        uilooph12 =  uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
        uicontrol('Style', 'Text', 'Parent', uilooph12, 'String', 'Px shape');
        gui.PXshape = uicontrol('Style', 'popupmenu', ...
            'Parent', uilooph12, ...
            'Enable', 'off', ...
            'String', {'circular'},...
            'Callback', @onPXshape);
        set(uilooph12, 'Sizes', [150 -1])
        
        uilooph13 =  uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
        uicontrol('Style', 'Text', 'Parent', uilooph13, 'String', 'Px diameter [m]');
        gui.PXsize = uicontrol('Style', 'Edit', ...
            'Parent', uilooph13, ...
            'Enable', 'off', ...
            'String', '2',...
            'Callback', @onPXsize);
        set(uilooph13, 'Sizes', [150 -1])
        
        uilooph14 =  uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
        uicontrol('Style', 'Text', 'Parent', uilooph14, 'String', 'Px current [A] / # turns');
        gui.PXcurrent = uicontrol('Style', 'Edit', ...
            'Parent', uilooph14, ...
            'Enable', 'off', ...
            'String', '20',...
            'Callback', @onPXcurrent);
        gui.PXturns = uicontrol('Style', 'Edit', ...
            'Parent', uilooph14, ...
            'Enable', 'off', ...
            'String', '50',...
            'Callback', @onPXcurrent);
        set(uilooph14, 'Sizes', [150 -1 -1])

%         uilooph15 =  uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
%         uicontrol('Style', 'Text', 'Parent', uilooph15, 'String', 'Px eight-dir [°] (0 = N)');
%         gui.PX8dir = uicontrol('Style', 'Edit', ...
%             'Parent', uilooph15, ...
%             'Enable', 'off', ...
%             'String', '',...
%             'Callback', @onPX8dir);
%         set(uilooph15, 'Sizes', [150 -1])
        
        uilooph16 =  uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
        uicontrol('Style', 'Text', 'Parent', uilooph16, 'String', 'Px ramp / ramp time');
        gui.PXramp = uicontrol('Style', 'popupmenu', ...
            'Parent', uilooph16, ...
            'Enable', 'off', ...
            'String', {'off', 'MIDI','LIN','LIN&EXP','EXP','GMR Flex'},...
            'Value', 1, ...
            'Callback', @onPXramp);
        gui.PXramptime = uicontrol('Style', 'popupmenu', ...
            'Parent', uilooph16, ...
            'Enable', 'off', ...
            'String', {'1 ms', '2 ms','3 ms','4 ms'},...
            'Value', 1, ...
            'Callback', @onPXramptime);
        set(uilooph16, 'Sizes', [150 -1 -1]);
        
        uilooph17 =  uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
        uicontrol('Style', 'Text', 'Parent', uilooph17, 'String', 'Px-Tx-delay [ms]');
        gui.PXdelay = uicontrol('Style', 'Edit', ...
            'Parent', uilooph17, ...
            'Enable', 'off', ...
            'String', '0',...
            'Callback', @onPXdelay);
        set(uilooph17, 'Sizes', [150 -1])
        
        uilooph18 = uiextras.HBox( 'Parent', uiloopprev);
        uicontrol('Style', 'Text', 'Parent', uilooph18, 'String', 'Px lookup table');

        uilooph19 = uiextras.HBox( 'Parent', uiloopprev,'Spacing',3);
        gui.calcLookupPP = uicontrol('Style', 'pushbutton', 'Parent', uilooph19, 'String', 'calc.', 'Callback', @onMeasCalcLookupPP);
        gui.saveLookupPP = uicontrol('Style', 'pushbutton', 'Parent', uilooph19, 'String', 'save','Enable', 'off', 'Callback', @onMeasSaveLookupPP);
        gui.loadLookupPP = uicontrol('Style', 'pushbutton', 'Parent', uilooph19, 'String', 'load', 'Callback', @onMeasLoadLookupPP);
        gui.resetLookupPP = uicontrol('Style', 'pushbutton', 'Parent', uilooph19, 'String', 'reset','Enable', 'off', 'Callback', @onMeasResetLookupPP);
        
        uilooph20 = uiextras.HBox( 'Parent', uiloopprev); %#ok<*NASGU>
        set(uiloopprev, 'Sizes', [24 24 26 26 24 26 24 24 -1]);
        set(uiloop1,'Sizes',[-1 -1]);
        
        
        % + measurement parameter
        uimeasp1 = uiextras.VBox('Parent', b);
        uimeasp = uiextras.BoxPanel('Parent', uimeasp1, 'Title', 'Tx Meas. Parameter');       
        uimeasv = uiextras.VBox('Parent', uimeasp,'Padding',3,'Spacing',3);
        
        uimeasv01_1 = uiextras.HBox( 'Parent', uimeasv);
        uicontrol('Style', 'Text', 'Parent', uimeasv01_1, ...
            'String', 'Pulse sequence' );
        gui.pulsesequence = uicontrol('Style', 'popupmenu', ...
                'Parent', uimeasv01_1, ...
                'String', {'FID'},...
                'Value', kdata.measure.pulsesequence, ...
                'Callback', @onEditPulseSequence);
        set(uimeasv01_1, 'Sizes', [150 -1]) 
        
        uimeasv01_2 =  uiextras.HBox( 'Parent', uimeasv);
        uicontrol('Style', 'Text', 'Parent', uimeasv01_2, ...
            'String', 'Pulse type' );
        gui.pulsetype = uicontrol('Style', 'popupmenu', ...
                'Parent', uimeasv01_2, ...
                'String', {'standard'},...
                'Value', kdata.measure.pulsetype, ...
                'Callback', @onEditPulseType);
        set(uimeasv01_2, 'Sizes', [150 -1])

        uimeasv01_3 =  uiextras.HBox( 'Parent', uimeasv);
        uicontrol('Style', 'Text', 'Parent', uimeasv01_3, ...
            'String', 'Pulse sign' );
        gui.pulsesign = uicontrol('Style', 'popupmenu', ...
                'Parent', uimeasv01_3, ...
                'String', {'standard','+','-'},...
                'Value', kdata.measure.pulsetype, ...
                'Callback', @onEditPulseSign);
        set(uimeasv01_3, 'Sizes', [150 -1])

        uimeasv02_1 =  uiextras.HBox( 'Parent', uimeasv);
        uicontrol('Style', 'Text', 'Parent', uimeasv02_1, ...
            'String', 'Pulse duration [s]' );
        gui.edit_taup1 = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uimeasv02_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.measure.taup1), ...
            'Callback', @ontaup1CellEdit);
        set(uimeasv02_1, 'Sizes', [150 -1])
        
        uimeasv02_2 =  uiextras.HBox( 'Parent', uimeasv);
        uicontrol('Style', 'Text', 'Parent', uimeasv02_2, ...
            'String', 'Off-resonance freq. [Hz]' );
        gui.edit_df = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uimeasv02_2, ...
            'Enable', 'on', ...
            'String', num2str(kdata.measure.df), ...
            'Callback', @oneditdf);    
        set(uimeasv02_2, 'Sizes', [150 -1])
    
        uimeasv03_1 =  uiextras.HBox( 'Parent', uimeasv);
        gui.advancedAP = uicontrol(...
            'Style', 'pushbutton',...
            'Parent', uimeasv03_1,...
            'String', 'Advanced adiabatic pulse settings',...
            'Enable', 'off', ...
            'Callback', @drawpulseshape);
%         set(uimeasv03_1, 'Sizes', [-1])  
        
        uimeasw04 = uiextras.HBox( 'Parent', uimeasv);
        gui.MeasQvec = uitable('Parent', uimeasw04);
        set(gui.MeasQvec, ...
            'Data', [(1:length(kdata.measure.pm_vec))' kdata.measure.pm_vec' (kdata.measure.Imax_vec)'], ...  % initial value
            'ColumnName', {'#', 'q [As]', 'max(I) [A]'}, ...
            'ColumnWidth', {40 80 80}, ...
            'RowName', [], ...
            'ColumnEditable', false);
        
        uimeasw05 = uiextras.HBox( 'Parent', uimeasv);
        gui.loadq = uicontrol('Style', 'pushbutton', 'Parent', uimeasw05, 'String', 'load pulse shape', 'Callback', @onMeasLoadQ);
        gui.setq = uicontrol('Style', 'pushbutton', 'Parent', uimeasw05, 'String', 'set q', 'Callback', @onMeasSetQ);
        set(uimeasw05, 'Sizes', [150 -1])

        uimeasw06 = uiextras.HBox( 'Parent', uimeasv);
        uicontrol('Style', 'Text', 'Parent', uimeasw06, 'String', 'Tx lookup table');

        uimeasw07 = uiextras.HBox( 'Parent', uimeasv);
        gui.calcLookup = uicontrol('Style', 'pushbutton', 'Parent', uimeasw07, 'String', 'calc.', 'Callback', @onMeasCalcLookup);
        gui.saveLookup = uicontrol('Style', 'pushbutton', 'Parent', uimeasw07, 'String', 'save','Enable', 'off', 'Callback', @onMeasSaveLookup);
        gui.loadLookup = uicontrol('Style', 'pushbutton', 'Parent', uimeasw07, 'String', 'load', 'Callback', @onMeasLoadLookup);
        gui.resetLookup = uicontrol('Style', 'pushbutton', 'Parent', uimeasw07, 'String', 'reset','Enable', 'off', 'Callback', @onMeasResetLookup);

        set(uimeasv, 'Sizes', [24 24 24 26 26 26 -1 26 14 26])

        % + earth parameter
        earthw = [150 -1];
        
        uiearthp = uiextras.BoxPanel('Parent', b, 'Title', 'Earth');        
        eV1  = uiextras.VBox('Parent', uiearthp,'Padding',3,'Spacing',3);
        
        eV1Hmag = uiextras.HBox('Parent', eV1);
        uicontrol('Style', 'text', 'Parent', eV1Hmag, 'String', 'B_0 magnitude [nT]')
        gui.EarthB0 = uicontrol('Style', 'edit', ...
            'Parent', eV1Hmag, ...
            'String', num2str(round(kdata.earth.erdt*1e9*10000)/10000), ...
            'Callback', @onEarthB0);
        set(eV1Hmag, 'Sizes', earthw)
        
        eV1Hfreq = uiextras.HBox('Parent', eV1);
        uicontrol('Style', 'text', 'Parent', eV1Hfreq, 'String', 'Larmor frequency [Hz]')
        gui.EarthF = uicontrol('Style', 'edit', 'Parent', eV1Hfreq, 'String', num2str(round(kdata.earth.f*10000)/10000), 'Callback', @onEarthW0);
        set(eV1Hfreq, 'Sizes', earthw)
        
        eV1Hincl = uiextras.HBox('Parent', eV1);
        uicontrol('Style', 'text', 'Parent', eV1Hincl, 'String', 'B_0 inclination [°]')
        gui.EarthInkl = uicontrol('Style', 'edit', 'Parent', eV1Hincl, 'String', num2str(kdata.earth.inkl), 'Callback', @onEarthInkl);
        set(eV1Hincl, 'Sizes', earthw)
        
        eV1Hdecl = uiextras.HBox('Parent', eV1);
        uicontrol('Style', 'text', 'Parent', eV1Hdecl, 'String', 'B_0 declination [°] (0 = N)')
        gui.EarthDecl= uicontrol('Style', 'edit', 'Parent', eV1Hdecl, 'String', num2str(kdata.earth.decl), 'Callback', @onEarthDecl);
        set(eV1Hdecl, 'Sizes', earthw)
        
        eV1AqT = uiextras.HBox('Parent', eV1);
        uicontrol('Style', 'text', 'Parent', eV1AqT, 'String', 'Temperature')
        gui.AquaTemp= uicontrol('Style', 'edit', 'Parent', eV1AqT, 'String', num2str(kdata.earth.temp), 'Callback', @onEarthAqT);
        set(eV1AqT, 'Sizes', earthw)
        
        set(eV1, 'Sizes', [26 26 26 26 26]);
        
        %set(b, 'Sizes', [150 180 200 210])
        uiaddp1 = uiextras.VBox('Parent', b);
        uiaddp = uiextras.BoxPanel('Parent', uiaddp1, 'Title', 'Additional Parameters');
        uiaddv = uiextras.VBox('Parent', uiaddp,'Padding',3,'Spacing',3);
        
        uiaddv01_1 = uiextras.HBox( 'Parent', uiaddv);
        gui.check_BS = uicontrol(...
            'Style', 'Checkbox', ...
            'Parent', uiaddv01_1, ...
            'Enable', 'on', ...
            'Value', kdata.measure.applyBS, ...
            'String', 'Bloch-Siegert Shift', ...
            'Callback', @onEditAdd);
        set(uiaddv01_1, 'Sizes', [-1])

        uiaddv03_1 = uiextras.HBox( 'Parent', uiaddv);
        gui.check_K3Dzphir = uicontrol(...
            'Style', 'Checkbox', ...
            'Parent', uiaddv03_1, ...
            'Enable', 'on', ...
            'Value', kdata.measure.K3Dzphir, ...
            'String', 'generate z, phi and r Kernels', ...
            'Callback', @onEditAdd);
        set(uiaddv03_1, 'Sizes', [-1])
        
        uiaddv04_1 = uiextras.HBox( 'Parent', uiaddv);
        gui.check_K3Dslices = uicontrol(...
            'Style', 'Checkbox', ...
            'Parent', uiaddv04_1, ...
            'Enable', 'on', ...
            'Value', kdata.measure.K3Dslices, ...
            'String', 'generate NS and EW slices', ...
            'Callback', @onEditAdd);
        set(uiaddv04_1, 'Sizes', [-1])

        uiaddv06_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv06_1, ...
            'String', 'Tx vertical offset [m]' );
        gui.edit_Txzoff = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv06_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Tx_zoff), ...
            'Callback', @onEditAdd);
        set(uiaddv06_1, 'Sizes', [150 -1])

        uiaddv07_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv07_1, ...
            'String', 'Rx vertical offset [m]' );
        gui.edit_Rxzoff = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv07_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Rx_zoff), ...
            'Callback', @onEditAdd);
        set(uiaddv07_1, 'Sizes', [150 -1])

        uiaddv08_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv08_1, ...
            'String', 'Px vertical offset [m]' );
        gui.edit_Pxzoff = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv08_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Px_zoff), ...
            'Callback', @onEditAdd);
        set(uiaddv08_1, 'Sizes', [150 -1])

        uiaddv09_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv09_1, ...
            'String', 'Tx vertical extent [m]' );
        gui.edit_Txzext = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv09_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Tx_zext), ...
            'Callback', @onEditAdd);
        set(uiaddv09_1, 'Sizes', [150 -1])

        uiaddv10_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv10_1, ...
            'String', 'Rx vertical extent [m]' );
        gui.edit_Rxzext = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv10_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Rx_zext), ...
            'Callback', @onEditAdd);
        set(uiaddv10_1, 'Sizes', [150 -1])

        uiaddv11_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv11_1, ...
            'String', 'Px vertical extent [m]' );
        gui.edit_Pxzext = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv11_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Px_zext), ...
            'Callback', @onEditAdd);
        set(uiaddv11_1, 'Sizes', [150 -1])

        uiaddv12_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv12_1, ...
            'String', 'Tx vertical elements' );
        gui.edit_Txnz = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv12_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Tx_nz), ...
            'Callback', @onEditAdd);
        set(uiaddv12_1, 'Sizes', [150 -1])

        uiaddv13_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv13_1, ...
            'String', 'Rx vertical elements' );
        gui.edit_Rxnz = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv13_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Rx_nz), ...
            'Callback', @onEditAdd);
        set(uiaddv13_1, 'Sizes', [150 -1])

        uiaddv14_1 =  uiextras.HBox( 'Parent', uiaddv);
        uicontrol('Style', 'Text', 'Parent', uiaddv14_1, ...
            'String', 'Px vertical elements' );
        gui.edit_Pxnz = uicontrol(...
            'Style', 'Edit', ...
            'Parent', uiaddv14_1, ...
            'Enable', 'on', ...
            'String', num2str(kdata.loop.Px_nz), ...
            'Callback', @onEditAdd);
        set(uiaddv14_1, 'Sizes', [150 -1])

        set(uiaddv, 'Sizes', [26 26 26 26 26 26 26 26 26 26 26 26]);

        set(b, 'Sizes', [-1 -1 -1 -1])
        
    end

%% Menu Callbacks
    function loadData(a,b) %#ok<*INUSD>
        [kdata,proclog] = loadmrsd(kdata);
        if proclog.txinfo.looptype == 0 | 1
            proclog.txinfo.looptype = 1; %use Inloop as standart
        end

        kdata.earth.w_rf      =  kdata.earth.f*2*pi;
        kdata.earth.erdt      =  kdata.earth.w_rf/kdata.gammaH;
        
        set(gui.EarthF,'String', num2str(round(kdata.earth.f*10000)/10000));       
        set(gui.EarthB0, 'String', num2str(round(kdata.earth.erdt*1e9*10000)/10000))
        set(gui.MeasQvec, ...
            'Data', [(1:length(kdata.measure.pm_vec))' kdata.measure.pm_vec' (kdata.measure.Imax_vec)']) % load data
        set(gui.MeasQvec, 'ForegroundColor', '#909090')
        set(gui.loadq, 'String', 'using pulse shapes - reset')
        onLoopShape(0,0);    % update gui - enable handles for loaded loop shape
        
        kdata.measure.pulsetype = 1;
        set(gui.pulsetype, 'Value', kdata.measure.pulsetype,'Enable','off');
        set(gui.edit_taup1, 'Enable', 'off', 'String', num2str(kdata.measure.taup1));
        set(gui.edit_df, 'Enable', 'On')

    end

    function [kdata,proclog] = loadmrsd(kdata)
        % load data
        inifile = mrs_readinifile;  % read ini file and get last .mrsd file (if exist)
        if strcmp(inifile.MRSData.file,'none') == 1
            inifile.MRSData.path = [pwd filesep];
            inifile.MRSData.file = 'mrs_project';
        end    
        
        [file.soundingname, file.soundingpath] = uigetfile(...
            {'*.mrsd','MRSData File (*.mrsd)';
            '*.*',  'All Files (*.*)'}, ...
            'Pick a MRSData file',...
            [inifile.MRSData.path inifile.MRSData.file]);
        datafile = [file.soundingpath,file.soundingname];
        
        [pathstr, name, ext] = fileparts(datafile);
        filepath = [pathstr filesep];
        filename = [name ext];
        proclog  = mrs_load_proclog(filepath, filename);
        
        %kdata            = get_defaults();
        if isfield(kdata.measure,'Txphase')
            kdata.measure = rmfield(kdata.measure,'Txphase');
        end
        if isfield(kdata.measure,'Pulse')
            kdata.measure = rmfield(kdata.measure,'Pulse');
        end
        if isfield(kdata.measure,'Ramp')
            kdata.measure = rmfield(kdata.measure,'Ramp');
        end
        
        kdata.measure.flag_loadAHP  = 0; % set flag to AHP 

        
        % clear q vector before loading
        kdata.measure.pm_vec          = [];
        kdata.measure.pm_vec_2ndpulse = [];
        kdata.measure.Imax_vec        = [];

        if isfield(proclog,"header")
            kdata.measure.nileaves = proclog.header.ileaves;
            kdata.measure.nq = proclog.header.nrecords;
            kdata.measure.nrec = length(proclog.header.files);
        end
        
        for m = 1:length(proclog.Q)
            if isfield(proclog.Q(m),'phase')
                kdata.measure.Txphase(m) = proclog.Q(m).phase;
            else
                kdata.measure.Txphase(m) = 0;
            end
            if isfield(proclog.Q(m),'pulse')
                kdata.measure.Pulse(m).Shape = proclog.Q(m).pulse;
                kdata.measure.Pulse(m).t = proclog.Q(m).pulse_time;
            end
            if isfield(proclog.Q(m),'ramp')
                kdata.measure.Ramp(m).Shape = proclog.Q(m).ramp_all;
                kdata.measure.Ramp(m).t = proclog.Q(m).ramp_time;
            end

            kdata.measure.pm_vec(m)   = proclog.Q(m).q;
            kdata.measure.Imax_vec(m) = proclog.Q(m).q/proclog.Q(m).timing.tau_p1;

            
            if proclog.Q(m).rx(1).sig(3).recorded
%             if ~isempty(proclog.Q(m).q2)
                kdata.measure.pm_vec_2ndpulse(m) = proclog.Q(m).q2;
                set(gui.pulsesequence , 'Value',2);
            end
            if proclog.Q(m).rx(1).sig(4).recorded
%             if ~isempty(proclog.Q(m).q2)
                kdata.measure.pm_vec_2ndpulse(m) = proclog.Q(m).q2;
                set(gui.pulsesequence , 'Value',3);
            end
            set(gui.pulsesequence ,'Enable','off');
        end
        kdata.earth.f    = proclog.Q(1).fT;
        kdata.measure.taup1 = proclog.Q(1).timing.tau_p1;
        if get(gui.pulsesequence , 'Value') ~= 1
            kdata.measure.taup2 = proclog.Q(1).timing.tau_p2; % NOT EX FOR 1PULSE!
        else
            kdata.measure.taup2 = -1; % NOT EX FOR 1PULSE!
        end
    end

    function onMeasLoadQ(a,b)
        if strcmp(gui.loadq.String, 'using pulse shapes - reset')
            if isfield(kdata.measure,'Txphase')
                kdata.measure = rmfield(kdata.measure,'Txphase');
            end
            if isfield(kdata.measure,'Pulse')
                kdata.measure = rmfield(kdata.measure,'Pulse');
            end
            if isfield(kdata.measure,'Ramp')
                kdata.measure = rmfield(kdata.measure,'Ramp');
            end
            onMeasSetQ(a,b)
            set(gui.loadq, 'String', 'load pulse shape')
            set(gui.MeasQvec, 'ForegroundColor', 'black')
            set(gui.pulsetype,'Enable','on');
            set(gui.pulsesequence,'Enable','on');
            set(gui.edit_taup1, 'Enable', 'on');
        else
            [kdata,proclog] = loadmrsd(kdata);
            kdata.earth.w_rf      =  kdata.earth.f*2*pi;
            kdata.earth.erdt      =  kdata.earth.w_rf/kdata.gammaH;
            set(gui.EarthF,'String', num2str(round(kdata.earth.f*10000)/10000));       
            set(gui.EarthB0, 'String', num2str(round(kdata.earth.erdt*1e9*10000)/10000))
            set(gui.MeasQvec, ...
                'Data', [(1:length(kdata.measure.pm_vec))' kdata.measure.pm_vec' (kdata.measure.Imax_vec)']) % load data
            set(gui.MeasQvec, 'ForegroundColor', '#909090')
            set(gui.loadq, 'String', 'using pulse shapes - reset')
            kdata.measure.pulsetype = 1;
            set(gui.pulsetype, 'Value', kdata.measure.pulsetype,'Enable','off');
            set(gui.edit_taup1, 'Enable', 'off', 'String', num2str(kdata.measure.taup1));
            set(gui.edit_df, 'Enable', 'On')

        end
    end

    function onMeasCalcLookup(a,b)
        if ~isfield(kdata.measure,"Pulse")
            warning("no pulse shape loaded, using sinusoidal pulses")
            measuretmp = kdata.measure;
            fsample = 51200; %Hz
            for iq = 1 %for sinusoidal, we only need one pulse shape
                measuretmp.Pulse(iq).t = linspace(0,measuretmp.taup1,round(fsample*measuretmp.taup1));
                measuretmp.Pulse(iq).Shape = sin(measuretmp.Pulse(iq).t*kdata.earth.w_rf);
            end
            measuretmp.pm_vec = [measuretmp.taup1]; %Amplitude 1
            measuretmp.Txphase = [0];
            kdata.measure.TxLookup = MakeTxLookupFile(measuretmp,kdata.earth); 
        else
            kdata.measure.TxLookup = MakeTxLookupFile(kdata.measure,kdata.earth); 
        end
        kdata.measure.useTxLookup = true;
        set(gui.resetLookup,'Enable','on');
        set(gui.saveLookup,'Enable','on');
    end

    function onMeasCalcLookupPP(a,b)
        if ~isfield(kdata.measure,"Ramp")
            error("no ramp shape loaded")
        else
            kdata.measure.PxLookup = MakePxLookupFile(kdata.measure,kdata.earth); 
        end
        kdata.measure.usePxLookup = true;
        set(gui.resetLookupPP,'Enable','on');
        set(gui.saveLookupPP,'Enable','on');
    end
        
    function onMeasSaveLookup(a,b)
        [filename,filepath] = uiputfile({...
            '*.mrsp','MRSmatlab pulse lookup file'; '*.*','All Files' },...
            'Save MRSmatlab pulse map file');
        TxLookup = kdata.measure.TxLookup;
        save([filepath, filename], 'TxLookup');
        fprintf(1,'pulse lookup file saved to %s\n', [filepath, filename]);
        kdata.measure.TxLookup.filename = filename;
    end

    function onMeasSaveLookupPP(a,b)
        [filename,filepath] = uiputfile({...
            '*.mrspp','MRSmatlab prepol lookup file'; '*.*','All Files' },...
            'Save MRSmatlab prepol file');
        PxLookup = kdata.measure.PxLookup;
        save([filepath, filename], 'PxLookup');
        fprintf(1,'prepol lookup file saved to %s\n', [filepath, filename]);
        kdata.measure.PxLookup.filename = filename;
    end
    
    function onMeasLoadLookup(a,b)
        [file.name,file.path] =  uigetfile(...
        {'*.mrsp','MRS pulse File (*.mrsp)';
        '*.*',  'All Files (*.*)'}, ...
        'Pick a MRS pulse file');
        TxLookup = [];
        TxLookup = load([file.path,file.name],'-mat');
        if isfield(TxLookup,'PulseMap') %"old" name
            TxLookup = TxLookup.PulseMap;
        else
            TxLookup = TxLookup.TxLookup;
        end
        if kdata.earth.f ~= TxLookup.earth.f
            warning("TxLookup table uses different frequency!")
        end
        if kdata.measure.taup1 ~= TxLookup.measure.taup1
            warning("TxLookup table uses different pulse duration!")
        end
        kdata.measure.TxLookup = TxLookup;
        kdata.measure.TxLookup.filename = file.name;
        kdata.measure.useTxLookup = true;
        set(gui.resetLookup,'Enable','on');
    end

    function onMeasLoadLookupPP(a,b)
        [file.name,file.path] =  uigetfile(...
        {'*.mrspp','MRS prepol File (*.mrspp)';
        '*.*',  'All Files (*.*)'}, ...
        'Pick a MRS prepol file');
        PxLookup = [];
        PxLookup = load([file.path,file.name],'-mat');
        PxLookup = PxLookup.PxLookup;
        if kdata.earth.f ~= PxLookup.earth.f
            warning("PP Lookup table uses different frequency!")
        end
        kdata.measure.PxLookup = PxLookup;
        kdata.measure.PxLookup.filename = file.name;
        kdata.measure.usePxLookup = true;
        set(gui.resetLookupPP,'Enable','on');
    end

    function onMeasResetLookup(a,b)
        kdata.measure = rmfield(kdata.measure,"TxLookup");
        kdata.measure.useTxLookup = false;
        set(gui.resetLookup,'Enable','off');
        set(gui.saveLookup,'Enable','off');
    end

    function onMeasResetLookupPP(a,b)
        kdata.measure = rmfield(kdata.measure,"PxLookup");
        kdata.measure.usePxLookup = false;
        set(gui.resetLookupPP,'Enable','off');
        set(gui.saveLookupPP,'Enable','off');
    end

    function loadKernel(a,b)
        inifile = mrs_readinifile;  % read .ini file and get last .mrsk file (if exist)
        if strcmp(inifile.MRSKernel.file,'none') == 1
            inifile.MRSKernel.path = [pwd filesep];
            inifile.MRSKernel.file = 'mrs_kernel';
        end
        [file.kernelname,file.kernelpath] =  uigetfile(...
            {'*.mrsk','MRS kernel File (*.mrsk)';
            '*.*',  'All Files (*.*)'}, ...
            'Pick a MRS kernel file',...
            [inifile.MRSKernel.path inifile.MRSKernel.file]);
        
        % load .mrsk file
        dat  = load([file.kernelpath,file.kernelname],'-mat');
        kdata = dat.kdata;
        kdata.gammaH = 267522189.96689254; %overwrite with more exact value
        if ~isfield(kdata.measure,'pm_vec_2ndpulse')% workaround old kernel without 2nd pulse
            kdata.measure.pm_vec_2ndpulse = kdata.measure.pm_vec;
        end
        proclog.path = inifile.MRSData.path;

        % enable view
        child=get(gui.KernelMenu,'Children');
        set(child(2),'Enable','on');
        
        set(gui.LoopShape,'Value',  kdata.loop.shape);
        set(gui.LoopSizeTx,'String',  num2str(kdata.loop.size));
        set(gui.LoopTurnsTx,'String', num2str(kdata.loop.turns));
        if ~isfield(kdata.loop,"Rxturns")
            if length(kdata.loop.turns) > 1% workaround for old kernels not including tx and rx turns separatly
                kdata.loop.Rxturns = kdata.loop.turns(2);
            else
                kdata.loop.Rxturns = kdata.loop.turns(1);
            end
        end
        set(gui.LoopTurnsRx,'String', num2str(kdata.loop.Rxturns));

        if ~isfield(kdata.loop,"Rxsize")
            if length(kdata.loop.size) > 1% workaround for old kernels not including tx and rx turns separatly
                kdata.loop.Rxsize = kdata.loop.size(2);
            else
                kdata.loop.Rxsize = kdata.loop.size(1);
            end
        end
        set(gui.LoopSizeRx, 'String', strjoin(string(kdata.loop.Rxsize),","));

        
        % set tickboxes 2pulse & df in measure
        % LATER: change if's to switch statement once kernel.earth.type is
        % sorted out
        % MMP: started replacing by kdata.measure.pulseseuqence --> debugging
        if isfield(kdata.measure,'pulsesequence')
            switch kdata.measure.pulsesequence
                case 'FID'
                   set(gui.pulsesequence,'Value', 1);
                   %set(gui.pulsetype, 'Enable', 'On')
                   % set(gui.pulsetype, 'Value', 1);
            end
        else
            set(gui.pulsesequence,'Value', 1);
        end
        onEditPulseSequence
%         if isempty(kdata.B1)
%             flag_2pulse = 0;
%         else
%             flag_2pulse = 1;
%         end

%         set(gui.checkbox_doublepulse,'Value', flag_2pulse);

        if isfield(kdata.measure,'pulsetype')
        switch kdata.measure.pulsetype
            case 1 % standard
                %set(gui.pulsesequence, 'Enable', 'On')
                set(gui.pulsetype, 'Value', 1);
            case 2 % adiabatic
                %set(gui.pulsesequence, 'Enable', 'Off')
                set(gui.pulsetype, 'Value', 2); 
        end
        end
        onEditPulseType
        
        % set df in gui
        set(gui.edit_df, 'String', num2str(kdata.measure.df));
        
        set(gui.MeasQvec, ...
            'Data', [(1:length(kdata.measure.pm_vec))' kdata.measure.pm_vec' (kdata.measure.Imax_vec)']) % load kernel
        
        set(gui.EarthB0,'String',   num2str(round(kdata.earth.erdt*1e9*10000)/10000));
        set(gui.EarthF,'String',    num2str(round(kdata.earth.f*10000)/10000));
        set(gui.EarthInkl,'String', num2str(kdata.earth.inkl));
    end

    function onSaveK(a,b)
        
        % read .ini file and get last .mrsk file name & path (if exist)
        inifile = mrs_readinifile;  
        if strcmp(inifile.MRSKernel.file,'none') == 1
            inifile.MRSKernel.path = [pwd filesep];
            inifile.MRSKernel.file = 'mrs_kernel';
        end
        
        kdatatmp = kdata;
        % prompt for file location and save kernel
        [filename,filepath] = uiputfile({...
            '*.mrsk','MRSmatlab kernel file'; '*.*','All Files' },...
            'Save MRSmatlab kernel file',...
            [inifile.MRSKernel.path inifile.MRSKernel.file]);

        if isfield(kdata.measure,"TxLookup")
            kdata.measure = rmfield(kdata.measure, "TxLookup"); %remove TxLookup because it is large
            kdata.measure.TxLookup.filename = kdatatmp.measure.TxLookup.filename;
        end
        if isfield(kdata.measure,"PxLookup")
            kdata.measure = rmfield(kdata.measure, "PxLookup"); %remove PxLookup because it is large
            kdata.measure.PxLookup.filename = kdatatmp.measure.PxLookup.filename;
        end
        save([filepath, filename], 'kdata', '-v7.3');
        fprintf(1,'kernel file saved to %s\n', [filepath, filename]);
        mrs_updateinifile([filepath, filename],2);

        kfile = filename;
        kdata = kdatatmp; %revert to version with TxLookup
    end

    function makeK(a,b)
         %remove data from previous runs
        for fn = ["K","K3","Kphi","Kr","KsliceNS","KsliceEW"]
            if isfield(kdata, fn)
                kdata = rmfield( kdata , fn);
            end
        end
        % calculate the kernel
        if max(kdata.earth.zm) > kdata.model.zmax
            kdata.model.zmax = max(kdata.earth.zm);
        end
      
        tic;
        [kdata.K, dummy, kdata.model, kdata.B1,K3D] = MakeKernel(kdata.loop, ...
                kdata.model, ...
                kdata.measure, ...
                kdata.earth);

        %transfer K3D fields (if any) to kdata 
        for fn = fieldnames(K3D)'
            kdata.(fn{1}) = K3D.(fn{1});
        end

        dummy =[];
        timeforkernel = toc;
        
        % change back sequence
        if get(gui.pulsesequence,'Value') == 2
           kdata.measure.pulsesequence = 2; 
        end
        
        % enable view and save
        child=get(gui.KernelMenu,'Children');
        set(child(1),'Enable','on');
        child=get(gui.FileMenu,'Children');
        set(child(1),'Enable','on');
    end

    function viewK(a,b)
        fs = 10;
        %Kernelonly = true;
        Kernelonly = false;
        Kernelreduce = 0;

        kfig = figure('Name','kernel','Position',[0 0 700 400], 'Toolbar', 'none');
        set(kfig, 'PaperUnits', 'points', ....
            'PaperSize', [700 400], ...
            'PaperPosition', [0 0 700 400])
        tbh = uitoolbar(kfig);
        png = load('png.mat'); eps = load('eps.mat'); logq = load('logq.mat'); logz = load('logz.mat');
        absk = load('abs.mat'); rek = load('re.mat'); imk = load('im.mat');
        xk=load('x.mat'); yk=load('y.mat'); zk=load('z.mat');
        uipushtool(tbh, 'CData', png.cdata, 'ClickedCallback', @onExportPNG);
        uipushtool(tbh, 'CData', eps.cdata,'ClickedCallback', @onExportEPS);
        uitogz = uitoggletool(tbh, 'CData', logz.cdata, 'Separator', 'on','ClickedCallback', @ontogLogZ);
        uitogq = uitoggletool(tbh, 'CData', logq.cdata,'ClickedCallback', @ontogLogQ);
        uiabsk = uitoggletool(tbh, 'State', 'on', 'CData', absk.cdata, 'Separator', 'on','ClickedCallback', @t_absk);
        uirek  = uitoggletool(tbh, 'CData', rek.cdata,'ClickedCallback', @t_rek);
        uiimk  = uitoggletool(tbh, 'CData', imk.cdata,'ClickedCallback', @t_imk);
        uizk = uitoggletool(tbh, 'State', 'on', 'CData', zk.cdata, 'Separator', 'on','ClickedCallback', @t_zk);
        uixk  = uitoggletool(tbh, 'CData', xk.cdata,'ClickedCallback', @t_xk);
        uiyk  = uitoggletool(tbh, 'CData', yk.cdata,'ClickedCallback', @t_yk);
        set(kfig, 'DefaultAxesFontSize', 10)
        set(kfig, 'DefaultTextFontSize', 10)
        
        if ~Kernelonly
            [kplt,k2] = plotK(1,3);
        else
            [kplt] = plotK(1,3); 
        end
        function [kplt,k2] = plotK(in,dim)
            if ~Kernelonly
                subplot(1,3,1:2);
            end

            scale_fac = 1e9; % nV
            
            % sensitivity weighting [nV/m] or [fT/m]
            weight = repmat(kdata.model.Dz,size(kdata.Kr,1),1)/scale_fac; 

            set(uixk, 'Visible', 'off')
            set(uiyk, 'Visible', 'off')
            set(uizk, 'Visible', 'off')

            KK = kdata.Kr;
            q = kdata.measure.pm_vec;
            
            if size(KK,1) == 1
                weight = kdata.model.Dr/scale_fac;
            else
                weight = repmat(kdata.model.Dr',size(KK,1),1)/scale_fac;
            end
            

            switch in
                case 1 % abs
                    tmpK = (abs(KK)./weight)';
                    mK = mean(tmpK(~isnan(tmpK)));
                    max_value = max(tmpK(~isnan(tmpK)));
                    min_value = min(tmpK(~isnan(tmpK)));
                    sK = std(tmpK(~isnan(tmpK)));
                    if ~Kernelonly
                        clims = [mK-sK mK+sK];
                    else
                        clims = [min_value max_value];
                    end
                case 2 % re
                    tmpK = (real(KK)./weight)';
                    mK = mean(tmpK(~isnan(tmpK)));
                    max_value = max(tmpK(~isnan(tmpK)));
                    min_value = min(tmpK(~isnan(tmpK)));
                    sK = std(tmpK(~isnan(tmpK)));
                    if ~Kernelonly
                        clims = [mK-sK mK+sK];
                    else
                        clims = [min_value max_value];
                    end
                case 3 % im
                    tmpK = (imag(KK)./weight)';
                    mK = mean(tmpK(~isnan(tmpK)));
                    max_value = max(tmpK(~isnan(tmpK)));
                    min_value = min(tmpK(~isnan(tmpK)));
                    sK = std(tmpK(~isnan(tmpK)));
                    if ~Kernelonly
                        clims = [mK-sK mK+sK];
                    else
                        clims = [min_value max_value];
                    end
            end


            % check if it is a single pulse moment kernel
            if size(tmpK,2) == 1
                kplt = plot(tmpK, kdata.model.z);
            elseif Kernelreduce
                kplt = plot(tmpK, kdata.model.z);
                set(kplt, {"DisplayName"},cellstr(string(q))')
                l=legend;
                set(l,"Location","best")
            else
                kplt = pcolor(kdata.measure.pm_vec, kdata.model.r, tmpK);
                set(gca,'CLim',clims);
            end

            % axis title
            switch in
                case 1

                    if ~Kernelonly
                        title('sensitivity kernel (abs value)', 'FontSize', fs);
                    else
                        title('abs', 'FontSize', fs);
                    end

                case 2
                    if ~Kernelonly
                        title('sensitivity kernel (real value)', 'FontSize', fs);
                    else
                        title('real', 'FontSize', fs);
                    end

                case 3
                    if ~Kernelonly
                        title('sensitivity kernel (imag value)', 'FontSize', fs);
                    else
                        title('imag', 'FontSize', fs);
                    end
            end
            
            % axis settings
            if size(tmpK,2) > 1 & ~Kernelreduce
                axis ij
                shading flat
                if Kernelonly
                    xlabel('{\itq} / As');
                else
                    xlabel('pulse moment q [As]', 'Fontsize', fs);
                end
                clb = colorbar('Location', 'EastOutside');
                if Kernelonly
                    set(get(clb,'Title'),'String','{\itu}_0 / nV m^{-1}')
                else
                    set(get(clb,'Title'),'String','nV/m');
                end

            else
                axis ij
                xlabel('amplitude [nV/m]', 'Fontsize', fs);
            end
            box on
            if ~Kernelonly
                grid on
            else
                grid off
            end
            set(gca, 'layer', 'top')
            if Kernelonly
                ylabel('{\itz} / m')
            else
                ylabel('depth [m]', 'Fontsize', fs)
            end
            kplt = gca;

            if ~Kernelonly
                % kernel sum
                k2 = subplot(1,3,3);
                KK(isnan(KK)) = 0;
                switch in
                    case 1 % abs
                        plot(abs(sum(KK,2)).*scale_fac, q, 'ro');
                        xlabel('amplitude [nV]', 'Fontsize', fs)
                    case 2 % re
                        plot(real(sum(KK,2)).*scale_fac, q, 'ro');
                        xlabel('amplitude [nV]', 'Fontsize', fs)
                    case 3 % im
                        plot(imag(sum(KK,2)).*scale_fac, q, 'ro');
                        %plot(rad2deg(angle(sum(KK,2))), kdata.measure.pm_vec, 'ro');
                        xlabel('amplitude [nV]', 'Fontsize', fs)
                end
                    
                title('kernel row sums', 'FontSize', fs)
                axis ij
                box on
                grid on
                set(gca, 'layer', 'top');
                ylabel('pulse moment [As]', 'Fontsize', fs)
                hold off;
            end
            
            switch get(uitogz, 'State')
                case 'off'
                    set(kplt, 'yscale','lin');
                case 'on'
                    set(kplt, 'yscale','log');
            end
            switch get(uitogq, 'State')
                case 'off'
                    set(kplt, 'xscale','lin');
                    if ~Kernelonly
                        set(k2, 'yscale','lin');
                    end
                case 'on'
                    set(kplt, 'xscale','log');
                    if ~Kernelonly
                        set(k2, 'yscale','log');
                    end
            end
        end
        
        % export buttons
        function onExportPNG(a,b)
            [pname, ppath] = uiputfile({'*.png'},'export as png');
            [outpath, outname, outxt] = fileparts([ppath, pname]);
            print(kfig, '-dpng', '-r600', fullfile([outpath, filesep, outname, '.png']));
        end
        function onExportEPS(a,b)
            [pname, ppath] = uiputfile({'*.eps'},'export as eps');
            [outpath, outname, outxt] = fileparts([ppath, pname]);
            print(kfig, '-depsc2', '-painters', fullfile([outpath, filesep, outname, '.eps']));
        end
        
        % axis toggle
        function ontogLogZ(a,b)
            switch get(uitogz, 'State')
                case 'off'
                    set(kplt, 'yscale','lin');
                case 'on'
                    set(kplt, 'yscale','log');

            end
        end
        function ontogLogQ(a,b)
            switch get(uitogq, 'State')
                case 'off'
                    set(kplt, 'xscale','lin');
                    if ~Kernelonly
                        set(k2, 'yscale','lin');
                    end
                case 'on'
                    set(kplt, 'xscale','log');
                    if ~Kernelonly
                        set(k2, 'yscale','log');
                    end
            end
        end
        
        % abs, re, im toggle buttons
        function t_absk(a,b)
            set(uirek, 'State', 'off')
            set(uiimk, 'State', 'off')
            dim=get(uixk, 'State')*1+get(uiyk, 'State')*2+get(uizk, 'State')*3;
            kplt = plotK(1,dim);
        end
        function t_rek(a,b)
            set(uiabsk, 'State', 'off')
            set(uiimk, 'State', 'off')
            dim=get(uixk, 'State')*1+get(uiyk, 'State')*2+get(uizk, 'State')*3;
            kplt = plotK(2,dim);
        end
        function t_imk(a,b)
            set(uiabsk, 'State', 'off')
            set(uirek, 'State', 'off')
            dim=get(uixk, 'State')*1+get(uiyk, 'State')*2+get(uizk, 'State')*3;
            kplt = plotK(3,dim);
        end
        %->Tobias: x, y, z toggle buttons
        function t_zk(a,b)
            set(uixk, 'State', 'off')
            set(uiyk, 'State', 'off')
            im=get(uiabsk, 'State')*1+get(uirek, 'State')*2+get(uiimk, 'State')*3;
            kplt = plotK(im,3);
        end
        function t_xk(a,b)
            set(uiyk, 'State', 'off')
            set(uizk, 'State', 'off')
            im=get(uiabsk, 'State')*1+get(uirek, 'State')*2+get(uiimk, 'State')*3;
            kplt = plotK(im,1);
        end
        function t_yk(a,b)
            set(uixk, 'State', 'off')
            set(uizk, 'State', 'off')
            im=get(uiabsk, 'State')*1+get(uirek, 'State')*2+get(uiimk, 'State')*3;
            kplt = plotK(im,2);
        end
        %<-Tobias
    end

    function onExport(a,b)
        [file.kernelname, file.kernelpath] = uiputfile({'*.mms'},'save kernel');
        if isfield(kdata, 'K')
            kdata = rmfield(kdata, 'K');
        end
        save([file.kernelpath, file.kernelname], 'kdata');
    end

    function onQuit(a,b)
        uiresume
        delete(gui.Window)
    end

    function onHelp(a,b)
        warndlg({'Whatever your question is:'; ''; 'Its not a bug - Its a feature!'; '';'All the rest is incorrect user action'}, 'modal')
    end

%% Loop Callbcks
    function onLoopShape(a,b)
        kdata.loop.Rxsize = 0; % initially set here, to avoid error
        kdata.loop.shape = get(gui.LoopShape,'Value');
        
        switch kdata.loop.shape
            case 1 % circular Inloop
                set(gui.LoopSizeString,'String','Diameter [m] (Tx / Rx)');
                set(gui.LoopSizeRx,'Enable','on');
                kdata.loop.Rxsize = str2double(split(erase(get(gui.LoopSizeRx, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
                set(gui.LoopTurnsString,'String','# Turns (Tx / Rx)');
                set(gui.LoopTurnsRx,'Enable','on');
                onLoopTurns;
        end        
    end

    function onLoopSize(a,b)
        %kdata.loop.size = str2double(get(gui.LoopSizeTx, 'String'));
        kdata.loop.size = str2double(split(erase(get(gui.LoopSizeTx, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
        kdata.loop.Treesize = str2double(get(gui.TreeSize, 'String'));
        switch kdata.loop.shape
            case {1} % InLoop
                kdata.model.zmax = 1.5 * max(kdata.loop.size);
                kdata.model.sinh_zmin = max(kdata.loop.size)/500;
                %kdata.loop.size(2)= str2double(get(gui.LoopSizeRx, 'String'));
                kdata.loop.Rxsize = str2double(split(erase(get(gui.LoopSizeRx, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
        end
    end

    function onLoopTurns(a,b)
        %kdata.loop.turns(1) = str2double(get(gui.LoopTurnsTx, 'String'));
        %kdata.loop.Rxturns = str2double(get(gui.LoopTurnsRx, 'String'));
        kdata.loop.turns = str2double(split(erase(get(gui.LoopTurnsTx, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
        kdata.loop.Rxturns = str2double(split(erase(get(gui.LoopTurnsRx, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
    end

    function onPXcheck(a,b)
        if get(gui.PXcheck,'Value') == 2
            set(gui.PXshape,'Enable','On');
%             if get(gui.PXshape,'Value') == 2
%                 set(gui.PX8dir,'Enable','On');
%             else
%                 set(gui.PX8dir,'Enable','Off');
%             end
            set(gui.PXsize,'Enable','On');
            set(gui.PXcurrent,'Enable','On');
            set(gui.PXturns,'Enable','On');
            set(gui.PXramp,'Enable','On');
            if get(gui.PXramp,'Value') == 1
                set(gui.PXramptime,'Enable','Off');
            else
                set(gui.PXramptime,'Enable','On');
                if kdata.measure.pulsetype == 3
                    %set(gui.PXdelay,'Enable','Off');
                else
                    set(gui.PXdelay,'Enable','On');
                    kdata.loop.PXdelay = str2double(get(gui.PXdelay,'String'))/1e3;
                end
            end            
            kdata.measure.PX = 1;
            kdata.loop.PXshape = get(gui.PXshape,'Value');
            kdata.loop.PXsize = str2double(split(erase(get(gui.PXsize, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
            kdata.loop.PXsign = sign(str2double(get(gui.PXcurrent,'String')));
            kdata.loop.PXcurrent = abs(str2double(get(gui.PXcurrent,'String')));
            kdata.loop.PXturns = str2double(split(erase(get(gui.PXturns, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';            
        else
            set(gui.PXshape,'Enable','Off');
            set(gui.PXsize,'Enable','Off');
            set(gui.PXcurrent,'Enable','Off');
            set(gui.PXturns,'Enable','Off');
%             set(gui.PX8dir,'Enable','Off');
            set(gui.PXdelay,'Enable','Off');
            kdata.measure.PX = 0;
            set(gui.PXramp,'Enable','Off');
            set(gui.PXramptime,'Enable','Off');
            set(gui.pulsetype, 'Value',1);
            onEditPulseType;
            %kdata.loop = rmfield(kdata.loop,{'PXsize','PXcurrent','PX8dir'});
        end
    end

    function onPXshape(a,b)
        kdata.loop.PXshape = get(gui.PXshape,'Value');
        % not used because Fig8 PX is not implemented
%         if kdata.loop.PXshape == 3
%             set(gui.PX8dir,'Enable','On','String',num2str(kdata.loop.PX8dir));
%         else
%             set(gui.PX8dir,'Enable','Off','String','');
%         end
    end

    function onPXsize(a,b)
        kdata.loop.PXsize = str2double(split(erase(get(gui.PXsize, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
    end

    function onPXcurrent(a,b)
        kdata.loop.PXsign = sign(str2double(get(gui.PXcurrent,'String')));
        kdata.loop.PXcurrent = abs(str2double(get(gui.PXcurrent,'String')));
        kdata.loop.PXturns  = str2double(split(erase(get(gui.PXturns, 'String'),{'[',']'}),{', ','; ',',',' ',';'}))';
%         kdata.loop.I = str2double(get(gui.PXcurrent,'String'))*str2double(get(gui.PXturns,'String'));
    end

%     function onPX8dir(a,b)
%         kdata.loop.PX8dir  = str2double(get(gui.PX8dir,'String'));
%     end

    function onPXramp(a,b)
        tmp = get(gui.PXramp,'Value');
        switch tmp
            case 1
                kdata.loop.usePXramp = false;
                kdata.loop.PXramp = 'none';
                set(gui.PXramptime,'Enable','Off');
                set(gui.PXdelay,'Enable','Off');
                kdata.loop.PXdelay = 0;
                set(gui.PXdelay,'String',num2str(kdata.loop.PXdelay));
            case 2
                kdata.loop.usePXramp = true;
                kdata.loop.PXramp = 'midi';
                set(gui.PXramptime,'Enable','On');
                if kdata.measure.pulsetype == 3
                    %set(gui.PXdelay,'Enable','Off');
                    %kdata.loop.PXdelay = 0;
                    %set(gui.PXdelay,'String',num2str(kdata.loop.PXdelay));
                else
                    set(gui.PXdelay,'Enable','On');
                end                
            case 3
                kdata.loop.usePXramp = true;
                kdata.loop.PXramp = 'lin';
                set(gui.PXramptime,'Enable','On');
                if kdata.measure.pulsetype == 3
                    %set(gui.PXdelay,'Enable','Off');
                    %kdata.loop.PXdelay = 0;
                    %set(gui.PXdelay,'String',num2str(kdata.loop.PXdelay));
                else
                    set(gui.PXdelay,'Enable','On');
                end
            case 4
                kdata.loop.usePXramp = true;
                kdata.loop.PXramp = 'linexp';
                set(gui.PXramptime,'Enable','On');
                if kdata.measure.pulsetype == 3
                    %set(gui.PXdelay,'Enable','Off');
                    %kdata.loop.PXdelay = 0;
                    %set(gui.PXdelay,'String',num2str(kdata.loop.PXdelay));
                else
                    set(gui.PXdelay,'Enable','On');
                end
            case 5
                kdata.loop.usePXramp = true;
                kdata.loop.PXramp = 'exp';
                set(gui.PXramptime,'Enable','On');
                if kdata.measure.pulsetype == 3
                    %set(gui.PXdelay,'Enable','Off');
                    %kdata.loop.PXdelay = 0;
                    %set(gui.PXdelay,'String',num2str(kdata.loop.PXdelay));
                else
                    set(gui.PXdelay,'Enable','On');
                end
            case 6
                kdata.loop.usePXramp = true;
                kdata.loop.PXramp = 'GMRFlex';
                set(gui.PXramptime,'Enable','On');
                if kdata.measure.pulsetype == 3
                    %set(gui.PXdelay,'Enable','Off');
                    %kdata.loop.PXdelay = 0;
                    %set(gui.PXdelay,'String',num2str(kdata.loop.PXdelay));
                else
                    set(gui.PXdelay,'Enable','On');
                end
        end
    end

    function onPXramptime(a,b)
        kdata.loop.PXramptime = get(gui.PXramptime,'Value')./1e3;
    end

    function onPXdelay(a,b)
        val = str2double(get(gui.PXdelay,'String'))/1e3;
        kdata.loop.PXdelay = val;
    end

%% Model Callbacks
    function onModMaxZ(a,b)
        kdata.model.zmax = str2double(get(gui.ModMaxZ, 'String'));
        kdata.model = MakeZvec(kdata.model, kdata.earth);
    end

    function onModSetZ(a,b)
        kdata.model = SetZGui(kdata.loop.size(1), length(kdata.measure.pm_vec), kdata.model);
        set(gui.ModelZvec, ...
            'Data', [(1:length(kdata.model.z))' kdata.model.z' kdata.model.Dz'])
    end

%% Loop Callbacks
    function onMeasSetQ(a,b)
        pm_vec_old = kdata.measure.pm_vec;
        Imax_vec_old = kdata.measure.Imax_vec;
        [kdata.measure.pm_vec, kdata.measure.Imax_vec] = SetQGui(kdata.measure.pm_vec, kdata.measure.taup1);
        switch get(gui.pulsesequence,'Value')
            case {1,2}
                kdata.measure.pm_vec_2ndpulse = kdata.measure.pm_vec;
            case 3
                kdata.measure.pm_vec_2ndpulse = 2*kdata.measure.pm_vec;
        end    
%         uiwait()
        set(gui.MeasQvec, ...
            'Data', [(1:length(kdata.measure.pm_vec))' kdata.measure.pm_vec' (kdata.measure.Imax_vec)'])  % change when set Q
        if isfield(kdata.measure,"Pulse")
            t_old = kdata.measure.Pulse(1).t;
            Phase_old = kdata.measure.Txphase;
            for i = 1:length(kdata.measure.Pulse(1).Shape)
                for j = 1:length(kdata.measure.Pulse)
                    Shape_old(i,j) = kdata.measure.Pulse(j).Shape(i);
                end
                Shape_new(i,:) = interp1(pm_vec_old,Shape_old(i,:),kdata.measure.pm_vec,"linear","extrap");
            end
            Phase_new = interp1(pm_vec_old,Phase_old,kdata.measure.pm_vec,"linear","extrap");
            figure(477); mesh(kdata.measure.Pulse(1).t,pm_vec_old,Shape_old',"EdgeColor","black"); hold on; mesh(kdata.measure.Pulse(1).t,kdata.measure.pm_vec,Shape_new',"EdgeColor","red"); hold off; xlabel('t / s'); ylabel('q / As'); zlabel('I / A');
            figure(478); plot(pm_vec_old,Phase_old); hold on; plot(kdata.measure.pm_vec,Phase_new); hold off; ylabel('phi / rad'); xlabel('q / As'); set(gca,'Xscale','log');
            kdata.measure = rmfield(kdata.measure,"Pulse");
            kdata.measure = rmfield(kdata.measure,"Txphase");
            for j = 1:length(kdata.measure.pm_vec)
                kdata.measure.Pulse(j).Shape = Shape_new(:,j)';
                kdata.measure.Pulse(j).t = t_old;
                kdata.measure.Txphase(j) = Phase_new(j);
            end
        end
    end

%% adiabatic Callbacks
    function onEditPulseSequence(a,b)
        kdata.measure.pulsesequence = get(gui.pulsesequence,'Value');
        switch kdata.measure.pulsesequence
                case 1 % FID
                    set(gui.pulsetype,'Enable','on');
                    onEditPulseType;
        end
    end

    function onEditPulseType(a,b)
        kdata.measure.pulsesequence = get(gui.pulsesequence,'Value');
        kdata.measure.pulsetype = get(gui.pulsetype, 'Value');
        switch kdata.measure.pulsetype
            case 1 % standard
                set(gui.edit_taup1,'Enable','On');
                set(gui.edit_df,'Enable','On');
                set(gui.check_BS,'Enable','On');
                set(gui.pulsesequence,'Enable','on');
                set(gui.advancedAP,'Enable','off');
                if kdata.measure.PX == 1 && kdata.loop.usePXramp == 1
                    set(gui.PXdelay,'Enable','on');
                else
                    set(gui.PXdelay,'Enable','off');
                    kdata.loop.PXdelay = 0;
                    set(gui.PXdelay,'String',num2str(kdata.loop.PXdelay));
                end
        end
    end

    function onEditPulseSign(a,b)
        kdata.measure.pulsesign = get(gui.pulsesign,'Value');
    end

    function ontaup1CellEdit(a,b)
        kdata.measure.taup1 = str2double(get(gui.edit_taup1, 'String'));
        if kdata.measure.pulsetype==2
            kfig = findobj('Name', 'Set Adiabatic Pulse Parameter');
            if ~isempty(kfig)
                delete(kfig)
            end      
            drawpulseshape  % function to draw pulse shape  
        end
        kdata.measure.Imax_vec = kdata.measure.pm_vec./kdata.measure.taup1;
        set(gui.MeasQvec, 'Data', [(1:length(kdata.measure.pm_vec))' kdata.measure.pm_vec' (kdata.measure.Imax_vec)']);
    end

    function oneditdf(a,b)
        kdata.measure.df = str2double(get(gui.edit_df, 'String')); 
    end
          
%% Earth Callbacks
    function onEarthB0(a,b)
        kdata.earth.erdt = str2double(get(gui.EarthB0,'String'))*1e-9; % nT-2-T
        kdata.earth.f = kdata.gammaH*kdata.earth.erdt/(2*pi);  
        kdata.earth.w_rf = kdata.earth.f*2*pi;
        kdata.measure.Imod.Qf0 = kdata.earth.f+kdata.measure.Imod.Qdf; 
        set(gui.EarthF,'String',num2str(round(kdata.earth.f*10000)/10000));
    end

    function onEarthW0(a,b)
        kdata.earth.f = str2double(get(gui.EarthF, 'String'));
        kdata.earth.w_rf = kdata.earth.f*2*pi;
        kdata.earth.erdt = kdata.earth.f*(2*pi)/kdata.gammaH;
        kdata.measure.Imod.Qf0 = kdata.earth.f+kdata.measure.Imod.Qdf; 
        set(gui.EarthB0,'String',num2str(round(kdata.earth.erdt*1e9*10000)/10000))
    end

    function onEarthInkl(a,b)
        kdata.earth.inkl = str2double(get(gui.EarthInkl, 'String'));
    end

    function onEarthDecl(a,b)
        kdata.earth.decl = str2double(get(gui.EarthDecl, 'String'));
    end

    function onEarthAqT(a,b)
        kdata.earth.temp = str2double(get(gui.AquaTemp, 'String'));
    end

    function onEditAdd(a,b)
        kdata.measure.applyBS = get(gui.check_BS, 'Value');
        kdata.measure.K3Dzphir = get(gui.check_K3Dzphir, 'Value');
        kdata.measure.K3Dslices = get(gui.check_K3Dslices, 'Value');
        kdata.loop.Tx_zoff = str2double(get(gui.edit_Txzoff, 'String'));
        kdata.loop.Rx_zoff = str2double(get(gui.edit_Rxzoff, 'String'));
        kdata.loop.Px_zoff = str2double(get(gui.edit_Pxzoff, 'String'));
        kdata.loop.Tx_zext = str2double(get(gui.edit_Txzext, 'String'));
        kdata.loop.Rx_zext = str2double(get(gui.edit_Rxzext, 'String'));
        kdata.loop.Px_zext = str2double(get(gui.edit_Pxzext, 'String'));
        kdata.loop.Tx_nz = str2double(get(gui.edit_Txnz, 'String'));
        kdata.loop.Rx_nz = str2double(get(gui.edit_Rxnz, 'String'));
        kdata.loop.Px_nz = str2double(get(gui.edit_Pxnz, 'String'));
    end

    function Initialize()
        proclog = struct();
        [kpath, filename, ext] = fileparts(sounding_pathdirfile);
        proclog = mrs_load_proclog([kpath filesep], [filename ext]);
        kfile   = [filename '.mrsk'];
    end

    function onSaveAndQuit(a,b)
        outfile = [kpath filesep kfile];
        save(outfile, 'kdata');
        fprintf(1,'kdata successfully saved to %s\n', outfile);
        uiresume;
        delete(gui.Window)
    end

    function onQuitWithoutSave(a,b)
        uiresume;
        delete(gui.Window)
    end

%% Function to draw pulse shape
    function drawpulseshape(a,b)
        if get(gui.pulsetype,'value') == 2
            dat = SetAPGUI(kdata.measure);
            kdata.measure.fmod = dat.fmod;
            kdata.measure.Imod = dat.Imod;
        end
    end

if standalone == 0
    uiwait(gui.Window)
end
end

%% Z DISCRETIZATION GUI
function zmod = SetZGui(sloop, nq, zmod)
zfig = findobj('Name', 'Set z values');
if ~isempty(zfig)
    delete(zfig)
end
zmod = CreateZDat(sloop, nq, zmod);
zgui = CreateZGui();
% initialize fields
onQspacing()
onSetZ()

    function zmod = CreateZDat(sloop, nq, zmod)
        zmod.z_space = 1;
        zmod.zmax = 1.5*sloop;
        if nq < 24
            zmod.nz = 96;
        else
            zmod.nz = 4*nq;
        end
        zmod.sinh_zmin = sloop/500;
        zmod.LL_dzmin = sloop/500;
        zmod.LL_dzmax = sloop/50;
        zmod.LL_dlog = sloop/5;
    end

    function zgui = CreateZGui()
        
        zgui.getzfig = figure( ...
            'Name', 'Set z values', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Toolbar', 'none', ...
            'HandleVisibility', 'on' );
        pos = get(zgui.getzfig, 'Position');
        set(zgui.getzfig, 'Position', [pos(1), pos(2) 400 300])
        
        %uiextras.set( zgui.getzfig, 'DefaultBoxPanelPadding', 5)
        %uiextras.set( zgui.getzfig, 'DefaultHBoxPadding', 2)
        
        uigetzf  = uiextras.HBox('Parent', zgui.getzfig);
        uigetzb1 = uiextras.VBox('Parent', uigetzf);
        zgui.ztab = uitable('Parent', uigetzb1);
        set(zgui.ztab, ...
            'Data', [(1:length(zmod.z))' zmod.z' zmod.Dz'], ...
            'ColumnName', {'#', 'z', 'dz'}, ...
            'ColumnWidth', {30 60 60}, ...
            'RowName', [], ...
            'ColumnEditable', false);
        
        uigetzb1a = uiextras.VBox('Parent', uigetzf);
        zgui.zax  = axes('Parent', uigetzb1a);
        pos = get(zgui.zax, 'Outerposition');
        set(zgui.zax, ...
            'Position', pos, ...
            'box', 'on', ...
            'XTickLabel', [], ...
            'YTickLabel', [])
        
        % right panel with dialogs
        uigetzb2 = uiextras.VBox('Parent', uigetzf, 'Padding', 5);
        
        uigetzh1  = uiextras.HBox('Parent', uigetzb2);
        zgui.Zmax_t = uicontrol('Style', 'text', 'Parent', uigetzh1, 'String', 'max depth');
        zgui.Zmax   = uicontrol('Style', 'edit', 'Parent', uigetzh1, 'String', num2str(zmod.zmax), 'Callback', @onZmax);
        
        uigetzh2      = uiextras.HBox('Parent', uigetzb2);
        zgui.Zspacing = uicontrol('Style', 'popupmenu', 'Parent', uigetzh2, 'String', {'sinh', 'loglin'}, 'Value', 1, 'Enable', 'on',  'Callback', @onQspacing);
               
        zgui.uigetzv3 = uiextras.VBox('Parent', uigetzb2);
        
        uigetzh4      = uiextras.HBox('Parent', uigetzb2);
        zgui.Qset     = uicontrol('Style', 'pushbutton', 'Parent', uigetzh4, 'String', 'set', 'Callback', @onSetZ);
        
        uigetzh5      = uiextras.HBox('Parent', uigetzb2);
        zgui.return   = uicontrol('Style', 'pushbutton', 'Parent', uigetzh5, 'String', 'return', 'Callback', @onReturn);
        
        set(uigetzb2, 'Sizes', [28 28 -1 28 28])
        
        set(uigetzf, 'Sizes', [170 60 170])
        
        
    end

    function onQspacing(a,b)
        acontrls = get(zgui.uigetzv3, 'Children');
        delete(acontrls)
        zmod.z_space = get(zgui.Zspacing, 'Value');
        switch zmod.z_space
            case 1 %sinh
                uigetzv3h1 = uiextras.HBox('Parent', zgui.uigetzv3);
                zgui.sinh_zmint = uicontrol('Style', 'text', 'Parent', uigetzv3h1, 'String', 'z min');
                zgui.sinh_zmin  = uicontrol('Style', 'edit', 'Parent', uigetzv3h1, 'String', num2str(zmod.sinh_zmin), 'Callback', @onSinhZmin);
                uigetzv3h2 = uiextras.HBox('Parent', zgui.uigetzv3);
                zgui.sinh_nzt   = uicontrol('Style', 'text', 'Parent', uigetzv3h2, 'String', '# layer');
                zgui.sinh_nz    = uicontrol('Style', 'edit', 'Parent', uigetzv3h2, 'String', num2str(zmod.nz), 'Callback', @onNz);
                uigetzv3h3 = uiextras.HBox('Parent', zgui.uigetzv3);
                set(zgui.uigetzv3, 'Sizes', [28 28 -1])
            case 2 %linlog
                uigetzv3h1 = uiextras.HBox('Parent', zgui.uigetzv3);
                zgui.ll_dzmint    = uicontrol('Style', 'text', 'Parent', uigetzv3h1, 'String', 'dz min');
                zgui.ll_dzmin     = uicontrol('Style', 'edit', 'Parent', uigetzv3h1, 'String', num2str(zmod.LL_dzmin), 'Callback', @onLLZmin);
                uigetzv3h2 = uiextras.HBox('Parent', zgui.uigetzv3);
                zgui.ll_dlogt = uicontrol('Style', 'text', 'Parent', uigetzv3h2, 'String', 'depth log');
                zgui.ll_dlog  = uicontrol('Style', 'edit', 'Parent', uigetzv3h2, 'String', num2str(zmod.LL_dlog), 'Callback', @onLLZminlog);
                uigetzv3h3 = uiextras.HBox('Parent', zgui.uigetzv3);
                zgui.ll_dzmaxt   = uicontrol('Style', 'text', 'Parent', uigetzv3h3, 'String', 'dz max');
                zgui.ll_dzmax    = uicontrol('Style', 'edit', 'Parent', uigetzv3h3, 'String', num2str(zmod.LL_dzmax), 'Callback', @onLLdZlin);
                uigetzv3h4 = uiextras.HBox('Parent', zgui.uigetzv3);
                set(zgui.uigetzv3, 'Sizes', [28 28 28 -1])
        end
        
    end

    function onSetZ(a,b)
        zmod = MakeZvec(zmod);
        set(zgui.ztab, ...
            'Data', [(1:length(zmod.z))' zmod.z' zmod.Dz'])
        zgui.zax; cla; hold on; axis ij
        for n = 1:length(zmod.z)
            plot([0 1], [zmod.z(n) zmod.z(n)], 'k-')
        end
    end

    function onReturn(a,b)
        uiresume(gcbf)
        delete(zgui.getzfig)
    end

    function onSinhZmin(a,b)
        zmod.sinh_zmin = str2double(get(zgui.sinh_zmin, 'String'));
    end

    function onNz(a,b)
        zmod.nz = str2double(get(zgui.sinh_nz, 'String'));
    end

    function onLLZmin(a,b)
        zmod.LL_dzmin = str2double(get(zgui.ll_dzmin, 'String'));        
    end

    function onLLZminlog(a,b)
        zmod.LL_dlog = str2double(get(zgui.ll_dlog, 'String'));
    end

    function onLLdZlin(a,b)
        zmod.LL_dzmax = str2double(get(zgui.ll_dzmax, 'String'));
    end
    function onZmax(a,b)
        zmod.zmax = str2double(get(zgui.Zmax, 'String'));
    end

uiwait(gcf)
end

%% PULSE MOMENTS GUI
function [pm_vec, Imax_vec] = SetQGui(pm_vec, taup1)

Imax_vec = pm_vec./taup1; % only true for on-res excitation

qdat = CreateQDat();
qgui = CreateQGui();


    function qdat = CreateQDat()
        qdat        = struct();
        qdat.nq     = length(pm_vec);
        qdat.qmin   = min(pm_vec);
        qdat.qmax   = max(pm_vec);
        qdat.qspace = 2;
    end

    function qgui = CreateQGui()
        
        qgui.getqfig = figure( ...
            'Name', 'Set q values', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'Toolbar', 'none', ...
            'HandleVisibility', 'on' );
        pos = get(qgui.getqfig, 'Position');
        set(qgui.getqfig, 'Position', [pos(1), pos(2) 300 300])
        
        %uiextras.set( qgui.getqfig, 'DefaultBoxPanelPadding', 5)
        %uiextras.set( qgui.getqfig, 'DefaultHBoxPadding', 2)
        
        uigetqf  = uiextras.HBox('Parent', qgui.getqfig);
        uigetqb1 = uiextras.VBox('Parent', uigetqf);
        qgui.qtab = uitable('Parent', uigetqb1);
        set(qgui.qtab, ...
            'Data', [(1:length(pm_vec))' pm_vec' (Imax_vec)'], ...
            'ColumnName', {'#', 'q [As]','max(I) [A]'}, ...
            'ColumnWidth', {20 65 65 }, ...
            'RowName', [], ...
            'ColumnEditable', false);
        
        % right panel with dialogs
        uigetqb2 = uiextras.VBox('Parent', uigetqf, 'Padding', 5);
        
        uigetqh1  = uiextras.HBox('Parent', uigetqb2);
        qgui.Qn_t = uicontrol('Style', 'text', 'Parent', uigetqh1, 'String', '# of q');
        qgui.Qn   = uicontrol('Style', 'edit', 'Parent', uigetqh1, 'String', num2str(length(pm_vec)), 'Callback', @onQnumber);
        
        uigetqh2 = uiextras.HBox('Parent', uigetqb2);
        qgui.QLin = uicontrol('Style', 'radiobutton', 'Parent', uigetqh2, 'String', 'lin', 'Value', 0, 'Enable', 'on',  'Callback', @onQLin);
        qgui.QLog = uicontrol('Style', 'radiobutton', 'Parent', uigetqh2, 'String', 'log', 'Value', 1, 'Enable', 'off', 'Callback', @onQLog);
        
        uigetqh3   = uiextras.HBox('Parent', uigetqb2);
        qgui.Qmin_t = uicontrol('Style', 'text', 'Parent', uigetqh3, 'String', 'q min');
        qgui.Qmin   = uicontrol('Style', 'edit', 'Parent', uigetqh3, 'String', num2str(min(pm_vec)), 'Callback', @onQmin);
        
        uigetqh4   = uiextras.HBox('Parent', uigetqb2);
        qgui.Qmax_t = uicontrol('Style', 'text', 'Parent', uigetqh4, 'String', 'q max');
        qgui.Qmax   = uicontrol('Style', 'edit', 'Parent', uigetqh4, 'String', num2str(max(pm_vec)), 'Callback', @onQmax);
        
        uigetqh5 = uiextras.HBox('Parent', uigetqb2);
        qgui.Qset = uicontrol('Style', 'pushbutton', 'Parent', uigetqh5, 'String', 'set', 'Callback', @onUpdateQTable);
        
        uigetqh6 = uiextras.HBox('Parent', uigetqb2);
        
        uigetqh7 = uiextras.HBox('Parent', uigetqb2);
        uicontrol('Style', 'pushbutton', 'Parent', uigetqh7, 'String', 'Return', 'Callback', @getqreturn)
        
        
        set(uigetqb2, 'Sizes', [28 28 28 28 28 -1 28])
        
        set(uigetqf, 'Sizes', [170 130])
    end


    function onQnumber(a,b)
        qdat.nq = str2double(get(qgui.Qn, 'String'));
    end

    function onQLin(a,b)
        qdat.qspace = 1;
        set(qgui.QLin, 'Enable', 'off', 'Value', 1)
        set(qgui.QLog, 'Enable', 'on',  'Value', 0)
    end

    function onQLog(a,b)
        qdat.qspace = 2;
        set(qgui.QLin, 'Enable', 'on',  'Value', 0)
        set(qgui.QLog, 'Enable', 'off', 'Value', 1)
    end

    function onQmin(a,b)
        qdat.qmin = str2double(get(qgui.Qmin, 'String'));
    end

    function onQmax(a,b)
        qdat.qmax = str2double(get(qgui.Qmax, 'String'));
    end

    function getqreturn(a,b)
        uiresume(gcbf)
        delete(qgui.getqfig)
    end

    function onUpdateQTable(a,b)
        switch qdat.qspace
            case 1
                pm_vec   = linspace(qdat.qmin, qdat.qmax, qdat.nq);
                Imax_vec = pm_vec./taup1;
            case 2
                pm_vec = logspace(log10(qdat.qmin), log10(qdat.qmax), qdat.nq);
                Imax_vec = pm_vec./taup1;                
        end 
        set(qgui.qtab, ...
            'Data', [(1:length(pm_vec))' pm_vec' (Imax_vec)'])
    end
uiwait(gcf)
end
