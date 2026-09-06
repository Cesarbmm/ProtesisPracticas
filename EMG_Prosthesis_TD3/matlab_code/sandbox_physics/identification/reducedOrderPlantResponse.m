function [q, v] = reducedOrderPlantResponse(q0, vInf, tau, tSeconds, limits, options)
%reducedOrderPlantResponse respuesta de los modelos reducidos A y B.
%
%   Modelo B:   dq/dt = v ,  dv/dt = (vInf - v)/tau ,  v(0) = 0
%   Modelo A:   el mismo con tau = 0  (velocidad instantanea)
%
%   A es exactamente B con tau = 0: los modelos son ANIDADOS y esa es toda la
%   razon por la que S4 puede atribuir cualquier diferencia unicamente a tau.
%
%   Con entrada constante durante el paso el sistema es LINEAL, asi que la
%   respuesta se calcula por su SOLUCION ANALITICA:
%
%       v(t) = vInf * (1 - exp(-t/tau))
%       q(t) = q0 + vInf * ( t - tau*(1 - exp(-t/tau)) )
%
%   La integracion RK4 esta disponible para el test de convergencia y como
%   camino para futuras no linealidades; no se usa Euler explicito.
%
%   `limits` = [minEncoder maxEncoder] del EMPIRICAL REACHABLE RANGE del motor
%   (sandboxPlantReachableRange). El clamp es duro: en esta version NO hay tope
%   elastico, porque k_limit y c_limit no estan identificados.
%
%   Unidades: q en cuentas de encoder, vInf en cuentas/s, tau y t en segundos.
%
%   ADVERTENCIA DE ALCANCE: vInf y tau son parametros FENOMENOLOGICOS. No son
%   J, B ni Kt. Cualquier trio con Kt/B = vInf/u y J/B = tau produce esta misma
%   trayectoria: los parametros fisicos no son identificables con estos datos.

arguments
    q0 (1, 1) double {mustBeFinite}
    vInf (1, 1) double {mustBeFinite}
    tau (1, 1) double {mustBeNonnegative}
    tSeconds (:, 1) double {mustBeNonnegative}
    limits (1, 2) double {mustBeFinite}
    options.method (1, 1) string {mustBeMember(options.method, ["analytic", "rk4"])} = "analytic"
    options.dt (1, 1) double {mustBePositive} = 1e-3
end

assert(limits(1) < limits(2), "Sandbox:BadLimits", "limits debe ser [min max].");

if options.method == "analytic"
    if tau <= 0
        q = q0 + vInf * tSeconds;
        v = repmat(vInf, size(tSeconds));
    else
        e = exp(-tSeconds / tau);
        q = q0 + vInf * (tSeconds - tau * (1 - e));
        v = vInf * (1 - e);
    end
else
    q = zeros(size(tSeconds));
    v = zeros(size(tSeconds));
    state = [q0; 0];
    previous = 0;
    for k = 1:numel(tSeconds)
        target = tSeconds(k);
        while previous < target - 1e-12
            h = min(options.dt, target - previous);
            state = rk4Step(state, vInf, tau, h);
            state(1) = min(max(state(1), limits(1)), limits(2));
            previous = previous + h;
        end
        q(k) = state(1);
        v(k) = state(2);
    end
end

% Limite empirico duro. La velocidad tiene signo constante, de modo que q es
% monotona y saturar el vector equivale a detener el movimiento en el tope.
q = min(max(q, limits(1)), limits(2));
end

function state = rk4Step(state, vInf, tau, h)
f = @(s) localDerivative(s, vInf, tau);
k1 = f(state);
k2 = f(state + h / 2 * k1);
k3 = f(state + h / 2 * k2);
k4 = f(state + h * k3);
state = state + h / 6 * (k1 + 2 * k2 + 2 * k3 + k4);
if tau <= 0
    state(2) = vInf;
end
end

function d = localDerivative(state, vInf, tau)
if tau <= 0
    d = [vInf; 0];
else
    d = [state(2); (vInf - state(2)) / tau];
end
end
