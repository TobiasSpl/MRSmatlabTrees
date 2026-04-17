function B = applyBfieldSign(B,Bsign)

if isfield(B,"Br")
    B.Br = Bsign.*B.Br;
end
if isfield(B,"Br")
    B.Bz = Bsign.*B.Bz;
end
B.x = Bsign.*B.x;
B.y = Bsign.*B.y;
B.z = Bsign.*B.z;

return