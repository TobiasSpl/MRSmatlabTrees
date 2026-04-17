function uiparameter = Request_userinfo(fdata)

% allow only one instance of the GUI
mfig = findobj('Name', 'Requesting GMR survey information');
if ~isempty(mfig)
    delete(mfig)
end

% set requested parameters to default
uiparameter = { 'Header file',          'x','','','','','','','',       ' Name of header file';...
                'RX task',              1,  1,  0,  0,  0,  0,  0,  0,  ' 0=off, 1=RX, 2=REF';...     
                'TX task',              1,  0,  0,  0,  0,  0,  0,  0,  ' 0=off, 1=TX (only one allowed)';...     
                'loop type',            1,  1,  0,  0,  0,  0,  0,  0,  ' 0=off, 1=circular, 2=square, 3=circ-8, 4=sq-8';...
                'loop size',            60, 30,  0,  0,  0,  0,  0,  0,  ' [m] (diameter / edge length)';...
                'loop turns',           1,  1,  0,  0,  0,  0,  0,  0,  ' ';...
                'Sample frequency',     1,  '','','','','','','',       ' [Hz] (obtained from header file)';...
                'Prepulse delay',       50, '','','','','','','',       ' [ms] time before pulse';...
                'Dead time',            8,  '','','','','','','',       ' [ms] time between pulse shutdown and FID recording';...
                'Current gain',         -1, '','','','','','','',       ' (obtained from header file)';...
                'Voltage gain',         -1, '','','','','','','',       ' (obtained from header file)';...   
                'Frequency modulation', 2, 100,0,0,0,'','','',       ' shape, startdf, enddf, paraA, paraB';...
                'Listening',            0, '','','','','','','',       ' shape, startdf, enddf, paraA, paraB'};
            
% set global structures
gui   = createInterface;
onLoad(0,0);                % call load on startup

    function gui = createInterface
        
    gui = struct();
    screensz = get(0,'ScreenSize');
    

    %% MAKE GUI WINDOW ----------------------------------------------------
    gui.figureid = figure( ...
        'Name', 'Requesting GMR survey information', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Toolbar', 'none', ...
        'HandleVisibility', 'on');
    
    set(gui.figureid, 'Position', [15 screensz(4)-500 900 380])

    % Set default panel settings
    %uiextras.set(gui.figureid, 'DefaultBoxPanelFontSize', 12);
    %uiextras.set(gui.figureid, 'DefaultBoxPanelFontWeight', 'bold')
    %uiextras.set(gui.figureid, 'DefaultBoxPanelPadding', 5)
    %uiextras.set(gui.figureid, 'DefaultHBoxPadding', 2)


    %% MAKE UICONTROLS ----------------------------------------------------
    mainbox = uiextras.VBox('Parent', gui.figureid);
    
    % boxes & panel for tables
    box_h2 = uiextras.HBox('Parent', mainbox);
        panel1 = uiextras.BoxPanel(...
                            'Parent', box_h2, ...
                            'Title', 'User input');
            box_h2v1 = uiextras.VBox('Parent', panel1);
            
                % table with general survey info
                gui.table_info = uitable('Parent', box_h2v1);
                set(gui.table_info, ...
                    'CellEditCallback', @onEditTable, ...
                    'ColumnName', {'Value', 'Info'}, ...
                    'ColumnWidth', {50 605}, ...
                    'RowName', uiparameter(7:end-1,1), ...
                    'Enable', 'off', ...
                    'Data',uiparameter(7:end-1,[2 10]),...
                    'ColumnFormat', {'numeric','char'},...
                    'ColumnEditable', [true false]);


                uimeasv01 =  uiextras.HBox( 'Parent', box_h2v1);
                uicontrol('Style', 'Text', 'Parent', uimeasv01, 'String', 'frequency-modulation');
%                 uicontrol('Style', 'Text', 'Parent', uimeasv01, 'String', '');   
                gui.Fmod = uicontrol('Style', 'popupmenu', ...
                        'Parent', uimeasv01, ...
                        'Enable', 'off', ...
                        'String', {'linear', 'tanhGMR','tanhMIDI'},...
                        'Value', uiparameter{12,2},...
                        'Callback', @onfmod); 

                gui.OffResPar = uitable('Parent', uimeasv01);
                set(gui.OffResPar, ...
                'Enable', 'off', ...
                'Data', uiparameter(12,3:6), ...
                'ColumnName', {'start', 'end', 'A', 'B'}, ...
                'ColumnWidth', {30 30 20 20}, ...
                'RowName', {'df[Hz]'}, ...
                'ColumnEditable', true, ...
                'CellEditCallback', @onOffResCellEdit);
                uicontrol('Style', 'Text', 'Parent', uimeasv01, 'String', '');   
                                
                % check for AHP
                if fdata.header.sequenceID==8 || fdata.header.sequenceID==10
                         set(gui.Fmod, 'Enable', 'on');
                         set(gui.OffResPar, 'Enable', 'on');                         
                end
        
                set(uimeasv01, 'Sizes', [180 50 180 -1]) 
            
       
                % table with channel-specific info
                gui.table_channels = uitable('Parent', box_h2v1);
                set(gui.table_channels, ...
                    'CellEditCallback', @onEditTable, ...
                    'ColumnName', {'Ch1', 'Ch2', 'Ch3', 'Ch4', 'Ch5', 'Ch6', 'Ch7', 'Ch8', 'Info'}, ...
                    'ColumnWidth', {50 50 50 50 50 50 50 50 288}, ...
                    'RowName', uiparameter(2:6,1), ...
                    'Enable', 'off', ...
                    'ColumnEditable', [true true true true true true true true false],...
                    'Data', uiparameter(2:6,2:10));
                
                gui.listen_cbx = uicontrol('Style', 'checkbox', 'Parent', box_h2v1, 'String', 'listen'); 

                set(box_h2v1, 'Sizes', [130 40 115 40])

                
    box_h3 = uiextras.HBox('Parent', mainbox);      
        gui.pushbutton_save = uicontrol(...
            'Enable', 'off', ...
            'Style', 'Pushbutton', ...
            'Parent', box_h3, ...
            'String', 'Continue', ...
            'Callback', @onContinue);
    set(box_h3, 'Sizes', [-1])        


    set(mainbox, 'Sizes',[-1  30])
    end

