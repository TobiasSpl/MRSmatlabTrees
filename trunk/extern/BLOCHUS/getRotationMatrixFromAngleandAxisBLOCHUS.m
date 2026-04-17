function R = getRotationMatrixFromAngleandAxisBLOCHUS(phi,n)
%getRotationMatrixFromAngleandAxis calculates rotation matrix R to rotate about
%an axis n by an angle phi
%
% Syntax:
%       getRotationMatrixFromAngleandAxis(phi,n)
%
% Inputs:
%       phi - rotation angle [rad]
%       n - rotation axis vector [x y z]
%
% Outputs:
%       R - 3x3 rotation matrix
%
% Example:
%       R = getRotationMatrixFromAngleandAxis(pi,[0 0 1]')
%       yields R = -1  0  0
%                   0 -1  0
%                   0  0  1
%       so that R*[1 0 0]' = [-1 0 0]'
%
% Other m-files required:
%       none
%
% Subfunctions:
%       none
%
% MAT-files required:
%       none
%
% See also: BLOCHUS
% Author: Thomas Hiller
% email: thomas.hiller[at]leibniz-liag.de
% License: GNU GPLv3 (at end)

%------------- BEGIN CODE --------------

% make "n" a unit vector
n = n./norm(n);
% get the individual components
nx = n(1);
ny = n(2);
nz = n(3);
% matrix terms needed
omcos = 1-cos(phi);
cosp = cos(phi);
sinp = sin(phi);

% assemble rotation matrix R
R = [nx*nx*omcos +    cosp  nx*ny*omcos - nz*sinp  nx*nz*omcos + ny*sinp; ...
     ny*nx*omcos + nz*sinp  ny*ny*omcos +    cosp  ny*nz*omcos - nx*sinp; ...
     nz*nx*omcos - ny*sinp  nz*ny*omcos + nx*sinp  nz*nz*omcos +    cosp];

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
