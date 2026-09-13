"""Auditoría E2E independiente, con Python estándar y únicamente CSV locales.

No ejecuta MATLAB, no importa el helper experimental ni lee datos de sujetos.
Reconstruye el autómata, reward, métricas, agregación y detectores preregistrados.
Un resultado científico negativo es compatible con una auditoría satisfactoria.
Las comparaciones de identidad CSV usan números ya serializados: la igualdad
bit a bit con el MAT original corresponde además a las pruebas MATLAB.
"""
import csv
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / "e2e_results"
SUM_FIELDS = {"correlationValid", "activeCommands", "noMotionCommands", "signFlips",
              "signFlipEligible", "directionFailures", "zeroMotionFailures", "persistentTwoCycle"}


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def number(row, field):
    return float(row[field])


def close(actual, expected, label, tolerance=1e-11):
    if math.isnan(actual) and math.isnan(expected):
        return
    if actual == expected:
        return
    assert math.isfinite(actual) and math.isfinite(expected) and abs(actual-expected) <= tolerance, (
        label, actual, expected, tolerance)


def average(values):
    values = [v for v in values if not math.isnan(v)]
    return sum(values)/len(values) if values else math.nan


def ratio(numerator, denominator):
    return numerator/denominator if denominator else math.nan


def sign(value):
    return (value > 0)-(value < 0)


def scaled_encoder(q, motor):
    # Constantes históricas de definitions.m; se verifica su hash de recepción.
    gap = [7500, 3650, 4000, 3550][motor-1]
    limit = [26500, 11500, 8500, 9000][motor-1]
    low = [1800, 900, 300, 900][motor-1]
    high = [4092, 2046, 1023, 2046][motor-1]
    q = abs(q)
    if q < gap:
        return low/high
    if q > limit:
        return 1.0
    slope = (high-low)/(limit-gap)
    return (slope*q+(high-slope*limit))/high


def quantize(raw):
    if abs(raw) < .05:
        return 0
    level = min([64, 96, 128, 160, 192, 224, 255], key=lambda v: abs(v-255*abs(raw)))
    return sign(raw)*level


def transition(desired, previous, pending, enabled):
    """Autómata derivado del preregistro, sin información de referencia."""
    request = desired != 0 and previous != 0 and sign(desired) != sign(previous)
    confirmed = cancelled = neutralized = False
    applied = desired
    next_pending = 0
    if enabled:
        if pending:
            assert previous == 0, "Pending debe seguir a un paso aplicado cero."
            confirmed = sign(desired) == pending
            cancelled = not confirmed
        elif request:
            neutralized = True
            applied = 0
            next_pending = sign(desired)
    return dict(request=int(request), confirmed=int(confirmed), cancelled=int(cancelled),
                neutralized=int(neutralized), pwm=applied, pendingAfter=next_pending)


def trace_key(row):
    return (int(row["enabled"]), row["subject"], int(row["repetition"]),
            int(row["side"]), int(row["motor"]))


def group_traces(rows):
    groups = defaultdict(list)
    for row in rows:
        assert row["subject"] not in {"MATEO", "SANDRA"}, "Sujeto sellado en artefactos."
        groups[trace_key(row)].append(row)
    for group in groups.values():
        group.sort(key=lambda r: int(r["step"]))
        assert [int(r["step"]) for r in group] == list(range(1, len(group)+1))
    return groups


def cycle_windows(q, h, pwm):
    windows = {}
    for end in range(4, len(pwm)+1):
        positions = q[end-4:end+1]
        commands = pwm[end-4:end]
        cycle = (all(abs(positions[i]-positions[4]) <= 1e-9 for i in [0, 2])
                 and abs(positions[1]-positions[3]) <= 1e-9
                 and abs(h[end-4]-h[end-3]) > .05
                 and all(commands[i]*commands[i+1] < 0 for i in range(3)))
        if cycle:
            windows[end] = tuple(sorted(positions[:2]))
    return windows


