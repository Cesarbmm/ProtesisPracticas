"""Auditoría independiente con Python estándar. No carga sujetos ni ejecuta RL."""
import csv
import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path


def verify():
    here = Path(__file__).resolve().parent
    root = here.parents[1]
    out = here / "e2d_results"
    read = lambda name: list(csv.DictReader((out / name).open(encoding="utf-8-sig", newline="")))
    sha = lambda file: hashlib.sha256(file.read_bytes()).hexdigest()
    manifest = json.loads((out / "artifact_manifest.json").read_text(encoding="utf-8"))
    for item in manifest["artifacts"]:
        assert sha(out / item["file"]) == item["sha256"], item["file"]
    history = read("historical_hashes_before.csv")
    for item in history:
        assert sha(root / item["path"]) == item["sha256"], item["path"]
    mean = lambda xs: sum(xs)/len(xs)
    close = lambda a, b: abs(a-b) <= 1e-11 or math.isnan(a) and math.isnan(b)
    def map_pwm(raw):
        if abs(raw) < .05:
            return 0
        level = min([64, 96, 128, 160, 192, 224, 255], key=lambda v: abs(v-255*abs(raw)))
        return level if raw > 0 else -level
    groups = defaultdict(list)
    rows = read("step_traces.csv")
    for row in rows:
        key = (float(row["epsilon"]), row["subject"], int(row["repetition"]), int(row["side"]), int(row["motor"]))
        groups[key].append(row)
    assert len(groups) == 4000 and len(rows) == 58760
    calculated = {}
    max_reward_error = 0
    for key, group in groups.items():
        epsilon = key[0]
        group.sort(key=lambda r: int(r["step"]))
        previous = 0
        errors, actions, deltas, rewards, hs, qs, pwms = [], [], [], [], [], [], []
        active = unmoved = 0
        for r in group:
            num = lambda name: float(r[name])
            historical = max(-1, min(1, 2*num("errorBefore")))
            raw = 0 if abs(num("errorBefore")) <= epsilon else historical
            assert close(historical, num("rawHistoricalSameState"))
            assert close(raw, num("rawDeadband"))
            assert map_pwm(raw) == int(r["pwm"])
            assert map_pwm(historical) == int(r["historicalPwmSameState"])
            error = num("hAfter")-num("referenceAfter")
            u = num("effective")
            assert close(u, num("pwm")/255)
            reward = -(error**2 + .01*u**2 + .05*(u-previous)**2)
            max_reward_error = max(max_reward_error, abs(reward-num("rewardMotor")))
            assert abs(reward-num("rewardMotor")) < 1e-12
            assert close(num("trackingTermMotor"), -error**2)
            assert close(num("actionPenaltyMotor"), .01*u**2)
            assert close(num("deltaPenaltyMotor"), .05*(u-previous)**2)
            assert int(r["zeroedDirect"]) == (num("historicalPwmSameState") != 0 and num("pwm") == 0)
            assert int(r["zeroedVersusBaseline"]) == (num("baselinePwm") != 0 and num("pwm") == 0)
            if qs:
                assert abs(qs[-1]-num("qBefore")) < 1e-8
            else:
                qs.append(num("qBefore"))
                hs.append(num("referenceBefore")-num("errorBefore"))
            qs.append(num("qAfter")); hs.append(num("hAfter")); pwms.append(num("pwm"))
            active += num("pwm") != 0
            unmoved += num("pwm") != 0 and abs(num("qAfter")-num("qBefore")) <= 1e-9
            if num("pwm") == 0:
                assert num("qAfter") == num("qBefore")
            errors.append(error); actions.append(u*u); deltas.append((u-previous)**2); rewards.append(reward)
            previous = u
        cycle = (all(abs(qs[-5+i]-qs[-1]) <= 1e-9 for i in [0, 2]) and
                 abs(qs[-4]-qs[-2]) <= 1e-9 and abs(hs[-5]-hs[-4]) > .05 and
                 all(a*b < 0 for a, b in zip(pwms[-4:-1], pwms[-3:])))
        calculated[key] = dict(trackingMSE=mean([e*e for e in errors]), MAE=mean([abs(e) for e in errors]),
                               rewardMean=mean(rewards), actionL2=mean(actions), deltaActionL2=mean(deltas),
                               flat_response=float(max(hs)-min(hs) <= 1e-9), activeCommands=active,
                               noMotionCommands=unmoved, persistentTwoCycle=int(cycle))
    for row in read("episode_motor_metrics.csv"):
        key = (float(row["epsilon"]), row["subject"], int(row["repetition"]), int(row["side"]), int(row["motor"]))
        for field, value in calculated[key].items():
            assert close(value, float(row[field])), (key, field)
    episode = defaultdict(list)
    for key, value in calculated.items():
        episode[key[:-1]].append(value)
    metrics = {}
    fields = ["trackingMSE", "MAE", "rewardMean", "actionL2", "deltaActionL2", "flat_response"]
    for key, motors in episode.items():
        rec = {name: mean([m[name] for m in motors]) for name in fields}
        rec["action_no_motion"] = sum(m["noMotionCommands"] for m in motors)/sum(m["activeCommands"] for m in motors)
        rec["cycles"] = sum(m["persistentTwoCycle"] for m in motors)
        metrics[key] = rec
    grid = [0, .03, .05, .08, .12]
    macros = {}
    for e in grid:
        # Muestra equilibrada: 10 episodios por sujeto/lado, 20 grupos.
        subset = [r for key, r in metrics.items() if key[0] == e]
        assert len(subset) == 200
        macros[e] = {field: mean([r[field] for r in subset]) for field in fields+['action_no_motion']}
        macros[e]["cycles"] = sum(r["cycles"] for r in subset)
    for row in read("epsilon_summary.csv"):
        for name in fields+['action_no_motion']:
            assert close(macros[float(row["epsilon"])][name], float(row[name])), name
    gates = read("candidate_gates.csv")
    degradation = read("subgroup_degradations.csv")
    for g in gates:
        e = float(g["epsilon"])
        subset = [r for r in rows if float(r["epsilon"]) == e]
        direct = sum(int(r["zeroedDirect"]) for r in subset)
        paired = sum(int(r["zeroedVersusBaseline"]) for r in subset)
        active_base = sum(int(r["baselinePwm"]) != 0 for r in subset)
        assert close(direct/len(subset), float(g["zeroedActionFraction"]))
        assert close(paired/active_base, float(g["pairedZeroedActiveFraction"]))
        assert int(g["cycles"]) == macros[e]["cycles"]
        mse_change = 100*(macros[e]["trackingMSE"]-macros[0]["trackingMSE"])/macros[0]["trackingMSE"]
        reward_change = 100*(macros[0]["rewardMean"]-macros[e]["rewardMean"])/abs(macros[0]["rewardMean"])
        assert abs(mse_change-float(g["mseChangePct"])) < 1e-9
        assert abs(reward_change-float(g["rewardChangePct"])) < 1e-9
        sub = [r for r in degradation if float(r["epsilon"]) == e]
        for kind, field in [("subject", "subjectDegradations"), ("motor", "motorDegradations"), ("direction", "directionDegradations")]:
            count = sum(float(r["mseChangePct"]) > 5+1e-12 or float(r["rewardChangePct"]) > 5+1e-12 for r in sub if r["kind"] == kind)
            assert count == int(g[field])
        reversals = sum(int(r["motor"]) == 3 and int(r["pwm"]) > 0 and float(r["qAfter"]) < float(r["qBefore"]) for r in subset)
        assert reversals == int(g["m3Reversals"]) == 0
        expected = [int(g["cycles"]) == 0, mse_change <= 5+1e-12, reward_change <= 5+1e-12,
                    int(g["subjectDegradations"]) <= 2 and int(g["motorDegradations"]) <= 1 and int(g["directionDegradations"]) == 0,
                    reversals == 0, bool(int(g["motionMetricsDefined"])) and float(g["maxFlatIncrease"]) <= .02+1e-12 and
                    float(g["maxNoMotionIncrease"]) <= .05+1e-12 and paired/active_base <= .2+1e-12]
        assert expected == [bool(int(g["pass"+letter])) for letter in "ABCDEF"]
        assert all(expected) == bool(int(g["passed"]))
    summary = json.loads((out / "e2d_summary.json").read_text(encoding="utf-8"))
    assert not any(int(g["passed"]) for g in gates)
    assert summary["SELECTED_EPSILON"] is None and summary["E2D_RESULT"] == "DEADBAND_NOT_SUFFICIENT"
    tests = read("test_results.csv")
    assert len(tests) == 107 and all(r["Passed"] == '1' and r["Failed"] == '0' and r["Incomplete"] == '0' for r in tests)
    result = dict(verified=True, historicalHashes=len(history), artifactHashes=len(manifest["artifacts"]),
                  motorSteps=len(rows), episodeMotorMetrics=len(calculated), tests=len(tests),
                  maxRewardReconstructionError=max_reward_error, cyclesByEpsilon=[macros[e]["cycles"] for e in grid],
                  selectedEpsilon=None, E2D_RESULT=summary["E2D_RESULT"])
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return result


if __name__ == "__main__":
    verify()
