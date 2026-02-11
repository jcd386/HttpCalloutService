# HttpCalloutService

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png)](https://githubsfdeploy.herokuapp.com/app/githubdeploy/jcd386/HttpCalloutService?ref=main)

A generic, Flow-invocable Apex class for performing HTTP callouts from Salesforce. Supports both Named Credentials (secure, admin-managed auth) and direct URLs for maximum flexibility.

## Features

- **Flow-Ready**: Appears as "HTTP Callout" action in Flow Builder under the Integration category
- **Named Credential Mode**: Secure, platform-managed authentication for production APIs
- **Direct URL Mode**: Flexible endpoint targeting for ad-hoc integrations (requires Remote Site Setting)
- **Configurable Headers**: Pass custom headers as a JSON string
- **Query Parameters**: Pass query params as JSON — automatically URL-encoded
- **Structured Output**: Status code, response body, response headers (JSON), success boolean, and error message
- **Bulk-Safe**: Processes multiple callout requests in a single invocation

## Apex Classes

| Class | Description |
|-------|-------------|
| `HttpCalloutService.cls` | Invocable service class with configurable HTTP callout logic |
| `HttpCalloutServiceTest.cls` | Test class with 32 tests covering all methods and error scenarios |

## Installation

### Option A: One-Click Deploy

Click the **Deploy to Salesforce** button above.

### Option B: Salesforce CLI

```bash
# Clone the repo
git clone https://github.com/jcd386/HttpCalloutService.git
cd HttpCalloutService

# Deploy to your org
sf project deploy start --target-org YOUR_ORG_ALIAS
```

## Usage

### In Flow Builder

1. Open any Flow in Flow Builder
2. Add an **Action** element
3. Search for **"HTTP Callout"** (under Integration category)
4. Configure the inputs:

### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| HTTP Method | Text | Yes | `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS` |
| Named Credential Name | Text | No | Developer name of a Named Credential (e.g., `My_API`) |
| Endpoint URL | Text | No | Full URL for direct mode (e.g., `https://api.example.com`) |
| Path | Text | No | Appended to endpoint (e.g., `/api/v1/users`) |
| Headers (JSON) | Text | No | `{"Authorization": "Bearer xyz", "Accept": "text/xml"}` |
| Body | Text | No | Request body for POST/PUT/PATCH |
| Query Parameters (JSON) | Text | No | `{"search": "hello", "limit": "10"}` |
| Timeout (ms) | Number | No | Timeout in milliseconds (default: 30000, max: 120000) |

**Note**: Either Named Credential Name or Endpoint URL is required (not both).

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| Status Code | Number | HTTP response status code (200, 401, 500, etc.) |
| Response Body | Text | Full response body |
| Response Headers (JSON) | Text | JSON string of all response headers |
| Success | Boolean | `true` if status code is 2xx |
| Error Message | Text | Error details on validation failure, exception, or non-2xx response |

### Example: Named Credential GET

```
HTTP Method:            GET
Named Credential Name:  My_External_API
Path:                   /api/v1/accounts
Query Parameters:       {"status": "active", "limit": "25"}
```

### Example: Direct URL POST

```
HTTP Method:    POST
Endpoint URL:   https://hooks.example.com/webhook
Headers:        {"Authorization": "Bearer my-token", "X-Custom": "value"}
Body:           {"event": "record.created", "id": "001xx000003ABCD"}
```

## Prerequisites

- **Named Credential Mode**: Create a Named Credential in Setup pointing to your external API
- **Direct URL Mode**: Add a Remote Site Setting in Setup for the target domain

## License

MIT

## Author

[We Summit Mountains](https://wesummitmountains.com) - Dallas-based Salesforce Consulting