def validate_trace(key, group):
    enabled, _, _, _, motor = key
    previous = pending = neutral_run = zero_run = 0
    q = [number(group[0], "qBefore")]
    h = [scaled_encoder(q[0], motor)]
    rewards, errors, actions, deltas, references, pwm = [], [], [], [], [], []
    events = Counter()
    max_reward_error = 0.0
    no_motion = overshoots = direction_failures = zero_motion = 0
    for row in group:
        n = lambda field: number(row, field)
        assert n("previousAppliedPwm") == previous
        assert n("pendingBefore") == pending
        close(n("qBefore"), q[-1], (key, row["step"], "continuidad q"), 1e-9)
        error = n("referenceBefore")-scaled_encoder(n("qBefore"), motor)
        close(error, n("errorBefore"), (key, "errorBefore"))
        raw = max(-1.0, min(1.0, 2*error))
        close(raw, n("rawAction"), (key, "rawAction"))
        desired = quantize(raw)
        assert desired == n("desiredPwm"), (key, "desiredPwm")
        close(desired/255, n("desiredEffective"), (key, "desiredEffective"))
        output = transition(desired, previous, pending, enabled)
        for field, value in output.items():
            assert value == n(field), (key, row["step"], field, value, n(field))
        applied = output["pwm"]
        u = applied/255
        close(u, n("effective"), (key, "effective"))
        after = scaled_encoder(n("qAfter"), motor)
        close(after, n("hAfter"), (key, "hAfter"))
        tracking_error = after-n("referenceAfter")
        delta = u-previous/255
        tracking = -tracking_error**2
        action_penalty = .01*u*u
        delta_penalty = .05*delta*delta
        reward = tracking-action_penalty-delta_penalty
        for field, value in [("trackingTermMotor", tracking), ("actionPenaltyMotor", action_penalty),
                             ("deltaPenaltyMotor", delta_penalty), ("rewardMotor", reward)]:
            close(value, n(field), (key, field), 1e-12)
        max_reward_error = max(max_reward_error, abs(reward-n("rewardMotor")))
        neutral_run = neutral_run+1 if output["neutralized"] else 0
        zero_run = zero_run+1 if applied == 0 else 0
        assert neutral_run == n("neutralRunLength") and zero_run == n("zeroRunLength")
        for field in ["request", "neutralized", "confirmed", "cancelled"]:
            events[field] += output[field]
        dq = n("qAfter")-n("qBefore")
        no_motion += applied != 0 and abs(dq) <= 1e-9
        direction_failures += dq*sign(applied) < -1e-9
        zero_motion += applied == 0 and abs(dq) > 1e-9
        before_error = h[-1]-n("referenceAfter")
        overshoots += (before_error*tracking_error < 0 and abs(before_error) > 1e-9
                       and abs(tracking_error) > 1e-9)
        q.append(n("qAfter")); h.append(after); pwm.append(applied)
        errors.append(tracking_error); references.append(n("referenceAfter"))
        actions.append(u*u); deltas.append(delta*delta); rewards.append(reward)
        previous = applied
        pending = output["pendingAfter"]
    active = sum(value != 0 for value in pwm)
    eligible = sum(a != 0 and b != 0 for a, b in zip(pwm, pwm[1:]))
    flips = sum(a*b < 0 for a, b in zip(pwm, pwm[1:]))
    x, y = h[1:], references
    correlation = math.nan
    if max(x)-min(x) > 1e-12 and max(y)-min(y) > 1e-12:
        dx, dy = [v-average(x) for v in x], [v-average(y) for v in y]
        correlation = sum(a*b for a, b in zip(dx, dy))/math.sqrt(sum(v*v for v in dx)*sum(v*v for v in dy))
    windows = cycle_windows(q, h, pwm)
    metrics = dict(trackingMSE=average([e*e for e in errors]), MAE=average([abs(e) for e in errors]),
                   correlation=correlation, correlationValid=int(math.isfinite(correlation)),
                   responseRange=max(h)-min(h), encoderRange=max(q)-min(q), referenceRange=max(y)-min(y),
                   flat_response=int(max(h)-min(h) <= 1e-9), action_no_motion=ratio(no_motion, active),
                   activeCommands=active, noMotionCommands=no_motion, actionL2=average(actions),
                   deltaActionL2=average(deltas), saturationFraction=average([abs(v/255) >= .95 for v in pwm]),
                   pwmHighFraction=average([abs(v) >= 128 for v in pwm]), rewardMean=average(rewards),
                   rewardTotal=sum(rewards), trackingTerm=-average([e*e for e in errors]),
                   actionPenalty=.01*average(actions), deltaActionPenalty=.05*average(deltas),
                   signFlipFraction=ratio(flips, eligible), signFlips=flips, signFlipEligible=eligible,
                   overshootFraction=overshoots/len(group), directionFailures=direction_failures,
                   zeroMotionFailures=zero_motion, persistentTwoCycle=int(len(group) in windows))
    assert events["neutralized"] == events["confirmed"]+events["cancelled"]+int(pending != 0)
    return metrics, windows, max_reward_error


