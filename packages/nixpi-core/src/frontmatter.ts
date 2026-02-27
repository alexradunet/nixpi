import YAML from "js-yaml";
import type { IFrontmatterParser, ObjectData } from "./types.js";

export class JsYamlFrontmatterParser implements IFrontmatterParser {
  parse(raw: string): ObjectData {
    const lines = raw.split("\n");

    // First line must be ---
    if (lines[0].replace(/\r$/, "") !== "---") {
      return { data: {}, content: raw };
    }

    // Scan for closing --- (must be on its own line)
    let closingIndex = -1;
    for (let i = 1; i < lines.length; i++) {
      if (lines[i].replace(/\r$/, "") === "---") {
        closingIndex = i;
        break;
      }
    }

    if (closingIndex === -1) {
      return { data: {}, content: raw };
    }

    const yamlStr = lines.slice(1, closingIndex).join("\n");
    const body = lines.slice(closingIndex + 1).join("\n");

    const data = yamlStr.trim() === ""
      ? {}
      : (YAML.load(yamlStr, { schema: YAML.JSON_SCHEMA }) as Record<string, unknown>) ?? {};

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
