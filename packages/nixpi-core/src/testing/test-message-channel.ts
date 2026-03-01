/**
 * In-process fake of the MessageChannel interface for testing.
 *
 * No network, no timers — pure in-memory message passing.
 */
import type { IncomingMessage, MessageChannel } from "../types.js";

export interface SentMessage {
  to: string;
  text: string;
  timestamp: number;
}

export class TestMessageChannel implements MessageChannel {
  readonly name = "test";

  /** All messages sent via sendMessage(), in order. */
  sent: SentMessage[] = [];

  private handler?: (msg: IncomingMessage) => Promise<string>;
  private connected = false;
  private connectError?: Error;

  /** Make connect() throw the given error (for error-path testing). */
  setConnectError(err: Error): void {
    this.connectError = err;
  }

  onMessage(handler: (msg: IncomingMessage) => Promise<string>): void {
    this.handler = handler;
  }

  async sendMessage(to: string, text: string): Promise<void> {
    if (!this.connected) {
      throw new Error("Cannot send message: not connected");
    }
    this.sent.push({ to, text, timestamp: Date.now() });
  }

  async connect(): Promise<void> {
    if (this.connectError) {
      throw this.connectError;
    }
    if (!this.handler) {
      throw new Error("onMessage must be called before connect()");
    }
    this.connected = true;
  }

  async disconnect(): Promise<void> {
    this.connected = false;
  }

  /**
   * Simulate an incoming message from `from` with the given `text`.
   * Invokes the registered handler and returns its response.
   * @throws If no handler is registered or not connected.
   */
  async simulateMessage(from: string, text: string): Promise<string> {
    if (!this.handler) {
      throw new Error("No message handler registered");
    }
    if (!this.connected) {
      throw new Error("Channel is not connected");
    }
    const msg: IncomingMessage = {
      from,
      text,
      timestamp: Date.now(),
      channel: "test",
    };
    return this.handler(msg);
  }

  /** Reset all state (sent messages, handler, connection). */
  reset(): void {
    this.sent = [];
    this.handler = undefined;
    this.connected = false;
    this.connectError = undefined;
  }
}
