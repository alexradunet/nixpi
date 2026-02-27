/** Parsed object data from a flat-file markdown with YAML frontmatter. */
export interface ObjectData {
  /** Frontmatter key-value pairs. */
  data: Record<string, unknown>;
  /** Markdown body content (after frontmatter). */
  content: string;
}

/** Lightweight reference to a stored object. */
export interface ObjectRef {
  type: string;
  slug: string;
  title?: string;
}

/** Parses and serializes YAML frontmatter in markdown files. */
export interface IFrontmatterParser {
  /** Parse a raw markdown string with YAML frontmatter into structured data and body content. */
  parse(raw: string): ObjectData;
  /** Serialize frontmatter data and markdown body content back into a raw markdown string. */
  stringify(data: Record<string, unknown>, content: string): string;
}

/** CRUD operations on the flat-file object store. */
export interface IObjectStore {
  /**
   * Create a new object file with the given type, slug, and optional frontmatter fields.
   * @returns A confirmation string (e.g. "created type/slug").
   * @throws If an object with the same type/slug already exists.
   */
  create(type: string, slug: string, fields?: Record<string, string>): string;
  /**
   * Read an object by type and slug, returning its parsed frontmatter and body content.
   * @throws If the object does not exist.
   */
  read(type: string, slug: string): ObjectData;
  /**
   * List objects, optionally filtered by type and frontmatter field values.
   * Pass `null` for type to list across all types. Supports tag filtering via `{ tag: "value" }`.
   */
  list(type: string | null, filters?: Record<string, string>): ObjectRef[];
  /**
   * Update frontmatter fields on an existing object. Automatically updates the `modified` timestamp.
   * @throws If the object does not exist.
   */
  update(type: string, slug: string, fields: Record<string, string>): void;
  /**
   * Full-text search across all objects for a substring pattern.
   * @returns Deduplicated references to matching objects.
   * @throws If the objects directory does not exist.
   */
  search(pattern: string): ObjectRef[];
  /**
   * Create a bidirectional link between two objects (specified as "type/slug" references).
   * @returns A confirmation string (e.g. "linked a <-> b").
   * @throws If either object does not exist or the reference format is invalid.
   */
  link(refA: string, refB: string): string;
}

/** Incoming message from any channel. */
export interface IncomingMessage {
  from: string;
  text: string;
  timestamp: number;
  channel: string;
}

/** Port interface for message channels (WhatsApp, Telegram, etc.). */
export interface MessageChannel {
  readonly name: string;
  onMessage(handler: (msg: IncomingMessage) => Promise<string>): void;
  sendMessage(to: string, text: string): Promise<void>;
  connect(): Promise<void>;
  disconnect(): Promise<void>;
}

/** Configuration for Pi agent integration. */
export interface AgentConfig {
  piCommand: string;
  piDir: string;
  repoRoot: string;
  objectsDir: string;
  skillsDir: string;
  timeoutMs: number;
}