def expected_events(rows, groups):
    def total(subset, keys):
        commands = len(subset)
        active = sum(number(r, "baselinePwm") != 0 for r in subset)
        neutral = sum(number(r, "neutralized") for r in subset)
        paired = sum(number(r, "baselinePwm") != 0 and number(r, "pwm") == 0 for r in subset)
        return dict(commands=commands, baselineActive=active,
                    requests=sum(number(r, "request") for r in subset), neutralized=neutral,
                    confirmed=sum(number(r, "confirmed") for r in subset),
                    cancelled=sum(number(r, "cancelled") for r in subset),
                    pendingEnd=sum(number(groups[k][-1], "pendingAfter") != 0 for k in keys),
                    neutralStepFraction=neutral/commands, neutralStepFractionOfActiveBaseline=ratio(neutral, active),
                    neutralizedBaselineActive=sum(number(r, "neutralized") != 0 and number(r, "baselinePwm") != 0 for r in subset),
                    pairedZeroed=paired, pairedZeroedActiveFraction=ratio(paired, active),
                    maxConsecutiveNeutralSteps=max(number(r, "neutralRunLength") for r in subset),
                    maxConsecutiveZeroCommands=max(number(r, "zeroRunLength") for r in subset),
                    zeroCommands=sum(number(r, "pwm") == 0 for r in subset))
    result = {}
    for enabled in [0, 1]:
        for kind in ["total", "motor", "direction", "motor_direction"]:
            for motor in range(1, 5) if "motor" in kind else [0]:
                for side in [1, 2] if "direction" in kind else [0]:
                    keys = [k for k in groups if k[0] == enabled and (not motor or k[4] == motor)
                            and (not side or k[3] == side)]
                    subset = [r for k in keys for r in groups[k]]
                    result[(enabled, kind, motor, side)] = total(subset, keys)
    return result


def compare_records(rows, key_function, calculated, tolerance=1e-11):
    assert len(rows) == len(calculated), ("número de registros", len(rows), len(calculated))
    seen = set()
    for row in rows:
        key = key_function(row)
        assert key not in seen, ("registro duplicado", key)
        seen.add(key)
        for field, value in calculated[key].items():
            close(value, number(row, field), (key, field), tolerance)


def means(records):
    return {field: average([r[field] for r in records]) for field in records[0]}


def aggregate(calculated):
    by_episode = defaultdict(list)
    for key, value in calculated.items():
        by_episode[key[:-1]].append(value)
    episodes = {}
    for key, motors in by_episode.items():
        assert len(motors) == 4
        rec = {field: (sum(m[field] for m in motors) if field in SUM_FIELDS else average([m[field] for m in motors]))
               for field in motors[0]}
        rec["action_no_motion"] = ratio(rec["noMotionCommands"], rec["activeCommands"])
        rec["signFlipFraction"] = ratio(rec["signFlips"], rec["signFlipEligible"])
        episodes[key] = rec
    subjects = sorted({key[1] for key in episodes})
    assert len(subjects) == 10
    subject_side = {}
    for enabled in [0, 1]:
        for subject in subjects:
            for side in [1, 2]:
                records = [v for k, v in episodes.items() if k[0] == enabled and k[1] == subject and k[3] == side]
                assert len(records) == 10
                subject_side[(enabled, subject, side)] = means(records)
    macros, by_subject, by_direction, by_motor = {}, {}, {}, {}
    for enabled in [0, 1]:
        macros[(enabled,)] = means([v for k, v in subject_side.items() if k[0] == enabled])
        for subject in subjects:
            by_subject[(enabled, subject)] = means([v for k, v in subject_side.items() if k[:2] == (enabled, subject)])
        for side in [1, 2]:
            by_direction[(enabled, side)] = means([v for k, v in subject_side.items() if k[0] == enabled and k[2] == side])
        for motor in range(1, 5):
            groups = [means([v for k, v in calculated.items() if k[0] == enabled and k[1] == subject
                             and k[3] == side and k[4] == motor]) for subject in subjects for side in [1, 2]]
            by_motor[(enabled, motor)] = means(groups)
    return episodes, macros, by_subject, by_direction, by_motor, subject_side


