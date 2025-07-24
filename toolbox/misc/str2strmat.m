function smat= str2strmat(s)
arguments
    s (1,1) string
end
if ~contains(s,";")
    smat = split(strmat2str(s),",").';
else
    smat = split(split(strmat2str(s),";"),",");
end
end