"""
Mirror of Swift PriorityScorer.
P = U×0.35 + I×0.25 + E×0.20 + C×0.15 + D×0.05
Validates weights sum to 1.0 at import time.
"""
import math

WEIGHTS = {"U": 0.35, "I": 0.25, "E": 0.20, "C": 0.15, "D": 0.05}
assert abs(sum(WEIGHTS.values()) - 1.0) < 0.0001, "FATAL: weights must sum to 1.0"

# Default energy curve by hour
ENERGY_CURVE = {
    0: 2.0, 1: 2.0, 2: 2.0, 3: 2.0, 4: 2.0,
    5: 4.0, 6: 5.0, 7: 5.0,
    8: 9.0, 9: 9.0, 10: 9.0, 11: 9.0,
    12: 6.0, 13: 5.0,
    14: 8.0, 15: 8.0, 16: 8.0,
    17: 6.0, 18: 6.0,
    19: 5.0, 20: 5.0,
    21: 4.0, 22: 4.0,
    23: 3.0,
}

TASK_ENERGY_REQ = {
    "deep_work": 6.5, "creative": 6.0, "study": 6.5, "admin": 3.0,
    "review": 4.0, "meeting": 5.0, "meal": 1.0, "exercise": 5.5,
    "class": 5.0, "break": 1.0, "other": 4.0,
}


def compute_U(task: dict) -> float:
    """Urgency: k=0.15, overdue=10, no deadline=2, else 10×exp(-0.15×h)"""
    deadline = task.get("deadline")
    if not deadline:
        return 2.0
    import time
    h = (deadline - time.time()) / 3600
    if h < 0:
        return 10.0
    return 10.0 * math.exp(-0.15 * h)


def compute_I(task: dict) -> float:
    """Importance with postpone penalty"""
    priority_map = {"P1": 10.0, "P2": 7.0, "P3": 4.0, "P4": 1.0}
    base = priority_map.get(task.get("priority", "P3"), 4.0)
    postpone_count = task.get("postponeCount", 0)
    return max(0.0, base - 0.5 * postpone_count)


def compute_E(task: dict, current_energy: float) -> float:
    """Energy match"""
    req = TASK_ENERGY_REQ.get(task.get("category", "other"), 4.0)
    if req <= 0:
        return 10.0
    return 10.0 * min(1.0, current_energy / req)


def compute_C(task: dict, context: dict) -> float:
    """Context fit"""
    in_class = context.get("is_in_class", False)
    if in_class and task.get("category") != "class":
        return 0.0
    if task.get("category") == "meal":
        hour = context.get("hour", 12)
        if 7 <= hour <= 9 or 12 <= hour <= 14 or 19 <= hour <= 21:
            return 10.0
    frontmost = context.get("frontmost_app", "")
    related = task.get("relatedAppBundleID", "")
    if related and frontmost == related:
        return 10.0
    return 5.0


def compute_D(task: dict) -> float:
    """Deadline momentum"""
    deadline = task.get("deadline")
    if not deadline:
        return 0.0
    import time
    h = (deadline - time.time()) / 3600
    if h < 6 or h > 72:
        return 0.0
    return 10.0 * (1.0 - h / 72.0)


def score_task(task: dict, context: dict, profile: dict = None) -> dict:
    """Full P score calculation"""
    hour = context.get("hour", 12)
    if profile and "energy_by_hour" in profile:
        current_energy = profile["energy_by_hour"].get(str(hour), ENERGY_CURVE.get(hour, 5.0))
    else:
        current_energy = ENERGY_CURVE.get(hour, 5.0)

    U = compute_U(task)
    I = compute_I(task)
    E = compute_E(task, current_energy)
    C = compute_C(task, context)
    D = compute_D(task)

    raw = U * WEIGHTS["U"] + I * WEIGHTS["I"] + E * WEIGHTS["E"] + C * WEIGHTS["C"] + D * WEIGHTS["D"]
    skip_count = task.get("skipCount", 0)
    final = raw * (0.8 ** skip_count)

    task = dict(task)
    task.update({
        "urgency": U, "importance": I, "energyMatch": E,
        "contextFit": C, "deadlineMomentum": D,
        "pFinal": max(0.0, min(10.0, final))
    })
    return task


def score_all(tasks: list, context: dict, profile: dict = None) -> list:
    scored = [score_task(t, context, profile) for t in tasks]
    return sorted(scored, key=lambda t: t.get("pFinal", 0), reverse=True)