def deterioration(current, baseline, reward=False):
    delta = baseline-current if reward else current-baseline
    if abs(baseline) <= 1e-12:
        return 0 if delta <= 1e-12 else math.inf
    return 100*delta/abs(baseline)


def fixed_orbit(group):
    commands = [number(r, "pwm") for r in group]
    active_tail = [v for v in commands[-20:] if v != 0]
    persistent = len(active_tail) >= 5 and all(a*b < 0 for a, b in zip(active_tail, active_tail[1:]))
    if len(group) < 32:
        return 0, persistent
    tail = group[-32:]
    q = [number(r, "qBefore") for r in tail]
    motor = int(group[0]["motor"])
    h = [scaled_encoder(v, motor) for v in q]
    dq = [number(r, "qAfter")-number(r, "qBefore") for r in tail]
    if max(h)-min(h) <= .05 or not any(v > 1e-9 for v in dq) or not any(v < -1e-9 for v in dq):
        return 0, persistent
    previous = [number(r, "previousAppliedPwm") for r in tail]
    pending = [number(r, "pendingBefore") for r in tail]
    for period in range(1, 9):
        if (all(abs(a-b) <= 1e-9 for a, b in zip(q, q[period:]))
                and previous[:-period] == previous[period:] and pending[:-period] == pending[period:]):
            return period, persistent
    return 0, persistent


