import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { IFrontmatterParser, ObjectData } from "../types.js";
import { ObjectStore } from "../object-store.js";

function makeTmpDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), "nixpi-test-"));
}

// Mock parser for unit tests — records calls and returns predictable data.
// Handles arrays by serializing as YAML lists and parsing them back.
class MockParser implements IFrontmatterParser {
  parseCalls: string[] = [];
  stringifyCalls: Array<{ data: Record<string, unknown>; content: string }> = [];

  parse(raw: string): ObjectData {
    this.parseCalls.push(raw);
    const match = raw.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
    if (!match) return { data: {}, content: raw };
    const lines = match[1].split("\n");
    const data: Record<string, unknown> = {};
    let currentKey = "";
    for (const line of lines) {
      if (line.startsWith("  - ")) {
        // Array item — append to current key
        if (currentKey) {
          if (!Array.isArray(data[currentKey])) data[currentKey] = [];
          (data[currentKey] as string[]).push(line.slice(4));
        }
      } else {
        const idx = line.indexOf(": ");
        if (idx !== -1) {
          currentKey = line.slice(0, idx);
          data[currentKey] = line.slice(idx + 2);
        } else if (line.endsWith(":")) {
          // Key with no inline value — next lines are array items
          currentKey = line.slice(0, -1);
          data[currentKey] = [];
        }
      }
    }
    return { data, content: match[2] };
  }

  stringify(data: Record<string, unknown>, content: string): string {
    this.stringifyCalls.push({ data, content });
    const lines: string[] = [];
    for (const [k, v] of Object.entries(data)) {
      if (Array.isArray(v)) {
        lines.push(`${k}:`);
        for (const item of v) lines.push(`  - ${item}`);
      } else {
        lines.push(`${k}: ${v}`);
      }
    }
    return `---\n${lines.join("\n")}\n---\n${content}`;
  }
}

describe("ObjectStore with mock parser", () => {
  let tmpDir: string;
  let mock: MockParser;
  let store: ObjectStore;

  beforeEach(() => {
    tmpDir = makeTmpDir();
    mock = new MockParser();
    store = new ObjectStore(tmpDir, mock);
  });

  it("create calls parser.stringify with correct data", () => {
    store.create("task", "test-task", { title: "Test" });
    assert.equal(mock.stringifyCalls.length, 1);
    assert.equal(mock.stringifyCalls[0].data.type, "task");
    assert.equal(mock.stringifyCalls[0].data.slug, "test-task");
    assert.equal(mock.stringifyCalls[0].data.title, "Test");
  });

  it("create throws on duplicate", () => {
    store.create("task", "dup");
    assert.throws(() => store.create("task", "dup"), /already exists/);
  });

  it("read returns ObjectData with .data and .content", () => {
    store.create("note", "n1", { title: "A Note" });
    const result = store.read("note", "n1");
    assert.equal(typeof result.data, "object");
    assert.equal(result.data.type, "note");
    assert.equal(typeof result.content, "string");
  });

  it("read throws on missing object", () => {
    assert.throws(() => store.read("task", "nope"), /not found/);
  });
});

