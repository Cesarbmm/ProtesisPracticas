function app=runMyoMultiParticipantApp(varargin)
% Sólo abre la app; no conecta ni reserva identidad hasta una acción del operador.
app=MyoContinuousAcquisitionApp('Campaign',myoOfficialCampaignConfig(),varargin{:});
end
