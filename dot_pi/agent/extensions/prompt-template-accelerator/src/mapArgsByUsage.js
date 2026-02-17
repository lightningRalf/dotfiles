function isMissing(value) {
  return value === undefined || value === null || value.trim().length === 0;
}

function ensureIndex(args, index) {
  while (args.length <= index) {
    args.push("");
  }
}

function inferSlotFromHint(index, hint) {
  const text = (hint ?? "").toLowerCase();

  if (/system4d|mode|off|lite|full/.test(text)) return "mode";
  if (/workflow|audience|context|repo|branch|project|environment/.test(text)) return "context";
  if (/constraint|constraints|extra|extras|preference|preferences|requirement|requirements|notes?/.test(text)) {
    return "extras";
  }
  if (/rough|prompt|idea|task|problem|goal|request/.test(text)) return "rough";

  if (index === 1) return "rough";
  if (index === 2) return "context";
  if (index === 3) return "mode";

  return "extras";
}

function getSlotValue(slot, inferred) {
  switch (slot) {
    case "rough":
      return inferred.roughThought;
    case "context":
      return inferred.contextSummary;
    case "mode":
      return inferred.system4dMode || "lite";
    case "extras":
    default:
      return inferred.extrasSummary;
  }
}

function getRestStart(usage, hints) {
  const starts = [];

  for (const slice of usage.slices ?? []) {
    if (Number.isFinite(slice.start) && slice.start >= 1) starts.push(slice.start);
  }

  for (const hint of hints.restHints ?? []) {
    if (Number.isFinite(hint.start) && hint.start >= 1) starts.push(hint.start);
  }

  if (usage.usesAllArgs && starts.length === 0) {
    starts.push(3);
  }

  if (starts.length === 0) return undefined;
  return Math.min(...starts);
}

function resolveRestSlot(restStart, usage, hints) {
  const restHints = hints.restHints ?? [];
  const exact = restHints.find((entry) => entry.start === restStart);
  const fallback = exact ?? restHints[0];

  if (fallback?.hint) {
    return inferSlotFromHint(restStart, fallback.hint);
  }

  if (usage.usesAllArgs) return "context";
  return "extras";
}

function getRestValue(slot, inferred) {
  if (slot === "context") {
    return inferred.contextExtrasSummary || inferred.contextSummary;
  }

  return getSlotValue(slot, inferred);
}

/**
 * Deterministic + line-hint-aware mapping:
 * - reads template line hints around placeholders when args are missing
 * - fills missing positional args with inferred context snippets
 * - appends extrasSummary when template uses variadic args and no rest args exist
 */
export function mapArgsByUsage(providedArgs, inferred, usage, hints = {}) {
  const mapped = [...providedArgs];

  for (let position = 1; position <= usage.highestPositionalIndex; position += 1) {
    const index = position - 1;
    ensureIndex(mapped, index);

    if (!isMissing(mapped[index])) continue;

    const hint = hints.positionalHints?.[position];
    const slot = inferSlotFromHint(position, hint);
    mapped[index] = getSlotValue(slot, inferred) ?? "";
  }

  const restStart = getRestStart(usage, hints);
  if (restStart === undefined) {
    return mapped;
  }

  const restStartIndex = Math.max(0, restStart - 1);
  const hasRestArgs = mapped.slice(restStartIndex).some((arg) => !isMissing(arg));

  if (!hasRestArgs) {
    const restSlot = resolveRestSlot(restStart, usage, hints);
    const restValue = getRestValue(restSlot, inferred);

    if (!isMissing(restValue ?? "")) {
      while (mapped.length < restStartIndex) {
        mapped.push("");
      }
      mapped.push(restValue);
    }
  }

  return mapped;
}
