# OpenCode Server and OCX Scripting Integration Report

## 1. Executive Summary

This report details the investigation into the scripting capabilities of `opencode` and the role of the `ocx` wrapper. The research confirms that `opencode` provides robust options for automation, primarily through its headless server and JSON-formatted CLI output. `ocx` currently functions as a straightforward Docker passthrough, presenting an opportunity to introduce higher-level abstractions that would significantly simplify scripting for end-users. This report outlines the existing capabilities and proposes specific enhancements for `ocx`.

## 2. `opencode` Scripting Capabilities

`opencode` offers three primary mechanisms for scripting and programmatic integration:

### 2.1. `opencode run` Command

-   **Simple Execution:** `opencode run "<prompt>"` provides a direct way to execute a prompt and receive a formatted text response. This is suitable for simple, one-off scripting tasks.
-   **JSON Output:** The `--format json` flag transforms the output into a stream of newline-delimited JSON (nd-JSON) objects. This is ideal for programmatic parsing and integration into more complex scripts and applications.

### 2.2. `opencode serve` Command

-   **Headless Server:** This command runs a headless HTTP server, exposing a comprehensive OpenAPI 3.1 documented API.
-   **Powerful Integration:** The API provides full control over `opencode` functionalities, including session management, message submission, command execution, and file system interaction. This is the most powerful and flexible method for building complex integrations and custom clients.

### 2.3. `opencode acp` Command

-   **Agent Client Protocol:** This command starts a server that communicates over `stdin`/`stdout` using nd-JSON. It is designed for deep, inter-process communication between `opencode` and other tools or agents.

## 3. `ocx` Current Role and Functionality

-   **Docker Wrapper:** `ocx` is a Nushell script that acts as a secure wrapper around a containerized `opencode` instance.
-   **Command Passthrough:** The `ocx opencode [...args]` command directly passes all arguments to the `opencode` binary running inside the Docker container.
-   **Conclusion:** While `ocx` simplifies running `opencode` in an isolated environment, it does not currently offer any abstractions to simplify the scripting process. A user scripting `ocx` is effectively scripting `opencode` directly, with the added layer of Docker.

## 4. Deep Dive: `opencode run --format json` Output Schema

A detailed analysis of the `opencode` source code (`run.ts` and SDK type definitions) reveals the following structure for the nd-JSON output.

### 4.1. General Structure

Each JSON object in the stream is an event with the following base structure:

```json
{
  "type": "event_type",
  "timestamp": 1672531200000,
  "sessionID": "session_id_string",
  ...event_specific_data
}
```

### 4.2. Event Types and Schemas

The investigation identified the following key event types:

-   **`tool_use`**: Indicates an agent is using a tool. The `part` object contains the full `ToolPart` schema, detailing the tool name, its current status (`pending`, `running`, `completed`, `error`), input parameters, and output.
-   **`text`**: Represents the final text output from the language model. The `part` object conforms to the `TextPart` schema.
-   **`step_start` / `step_finish`**: Mark the beginning and end of an agent's reasoning step, containing `StepStartPart` and `StepFinishPart` schemas respectively.
-   **`error`**: Fired when a `session.error` event occurs. The `error` object contains a detailed error structure.

### 4.3. Error Handling and Schema

-   Errors are streamed as a dedicated `error` event within the JSON stream.
-   The process will exit with a non-zero status code (`1`) after streaming the error event.
-   The error object's schema is well-defined and can be one of the following types: `ProviderAuthError`, `UnknownError`, `MessageOutputLengthError`, `MessageAbortedError`, or `ApiError`.

## 5. Proposed Enhancements for `ocx`

To improve the scripting experience, `ocx` could be enhanced with features that abstract away the complexities of Docker and the `opencode` API.

-   **Server Management:** Introduce `ocx server <start|stop|status|logs>` commands to manage the `opencode serve` process within the container, making it trivial to run a persistent `opencode` backend.
-   **Simplified Client Interface:** Add an `ocx client` command set to interact with the managed server. This would provide a much simpler interface for scripting than making raw `curl` requests.
    -   `ocx client prompt "your prompt"`
    -   `ocx client command /some_command "with args"`
-   **Configuration:** Enhance `ocx.json` to allow for easier configuration of the server and other scripting-related settings.

By implementing these features, `ocx` can evolve from a simple wrapper into a powerful tool that facilitates sophisticated automation and integration with `opencode`.
