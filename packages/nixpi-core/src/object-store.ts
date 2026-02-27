import fs from "node:fs";
import path from "node:path";
import type { IFrontmatterParser, IObjectStore, ObjectData, ObjectRef } from "./types.js";
import { JsYamlFrontmatterParser } from "./frontmatter.js";

// Canonical runtime implementation: scripts/nixpi-object.sh (used by Pi skills).
// This TypeScript version serves as a typed reference implementation for tests.
export class ObjectStore implements IObjectStore {
  private readonly parser: IFrontmatterParser;

  constructor(
    private readonly objectsDir: string,
    parser?: IFrontmatterParser
  ) {
    this.parser = parser ?? new JsYamlFrontmatterParser();
  }

  private objectPath(type: string, slug: string): string {
    return path.join(this.objectsDir, type, `${slug}.md`);
  }

  private nowIso(): string {
    return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  }

  create(
    type: string,
    slug: string,
    fields: Record<string, string> = {}
  ): string {
    const filepath = this.objectPath(type, slug);

    fs.mkdirSync(path.dirname(filepath), { recursive: true });

    const now = this.nowIso();

    // Build data in priority order: type, slug, title, status, priority, project, area, ...rest, created, modified
    const priorityKeys = ["type", "slug", "title", "status", "priority", "project", "area"];
    const data: Record<string, unknown> = {};

    // Add priority keys first (if present)
    for (const k of priorityKeys) {
      if (k === "type") data.type = type;
      else if (k === "slug") data.slug = slug;
      else if (k in fields) data[k] = fields[k];
    }

    // Add remaining fields alphabetically
    const rest = Object.keys(fields)
      .filter((k) => !priorityKeys.includes(k))
      .sort();
    for (const k of rest) {
      data[k] = fields[k];
    }

    // Split comma-delimited tags/links with trim
    if (typeof data.tags === "string") {
      data.tags = (data.tags as string).split(",").map((s) => s.trim()).filter(Boolean);
    }
    if (typeof data.links === "string") {
      data.links = (data.links as string).split(",").map((s) => s.trim()).filter(Boolean);
    }

    // Timestamps last
    data.created = now;
    data.modified = now;

    const title = data.title as string | undefined;
    const body = title ? `# ${title}\n` : "";

    // Atomic exclusive-create: flag 'wx' fails if file already exists,
    // preventing race conditions between check and write.
    try {
      fs.writeFileSync(filepath, this.parser.stringify(data, body), { flag: "wx" });
    } catch (err: unknown) {
      if ((err as NodeJS.ErrnoException).code === "EEXIST") {
        throw new Error(`object already exists: ${type}/${slug}`);
      }
      throw err;
    }

    return `created ${type}/${slug}`;
  }

  read(type: string, slug: string): ObjectData {
    const filepath = this.objectPath(type, slug);
    let raw: string;
    try {
      raw = fs.readFileSync(filepath, "utf-8");
    } catch (err: unknown) {
      if ((err as NodeJS.ErrnoException).code === "ENOENT") {
        throw new Error(`object not found: ${type}/${slug}`);
      }
      throw err;
    }
    return this.parser.parse(raw);
  }

  list(
    type: string | null,
    filters: Record<string, string> = {}
  ): ObjectRef[] {
    const searchDirs: string[] = [];

    if (type === null) {
      if (!fs.existsSync(this.objectsDir)) return [];
      for (const entry of fs.readdirSync(this.objectsDir, {
        withFileTypes: true,
      })) {
        if (entry.isDirectory()) {
          searchDirs.push(path.join(this.objectsDir, entry.name));
        }
      }
    } else {
      const dir = path.join(this.objectsDir, type);
      if (fs.existsSync(dir)) searchDirs.push(dir);
    }

    const results: ObjectRef[] = [];

    for (const dir of searchDirs) {
      for (const file of fs.readdirSync(dir)) {
        if (!file.endsWith(".md")) continue;
        const filepath = path.join(dir, file);
        const raw = fs.readFileSync(filepath, "utf-8");
        const parsed = this.parser.parse(raw);
        const d = parsed.data;

        let match = true;
        for (const [key, val] of Object.entries(filters)) {
          if (key === "tag") {
            const tags = Array.isArray(d.tags) ? d.tags : [];
            if (!tags.includes(val)) {
              match = false;
              break;
            }
          } else {
            if (String(d[key] ?? "") !== val) {
              match = false;
              break;
            }
          }
        }

        if (match) {
          const ref: ObjectRef = {
            type: String(d.type ?? ""),
            slug: String(d.slug ?? ""),
          };
          if (d.title) ref.title = String(d.title);
          results.push(ref);
        }
      }
    }

    return results;
  }

