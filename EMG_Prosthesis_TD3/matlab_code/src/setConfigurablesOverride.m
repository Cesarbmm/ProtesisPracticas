function setConfigurablesOverride(override)
%setConfigurablesOverride stores an override and its cached signature.

if nargin < 1 || isempty(override)
    override = struct();
end

setappdata(0, 'configurables_override', override);
setappdata(0, 'configurables_override_key', makeConfigurablesOverrideKey(override));
clear configurables
end
