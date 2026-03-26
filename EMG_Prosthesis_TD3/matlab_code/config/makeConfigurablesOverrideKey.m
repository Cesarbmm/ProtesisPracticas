function key = makeConfigurablesOverrideKey(override)
%makeConfigurablesOverrideKey builds a compact stable signature for overrides.
% This avoids repeated heavy conversions such as mat2str on large numeric
% arrays or nested structs during long training runs.

if nargin < 1 || ~isstruct(override) || isempty(fieldnames(override))
    key = "__no_override__";
    return;
end

fields = sort(fieldnames(override));
parts = strings(numel(fields), 1);
for i = 1:numel(fields)
    fieldName = string(fields{i});
    parts(i) = fieldName + "=" + localValueSignature(override.(fields{i}));
end
key = strjoin(parts, "|");
end

function signature = localValueSignature(value)
if isstring(value)
    if isscalar(value)
        signature = value;
    else
        signature = "string[" + join(value(:).', ",") + "]";
    end
elseif ischar(value)
    signature = string(value);
elseif isnumeric(value)
    signature = localNumericSignature(value);
elseif islogical(value)
    signature = localLogicalSignature(value);
elseif isstruct(value)
    signature = localStructSignature(value);
elseif iscell(value)
    signature = "cell" + mat2str(size(value));
elseif isa(value, "function_handle")
    signature = "fh:" + string(func2str(value));
else
    signature = "obj:" + string(class(value));
end
end

function signature = localNumericSignature(value)
if isempty(value)
    signature = string(class(value)) + "[empty]";
    return;
end

if isscalar(value)
    signature = string(class(value)) + ":" + string(value);
    return;
end

if numel(value) <= 8
    values = string(reshape(value, 1, []));
    signature = string(class(value)) + mat2str(size(value)) + "[" + join(values, ",") + "]";
    return;
end

signature = sprintf("%s%s[min=%.6g,max=%.6g,mean=%.6g]", ...
    class(value), mat2str(size(value)), min(value(:)), max(value(:)), mean(value(:)));
signature = string(signature);
end

function signature = localLogicalSignature(value)
if isempty(value)
    signature = "logical[empty]";
    return;
end

if numel(value) <= 16
    values = string(double(reshape(value, 1, [])));
    signature = "logical" + mat2str(size(value)) + "[" + join(values, ",") + "]";
else
    signature = "logical" + mat2str(size(value)) + "[nnz=" + nnz(value) + "]";
end
end

function signature = localStructSignature(value)
fields = sort(fieldnames(value));
if isempty(fields)
    signature = "struct{}";
    return;
end

parts = strings(numel(fields), 1);
for i = 1:numel(fields)
    parts(i) = string(fields{i}) + ":" + localValueSignature(value.(fields{i}));
end
signature = "struct{" + strjoin(parts, ",") + "}";
end
