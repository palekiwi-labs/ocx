# `opencode run --format json` Detailed Report

## 1. Overview

When using the `opencode run` command with the `--format json` flag, the output is a stream of newline-delimited JSON (nd-JSON) objects. Each object represents an event that occurred during the execution of the command. This format is designed for programmatic consumption, allowing scripts and applications to easily parse and react to the events in real-time.

## 2. General JSON Object Structure

Every JSON object in the output stream follows a consistent base structure:

```json
{
  "type": "string",
  "timestamp": "number",
  "sessionID": "string"
}
```

-   **`type`**: A string that identifies the type of event.
-   **`timestamp`**: A number representing the time the event occurred, in milliseconds since the Unix epoch.
-   **`sessionID`**: A string that uniquely identifies the session in which the event occurred.

In addition to these base fields, each event type includes a data payload that is specific to that event.

## 3. Event Types and Schemas

The following are the key event types and their associated data schemas.

### 3.1. `text` Event

This event represents the final text output from the language model.

-   **`type`**: `"text"`
-   **`part`**: A `TextPart` object with the following structure:
    ```json
    {
      "id": "string",
      "sessionID": "string",
      "messageID": "string",
      "type": "text",
      "text": "string",
      "time": {
        "start": "number",
        "end": "number"
      }
    }
    ```

### 3.2. `tool_use` Event

This event is emitted when an agent uses a tool.

-   **`type`**: `"tool_use"`
-   **`part`**: A `ToolPart` object that includes the tool's state. The `state` object can have one of the following statuses: `pending`, `running`, `completed`, or `error`.
    -   When `status` is `completed`, the structure is:
        ```json
        {
          "status": "completed",
          "input": "object",
          "output": "string",
          "title": "string",
          "time": {
            "start": "number",
            "end": "number"
          }
        }
        ```

### 3.3. `step_start` and `step_finish` Events

These events mark the beginning and end of an agent's reasoning step.

-   **`type`**: `"step_start"` or `"step_finish"`
-   **`part`**: A `StepStartPart` or `StepFinishPart` object, respectively.

### 3.4. `error` Event

This event is emitted when an error occurs during the session.

-   **`type`**: `"error"`
-   **`error`**: An object containing the error details. The structure of this object varies depending on the type of error.

## 4. Error Handling and Schemas

When an error occurs, an `error` event is emitted, and the process exits with a non-zero status code (`1`). The `error` object can have one of the following schemas:

-   **`ProviderAuthError`**: Authentication error with the provider.
-   **`UnknownError`**: A generic, unknown error.
-   **`MessageOutputLengthError`**: The output of the message exceeded the maximum length.
-   **`MessageAbortedError`**: The message was aborted.
-   **`ApiError`**: An error occurred while making an API request.

This detailed breakdown of the JSON response format provides the necessary information to build robust scripts and applications that integrate with `opencode`.
