function s = strmat2str(smat)
arguments
    smat string 
end
s = join(join(smat,",",2),";");
end

