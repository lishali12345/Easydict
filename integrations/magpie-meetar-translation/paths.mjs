import { homedir } from "node:os";
import { isAbsolute, join } from "node:path";

/** Keep personal configuration and translation content outside the checkout. */
export function paths(options = {}) {
  const directory = options.directory ?? join(homedir(), "Library", "Application Support", "MeeTarTranslation");
  if (typeof directory !== "string" || !isAbsolute(directory)) {
    throw new Error("Translation data directory must be an absolute path");
  }
  return {
    directory,
    policy: join(directory, "policy.json"),
    database: join(directory, "records.sqlite"),
  };
}
