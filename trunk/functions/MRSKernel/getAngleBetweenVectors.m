function [theta,sgn] = getAngleBetweenVectors(x,y,n)
%getAngleBetweenVectors calculates the angle theta between two vectors 'x' and 'y'
%
% Syntax:
%       getAngleBetweenVectors(x,y)
%
% Inputs:
%       x - vector
%       y - vector
%       n - normal vector of plane used to determine sgn
%
% Outputs:
%       theta - angle between x and y [rad]
%       sgn - sign of theta
%
% Example:
%       getAngleBetweenVectors([1 0 0],[0 0 1])
%
% Other m-files required:
%       none;
%
% Subfunctions:
%       none
%
% MAT-files required:
%       none
%
% See also BLOCHUS
% Author: Thomas Hiller
% email: thomas.hiller[at]leibniz-liag.de
% License: GNU GPLv3 (at end)

%------------- BEGIN CODE --------------

if nargin < 3
    n = [0,0,1];
end



if numel(x)<=3 % vector treatment
    % if x is a vector make x and y column vectors
    x = x(:);
    y = y(:);
    % angle [rad]
    theta = acos(dot(x,y)./(norm(x).*norm(y)));    
    % sign
    sgn = sign(dot(cross(x,y),n));
    sgn(sgn==0) = 1;
else % matrix treatment
    % angle [rad]
    ndim = ndims(x);
    x = permute(x,[ndim,1:ndim-1]);
    y = permute(y,[ndim,1:ndim-1]);
    colons = repmat({':'}, 1, ndim-1);
    normx = sqrt(x(1,colons{:}).^2+x(2,colons{:}).^2+x(3,colons{:}).^2);
    normy = sqrt(y(1,colons{:}).^2+y(2,colons{:}).^2+y(3,colons{:}).^2);
    theta = acos(dot(x,y,1)./(normx.*normy));   
    theta = permute(theta,[2:ndim,1]);
    % sign
    %sgn = ones(size(theta));
    sgn = sign(dot(cross(x,y),repmat(n',1,size(x,2),size(x,3),size(x,4),1)));
    sgn = permute(sgn,[2:ndim,1]);
end

if ~isreal(theta)
    theta = real(theta);
end

return

%------------- END OF CODE --------------

%% License:
% GNU GPLv3
%
% BLOCHUS
% Copyright (C) 2019 Thomas Hiller
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
