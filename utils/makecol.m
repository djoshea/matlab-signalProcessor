function vec = makecol(vec)
    if isvector(vec) && size(vec, 2) > size(vec, 1)
        vec = vec';
    end
end

