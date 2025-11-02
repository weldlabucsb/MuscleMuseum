function S = obj2struct(x, opt, depth, seenHandles, propertyFilter)
    % recursively converts object to a struct
    %
    % x: the matlab object to convert
    % opt (options): 
    %       "IncludeDependent", "IncludeHidden", "IncludeTransient"
    %       "MaxDepth"
    % dept: the depth of the current layer
    % seenHandles: an array of object handels to prevent infinite loops
    % propertyFilter: a cell array of properties to export
    %   Ex. {depth0_prop1, {depth0_prop2, {depth1_prop1, depth1_prop2}}}
    %   If the propertyFilter is empty {}, All object properties
    %   are returned
        
    if depth > opt.MaxDepth || isempty(x)
        S = struct(); 
        return;
    end

    % prevent infinite loops
    if isa(x, 'handle')
        if any(cellfun(@(h) h==x, seenHandles))
            S = struct('circular', true, 'class', class(x));
            return;
        end
        seenHandles{end+1} = x;
    end
    
    %built-in data types to struct
    if isstruct(x)
        S = struct();
        f = fieldnames(x);
        for k = 1:numel(x)
            for i = 1:numel(f)
                try
                    subFilter = {};
                    if ~isempty(propertyFilter)
                        [isPresent, subFilter] = filterContainsProperty(propertyFilter, f{i});
                        if ~isPresent
                            continue
                        end
                    end
                    S(k).(f{i}) = dispatch_obj2struct(x(k).(f{i}), opt, depth, seenHandles, subFilter);
                catch ME
                    S(k).(f{i}) = struct('inconvertible', true, 'message', ME.message);
                end
            end
        end
        return
    elseif iscell(x)
        S = cellfun(@(c) dispatch_obj2struct(c, opt, depth, seenHandles, propertyFilter), x, 'UniformOutput', false);
        return
    elseif istable(x) || istimetable(x)
        S = table2struct(x, 'ToScalar', true);
        return
    elseif isa(x, 'containers.Map')
        S = struct();
        keys = x.keys;
        for i = 1:numel(keys)
            key = matlab.lang.makeValidName(string(keys{i}));
            try
                subFilter = {};
                if ~isempty(propertyFilter)
                    [isPresent, subFilter] = filterContainsProperty(propertyFilter, key);
                    if ~isPresent
                        continue
                    end
                end
                S.(key) = dispatch_obj2struct(x(keys{i}), opt, depth, seenHandles, subFilter);
            catch ME
                S.(key) = struct('inconvertible', true, 'message', ME.message);
            end
        end
        return
    elseif isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || ...
              isdatetime(x) || isduration(x) || iscalendarduration(x) || ...
              iscategorical(x)
        S = x;
        return
    end
    
    %unknown datatype
    meta = metaclass(x);
    props = meta.PropertyList;
    
    keep = true(size(props));
    if ~opt.IncludeHidden,    keep = keep & ~[props.Hidden].';    end
    if ~opt.IncludeTransient, keep = keep & ~[props.Transient].'; end
    if ~opt.IncludeDependent, keep = keep & ~[props.Dependent].'; end
    props = props(keep);

    % readable props only
    props = props((string({props.GetAccess}) == "public").' | ...
        (string({props.GetAccess}) == "protected").');

    S = struct();
    S.class = class(x);
    for i = 1:numel(props)
        pn = props(i).Name;
        try
            subFilter = {};
            if ~isempty(propertyFilter)
                [isPresent, subFilter] = filterContainsProperty(propertyFilter, pn);
                if ~isPresent
                    continue
                end
            end
            val = x.(pn);
            S.(pn) = dispatch_obj2struct(val, opt, depth, seenHandles, subFilter);
        catch ME
            S.(pn) = struct('inconvertible', true, 'message', ME.message);
        end
    end
end

function S = dispatch_obj2struct(val, opt, depth, seenHandles, propertyFilter)
    if isobject(val)
        if numel(val) > 1
            S = arrayfun(@(o) obj2struct(o, opt, depth+1, seenHandles, propertyFilter), val, 'UniformOutput', false);
            S = [S{:}];
        else
            S = obj2struct(val, opt, depth+1, seenHandles, propertyFilter);
        end
    elseif isstruct(val)
        S = obj2struct(val, opt, depth+1, seenHandles, propertyFilter); % reuse path
    elseif iscell(val)
        S = cellfun(@(c) dispatch_obj2struct(c, opt, depth+1, seenHandles, propertyFilter), val, 'UniformOutput', false);
    elseif istable(val) || istimetable(val)
        S = table2struct(val, 'ToScalar', true);
    elseif isa(val,'containers.Map')
        S = obj2struct(val, opt, depth+1, seenHandles, propertyFilter);
    else
        S = val;
    end
end

function [isPresent, subFilter] = filterContainsProperty(propertyFilter, propertyName)
    subFilter = {};
    idx = find(cellfun(@(c) ...
        (iscell(c) && numel(c)>=1 && string(c{1})==propertyName) || ...
        (~iscell(c) && string(c)==propertyName), ...
        propertyFilter), 1);
    
    if isempty(idx)
        isPresent = false;
        return
    end

    isPresent = true;
    
    it = propertyFilter{idx};
    if iscell(it) && numel(it) == 2
        subFilter = it{2};
    elseif iscell(it) && numel(it) > 2
        ME = MException(['Unexpected nested property filter. ' ...
        'Received a cell with %d elements, expected 2. ' ...
        'Ex: {Property,{Sub_Property1,Sub_Property2, etc...}}'], ...
        numel(it));
        throw(ME)
    end
    return
end