  update(
    type: string,
    slug: string,
    fields: Record<string, string>
  ): void {
    const filepath = this.objectPath(type, slug);
    let raw: string;
    try {
      raw = fs.readFileSync(filepath, "utf-8");
    } catch (err: unknown) {
      if ((err as NodeJS.ErrnoException).code === "ENOENT") {
        throw new Error(`object not found: ${type}/${slug}`);
      }
      throw err;
    }
    const parsed = this.parser.parse(raw);
    const data = parsed.data;

    for (const [key, val] of Object.entries(fields)) {
      if (key === "tags" || key === "links") {
        data[key] = val.split(",").map((s) => s.trim()).filter(Boolean);
      } else {
        data[key] = val;
      }
    }
    data.modified = this.nowIso();

    fs.writeFileSync(filepath, this.parser.stringify(data, parsed.content));
  }

  search(pattern: string): ObjectRef[] {
    if (!fs.existsSync(this.objectsDir)) {
      throw new Error(`objects directory not found: ${this.objectsDir}`);
    }

    const results: ObjectRef[] = [];
    const seen = new Set<string>();

    for (const entry of fs.readdirSync(this.objectsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const typeDir = path.join(this.objectsDir, entry.name);

      for (const file of fs.readdirSync(typeDir)) {
        if (!file.endsWith(".md")) continue;
        const filepath = path.join(typeDir, file);
        const raw = fs.readFileSync(filepath, "utf-8");

        if (!raw.includes(pattern)) continue;

        const parsed = this.parser.parse(raw);
        const d = parsed.data;
        const objType = String(d.type ?? "");
        const objSlug = String(d.slug ?? "");
        const key = `${objType}/${objSlug}`;

        if (!seen.has(key)) {
          seen.add(key);
          const ref: ObjectRef = { type: objType, slug: objSlug };
          if (d.title) ref.title = String(d.title);
          results.push(ref);
        }
      }
    }

    return results;
  }

  link(refA: string, refB: string): string {
    const parseRef = (ref: string) => {
      const slash = ref.indexOf("/");
      if (slash === -1) {
        throw new Error(
          `invalid reference format: '${ref}' (expected type/slug)`
        );
      }
      return { type: ref.slice(0, slash), slug: ref.slice(slash + 1) };
    };

    const a = parseRef(refA);
    const b = parseRef(refB);

    const pathA = this.objectPath(a.type, a.slug);
    const pathB = this.objectPath(b.type, b.slug);

    // Validate both exist before mutating either (read will throw ENOENT)
    this.readFileOrThrow(pathA, refA);
    this.readFileOrThrow(pathB, refB);

    this.addLink(pathA, refB);
    this.addLink(pathB, refA);

    return `linked ${refA} <-> ${refB}`;
  }

  private readFileOrThrow(filepath: string, ref: string): string {
    try {
      return fs.readFileSync(filepath, "utf-8");
    } catch (err: unknown) {
      if ((err as NodeJS.ErrnoException).code === "ENOENT") {
        throw new Error(`object not found: ${ref}`);
      }
      throw err;
    }
  }

  private addLink(filepath: string, linkRef: string): void {
    const raw = fs.readFileSync(filepath, "utf-8");
    const parsed = this.parser.parse(raw);
    const data = parsed.data;

    const links: string[] = Array.isArray(data.links) ? [...data.links] : [];
    if (!links.includes(linkRef)) {
      links.push(linkRef);
      data.links = links;
      fs.writeFileSync(filepath, this.parser.stringify(data, parsed.content));
    }
  }
}
