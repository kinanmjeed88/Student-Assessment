import { describe, expect, it } from "vitest";

describe("Android signing secrets", () => {
  it("provides non-empty protected passwords for the keystore and key", () => {
    expect(process.env.ANDROID_KEYSTORE_PASSWORD?.trim().length).toBeGreaterThanOrEqual(8);
    expect(process.env.ANDROID_KEY_PASSWORD?.trim().length).toBeGreaterThanOrEqual(8);
  });
});