%% on LOAD
    function onLoad(a,b) %#ok<*INUSD>
          
        % update parameters
        for iCh = 1:length(fdata.header.rxt)
            % convert from GMR rxt to MRSmatlab rxt
            % GMR: 0 detect, 1 reference, 2 off
            % MRS: 0 off, 1 RX, 2 reference

            uiparameter(2,iCh+1) = {mod(fdata.header.coil(iCh).task+1,3)};
            %uiparameter(3,iCh+1) = {mod(fdata.header.coil(iCh).task+1,3)};
             % GMR Geometry	1: Square; 2: Circle; 3: Figure 8
             % MRS 0=off, 1=circular, 2=square, 3=circ-8, 4=sq-8';...
             switch fdata.header.coil(iCh).shape
                 case 0; uiparameter(4,iCh+1) = {0};
                 case 1; uiparameter(4,iCh+1) = {2};
                 case 2; uiparameter(4,iCh+1) = {1};
                 case 3; uiparameter(4,iCh+1) = {3};
             end
            uiparameter(5,iCh+1) = {fdata.header.coil(iCh).size};
            uiparameter(6,iCh+1) = {fdata.header.coil(iCh).nturns};
            %uiparameter(2,iCh+1) = {mod(fdata.header.rxt(iCh)+1,3)};
        end
        %uiparameter(3,1)  = {1};                % set ch1 to TX per default
        uiparameter(7,2)  = {fdata.header.fS};
        uiparameter(10,2) = {fdata.header.gain_I};
        uiparameter(11,2) = {fdata.header.gain_V};
        
        % update default prepulse delay
        switch fdata.header.sequenceID
            case {1,2}
                uiparameter(8,2)  = {50};   % prepulse delay is 50ms for sequences 1 & 2
            case {4,8}
                uiparameter(8,2)  = {10};   % prepulse delay is 10ms for sequence 4 % 8
        end
        
        
        % if version > 1: get dead time from header file
        if fdata.header.DAQversion > 1
            uiparameter(9,2)  = {fdata.header.tau_dead*1000};
        end
        % update gui
        set(gui.table_channels, ...
                'Enable', 'on', ...
                'Data',uiparameter(2:6,2:10));
        set(gui.table_info, ...
                'Enable', 'on', ...
                'Data',uiparameter(7:end-1,[2 10]));
        set(gui.pushbutton_save,'Enable', 'on')
    end
  
    %% ON EDIT TABLE ------------------------------------------------------
    function onEditTable(a,b)
        
        % get table data
        xtable = get(a,'Data');
        
        % if RXtask & TXtask are both zero, set all other values to zero
        for iCh = 1:size(xtable,2)-1
            if xtable{1,iCh}==0 && xtable{2,iCh}==0
                xtable{3,iCh} = 0;
                xtable{4,iCh} = 0;
                xtable{5,iCh} = 0;
            end
        end
        
        % allow only one TX
        if b.Indices(1)==2 && b.NewData == 1    % if one TX was set to 1
            for iCh = 1:size(xtable,2)-1
                xtable{2,iCh} = 0;              % set all TX to zero
            end
            xtable{2,b.Indices(2)} = 1;         % reset changed TX to one
        end
        
        % update table
        set(a, 'Data', xtable)
        
        % select next cell: needs findjobj toolbox and checks if it is
        % installed
        if exist('findjobj')
            %get java handle of table
            jUIScrollPane = findjobj(a);
            jUITable = jUIScrollPane.getViewport.getView;
            row=b.Indices(1);
            col=b.Indices(2);
            %select next row if col8 is reached
            if col==8
                row=row+1;
                col=0;
            end
            %select cell
            jUITable.changeSelection(row-1,col, false, false);
        else
            message='install findjobj to make navigating this table easier: https://de.mathworks.com/matlabcentral/fileexchange/14317-findjobj-find-java-handles-of-matlab-graphic-objects';
            %show warning only once and without backtrace
            if ~strcmp(lastwarn,message)
                warning off backtrace
                warning(message);
                warning on backtrace
            end
        end
        set(gui.pushbutton_save,'Enable', 'on')
    end
%% Callbacks
    function onfmod(a,b)
        uiparameter{12,2} = get(gui.Fmod, 'Value');
    end

   function onOffResCellEdit(~, EdtData)
        switch EdtData.Indices(2)
            case 1
                uiparameter{12,3}   = EdtData.NewData;
            case 2
                uiparameter{12,4}   = EdtData.NewData;
            case 3
                uiparameter{12,5}   = EdtData.NewData;
            case 4
                uiparameter{12,6}   = EdtData.NewData;
        end
        set(gui.OffResPar, ...
            'Data', uiparameter(12,3:6));
   end

%% FUNCTION Continue_GMRUSERINFO -----------------------------------------
    function onContinue(a,b)   
        % collect info from ui table
        data_table_channels  = get(gui.table_channels, 'Data');
        uiparameter(2:6,2:9) = data_table_channels(:,1:8);
        uiparameter(13,2) = {get(gui.listen_cbx, 'Value')};
        delete(gui.figureid)
    end

uiwait(gui.figureid)
end