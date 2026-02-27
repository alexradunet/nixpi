import YAML from "js-yaml";
import type { IFrontmatterParser, ObjectData } from "./types.js";

export class JsYamlFrontmatterParser implements IFrontmatterParser {
  parse(raw: string): ObjectData {
    // Normalize all CRLF to LF at entry
    const normalized = raw.replace(/\r\n/g, "\n");
    const lines = normalized.split("\n");

    // First line must be ---
    if (lines[0] !== "---") {
      return { data: {}, content: raw };
    }

    // Scan for closing --- (must be on its own line)
    let closingIndex = -1;
    for (let i = 1; i < lines.length; i++) {
      if (lines[i] === "---") {
        closingIndex = i;
        break;
      }
    }

    if (closingIndex === -1) {
      return { data: {}, content: raw };
    }

    const yamlStr = lines.slice(1, closingIndex).join("\n");
    const body = lines.slice(closingIndex + 1).join("\n");

    let data: Record<string, unknown> = yamlStr.trim() === ""
      ? {}
      : (YAML.load(yamlStr, { schema: YAML.JSON_SCHEMA }) as Record<string, unknown>) ?? {};

    // Normalize Date objects back to ISO strings (JSON_SCHEMA can coerce timestamps)
    for (const [key, val] of Object.entries(data)) {
      if (val instanceof Date) {
        data[key] = val.toISOString();
      }
    }

    return { data, content: body };
  }

  stringify(data: Record<string, unknown>, content: string): string {
    const yaml = YAML.dump(data, {
      schema: YAML.JSON_SCHEMA,
      lineWidth: -1,
      quotingType: "'",
      forceQuotes: false,
    });
    return `---\n${yaml}---\n${content}`;
  }
}