def verify():
    read = lambda name: read_csv(OUT/name)
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    history = read("historical_hashes_before.csv")
    assert len(history) == 589, "El inventario de recepción E2E debe proteger 589 archivos."
    for item in history:
        assert "sandbox" not in item["path"].lower()
        assert sha(ROOT/item["path"]) == item["sha256"], ("histórico modificado", item["path"])
    prereg = ROOT.parent/"docs/paired_reference/PREREGISTRO_E2E.md"
    prereg_hash = (OUT/"preregistration.sha256").read_text(encoding="utf-8-sig").strip()
    assert sha(prereg) == prereg_hash, "Preregistro modificado."
    artifact_count = None
    if (OUT/"artifact_manifest.json").exists():
        manifest = json.loads((OUT/"artifact_manifest.json").read_text(encoding="utf-8-sig"))
        for item in manifest["artifacts"]:
            assert sha(OUT/item["file"]) == item["sha256"], ("hash de artefacto", item["file"])
        artifact_count = len(manifest["artifacts"])
    rows = read("step_traces.csv")
    groups = group_traces(rows)
    assert len(rows) == 23504 and len(groups) == 1600
    calculated, windows = {}, {}
    max_reward_error = 0.0
    for key, group in groups.items():
        calculated[key], windows[key], error = validate_trace(key, group)
        max_reward_error = max(max_reward_error, error)
    compare_records(read("episode_motor_metrics.csv"), trace_key, calculated, 1e-8)
    episodes, macros, subjects, directions, motors, subject_side = aggregate(calculated)
    compare_records(read("episode_metrics.csv"), lambda r: trace_key({**r, "motor": "0"})[:-1], episodes, 1e-8)
    for filename, keyfn, table in [
            ("mode_summary.csv", lambda r: (int(r["enabled"]),), macros),
            ("subject_summary.csv", lambda r: (int(r["enabled"]), r["subject"]), subjects),
            ("direction_summary.csv", lambda r: (int(r["enabled"]), int(r["side"])), directions),
            ("motor_summary.csv", lambda r: (int(r["enabled"]), int(r["motor"])), motors),
            ("subject_side_summary.csv", lambda r: (int(r["enabled"]), r["subject"], int(r["side"])), subject_side)]:
        compare_records(read(filename), keyfn, table, 1e-8)
    per_step = defaultdict(list)
    for row in rows:
        per_step[trace_key(row)[:-1]+(int(row["step"]),)].append(row)
    for key, step in per_step.items():
        assert len(step) == 4
        reward = average([number(r, "rewardMotor") for r in step])
        for row in step:
            close(reward, number(row, "rewardEpisode"), (key, "rewardEpisode"), 1e-12)
    baseline_rows = [r for r in read_csv(HERE/"e2d_results/step_traces.csv") if number(r, "epsilon") == 0]
    baseline = {(r["subject"], int(r["repetition"]), int(r["side"]), int(r["motor"]), int(r["step"])): r for r in baseline_rows}
    assert len(baseline) == 11752
    for row in rows:
        b = baseline[trace_key(row)[1:]+(int(row["step"]),)]
        assert number(row, "baselinePwm") == number(b, "pwm")
        for field in ["referenceBefore", "referenceAfter"]:
            assert number(row, field) == number(b, field)
        if not int(row["enabled"]):
            for field, previous_field in [("qBefore", "qBefore"), ("qAfter", "qAfter"),
                                          ("rawAction", "rawDeadband"), ("effective", "effective"), ("pwm", "pwm")]:
                assert number(row, field) == number(b, previous_field), ("OFF contra E2D ε0", field)
            close(number(row, "rewardEpisode"), number(b, "rewardEpisode"), "OFF reward", 1e-12)
    events = expected_events(rows, groups)
    compare_records(read("event_summary.csv"), lambda r: (int(r["enabled"]), r["kind"], int(r["motor"]), int(r["side"])), events)
    calculated_windows = {}
    for key, entries in windows.items():
        for end, pair in entries.items():
            baseline_pair = windows[(0,)+key[1:]].get(end)
            same = baseline_pair is not None and max(abs(a-b) for a, b in zip(pair, baseline_pair)) <= 1e-9
            calculated_windows[key+(end,)] = dict(terminal=int(end == len(groups[key])), qLow=pair[0], qHigh=pair[1],
                                                 newVersusBaselineAtSameWindow=int(not same))
    compare_records(read("cycle_windows.csv"), lambda r: trace_key(r)+(int(r["endStep"]),), calculated_windows, 1e-8)
    pwm_counts = {(key, pwm): sum(number(r, "pwm") == pwm for r in group)
                  for key, group in groups.items() for pwm in [-255, -224, -192, -160, -128, -96, -64, 0, 64, 96, 128, 160, 192, 224, 255]}
    distribution = read("pwm_distribution.csv")
    assert len(distribution) == len(pwm_counts)
    for row in distribution:
        assert number(row, "count") == pwm_counts[(trace_key(row), int(row["pwm"]))]
    degradation = {}
    gate_details = {}
    for enabled in [0, 1]:
        current, baseline_macro = macros[(enabled,)], macros[(0,)]
        flats = [current["flat_response"]-baseline_macro["flat_response"]]
        unmoved = [current["action_no_motion"]-baseline_macro["action_no_motion"]]
        counts = {}
        for kind, table in [("subject", subjects), ("motor", motors), ("direction", directions)]:
            count = 0
            for key, value in table.items():
                if key[0] != enabled:
                    continue
                base = table[(0, key[1])]
                dm = deterioration(value["trackingMSE"], base["trackingMSE"])
                dr = deterioration(value["rewardMean"], base["rewardMean"], True)
                degraded = dm > 5+1e-12 or dr > 5+1e-12
                rec = dict(mseChangePct=dm, rewardChangePct=dr, degraded=int(degraded),
                           flatIncrease=value["flat_response"]-base["flat_response"],
                           noMotionIncrease=value["action_no_motion"]-base["action_no_motion"])
                degradation[(enabled, kind, str(key[1]))] = rec
                count += degraded
                if kind != "subject":
                    flats.append(rec["flatIncrease"]); unmoved.append(rec["noMotionIncrease"])
            counts[kind] = count
        subset = [r for r in rows if int(r["enabled"]) == enabled]
        cycles = sum(v["persistentTwoCycle"] for k, v in calculated.items() if k[0] == enabled)
        mode_windows = [v for k, v in calculated_windows.items() if k[0] == enabled]
        detail = dict(cycles=cycles, newCycles=sum(v["terminal"] and v["newVersusBaselineAtSameWindow"] for v in mode_windows),
                      mseChangePct=deterioration(current["trackingMSE"], baseline_macro["trackingMSE"]),
                      rewardChangePct=deterioration(current["rewardMean"], baseline_macro["rewardMean"], True),
                      subjectDegradations=counts["subject"], motorDegradations=counts["motor"], directionDegradations=counts["direction"],
                      m3Reversals=sum(int(r["motor"]) == 3 and number(r, "pwm") > 0 and number(r, "qAfter") < number(r, "qBefore") for r in subset),
                      zeroMotionFailures=sum(number(r, "pwm") == 0 and abs(number(r, "qAfter")-number(r, "qBefore")) > 1e-9 for r in subset),
                      maxFlatIncrease=max(flats), maxNoMotionIncrease=max(unmoved),
                      flatDefined=int(all(math.isfinite(v) for v in flats)), noMotionDefined=int(all(math.isfinite(v) for v in unmoved)),
                      neutralStepFractionOfActiveBaseline=events[(enabled, "total", 0, 0)]["neutralStepFractionOfActiveBaseline"],
                      slidingCycleWindows=len(mode_windows), newSlidingCycleWindows=sum(v["newVersusBaselineAtSameWindow"] for v in mode_windows),
                      inactiveEpisodeMotors=sum(v["activeCommands"] == 0 for k, v in calculated.items() if k[0] == enabled),
                      trackingMSE=current["trackingMSE"], rewardMean=current["rewardMean"])
        flags = [cycles == 0, detail["newCycles"] == 0, detail["mseChangePct"] <= 5+1e-12,
                 detail["rewardChangePct"] <= 5+1e-12, counts["subject"] <= 2 and counts["motor"] <= 1 and counts["direction"] == 0,
                 detail["flatDefined"] and detail["maxFlatIncrease"] <= .02+1e-12,
                 detail["noMotionDefined"] and detail["maxNoMotionIncrease"] <= .05+1e-12,
                 detail["neutralStepFractionOfActiveBaseline"] <= .10+1e-12,
                 detail["m3Reversals"] == 0, detail["zeroMotionFailures"] == 0]
        detail.update({"pass"+letter: int(flag) for letter, flag in zip("ABCDEFGHIJ", flags)})
        detail["passed"] = int(all(flags))
        gate_details[(enabled,)] = detail
    compare_records(read("subgroup_degradations.csv"), lambda r: (int(r["enabled"]), r["kind"], r["group"]), degradation, 1e-8)
    compare_records(read("candidate_gates.csv"), lambda r: (int(r["enabled"]),), gate_details, 1e-8)
    close(macros[(0,)]["trackingMSE"], .025400336373607925, "MSE basal E2B", 1e-12)
    close(macros[(0,)]["rewardMean"], -.03272837710980499, "reward basal E2B", 1e-12)
    assert gate_details[(0,)]["cycles"] == 2 and gate_details[(0,)]["m3Reversals"] == 0
    # Casos originales duplicados con trazas completas y misma identidad numérica.
    known = read("known_cases_all_motors.csv")
    indexed_rows = {trace_key(r)+(int(r["step"]),): r for r in rows}
    for row in known:
        expected = indexed_rows[trace_key(row)+(int(row["step"]),)]
        assert row == expected, "Reproducción del caso conocido difiere de episodio completo."
    fixed_rows = read("fixed_reference_traces.csv")
    fixed_groups = group_traces(fixed_rows)
    assert len(fixed_groups) == 40 and len(fixed_rows) == 4000
    fixed_calculated = {}
    fixed_baseline = read_csv(HERE/"e2c_results/cycle_fixed_reference_replay.csv")
    fixed_baseline = {(int(r["caseId"]), int(r["referenceIndex"]), int(r["initialStateIndex"]), int(r["step"])): r for r in fixed_baseline}
    for key, group in fixed_groups.items():
        metrics, found, error = validate_trace(key, group)
        max_reward_error = max(max_reward_error, error)
        period, persistent = fixed_orbit(group)
        mode = key[0]
        first = group[0]
        fixed_key = (mode, int(first["caseId"]), int(first["referenceIndex"]), int(first["initialStateIndex"]))
        fixed_calculated[fixed_key] = dict(terminalCycle=int(len(group) in found), period=period,
            persistentReversals=int(persistent), neutralSteps=sum(number(r, "neutralized") for r in group),
            requests=sum(number(r, "request") for r in group), confirmed=sum(number(r, "confirmed") for r in group),
            cancelled=sum(number(r, "cancelled") for r in group), pendingEnd=int(number(group[-1], "pendingAfter") != 0),
            confirmedLast20=sum(number(r, "confirmed") for r in group[-20:]), lastQ=number(group[-1], "qAfter"),
            lastError=number(group[-1], "errorBefore"), reference=number(first, "referenceBefore"))
        for row in group:
            assert number(row, "referenceBefore") == number(first, "referenceBefore")
            assert number(row, "referenceAfter") == number(first, "referenceAfter")
            if not mode:
                old = fixed_baseline[fixed_key[1:]+(int(row["step"]),)]
                for field, oldfield in [("qBefore", "qBefore"), ("qAfter", "qAfter"), ("pwm", "pwm"),
                                        ("rawAction", "raw"), ("effective", "effective")]:
                    assert number(row, field) == number(old, oldfield), ("OFF fijo contra E2C", field)
    compare_records(read("fixed_reference_summary.csv"),
                    lambda r: (int(r["enabled"]), int(r["caseId"]), int(r["referenceIndex"]), int(r["initialStateIndex"])), fixed_calculated, 1e-8)
    diagnostic = json.loads((OUT/"diagnostic_summary.json").read_text(encoding="utf-8-sig"))
    for field, value in [("onHistoricalCycles", sum(v["terminalCycle"] for k, v in fixed_calculated.items() if k[0] == 1)),
                         ("onAugmentedStateCycles", sum(v["period"] > 0 for k, v in fixed_calculated.items() if k[0] == 1)),
                         ("onPersistentReversals", sum(v["persistentReversals"] for k, v in fixed_calculated.items() if k[0] == 1))]:
        assert diagnostic[field] == value
    measurement = json.loads((OUT/"measurement_summary.json").read_text(encoding="utf-8-sig"))
    assert measurement["baselineExact"] and measurement["baselineMaxRewardError"] <= 1e-12
    assert measurement["preregistrationSHA256"] == prereg_hash
    assert measurement["sourceSHA256"] == sha(HERE/"e2b_results/trajectories.mat")
    assert measurement["episodes"] == 200 and measurement["commandsPerMode"] == 11752
    assert measurement["RL_AUTHORIZED"] is False
    tests_count = None
    if (OUT/"test_results.csv").exists():
        tests = read("test_results.csv")
        previous = read("previous_test_results.csv")
        assert len(previous) == 107 and len(tests) > 107
        assert all(r["Passed"] == "1" and r["Failed"] == "0" and r["Incomplete"] == "0" for r in tests)
        tests_count = len(tests)
    expected_result = "REVERSAL_GUARD_SUPPORTED" if gate_details[(1,)]["passed"] else "REVERSAL_GUARD_NOT_SUFFICIENT"
    if (OUT/"e2e_summary.json").exists():
        summary = json.loads((OUT/"e2e_summary.json").read_text(encoding="utf-8-sig"))
        assert summary["E2E_RESULT"] == expected_result
        assert summary["RL_AUTHORIZED"] is False
    result = dict(verified=True, historicalHashes=len(history), preregistrationSHA256=prereg_hash,
                  artifactHashes=artifact_count, motorSteps=len(rows), episodeMotorMetrics=len(calculated),
                  maxRewardReconstructionError=max_reward_error,
                  historicalCycles=[gate_details[(e,)]["cycles"] for e in [0, 1]],
                  augmentedFixedCycles=[sum(v["period"] > 0 for k, v in fixed_calculated.items() if k[0] == e) for e in [0, 1]],
                  failedGates=[letter for letter in "ABCDEFGHIJ" if not gate_details[(1,)]["pass"+letter]],
                  tests=tests_count, E2E_RESULT=expected_result)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return result


if __name__ == "__main__":
    verify()
