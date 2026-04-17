function [fdata,proclog]=mrsSigPro_reduceQ(fdata,factor,proclog)

if ~isfield(fdata.info,"reducedQ")
    fdata.info.reducedQ = 1;
end

assert(nargin>=2,'not enough arguments')
assert(int8(factor)==factor, 'factor must be integer')
nq = length(fdata.Q);
nrec = length(fdata.Q(1).rec);
mq = nq/factor;
mrec = nrec*factor;
assert(int8(mq)==mq,'nq must be a multiple of factor')

fdata_temp = fdata;
fdata = rmfield(fdata,"Q");

if nargin==3
    proclog_temp = proclog;
    proclog = rmfield(proclog,"event");
    proclog = rmfield(proclog,"Q");
    proclog.event = zeros(1,8);
end

for iq=1:nq
    jq = floor((iq-1)/factor)+1;
    for irec=1:nrec
        jrec = mod(iq-1,factor)*nrec+irec;
        fdata_temp.Q(iq).rec(irec).q_org = fdata_temp.Q(iq).q;
        fdata.Q(jq).rec(jrec) = fdata_temp.Q(iq).rec(irec);
        if isfield(fdata,'noise')
            fdata.noise.rec(jrec) = fdata_temp.noise.rec(irec);
        end
        if isfield(fdata.info,'listening') && fdata.info.listening
            fdata.Q(jq).rec(jrec).info.phases.phi_gen=[0 1 0 0];
        else
            fdata.Q(jq).rec(jrec).info.phases.phi_gen=fdata_temp.Q(iq).rec(irec).info.phases.phi_gen;
        end
        if nargin==3
            event_temp=proclog_temp.event(proclog_temp.event(:,2)==iq & proclog_temp.event(:,3) == irec,:);
            if ~isempty(event_temp)
                event_temp(:,2)=jq;
                event_temp(:,3)=jrec;
                proclog.event=cat(1,proclog.event, event_temp);
            end
        end
    end
    if mod(iq,factor)==1
        fdata.Q(jq).q = mean([fdata_temp.Q(iq:iq+factor-1).q]);
        fdata.Q(jq).q2 = mean([fdata_temp.Q(iq:iq+factor-1).q2]);
        if nargin==3
            proclog.Q(jq) = proclog_temp.Q(iq);
            proclog.Q(jq).q = fdata.Q(jq).q;
            proclog.Q(jq).q2 = fdata.Q(jq).q2;
        end
    end
end

fdata.header.nrec = mrec;
fdata.header.nQ = mq;
%fdata.info.reducedQ = fdata.info.reducedQ*factor;
fdata.info.reducedQ = fdata.info.reducedQ*factor;