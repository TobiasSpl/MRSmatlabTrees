function [dh,ic] = SepLoopTriangulation(B01,B02,loop,varargin)
% OLD:
% eightOritn = loop(1).eightoritn/360.0*2.0*pi;
%
% % get cartesian coordinates for first loop and reshape to vector
% Xc01 = reshape(cos(B01.phi')*B01.r',1,size(B01.x,1)*size(B01.x,2));
% Yc01 = reshape(sin(B01.phi')*B01.r',1,size(B01.x,1)*size(B01.x,2));
%
% % same for second but shiftes by loop distance
% Xc02 = reshape(cos(B02.phi')*B02.r' + loop.eightsep*cos(-eightOritn),1,size(B02.x,1)*size(B02.x,2));
% Yc02 = reshape(sin(B02.phi')*B02.r' + loop.eightsep*sin(-eightOritn),1,size(B02.x,1)*size(B02.x,2));
%
% % complete coordinates of both fields
% Xcomplete = [Xc01 Xc02];
% Ycomplete = [Yc01 Yc02];
%
% % triangulation of these point
% dt = DelaunayTri(Xcomplete',Ycomplete');
% % centers of triangles --> calculation of fields at these points
% ic = incenters(dt); %
% % get area of triangles
% dh  = polyarea(Xcomplete(dt.Triangulation)',Ycomplete(dt.Triangulation)')';

usePx = false;
if nargin > 3
    Bp = varargin{1};
    usePx = true;
end

% get cartesian coordinates for first loop and reshape to vector
Xc01 = cos(B01.phi')*B01.r';
Yc01 = sin(B01.phi')*B01.r';
Xc01 = Xc01(:);
Yc01 = Yc01(:);

% same for second but shift by loop distance
Xc02 = cos(B02.phi')*B02.r' + loop.eightsep*cosd(-loop(1).eightoritn);
Yc02 = sin(B02.phi')*B02.r' + loop.eightsep*sind(-loop(1).eightoritn);
Xc02 = Xc02(:);
Yc02 = Yc02(:);

if usePx
    XcPx = cos(Bp.phi')*Bp.r';
    YcPx = sin(Bp.phi')*Bp.r';
    XcPx = XcPx(:);
    YcPx = YcPx(:);
    
    % complete coordinates of both fields
    Xcomplete = [Xc01; Xc02; XcPx];
    Ycomplete = [Yc01; Yc02; YcPx];
else
    % complete coordinates of both fields
    Xcomplete = [Xc01; Xc02];
    Ycomplete = [Yc01; Yc02];
end

% triangulation of these points
dt = delaunayTriangulation(Xcomplete,Ycomplete);
plotStuff=false;
if plotStuff
    figure(4)
    triplot(dt,Xcomplete,Ycomplete);
end
% centers of triangles --> calculation of fields at these points
ic = incenter(dt); % Xnew = ic(:,1); Ynew = ic(:,2);
% get area of triangles
dh  = polyarea(Xcomplete(dt.ConnectivityList)',Ycomplete(dt.ConnectivityList)')';