import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import yaml from "js-yaml";
import { validateSpec } from "../src/validate.js";

const here = dirname(fileURLToPath(import.meta.url));
const exampleSpec = yaml.load(
  readFileSync(resolve(here, "../../../praetor.spec.yaml"), "utf8"),
) as Record<string, unknown>;

describe("praetor spec schema", () => {
  it("accepts the example praetor.spec.yaml", () => {
    const { valid, errors } = validateSpec(exampleSpec);
    expect(errors).toEqual([]);
    expect(valid).toBe(true);
  });

  it("rejects an unknown top-level key (additionalProperties:false)", () => {
    expect(validateSpec({ ...exampleSpec, surprise: true }).valid).toBe(false);
  });

  it("rejects a malformed account address", () => {
    expect(validateSpec({ ...exampleSpec, account: "0xnothex" }).valid).toBe(false);
  });

  it("rejects bps over 10000", () => {
    const limits = { ...(exampleSpec.limits as object), max_slippage_bps: 10001 };
    expect(validateSpec({ ...exampleSpec, limits }).valid).toBe(false);
  });

  it("rejects a missing required field (account)", () => {
    const { account: _omit, ...noAccount } = exampleSpec;
    expect(validateSpec(noAccount).valid).toBe(false);
  });
});
