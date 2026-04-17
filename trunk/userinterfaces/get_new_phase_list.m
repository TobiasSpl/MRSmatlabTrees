function phase_list = get_new_phase_list(fdata,irx)

% allow only one instance of the GUI
mfig = findobj('Name', 'Requesting new Phases');
if ~isempty(mfig)
    delete(mfig)
end

% set requested parameters to default
nq = length(fdata.Q);
nrec = length(fdata.Q(1).rec);
nrx = length(fdata.Q(1).rec(1).rx);
data= cell(nrec+1,nq,nrx);
for iq=1:nq
    for iirx=irx %posibility to extend this to all channels
        for irec=1:nrec
            data(irec,iq,irx)={fdata.Q(iq).rec(irec).info.phases.phi_gen(2)};
        end
        for i=nrec+1
            data(i,iq,irx)={false};
        end
    end
end

% set global structures
gui   = createInterface;
%if there is a problem with webwindows, give user full access to matlab folders
onLoad(0,0);                % call load on startup
function gui = createInterface_old
        
    gui = struct();
    screensz = get(0,'ScreenSize');
    
%% MAKE GUI WINDOW ----------------------------------------------------
    gui.figureid = figure( ...
        'Name', 'Requesting new Phases', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Toolbar', 'none', ...
        'HandleVisibility', 'on');
    
    set(gui.figureid, 'Position', [15 screensz(4)-850 900 780])

    % Set default panel settings
    %uiextras.set(gui.figureid, 'DefaultBoxPanelFontSize', 12);
    %uiextras.set(gui.figureid, 'DefaultBoxPanelFontWeight', 'bold')
    %uiextras.set(gui.figureid, 'DefaultBoxPanelPadding', 5)
    %uiextras.set(gui.figureid, 'DefaultHBoxPadding', 2)


    %% MAKE UICONTROLS ----------------------------------------------------
    mainbox = uiextras.VBox('Parent', gui.figureid);
    ColNames = num2cell(1:nq);
    RowNames = [num2cell(1:nrec),{'overwrite'},num2cell(1:nrec)];
    ColWidth = num2cell(ones(1,nq)*50);
    ColEdit = true(1,nq);
    % boxes & panel for tables
    box_v2 = uiextras.VBox('Parent', mainbox);
    panel1 = uiextras.BoxPanel(...
                            'Parent', box_v2, ...
                            'Title', 'User input');
            box_v2_p1 = uiextras.VBox('Parent', panel1);
                gui.table_phase = uitable('Parent', box_v2_p1);
                set(gui.table_phase, ...
                    'CellEditCallback', @onEditTable, ...
                    'ColumnName', ColNames, ...
                    'ColumnWidth', ColWidth, ...
                    'RowName', RowNames, ...
                    'Enable', 'off', ...
                    'ColumnEditable', ColEdit, ...
                    'Data', data(:,:,irx));
                
    box_h3 = uiextras.HBox('Parent', mainbox);      
        gui.pushbutton_continue = uicontrol(...
            'Enable', 'on', ...
            'Style', 'Pushbutton', ...
            'Parent', box_h3, ...
            'String', 'Continue', ...
            'Callback', @onContinue);
    set(box_h3, 'Sizes', [-1])        


    set(mainbox, 'Sizes',[-1  30])
    end

