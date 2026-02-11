# HttpCalloutService

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png)](https://githubsfdeploy.herokuapp.com/app/githubdeploy/jcd386/HttpCalloutService?ref=main)

A generic, Flow-invocable Apex class for performing HTTP callouts from Salesforce. Supports both Named Credentials (secure, admin-managed auth) and direct URLs for maximum flexibility.

## Features

- **Flow-Ready**: Appears as "HTTP Callout" action in Flow Builder under the Integration category
- **Named Credential Mode**: Secure, platform-managed authentication for production APIs
- **Direct URL Mode**: Flexible endpoint targeting for ad-hoc integrations (requires Remote Site Setting)
- **Inline Headers & Query Params**: Up to 5 headers and 5 query parameters configured directly in the action UI — no collections, variables, or JSON required
- **Structured Output**: Status code, response body, response headers (JSON), success boolean, and error message
- **Bulk-Safe**: Processes multiple callout requests in a single invocation

## Apex Classes

| Class | Description |
|-------|-------------|
| `HttpCalloutService.cls` | Invocable service class with configurable HTTP callout logic |
| `HttpCalloutServiceTest.cls` | Test class with 54 tests covering all methods and error scenarios |

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
4. Configure the inputs — headers and query parameters are filled in directly as fields (no collections needed)

### Inputs

#### Core Fields

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| HTTP Method | Text | Yes | `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS` |
| Named Credential Name | Text | No | Developer name of a Named Credential (e.g., `My_API`) |
| Endpoint URL | Text | No | Full URL for direct mode (e.g., `https://api.example.com`) |
| Path | Text | No | Appended to endpoint (e.g., `/api/v1/users`) |
| Body | Text | No | Request body for POST/PUT/PATCH |
| Timeout (ms) | Number | No | Timeout in milliseconds (default: 30000, max: 120000) |

**Note**: Either Named Credential Name or Endpoint URL is required (not both).

#### Headers (up to 5)

| Input | Type | Description |
|-------|------|-------------|
| Header 1 Key | Text | Name of the first request header (e.g., `Authorization`) |
| Header 1 Value | Text | Value of the first request header (e.g., `Bearer xyz`) |
| Header 2 Key | Text | Name of the second request header |
| Header 2 Value | Text | Value of the second request header |
| Header 3 Key | Text | Name of the third request header |
| Header 3 Value | Text | Value of the third request header |
| Header 4 Key | Text | Name of the fourth request header |
| Header 4 Value | Text | Value of the fourth request header |
| Header 5 Key | Text | Name of the fifth request header |
| Header 5 Value | Text | Value of the fifth request header |

Only fill in the header slots you need. Blank key fields are ignored.

#### Query Parameters (up to 5)

| Input | Type | Description |
|-------|------|-------------|
| Query Param 1 Key | Text | Name of the first query parameter |
| Query Param 1 Value | Text | Value of the first query parameter |
| Query Param 2 Key | Text | Name of the second query parameter |
| Query Param 2 Value | Text | Value of the second query parameter |
| Query Param 3 Key | Text | Name of the third query parameter |
| Query Param 3 Value | Text | Value of the third query parameter |
| Query Param 4 Key | Text | Name of the fourth query parameter |
| Query Param 4 Value | Text | Value of the fourth query parameter |
| Query Param 5 Key | Text | Name of the fifth query parameter |
| Query Param 5 Value | Text | Value of the fifth query parameter |

Query parameter values are automatically URL-encoded. Only fill in the slots you need.

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| Status Code | Number | HTTP response status code (200, 401, 500, etc.) |
| Response Body | Text | Full response body |
| Response Headers JSON | Text | All response headers as a JSON string (e.g., `{"Content-Type":"application/json"}`) |
| Success | Boolean | `true` if status code is 2xx |
| Error Message | Text | Error details on validation failure, exception, or non-2xx response |

### Example: Named Credential GET with Query Params

```
HTTP Method:            GET
Named Credential Name:  My_External_API
Path:                   /api/v1/accounts
Query Param 1 Key:      status
Query Param 1 Value:    active
Query Param 2 Key:      limit
Query Param 2 Value:    25
```

### Example: Direct URL POST with Headers

```
HTTP Method:        POST
Endpoint URL:       https://hooks.example.com/webhook
Header 1 Key:       Authorization
Header 1 Value:     Bearer my-token
Header 2 Key:       X-Custom
Header 2 Value:     value
Body:               {"event": "record.created", "id": "001xx000003ABCD"}
```

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
