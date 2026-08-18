function checksum = computeIntentCalibrationChecksum(calibration)
%computeIntentCalibrationChecksum hashes a schema-ordered calibration payload.
%
% The checksum excludes its own contentSha256 field. It detects accidental
% mutation; compatibility is still decided by validateIntentCalibration.

arguments
    calibration (1, 1) struct
end

if isfield(calibration, "contentSha256")
    calibration = rmfield(calibration, "contentSha256");
end
calibration = canonicalizeValue(calibration);
try
    payload = unicode2native(jsonencode(calibration), "UTF-8");
catch cause
    error("computeIntentCalibrationChecksum:EncodingFailed", ...
        "Calibration cannot be encoded canonically: %s", cause.message);
end

digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(uint8(payload));
digestBytes = typecast(digest.digest(), "uint8");
checksum = lower(string(reshape(dec2hex(digestBytes, 2)', 1, [])));
end

function value = canonicalizeValue(value)
if isstruct(value)
    sortedFields = sort(fieldnames(value));
    value = orderfields(value, sortedFields);
    for elementIdx = 1:numel(value)
        for fieldIdx = 1:numel(sortedFields)
            fieldName = sortedFields{fieldIdx};
            value(elementIdx).(fieldName) = ...
                canonicalizeValue(value(elementIdx).(fieldName));
        end
    end
elseif iscell(value)
    for elementIdx = 1:numel(value)
        value{elementIdx} = canonicalizeValue(value{elementIdx});
    end
end
end
