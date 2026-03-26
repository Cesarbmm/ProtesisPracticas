function clearConfigurablesOverride()
%clearConfigurablesOverride removes override state used by configurables().

if isappdata(0, 'configurables_override')
    rmappdata(0, 'configurables_override');
end
if isappdata(0, 'configurables_override_key')
    rmappdata(0, 'configurables_override_key');
end
clear configurables
end
