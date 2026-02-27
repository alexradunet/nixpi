import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { JsYamlFrontmatterParser } from "../frontmatter.js";

const parser = new JsYamlFrontmatterParser();

describe("JsYamlFrontmatterParser", () => {
  describe("parse", () => {
    it("parses frontmatter and body", () => {
      const raw = "---\ntitle: Hello\nslug: hello\n---\n# Hello\n";
      const result = parser.parse(raw);
      assert.equal(result.data.title, "Hello");
      assert.equal(result.data.slug, "hello");
      assert.equal(result.content, "# Hello\n");
    });

    it("parses arrays in frontmatter", () => {
      const raw = "---\ntags:\n  - nix\n  - devops\nlinks:\n  - task/foo\n---\nbody\n";
      const result = parser.parse(raw);
      assert.deepEqual(result.data.tags, ["nix", "devops"]);
      assert.deepEqual(result.data.links, ["task/foo"]);
      assert.equal(result.content, "body\n");
    });

    it("returns raw content when no frontmatter", () => {
      const raw = "Just some text without frontmatter.";
      const result = parser.parse(raw);
      assert.deepEqual(result.data, {});
      assert.equal(result.content, raw);
    });

    it("handles empty frontmatter", () => {
      const raw = "---\n---\nbody content\n";
      const result = parser.parse(raw);
      assert.deepEqual(result.data, {});
      assert.equal(result.content, "body content\n");
    });

    it("handles empty body", () => {
      const raw = "---\ntype: note\n---\n";
      const result = parser.parse(raw);
      assert.equal(result.data.type, "note");
      assert.equal(result.content, "");
    });

    it("does not match --- inside body content (H5)", () => {
      const raw = "---\ntitle: Test\n---\nSome text\n---\nMore text after dashes\n";
      const result = parser.parse(raw);
      assert.equal(result.data.title, "Test");
      assert.equal(result.content, "Some text\n---\nMore text after dashes\n");
    });

    it("keeps ISO timestamp strings as strings, not Date objects (H6)", () => {
      const raw = "---\ncreated: '2026-01-15T10:30:00Z'\nmodified: '2026-02-20T08:00:00Z'\n---\n";
      const result = parser.parse(raw);
      assert.equal(typeof result.data.created, "string");
      assert.equal(result.data.created, "2026-01-15T10:30:00Z");
      assert.equal(typeof result.data.modified, "string");
      assert.equal(result.data.modified, "2026-02-20T08:00:00Z");
    });

    it("handles CRLF line endings", () => {
      const raw = "---\r\ntitle: CRLF\r\n---\r\nbody\r\n";
      const result = parser.parse(raw);
      assert.equal(result.data.title, "CRLF");
      assert.ok(result.content.includes("body"));
    });

    it("returns empty data for unclosed frontmatter", () => {
      const raw = "---\ntitle: Unclosed\nno closing delimiter";
      const result = parser.parse(raw);
      assert.deepEqual(result.data, {});
      assert.equal(result.content, raw);
    });
  });

  describe("stringify", () => {
    it("produces valid frontmatter document", () => {
      const data = { type: "task", slug: "foo" };
      const content = "# Foo\n";
      const result = parser.stringify(data, content);
      assert.ok(result.startsWith("---\n"));
      assert.ok(result.includes("type: task"));
      assert.ok(result.includes("slug: foo"));
      assert.ok(result.endsWith("---\n# Foo\n"));
    });

    it("serializes arrays as YAML lists", () => {
      const data = { tags: ["a", "b"] };
      const result = parser.stringify(data, "");
      assert.ok(result.includes("tags:"));
      assert.ok(result.includes("  - a"));
      assert.ok(result.includes("  - b"));
    });
  });

  describe("round-trip", () => {
    it("parse(stringify(data, content)) preserves values", () => {
      const data = {
        type: "journal",
        slug: "2026-01-01",
        title: "New Year",
        tags: ["reflection", "goals"],
        links: ["task/plan-year"],
      };
      const content = "\n# New Year\n\nReflections on the year.\n";

      const serialized = parser.stringify(data, content);
      const parsed = parser.parse(serialized);

      assert.equal(parsed.data.type, "journal");
      assert.equal(parsed.data.slug, "2026-01-01");
      assert.equal(parsed.data.title, "New Year");
      assert.deepEqual(parsed.data.tags, ["reflection", "goals"]);
      assert.deepEqual(parsed.data.links, ["task/plan-year"]);
      assert.equal(parsed.content, content);
    });

    it("ISO timestamp round-trip stays string (H6)", () => {
      const data = {
        type: "note",
        slug: "ts-test",
        created: "2026-01-15T10:30:00Z",
        modified: "2026-02-20T08:00:00Z",
      };
      const content = "";

      const serialized = parser.stringify(data, content);
      const parsed = parser.parse(serialized);

      assert.equal(typeof parsed.data.created, "string");
      assert.equal(parsed.data.created, "2026-01-15T10:30:00Z");
      assert.equal(typeof parsed.data.modified, "string");
      assert.equal(parsed.data.modified, "2026-02-20T08:00:00Z");

      // Second round-trip should be identical
      const serialized2 = parser.stringify(parsed.data, parsed.content);
      assert.equal(serialized, serialized2);
    });
  });
});
