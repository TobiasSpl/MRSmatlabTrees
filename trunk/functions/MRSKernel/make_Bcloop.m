function [B, dh] = make_Bcloop(z,size,turns,zoff,zext,nz,signs,earth,model)

earthf = earth.f;
earthsm = earth.sm;
earthzm = earth.zm;
earthres = earth.res;

r = model.r;
Dr = model.Dr;
phi = model.phi;
dphi = model.dphi;

for i=1:length(size)
    if i==1
        if nz > 1
            [B,dh] = B1cloop_v2(size(i)/2, r, Dr, z+zoff-zext/2, earthf, earthsm, [0 earthzm], earthres, phi, dphi);
            B = multiplyBraw(B,turns(i)/nz);
            for j = 1:nz-1
                [Btmp,dh] = B1cloop_v2(size(i)/2,r,Dr,z+zoff+j/(nz-1)*zext-zext/2,earthf,earthsm,[0 earthzm],1, phi, dphi);
                Btmp = multiplyBraw(Btmp,turns(i)/nz*signs(j+1));
                B = addBraw(Btmp,B);
            end
        else
            [B,dh] = B1cloop_v2(size(i)/2, r, Dr, z+zoff, earthf, earthsm, [0 earthzm], earthres, phi, dphi);
            B = multiplyBraw(B,turns(i));
        end
    else
        if nz > 1
            [Btmp,dh] = B1cloop_v2(size(i)/2, r, Dr, z+zoff-zext/2, earthf, earthsm, [0 earthzm], earthres, phi, dphi);
            B = addBraw(B,multiplyBraw(Btmp,turns(i)/nz));
            for j = 1:nz-1
                [Btmp,dh] = B1cloop_v2(size(i)/2,r,Dr,z+zoff+j/(nz-1)*zext-zext/2 ,earthf,earthsm,[0 earthzm],1, phi, dphi);
                Btmp = multiplyBraw(Btmp,turns(i)/nz*signs(j+1));
                B = addBraw(Btmp,B);
            end
        else
            [Btmp,dh] = B1cloop_v2(size(i)/2, r, Dr, z+zoff, earthf, earthsm, [0 earthzm], earthres, phi, dphi);
            Btmp = multiplyBraw(Btmp,turns(i));
            B = addBraw(Btmp,B);
        end
    end
end
end

function B = multiplyBraw(B,m)
    B.x=B.x*m;
    B.y=B.y*m;
    B.z=B.z*m;
    if isfield(B,"Br")
        B.Br=B.Br*m;
    end
    if isfield(B,"Bz")
        B.Bz=B.Bz*m;
    end
end

function B = addBraw(B,B2)
    B.x=B.x+B2.x;
    B.y=B.y+B2.y;
    B.z=B.z+B2.z;
    if isfield(B,"Br")
        B.Br=B.Br+B2.Br;
    end
    if isfield(B,"Bz")
        B.Bz=B.Bz+B2.Bz;
    end
end