function gui = createInterface(gui)
        
    screensz = get(0,'ScreenSize');
    

    %% MAKE GUI WINDOW ----------------------------------------------------
    gui.figureid   = uifigure(...       
        'Name', 'Requesting new Phases', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'Toolbar', 'none', ...
        'HandleVisibility', 'on');
    set(gui.figureid, 'Position', [15 screensz(4)-850 900 780])

    % Set default panel settings
    %uiextras.set(gui.figureid, 'DefaultBoxPanelFontSize', 12);
    %uiextras.set(gui.figureid, 'DefaultBoxPanelFontWeight', 'bold')
    %uiextras.set(gui.figureid, 'DefaultBoxPanelPadding', 5)
    %uiextras.set(gui.figureid, 'DefaultHBoxPadding', 2)


    %% MAKE UICONTROLS ----------------------------------------------------
    gui.mainbox = uigridlayout(gui.figureid,[20 6]);
    ColNames = num2cell(1:nq);
    RowNames = [num2cell(1:nrec),{'overwrite'}];
    ColWidth = num2cell(ones(1,nq)*50);
    ColEdit = true(1,nq);
    % boxes & panel for tables
        gui.table_phase = uitable('Parent', gui.mainbox);
            set(gui.table_phase, ...
                    'CellEditCallback', @onEditTable, ...
                    'ColumnName', ColNames, ...
                    'ColumnWidth', ColWidth, ...
                    'RowName', RowNames, ...
                    'Enable', 'off', ...
                    'ColumnEditable', ColEdit, ...
                    'Data', data(:,:,irx));
            gui.table_phase.Layout.Row = [1 17];
            gui.table_phase.Layout.Column = [1 6];
        gui.label_Selection = uilabel(gui.mainbox,'Text','q-Selection:');
            gui.label_Selection.Layout.Row = [18];
            gui.label_Selection.Layout.Column = [1];

        gui.pushbutton_SAll = uibutton(gui.mainbox,'push', ...
            'Text', 'All', ...
            'ButtonPushedFcn', @onSAll);
            gui.pushbutton_SAll.Layout.Row = [18];
            gui.pushbutton_SAll.Layout.Column = [2];
        gui.pushbutton_SOdd = uibutton(gui.mainbox,'push', ...
            'Text', 'Odd', ...
            'ButtonPushedFcn', @onSOdd);
            gui.pushbutton_SOdd.Layout.Row = [18];
            gui.pushbutton_SOdd.Layout.Column = [3];
        gui.pushbutton_SPair = uibutton(gui.mainbox,'push', ...
            'Text', 'Pairwise', ...
            'ButtonPushedFcn', @onSPair);
            gui.pushbutton_SPair.Layout.Row = [18];
            gui.pushbutton_SPair.Layout.Column = [4];
        gui.pushbutton_SInv = uibutton(gui.mainbox,'push', ...
            'Text', 'Invert', ...
            'ButtonPushedFcn', @onSInv);
            gui.pushbutton_SInv.Layout.Row = [18];
            gui.pushbutton_SInv.Layout.Column = [5];

        gui.pushbutton_reset = uibutton(gui.mainbox,'push', ...
            'Text', 'Reset', ...
            'ButtonPushedFcn', @onReset);
            gui.pushbutton_reset.Layout.Row = [19 20];
            gui.pushbutton_reset.Layout.Column = [1];
        gui.pushbutton_overwrite = uibutton(gui.mainbox,'push', ...
            'Text', 'Overwrite ...', ...
            'ButtonPushedFcn', @onOverwrite);
            gui.pushbutton_overwrite.Layout.Row = [19 20];
            gui.pushbutton_overwrite.Layout.Column = [2];
        
        gui.control_box_group1 = uibuttongroup('Parent', gui.mainbox);
            gui.control_box_group1.Layout.Row = [19 20];
            gui.control_box_group1.Layout.Column = [3];
        
        gui.panel=uipanel('Parent', gui.mainbox);
            gui.panel.Layout.Row = [19 20];
            gui.panel.Layout.Column = [4];
        
        gui.control_box_group2 = uibuttongroup('Parent', gui.mainbox);
            gui.control_box_group2.Layout.Row = [19 20];
            gui.control_box_group2.Layout.Column = [5];

        gui.pushbutton_save = uibutton(gui.mainbox,'push', ...
            'Text', 'Continue', ...
            'ButtonPushedFcn', @onContinue);
            gui.pushbutton_save.Layout.Row = [19 20];
            gui.pushbutton_save.Layout.Column = [6];
            
            gui.rb_col=uiradiobutton('Parent',gui.control_box_group1, ...
                'Value', true, ...
                'Position',[1 25 100 20],...
                'Text', 'with Column');

            gui.rb_value=uiradiobutton('Parent',gui.control_box_group1, ...
                'Value', false, ...
                'Position',[1 5 100 20],...
                'Text', 'with Value');
            
            gui.input = uitextarea('Parent',gui.panel,...
                'Value','',...
                'Position',[1 25 100 20]);

            gui.cbx_even=uicheckbox('Parent',gui.control_box_group2, ...
                'Value', true, ...
                'Position',[1 25 100 20],...
                'Text', 'even Records');

            gui.cbx_odd=uicheckbox('Parent',gui.control_box_group2, ...
                'Value', true, ...
                'Position',[1 5 100 20],...
                'Text', 'odd Records');

    color_cells(gui,[1:nq])
