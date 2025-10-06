// Type-safe, self-documenting CLI parser for Deno
// Usage: import { defineCli, parseCli } from "./utils/cli_parser.ts"
import consola from "npm:consola";

export type FlagType = "string" | "boolean" | "number";

export interface FlagSpec<T extends FlagType = FlagType> {
  description: string;
  type: T;
  required?: boolean;
  default?: T extends "boolean"
    ? boolean
    : T extends "number"
    ? number
    : string;
  choices?: T extends "string" ? readonly string[] : never;
  alias?: string[];
}

export interface CommandSpec {
  description: string;
  [x: string]: FlagSpec | string;
}

// --- Type helper to flatten CLI argument definitions ---
type TypeFromCliType<T> =
  T extends { type: "boolean" } ? boolean :
  T extends { type: "string" } ? string :
  T extends { type: "number" } ? number :
  never;

export type FlattenCliArgs<T> = {
  [K in keyof T as K extends "description" ? never : K]?:
    T[K] extends { type: "boolean" | "string" | "number" }
      ? TypeFromCliType<T[K]>
      : T[K] extends object
        ? FlattenCliArgs<T[K]>
        : never;
};

// --- FLATTENED CLI SPEC SUPPORT ---
// Now, each command is an object with a description and its options as direct properties (not an array)

// Utility type to map OptionSpec to its TS type
export type OptionSpecToTs<T> = T extends { type: infer U; choices?: infer C }
  ? U extends "string" | "boolean" | "number"
    ? U extends "string"
      ? C extends readonly string[]
        ? C[number]
        : string
      : U extends "boolean"
      ? boolean
      : U extends "number"
      ? number
      : never
    : never
  : never;

export interface CommandSpecFlat {
  description: string;
  [option: string]:
    | {
        type: "string" | "boolean" | "number";
        description: string;
        required?: boolean;
        default?: string | boolean | number;
        choices?: readonly string[];
        alias?: string[];
      }
    | string | boolean | number;
}

export type CliSpecFlat<K extends string = string> = Record<K, CommandSpecFlat>;

type OptionKeys<T> = Exclude<keyof T, "description">;

export type OptionObjectToFlags<T> = {
  [K in OptionKeys<T>]: OptionSpecToTs<T[K]>;
} & {
  [K in OptionKeys<T> as T[K] extends { alias: infer A extends string[] }
    ? A[number]
    : never]?: OptionSpecToTs<T[K]>;
};

export type CliCommandOptionsFlat<
  S extends CliSpecFlat,
  K extends keyof S
> = OptionObjectToFlags<S[K]>;

export function defineCli<T extends CliSpecFlat>(spec: T) {
  // Inject env var defaults for each command/option
  const envPrefix = "PBS_";
  for (const [cmd, def] of Object.entries(spec)) {
    for (const [optKey, opt] of Object.entries(def)) {
      if (optKey === "description" || typeof opt !== "object") continue;
      const envVar = `${envPrefix}${cmd.toUpperCase()}_${optKey
        .replace(/-/g, "_")
        .toUpperCase()}`;
      const envVal = Deno.env.get(envVar);
      if (envVal !== undefined) {
        if (opt.type === "boolean") {
          opt.default = envVal === "true";
        } else if (opt.type === "number") {
          const n = Number(envVal);
          if (!isNaN(n)) opt.default = n;
        } else {
          opt.default = envVal;
        }
      }
    }
  }
  return spec;
}

function parseValue(
  type: FlagType,
  value: string | undefined,
  choices?: readonly string[]
) {
  if (type === "boolean") return value === "true" || value === undefined;
  if (type === "number") {
    const n = Number(value);
    if (isNaN(n)) throw new Error(`Invalid number: ${value}`);
    return n;
  }
  if (type === "string") {
    if (choices && value && !choices.includes(value)) {
      throw new Error(
        `Invalid value: ${value}. Allowed: ${choices.join(", ")}`
      );
    }
    return value ?? "";
  }
  return value;
}

// Helper type: Get the flags type for a given command key from a parsed result
export type ParsedCliResult<S extends CliSpecFlat> =
  | {
      [K in keyof S]: { command: K; flags: CliCommandOptionsFlat<S, K> };
    }[keyof S];

// Support for global flags (e.g. dry-run)
const GLOBAL_FLAGS = ["dry-run", "unsafe-cli-fall-through"];
const GLOBAL_ENV_VARS = Object.fromEntries(
  GLOBAL_FLAGS.map((flag) => [
    flag,
    `PBS_${flag.replace(/-/g, "_").toUpperCase()}`,
  ])
);

