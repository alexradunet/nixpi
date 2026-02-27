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
  parse(raw: string): ObjectData;
  stringify(data: Record<string, unknown>, content: string): string;
}

/** CRUD operations on the flat-file object store. */
export interface IObjectStore {
  create(type: string, slug: string, fields?: Record<string, string>): string;
  read(type: string, slug: string): ObjectData;
  list(type: string | null, filters?: Record<string, string>): ObjectRef[];
  update(type: string, slug: string, fields: Record<string, string>): void;
  search(pattern: string): ObjectRef[];
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

/** Routes incoming messages to the appropriate handler. */
export interface MessageRouter {
  registerChannel(channel: MessageChannel): void;
  route(msg: IncomingMessage): Promise<string>;
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
