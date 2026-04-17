function [fdata,proclog] = reduceQ_GUI(fdata,proclog)

% allow only one instance of the GUI
mfig = findobj('Name', 'Reduce Q values');
if ~isempty(mfig)
    delete(mfig)
end

% set requested parameters to default
nq = length(fdata.Q);
data= cell(nq,3);
factor = 2;
for iq=1:nq
    nrec(iq) = length(fdata.Q(iq).rec);
    q_org(iq) = fdata.Q(iq).q;
end
% set global structures
gui   = createInterface;
%if there is a problem with webwindows, give user full access to matlab folders
onLoad(0,0);                % call load on startup
function gui = createInterface
        
    screensz = get(0,'ScreenSize');
    

    %% MAKE GUI WINDOW ----------------------------------------------------
    gui.figureid = uifigure( ...
        'Name', 'Reduce Q values', ...
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
    ColWidth = num2cell([50, 100 ,50]);
    ColEdit = true(1,nq);
    % boxes & panel for tables
        gui.table = uitable('Parent', gui.mainbox);
            set(gui.table, ...
                    'CellEditCallback', @onEditTable, ...
                    'ColumnWidth', ColWidth, ...
                    'Enable', 'off', ...
                    'ColumnEditable', ColEdit, ...
                    'Data', data(:,:));
            gui.table.Layout.Row = [1 17];
            gui.table.Layout.Column = [1 2];
        gui.ax = axes('Parent', gui.mainbox);
        gui.ax.Layout.Row = [1 17];
        gui.ax.Layout.Column = [3 6];

        
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
                'Text', 'from top');

            gui.rb_value=uiradiobutton('Parent',gui.control_box_group1, ...
                'Value', false, ...
                'Position',[1 5 100 20],...
                'Text', 'from bottom');
            
            gui.input = uitextarea('Parent',gui.panel,...
                'Value','2',...
                'Position',[1 25 100 20],...
                'ValueChangedFcn',@onEdit);

end
%% on LOAD
    function onLoad(a,b) %#ok<*INUSD>
        updateTable(a,b)
        plotQ(a,b)
    end
  
    %% ON EDIT TABLE ------------------------------------------------------
    function onEditTable(a,b)
        % get table data
        data = get(a,'Data');
        set(a, 'Data', data)
        plotQ(a,b)
    end
%% Callbacks
    function plotQ(a,b)
        cla(gui.ax)
        plot(gui.ax,q_org,"Marker","*","LineStyle","none","Color","black");
        hold on
        for iq_new = 1:max([data{:,1}])
            qs = find([data{:,1}]==iq_new);
            plot(gui.ax,qs,q_org(qs),"Marker",".","LineStyle","none");
            if length(qs)>1
                rectangle('Position',[min(qs),min(q_org(qs)),max(qs)-min(qs),max(q_org(qs))-min(q_org(qs))])
            end
        end
        set(gui.ax,"YScale","log")
    end

    function onEdit(a,b)
        factor =  str2num(gui.input.Value{:});
        updateTable(a,b)
        plotQ(a,b)
    end


%% FUNCTION Continue_GMRUSERINFO -----------------------------------------
    function onContinue(a,b)   
        % collect info from ui table
        temp = get(gui.table, 'Data')';
        Index = [temp{1,:}];
        fdata0 = fdata;
        proclog0 = proclog;
        nq_new = length(unique(Index));
        nrec = zeros(nq_new,1);
        %records as extra stacks
        fdata = rmfield(fdata,"Q");
        for iq=1:nq
            jq = Index(iq);
            for irec=1:length(fdata0.Q(iq).rec)
                jrec = irec+nrec(jq);
                fdata.Q(jq).rec(jrec) = fdata0.Q(iq).rec(irec);
                if isfield(fdata,'noise')
                    fdata.noise.rec(jrec) = fdata0.noise.rec(irec);
                end
                %{
                if isfield(fdata.info,'listening') && fdata.info.listening
                    fdata.Q(jq).rec(jrec).info.phases.phi_gen=[0 1 0 0];
                else
                    fdata.Q(jq).rec(jrec).info.phases.phi_gen=fdata0.Q(iq).rec(irec).info.phases.phi_gen;
                end
                %}
            end
            nrec(jq) = nrec(jq)+length(fdata0.Q(iq).rec);
        end
        
        proclog = rmfield(proclog,"Q");
        for jq = 1:nq_new
            iq = find(Index==jq);
            fdata.Q(jq).q = mean([fdata0.Q(iq).q]);
            fdata.Q(jq).q2 = mean([fdata0.Q(iq).q2]);
            proclog.Q(jq) = proclog0.Q(iq(1));
            proclog.Q(jq).q = fdata.Q(jq).q;
            proclog.Q(jq).q2 = fdata.Q(jq).q2;
        end

        delete(gui.figureid)
    end

    function updateTable(a,b)
        nq = size(data,1);
        for iq=1:nq
            data(iq,1)={ceil(iq/factor)};
            data(iq,2)={q_org(iq)};
            data(iq,3)={nrec(iq)};
        end
        set(gui.table, ...
            'Enable', 'on', ...
            'Data',data(:,:), ...
            'ColumnFormat',{'numeric', 'long', 'numeric'});
    end


uiwait(gui.figureid)
end