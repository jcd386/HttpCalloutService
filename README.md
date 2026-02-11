# HttpCalloutService

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png)](https://githubsfdeploy.herokuapp.com/app/githubdeploy/jcd386/HttpCalloutService?ref=main)

A generic, Flow-invocable Apex class for performing HTTP callouts from Salesforce. Supports both Named Credentials (secure, admin-managed auth) and direct URLs for maximum flexibility.

## Features

- **Flow-Ready**: Appears as "HTTP Callout" action in Flow Builder under the Integration category
- **Custom Property Editor**: Dynamic UI with add/remove rows for headers and query parameters — no fixed limits
- **Named Credential Mode**: Secure, platform-managed authentication for production APIs
- **Direct URL Mode**: Flexible endpoint targeting for ad-hoc integrations (requires Remote Site Setting)
- **Structured Output**: Status code, response body, response headers (JSON), success boolean, and error message
- **Bulk-Safe**: Processes multiple callout requests in a single invocation

## Components

| Component | Type | Description |
|-----------|------|-------------|
| `HttpCalloutService.cls` | Apex Class | Invocable service class with configurable HTTP callout logic |
| `HttpCalloutServiceTest.cls` | Test Class | 63 tests covering all methods and error scenarios |
| `httpCalloutEditor` | LWC | Custom Property Editor for dynamic header/param configuration in Flow Builder |

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

### Namespace Note

If your org has a **custom namespace** (e.g., `myns`), update the `configurationEditor` value in `HttpCalloutService.cls` from `c-http-callout-editor` to `myns-http-callout-editor` before deploying.

## Usage

### In Flow Builder

1. Open any Flow in Flow Builder
2. Add an **Action** element
3. Search for **"HTTP Callout"** (under Integration category)
4. The Custom Property Editor loads with a clean UI for configuring the callout:
   - Select HTTP method from a dropdown
   - Enter Named Credential name or direct URL
   - Add/remove header rows dynamically
   - Add/remove query parameter rows dynamically

### Inputs

#### Core Fields

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| HTTP Method | Text | Yes | `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS` |
| Named Credential Name | Text | No | Developer name of a Named Credential (e.g., `My_API`) |
| Endpoint URL | Text | No | Full URL for direct mode (e.g., `https://api.example.com`) |
| Path | Text | No | Appended to endpoint (e.g., `/api/v1/users`) |
| Body | Text | No | Request body (shown only for POST/PUT/PATCH) |
| Timeout (ms) | Number | No | Timeout in milliseconds (default: 30000, max: 120000) |

**Note**: Either Named Credential Name or Endpoint URL is required (not both).

#### Headers

Add as many request headers as needed using the **Add Header** button. Each row has a Key and Value field. Remove rows with the delete button. Empty keys are ignored.

#### Query Parameters

Add as many query parameters as needed using the **Add Parameter** button. Values are automatically URL-encoded. Empty keys are ignored.

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| Status Code | Number | HTTP response status code (200, 401, 500, etc.) |
| Response Body | Text | Full response body |
| Response Headers JSON | Text | All response headers as a JSON string (e.g., `{"Content-Type":"application/json"}`) |
| Success | Boolean | `true` if status code is 2xx |
| Error Message | Text | Error details on validation failure, exception, or non-2xx response |

### Example: Named Credential GET with Query Params

In Flow Builder, configure the action:
- **HTTP Method**: GET
- **Named Credential Name**: My_External_API
- **Path**: /api/v1/accounts
- **Query Parameters**: Click "Add Parameter" twice, then enter:
  - Row 1: Key = `status`, Value = `active`
  - Row 2: Key = `limit`, Value = `25`

### Example: Direct URL POST with Headers

- **HTTP Method**: POST
- **Endpoint URL**: https://hooks.example.com/webhook
- **Headers**: Click "Add Header" twice, then enter:
  - Row 1: Key = `Authorization`, Value = `Bearer my-token`
  - Row 2: Key = `X-Custom`, Value = `value`
- **Body**: `{"event": "record.created", "id": "001xx000003ABCD"}`

## Setting Up Named Credentials

Named Credentials are the recommended way to manage authentication. The modern architecture (API 50+) uses a three-layer model: **External Credential** (auth config) > **Named Credential** (endpoint URL) > **Permission Set** (user access).

### Step 1: Create an External Credential

1. Go to **Setup** > search **"Named Credentials"** > click the **External Credentials** tab
2. Click **New**
3. Fill in the fields:
   - **Label**: e.g., `My API External Cred`
   - **Name**: e.g., `My_API_External_Cred` (auto-populated)
   - **Authentication Protocol**: Choose based on your API:

| Protocol | Use When |
|----------|----------|
| **Custom** | API key in a header, static Bearer token, or any custom auth header |
| **OAuth 2.0** | Standard OAuth (Client Credentials, Authorization Code, JWT Bearer) |
| **AWS Signature Version 4** | AWS APIs |

4. Click **Save**

### Step 2: Create a Principal

A principal defines **whose credentials** are used when making the callout.

1. On your External Credential record, scroll to the **Principals** section
2. Click **New**
3. Choose a principal type:

| Type | Description |
|------|-------------|
| **Named Principal** | Single shared credential for all users (e.g., a service account API key). Best for org-wide integrations. |
| **Per-User Principal** | Each user authenticates individually (e.g., per-user OAuth tokens). Best for user-context APIs. |

4. **For Custom protocol (API Key / Bearer Token)**:
   - After saving the principal, scroll to **Authentication Parameters**
   - Click **New** and add your credentials:
     - **Parameter Type**: Choose `Header` (for auth headers) or `Query Parameter`
     - **Name**: e.g., `Authorization`
     - **Value**: e.g., `Bearer your-api-key-here`
   - Add additional parameters as needed (e.g., `X-Api-Key`)

5. **For OAuth 2.0**:
   - Configure the Identity Provider, Client ID, Client Secret, Token Endpoint, and Scopes on the External Credential
   - The principal will handle token refresh automatically

### Step 3: Create the Named Credential

1. Go to **Setup** > **Named Credentials** > **Named Credentials** tab
2. Click **New**
3. Fill in:
   - **Label**: e.g., `My API`
   - **Name**: e.g., `My_API` (this is what you pass to `namedCredentialName` in Flow)
   - **URL**: The base URL of the API (e.g., `https://api.example.com`)
   - **External Credential**: Select the External Credential from Step 1
   - **Generate Authorization Header**: Check this if the External Credential should automatically add auth headers
4. Click **Save**

### Step 4: Grant Access via Permission Set

Users need explicit permission to use the External Credential. This is managed through **Permission Sets** (not profiles — best practice).

1. Go to **Setup** > **Permission Sets**
2. Create a new Permission Set or open an existing one
   - **Label**: e.g., `My API Access`
3. In the Permission Set, find **External Credential Principal Access**
4. Click **Edit**
5. Move your principal (e.g., `My_API_External_Cred - Named Principal`) from **Available** to **Enabled**
6. Click **Save**
7. **Assign the Permission Set** to the users or profiles that need access:
   - Permission Set > **Manage Assignments** > **Add Assignment** > select users

### Step 5: Per-User Principal Setup (if applicable)

If you chose **Per-User Principal**, each user must also provide their own credentials:

1. Users go to **Personal Settings** > **External Credentials** (or an admin can manage via the **User External Credentials** related list on the User record)
2. Click **New** or **Edit** next to the credential
3. Enter their individual authentication parameters (e.g., their personal API key or trigger an OAuth flow)

### Verifying Your Setup

To verify everything is configured correctly:

1. Open **Developer Console** or **Execute Anonymous**:
   ```apex
   HttpRequest req = new HttpRequest();
   req.setEndpoint('callout:My_API/api/v1/health');
   req.setMethod('GET');
   HttpResponse res = new Http().send(req);
   System.debug(res.getStatusCode() + ': ' + res.getBody());
   ```
2. If you get a `401` or `403`, check:
   - Permission Set is assigned to the running user
   - External Credential Principal Access is enabled on the Permission Set
   - Authentication parameters are correct on the principal

## Direct URL Mode Prerequisites

If using direct URLs instead of Named Credentials:

1. Go to **Setup** > search **"Remote Site Settings"**
2. Click **New Remote Site**
3. Enter the base URL of the external API (e.g., `https://api.example.com`)
4. Click **Save**

## License

MIT

## Author

[We Summit Mountains](https://wesummitmountains.com) - Dallas-based Salesforce Consulting