end

    function color_cells(gui,qs)
        if isempty(qs) ||nrec==1
            return
        else
            for iiq=1:length(qs)
                for iirec=1:2:nrec
                    %difference between phase and next should be pi, calculate
                    %relative deviation
                    deviation(iirec,iiq)=abs(abs(data{iirec,qs(iiq),irx}-data{iirec+1,qs(iiq),irx})-pi)/pi;
                    deviation(iirec+1,iiq)=deviation(iirec,iiq);
                    %even and odd values needed for stability criteria
                    even_val(ceil(iirec/2),iiq)=data{iirec,qs(iiq),irx};
                    odd_val(ceil(iirec/2),iiq)=data{iirec+1,qs(iiq),irx};
                end
            end
            if nrec>=4
                stability=1-(sum(abs(even_val-mean(even_val)))+sum(abs(odd_val-mean(odd_val))))/nrec;
            else
                stability=zeros(length(qs),1);
            end
            if ~isempty(gui.table_phase.StyleConfigurations)
                remove=[];
                for i=1:length(gui.table_phase.StyleConfigurations.TargetIndex)
                    if ismember(gui.table_phase.StyleConfigurations.TargetIndex{i}(3),qs)
                        remove=[remove,i];
                    end
                end
                removeStyle(gui.table_phase,remove)
            end
            for iiq=1:length(qs)
                for iirec=1:2:nrec
                    style=uistyle("BackgroundColor",[sqrt(deviation(iirec,iiq)),1-sqrt(deviation(iirec,iiq)),0.3]);
                    addStyle(gui.table_phase,style,'cell',[iirec qs(iiq);iirec+1 qs(iiq)])
                end
            end
            %set columns to use and columns to overwrite on startup
            if length(qs)==nq
                iq_use=find(sum(deviation)==min(sum(deviation)),1,"first");
                set(gui.input,'Value', num2str(iq_use));
                for iiq=1:length(qs)
                    data(nrec+1,qs(iiq),irx) = {sum(abs(deviation(:,qs(iiq)))/nrec)>0.15 && stability(qs(iiq))<0.9};
                end
            end
        end
    end
%% on LOAD
    function onLoad(a,b) %#ok<*INUSD>
        
        % update gui
        set(gui.table_phase, ...
                'Enable', 'on', ...
                'Data',data(:,:,irx));
    end
  
    %% ON EDIT TABLE ------------------------------------------------------
    function onEditTable(a,b)
        % get table data
        temp = get(a,'Data');
        %get java handle of table
        row=b.Indices(1);
        col=b.Indices(2);
        %reset org table
        data(1:nrec+1,:,irx) = temp(1:nrec+1,:);
        set(a, 'Data', temp)
        if row<=nrec
            color_cells(gui,[col])
        end
    end
%% Callbacks

%% FUNCTION Continue_GMRUSERINFO -----------------------------------------
    function onContinue(a,b)   
        % collect info from ui table
        temp = get(gui.table_phase, 'Data')';
        phase_list(:,:)  = cell2mat(temp(:,1:nrec));
        delete(gui.figureid)
    end

    function onOverwrite(a,b)   
        % collect info from ui table
        temp = get(gui.table_phase, 'Data');
        overwrite=find([temp{nrec+1,:}]==true);
        use=str2num(cell2mat(gui.input.Value));
        assert(isnumeric(use)&&length(use)==1,'input needs to be a single numeric value')
        
        col_bool=get(gui.rb_col,'Value');
        even_bool=get(gui.cbx_even,'Value');
        odd_bool=get(gui.cbx_odd,'Value');

        for iiq=1:length(overwrite)
            if even_bool
                if col_bool
                    data(2:2:nrec,overwrite(iiq),irx) = temp(2:2:nrec,use);
                else
                    data(2:2:nrec,overwrite(iiq),irx) = {use};
                end
            end
            if odd_bool
                if col_bool
                    data(1:2:nrec,overwrite(iiq),irx) = temp(1:2:nrec,use);
                else
                    data(1:2:nrec,overwrite(iiq),irx) = {use};
                end
            end
        end
        set(gui.table_phase, 'Data', data(:,:,irx))
        color_cells(gui,overwrite)
    end

    function onReset(a,b)
        for iiq=1:nq
            for iirec=1:nrec
                data(iirec,iiq,irx)={fdata.Q(iiq).rec(iirec).info.phases_org.phi_gen(irx)};
            end
        end
        set(gui.table_phase, 'Data', data(:,:,irx))
        color_cells(gui,[1:nq])
    end

    function onSAll(a,b)
        for iiq=1:nq
            data(nrec+1,iiq,irx)={true};
        end
        set(gui.table_phase, 'Data', data(:,:,irx))
    end

    function onSOdd(a,b)
        for iiq=1:nq
            data(nrec+1,iiq,irx)={mod(iiq,2)==1};
        end
        set(gui.table_phase, 'Data', data(:,:,irx))
    end

    function onSPair(a,b)
        for iiq=1:nq
            data(nrec+1,iiq,irx)={mod(iiq+1,4)>1};
        end
        set(gui.table_phase, 'Data', data(:,:,irx))
    end
    
    function onSInv(a,b)
        temp = get(gui.table_phase, 'Data');
        for iiq=1:nq
            overwrite=temp{nrec+1,iiq};
            data(nrec+1,iiq,irx)={~overwrite};
        end
        set(gui.table_phase, 'Data', data(:,:,irx))
    end


uiwait(gui.figureid)
end