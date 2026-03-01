/**
 * Scenario-based Pi response mock.
 *
 * Pattern-matching replacement for processMessage() — no subprocess needed.
 */

export interface PiScenario {
  /** Name for logging/debugging. */
  name: string;
  /** Pattern to match against input text. */
  match: RegExp | string;
  /** Response to return when matched. */
  response: string;
}

export interface PiMockCall {
  input: string;
  matchedScenario: string | null;
  response: string;
  timestamp: number;
}

export class ScenarioBasedPiMock {
  /** All invocations logged in order. */
  calls: PiMockCall[] = [];

  private scenarios: PiScenario[];
  private defaultResponse: string;

  constructor(scenarios: PiScenario[], defaultResponse = "(no response)") {
    this.scenarios = scenarios;
    this.defaultResponse = defaultResponse;
  }

  /** Find first matching scenario and return its response. */
  respond(text: string): string {
    for (const scenario of this.scenarios) {
      const matches =
        typeof scenario.match === "string"
          ? text.includes(scenario.match)
          : scenario.match.test(text);

      if (matches) {
        const call: PiMockCall = {
          input: text,
          matchedScenario: scenario.name,
          response: scenario.response,
          timestamp: Date.now(),
        };
        this.calls.push(call);
        return scenario.response;
      }
    }

    // No match — use default
    const call: PiMockCall = {
      input: text,
      matchedScenario: null,
      response: this.defaultResponse,
      timestamp: Date.now(),
    };
    this.calls.push(call);
    return this.defaultResponse;
  }

  /** Reset all recorded calls. */
  reset(): void {
    this.calls = [];
  }
}
