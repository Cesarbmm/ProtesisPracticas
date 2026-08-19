function gpuInfo = configureGpuForTraining(useGpu)
%configureGpuForTraining enables MATLAB GPU state for training when possible.

if nargin < 1 || isempty(useGpu)
    useGpu = true;
end

gpuInfo = struct( ...
    "useGpuRequested", logical(useGpu), ...
    "gpuAvailable", false, ...
    "gpuEnabled", false, ...
    "gpuName", "", ...
    "gpuComputeCapability", "", ...
    "forwardCompatibilityEnabled", false, ...
    "gpuFallbackReason", "");

if ~useGpu
    gpuInfo.gpuFallbackReason = "GPU not requested.";
    return;
end

if exist("gpuDevice", "file") ~= 2
    gpuInfo.gpuFallbackReason = "gpuDevice is not available.";
    warning(gpuInfo.gpuFallbackReason);
    return;
end

try
    setenv("CUDA_CACHE_MAXSIZE", "536870912");
    parallel.gpu.enableCUDAForwardCompatibility(true);
    gpuInfo.forwardCompatibilityEnabled = true;

    g = gpuDevice(1);
    gpuInfo.gpuAvailable = true;
    gpuInfo.gpuEnabled = true;
    gpuInfo.gpuName = string(g.Name);
    gpuInfo.gpuComputeCapability = string(g.ComputeCapability);
catch ME
    gpuInfo.gpuFallbackReason = string(ME.message);
    warning("GPU:EnableFailed", "GPU could not be enabled: %s", ME.message);
end
end