describe("ObjectStore integration (real parser)", () => {
  let tmpDir: string;
  let store: ObjectStore;

  beforeEach(() => {
    tmpDir = makeTmpDir();
    store = new ObjectStore(tmpDir);
  });

  it("create + read round-trip returns structured data", () => {
    store.create("journal", "day1", { title: "Day One" });
    const result = store.read("journal", "day1");
    assert.equal(result.data.type, "journal");
    assert.equal(result.data.slug, "day1");
    assert.equal(result.data.title, "Day One");
    assert.ok(result.content.includes("# Day One"));
    assert.ok(result.data.created);
    assert.ok(result.data.modified);
  });

  it("list returns ObjectRef[] with type/slug/title", () => {
    store.create("task", "a", { title: "Alpha", status: "active" });
    store.create("task", "b", { title: "Beta", status: "done" });
    store.create("note", "c", { title: "Gamma" });

    const all = store.list(null);
    assert.equal(all.length, 3);
    assert.ok(all.every((ref) => ref.type && ref.slug));

    const tasks = store.list("task");
    assert.equal(tasks.length, 2);

    const active = store.list("task", { status: "active" });
    assert.equal(active.length, 1);
    assert.equal(active[0].slug, "a");
    assert.equal(active[0].title, "Alpha");
  });

  it("list filters by tag", () => {
    store.create("note", "tagged", { title: "Tagged", tags: "nix,devops" });
    store.create("note", "untagged", { title: "Untagged" });

    const results = store.list("note", { tag: "nix" });
    assert.equal(results.length, 1);
    assert.equal(results[0].slug, "tagged");
  });

  it("update changes fields and preserves others", () => {
    store.create("task", "t1", { title: "Original", status: "active" });
    store.update("task", "t1", { status: "done" });

    const result = store.read("task", "t1");
    assert.equal(result.data.status, "done");
    assert.equal(result.data.title, "Original");
  });

  it("link creates bidirectional links", () => {
    store.create("task", "t1");
    store.create("note", "n1");

    const result = store.link("task/t1", "note/n1");
    assert.ok(result.includes("linked"));

    const t1 = store.read("task", "t1");
    const n1 = store.read("note", "n1");
    assert.ok(Array.isArray(t1.data.links));
    assert.ok((t1.data.links as string[]).includes("note/n1"));
    assert.ok(Array.isArray(n1.data.links));
    assert.ok((n1.data.links as string[]).includes("task/t1"));
  });

  it("link is idempotent", () => {
    store.create("task", "t1");
    store.create("note", "n1");

    store.link("task/t1", "note/n1");
    store.link("task/t1", "note/n1");

    const t1 = store.read("task", "t1");
    const links = t1.data.links as string[];
    assert.equal(links.filter((l) => l === "note/n1").length, 1);
  });

  it("search returns ObjectRef[] matching content", () => {
    store.create("task", "find-me", { title: "Unique Keyword XYZ" });
    store.create("note", "other", { title: "Nothing" });

    const results = store.search("XYZ");
    assert.equal(results.length, 1);
    assert.equal(results[0].slug, "find-me");
    assert.equal(results[0].type, "task");
    assert.equal(results[0].title, "Unique Keyword XYZ");
  });

  it("search throws on nonexistent directory", () => {
    const badStore = new ObjectStore("/tmp/nonexistent-nixpi-dir-12345");
    assert.throws(() => badStore.search("anything"), /not found/);
  });

  it("search returns empty array on no matches", () => {
    store.create("note", "hello", { title: "Hello" });
    const results = store.search("zzz-no-match-zzz");
    assert.equal(results.length, 0);
  });

  it("tags with whitespace are trimmed (M1)", () => {
    store.create("note", "ws-tags", { title: "WS", tags: "tag1, tag2 , tag3" });
    const result = store.read("note", "ws-tags");
    assert.deepEqual(result.data.tags, ["tag1", "tag2", "tag3"]);
  });

  it("links with whitespace are trimmed (M1)", () => {
    store.create("note", "ws-links", { title: "WS", links: "task/a, task/b" });
    const result = store.read("note", "ws-links");
    assert.deepEqual(result.data.links, ["task/a", "task/b"]);
  });

  it("update rejects protected fields (type, slug, created)", () => {
    store.create("task", "protected");
    assert.throws(() => store.update("task", "protected", { type: "note" }), /protected field: type/);
    assert.throws(() => store.update("task", "protected", { slug: "changed" }), /protected field: slug/);
    assert.throws(() => store.update("task", "protected", { created: "2020-01-01T00:00:00Z" }), /protected field: created/);
    // Non-protected fields still work
    store.update("task", "protected", { status: "done" });
    const result = store.read("task", "protected");
    assert.equal(result.data.status, "done");
  });

  it("update trims tags whitespace (M1)", () => {
    store.create("note", "trim-update");
    store.update("note", "trim-update", { tags: " a , b , c " });
    const result = store.read("note", "trim-update");
    assert.deepEqual(result.data.tags, ["a", "b", "c"]);
  });

  it("create builds fields in priority order", () => {
    store.create("task", "ordered", {
      title: "Ordered",
      area: "work",
      status: "active",
      priority: "high",
      project: "nixpi",
      custom: "val",
    });
    const result = store.read("task", "ordered");
    const keys = Object.keys(result.data);
    // type, slug should come before status, priority etc
    assert.ok(keys.indexOf("type") < keys.indexOf("status"));
    assert.ok(keys.indexOf("slug") < keys.indexOf("priority"));
    // created/modified should be last
    assert.ok(keys.indexOf("created") > keys.indexOf("custom"));
    assert.ok(keys.indexOf("modified") > keys.indexOf("custom"));
  });

  it("concurrent create of same slug fails for one caller", async () => {
    const results = await Promise.allSettled(
      Array.from({ length: 5 }, (_, i) =>
        new Promise<string>((resolve, reject) => {
          try {
            resolve(store.create("task", "race", { title: `Writer ${i}` }));
          } catch (err) {
            reject(err);
          }
        })
      )
    );
    const fulfilled = results.filter((r) => r.status === "fulfilled");
    const rejected = results.filter((r) => r.status === "rejected");
    assert.equal(fulfilled.length, 1, "exactly one create should succeed");
    assert.equal(rejected.length, 4, "remaining creates should fail");
    for (const r of rejected) {
      assert.ok((r as PromiseRejectedResult).reason.message.includes("already exists"));
    }
  });

  it("concurrent updates do not corrupt file", async () => {
    store.create("task", "cu", { title: "Concurrent", status: "active" });
    await Promise.all(
      Array.from({ length: 10 }, (_, i) =>
        new Promise<void>((resolve) => {
          store.update("task", "cu", { status: `status-${i}` });
          resolve();
        })
      )
    );
    const result = store.read("task", "cu");
    // File should still be valid and readable
    assert.equal(result.data.type, "task");
    assert.ok(String(result.data.status).startsWith("status-"));
  });

  it("concurrent link operations do not duplicate links", async () => {
    store.create("task", "lt");
    store.create("note", "ln");
    await Promise.all(
      Array.from({ length: 5 }, () =>
        new Promise<void>((resolve) => {
          store.link("task/lt", "note/ln");
          resolve();
        })
      )
    );
    const t = store.read("task", "lt");
    const links = t.data.links as string[];
    assert.equal(links.filter((l) => l === "note/ln").length, 1, "link should not be duplicated");
  });
});
