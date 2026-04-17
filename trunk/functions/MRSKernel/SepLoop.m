function [B1,B2,Bpre] = SepLoop(B01,B02,loop,ic,dh,varargin)

if nargin > 5
    Bp = varargin{1};
    usePx = true;
else
    Bpre = [];
    usePx = false;
end

eightOritn = loop(1).eightoritn/360.0*2.0*pi;

% get Cartesian coordinates for first loop and reshape to vector 
Xc01 = reshape(cos(B01.phi')*B01.r',1,size(B01.x,1)*size(B01.x,2));
Yc01 = reshape(sin(B01.phi')*B01.r',1,size(B01.x,1)*size(B01.x,2));

% same for second but shifts by loop distance
Xc02 = reshape(cos(B02.phi')*B02.r' + loop.eightsep*cos(-eightOritn),1,size(B02.x,1)*size(B02.x,2));
Yc02 = reshape(sin(B02.phi')*B02.r' + loop.eightsep*sin(-eightOritn),1,size(B02.x,1)*size(B02.x,2));

% reshape field to vector as needed for interpolation
B01x = reshape(B01.x,1,size(B01.x,1)*size(B01.x,2));
B01y = reshape(B01.y,1,size(B01.x,1)*size(B01.x,2));
B01z = reshape(B01.z,1,size(B01.x,1)*size(B01.x,2));

% reshape field to vector as needed for interpolation
B02x = reshape(B02.x,1,size(B02.x,1)*size(B02.x,2));
B02y = reshape(B02.y,1,size(B02.x,1)*size(B02.x,2));
B02z = reshape(B02.z,1,size(B02.x,1)*size(B02.x,2));

% split coordinate vector of inner centers of triangles to x/y
Xnew = ic(:,1); Ynew = ic(:,2);

% take care of Px loop
if usePx
    % get Cartesian coordinates for Px loop and reshape to vector
    XcPx = reshape(cos(Bp.phi')*Bp.r',1,size(Bp.x,1)*size(Bp.x,2));
    YcPx = reshape(sin(Bp.phi')*Bp.r',1,size(Bp.x,1)*size(Bp.x,2));
    
    % reshape field to vector as needed for interpolation
    Bpx = reshape(Bp.x,1,size(Bp.x,1)*size(Bp.x,2));
    Bpy = reshape(Bp.y,1,size(Bp.x,1)*size(Bp.x,2));
    Bpz = reshape(Bp.z,1,size(Bp.x,1)*size(Bp.x,2));
    
    % interpolate to complete coordinates
    F     = TriScatteredInterp(XcPx(:),YcPx(:),real(Bpx(:)));
    Bpx_r = F(Xnew,Ynew);
    F     = TriScatteredInterp(XcPx(:),YcPx(:),real(Bpy(:)));
    Bpy_r = F(Xnew,Ynew);
    F     = TriScatteredInterp(XcPx(:),YcPx(:),real(Bpz(:)));
    Bpz_r = F(Xnew,Ynew);
    
    F     = TriScatteredInterp(XcPx(:),YcPx(:),imag(Bpx(:)));
    Bpx_i = F(Xnew,Ynew);
    F     = TriScatteredInterp(XcPx(:),YcPx(:),imag(Bpy(:)));
    Bpy_i = F(Xnew,Ynew);
    F     = TriScatteredInterp(XcPx(:),YcPx(:),imag(Bpz(:)));
    Bpz_i = F(Xnew,Ynew);
    
    Bprex = Bpx_r + 1i*Bpx_i;
    Bprey = Bpy_r + 1i*Bpy_i;
    Bprez = Bpz_r + 1i*Bpz_i;
    
    % replace NAN (at points outside) by minimum value
    Bprex(isnan(Bprex))= min(Bprex);
    Bprey(isnan(Bprey))= min(Bprey);
    Bprez(isnan(Bprez))= min(Bprez);
    
    Bpre.x = Bprex;
    Bpre.y = Bprey;
    Bpre.z = Bprez;
    
    % remaining Bp-field stuff
    % Br and Bz are different from x, y and z!
    Bpre.Br = Bp.Br;
    Bpre.Bz = Bp.Bz;
    Bpre.r = Bp.r;
    Bpre.phi = Bp.phi;
    Bpre.dh = dh;
end

% interpolate to complete coordinates
F     = TriScatteredInterp(Xc01(:),Yc01(:),real(B01x(:)));
B1x_r = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc01(:),Yc01(:),real(B01y(:)));
B1y_r = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc01(:),Yc01(:),real(B01z(:)));
B1z_r = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc02(:),Yc02(:),real(B02x(:)));
B2x_r = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc02(:),Yc02(:),real(B02y(:)));
B2y_r = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc02(:),Yc02(:),real(B02z(:)));
B2z_r = F(Xnew,Ynew);

F     = TriScatteredInterp(Xc01(:),Yc01(:),imag(B01x(:)));
B1x_i = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc01(:),Yc01(:),imag(B01y(:)));
B1y_i = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc01(:),Yc01(:),imag(B01z(:)));
B1z_i = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc02(:),Yc02(:),imag(B02x(:)));
B2x_i = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc02(:),Yc02(:),imag(B02y(:)));
B2y_i = F(Xnew,Ynew);
F     = TriScatteredInterp(Xc02(:),Yc02(:),imag(B02z(:)));
B2z_i = F(Xnew,Ynew);

B1.x = B1x_r + 1i*B1x_i;
B1.y = B1y_r + 1i*B1y_i;
B1.z = B1z_r + 1i*B1z_i;

B2.x = B2x_r + 1i*B2x_i;
B2.y = B2y_r + 1i*B2y_i;
B2.z = B2z_r + 1i*B2z_i;

% replace NAN (at points outside) by minimum value
B1.x(isnan(B1.x))= min(B1.x);
B1.y(isnan(B1.y))= min(B1.y);
B1.z(isnan(B1.z))= min(B1.z);
B2.x(isnan(B2.x))= min(B2.x);
B2.y(isnan(B2.y))= min(B2.y);
B2.z(isnan(B2.z))= min(B2.z);

% remaining B1-field stuff
% Br and Bz are different from x, y and z!
B1.Br = B01.Br;
B1.Bz = B01.Bz;
B1.r = B01.r;
B1.phi = B01.phi;
B1.dh = dh;
B1.ic = ic;
% remaining B2-field stuff
% Br and Bz are different from x, y and z!
B2.Br = B02.Br;
B2.Bz = B02.Bz;
B2.r = B02.r;
B2.phi = B02.phi;
B2.dh = dh;
B2.ic = ic;

%figure(5); pcolor(cos(B01.phi')*B01.r', sin(B01.phi')*B01.r', (real(B01.x))); axis equal, axis tight;shading flat;
%figure(6); tri=delaunay(Xnew,Ynew); trisurf(tri,Xnew,Ynew,real(B1.x));shading flat;view([0 90])
return