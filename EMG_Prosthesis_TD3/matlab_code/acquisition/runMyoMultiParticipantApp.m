function app=runMyoMultiParticipantApp(varargin)
% Sólo abre la app; no conecta ni reserva identidad hasta una acción del operador.
app=MyoContinuousAcquisitionApp('Campaign',myoCampaignConfig(),varargin{:});
end