export function parseCli<S extends CliSpecFlat>(
  spec: S,
  args: string[] = Deno.args
): ParsedCliResult<S> {
  // Debug logging: if --debug is present, set consola level to 5
  if (args.includes("--debug")) {
    consola.level = 5;
    consola.debug("Debug mode enabled. Args:", args);
  }
  // Extract global flags
  const globalFlags: Record<string, unknown> = {};
  // Check for global env vars (e.g., PBS_DRY_RUN, PBS_UNSAFE_CLI_FALL_THROUGH)
  for (const [flag, envVar] of Object.entries(GLOBAL_ENV_VARS)) {
    const envVal = Deno.env.get(envVar);
    if (envVal !== undefined) {
      globalFlags[flag] = parseValue("boolean", envVal);
    }
  }
  const filteredArgs: string[] = [];
  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg.startsWith("--")) {
      const name = arg.slice(2);
      if (GLOBAL_FLAGS.includes(name)) {
        globalFlags[name] = true;
        i++;
        continue;
      }
    } else if (arg.startsWith("-")) {
      const aliases = arg.slice(1).split("");
      for (const a of aliases) {
        if (GLOBAL_FLAGS.includes(a)) {
          globalFlags[a] = true;
        }
      }
      i++;
      continue;
    }
    filteredArgs.push(arg);
    i++;
  }
  const [cmd, ...rest] = filteredArgs;
  if (!cmd || !(cmd in spec)) {
    printGlobalHelp(spec);
    Deno.exit(1);
  }
  const command = spec[cmd as keyof S];
  const opts = Object.entries(command).filter(([k]) => k !== "description");
  const flags: Record<string, unknown> = { ...globalFlags };
  i = 0;
  while (i < rest.length) {
    const arg = rest[i];
    if (arg === "--help" || arg === "-h") {
      printCommandHelp(cmd, command);
      Deno.exit(0);
    }
    if (arg.startsWith("--")) {
      const name = arg.slice(2);
      const optEntry = opts.find(
        ([k, o]) =>
          k === name || (typeof o === "object" && o.alias?.includes(name))
      );
      if (!optEntry) {
        if (globalFlags["unsafe-cli-fall-through"]) {
          i++;
          continue;
        }
        throw new Error(`Unknown option: --${name}`);
      }
      const [optKey, opt] = optEntry;
      if (typeof opt !== "object") throw new Error(`Invalid option: --${name}`);
      if (opt.type === "boolean") {
        flags[optKey] = true;
        i++;
      } else {
        const val = rest[i + 1];
        flags[optKey] = parseValue(opt.type, val, opt.choices);
        i += 2;
      }
    } else if (arg.startsWith("-")) {
      const aliases = arg.slice(1).split("");
      for (const a of aliases) {
        const optEntry = opts.find(
          ([_, o]) => typeof o === "object" && o.alias?.includes(a)
        );
        if (!optEntry) {
          if (globalFlags["unsafe-cli-fall-through"]) {
            continue;
          }
          throw new Error(`Unknown option: -${a}`);
        }
        const [optKey, opt] = optEntry;
        if (typeof opt !== "object") throw new Error(`Invalid option: -${a}`);
        if (opt.type === "boolean") {
          flags[optKey] = true;
        } else {
          const val = rest[i + 1];
          flags[optKey] = parseValue(opt.type, val, opt.choices);
          i++;
        }
      }
      i++;
    } else {
      i++;
    }
  }
  for (const [optKey, opt] of opts) {
    if (typeof opt !== "object") continue;
    if (flags[optKey] === undefined) {
      if (opt.default !== undefined) flags[optKey] = opt.default;
      else if (opt.required)
        throw new Error(`Missing required option: --${optKey}`);
    }
  }
  // Return with the correct discriminated union type
  return { command: cmd, flags } as ParsedCliResult<S>;
}

// Add color helpers
const color = {
  green: (s: string) => `\x1b[32m${s}\x1b[0m`,
  yellow: (s: string) => `\x1b[33m${s}\x1b[0m`,
  cyan: (s: string) => `\x1b[36m${s}\x1b[0m`,
  magenta: (s: string) => `\x1b[35m${s}\x1b[0m`,
  bold: (s: string) => `\x1b[1m${s}\x1b[0m`,
};

function printGlobalHelp(spec: CliSpecFlat) {
  consola.log(color.cyan("Available commands:"));
  for (const [cmd, def] of Object.entries(spec)) {
    consola.log(`  ${color.green(cmd)}: ${def.description}`);
  }
  consola.log("\n" + color.yellow("Use <command> --help for more info."));
}

function printCommandHelp(cmd: string, def: CommandSpecFlat) {
  consola.log(
    color.cyan(`Usage: pbs ${color.green(cmd)} [options]\n${def.description}`)
  );
  for (const [optKey, opt] of Object.entries(def)) {
    if (optKey === "description" || typeof opt !== "object") continue;
    const alias = opt.alias ? color.yellow(`-${opt.alias.join(", -")}`) : "";
    const choices = opt.choices
      ? color.magenta(` [${opt.choices.join("|")}]`)
      : "";
    const defVal =
      opt.default !== undefined ? color.cyan(` (default: ${opt.default})`) : "";
    // Use global env var if this is a global flag
    consola.log(
      `  ${color.green(`--${optKey}`)}${alias ? ", " + alias : ""}${choices}: ${
        opt.description
      }${defVal}`
    );
  }
  // Print global flags not in this command
  for (const globalFlag of GLOBAL_FLAGS) {
    if (def[globalFlag]) continue;
    const envVar = GLOBAL_ENV_VARS[globalFlag];
    const envVal = Deno.env.get(envVar);
    const envInfo =
      envVal !== undefined
        ? color.green(` [env: ${envVar}=${envVal}]`)
        : color.yellow(` [env: ${envVar} unset]`);
    consola.log(`  ${color.green(`--${globalFlag}`)}: (global flag)${envInfo}`);
  }
}
