classdef MockMyoPrecheckSource < MockMyoDataSource
 % Alteraciones sintéticas para probar la revisión de avisos; sin hardware.
 properties
  Mode="flat"
 end
 methods
  function p=read(obj)
   p=read@MockMyoDataSource(obj);
   switch obj.Mode
    case "flat",p.emg_raw(:,1)=0;
    case "clipped",p.emg_raw(:,2)=127/128;
    case "nonfinite",p.emg_raw(:,3)=NaN;
   end
  end
 end
end
