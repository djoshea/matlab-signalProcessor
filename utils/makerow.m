function vec = makerow(vec)
    if isvector(vec) && size(vec, 1) > size(vec, 2)
        vec = vec';
    end
end

