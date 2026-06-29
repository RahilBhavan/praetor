import _Ajv2020 from "ajv/dist/2020.js";
import { readFileSync } from "node:fs";
import type { Spec } from "./types.js";

// ajv ships CJS; under ESM the default import can arrive nested. Guard both.
const Ajv2020 = ((_Ajv2020 as unknown as { default?: unknown }).default ??
  _Ajv2020) as typeof _Ajv2020;

// Load the schema at runtime (works for both source under vitest and built dist).
// Avoids a bare `import x from "./schema.json"`, which crashes under plain Node ESM
// with ERR_IMPORT_ATTRIBUTE_MISSING (and `with { type: "json" }` is unsupported on
// Node 20.0–20.9, below our engines floor).
export const schema = JSON.parse(
  readFileSync(new URL("../schema.json", import.meta.url), "utf8"),
) as Record<string, unknown>;

export interface ValidationError {
  instancePath: string;
  message: string;
}
export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
}

const ajv = new Ajv2020({ allErrors: true, strict: false });
const validateFn = ajv.compile(schema);

/** Validate an already-parsed spec object against the Praetor JSON Schema. */
export function validateSpec(spec: unknown): ValidationResult {
  const valid = validateFn(spec) as boolean;
  const errors = (validateFn.errors ?? []).map((e) => ({
    instancePath: e.instancePath,
    message: e.message ?? "invalid",
  }));
  return { valid, errors };
}

/** Validate and narrow; throws on failure. Use at engine/compiler entry (fail-closed). */
export function assertSpec(spec: unknown): Spec {
  const { valid, errors } = validateSpec(spec);
  if (!valid) {
    const detail = errors.map((e) => `${e.instancePath || "/"} ${e.message}`).join("; ");
    throw new Error(`Invalid Praetor spec: ${detail}`);
  }
  return spec as Spec;
}
