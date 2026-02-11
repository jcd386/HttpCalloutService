/**
 * @description Generic HTTP callout service for Flow and Apex consumption.
 *              Supports both Named Credentials (recommended) and direct URLs.
 *              Provides flexible header, query parameter, and body configuration.
 *
 * USAGE MODES:
 * - Named Credential Mode: Provide namedCredentialName for secure, managed auth
 * - Direct URL Mode: Provide endpointUrl (requires Remote Site Setting)
 *
 * @author We Summit Mountains
 * @date 2026
 */
public with sharing class HttpCalloutService {

    // ─────────────────────────────────────────────────────────────────────────
    // CONSTANTS
    // ─────────────────────────────────────────────────────────────────────────

    @TestVisible private static final Integer DEFAULT_TIMEOUT = 30000;
    @TestVisible private static final Integer MAX_TIMEOUT = 120000;
    @TestVisible private static final String DEFAULT_CONTENT_TYPE = 'application/json';
    @TestVisible private static final Set<String> VALID_METHODS = new Set<String>{
        'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'
    };
    @TestVisible private static final Set<String> BODY_METHODS = new Set<String>{
        'POST', 'PUT', 'PATCH'
    };

    // ─────────────────────────────────────────────────────────────────────────
    // INNER CLASSES - Apex-Defined Data Types
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Key-value pair for headers and query parameters.
     *              In Flow Builder, create variables of this type and add them
     *              to a collection to pass multiple headers or query params.
     */
    public class KeyValuePair {
        @InvocableVariable(required=true label='Key'
            description='Header name or query parameter name')
        public String key;

        @InvocableVariable(required=true label='Value'
            description='Header value or query parameter value')
        public String value;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INNER CLASSES - Input/Output Wrappers
    // ─────────────────────────────────────────────────────────────────────────

    public class CalloutInput {
        @InvocableVariable(required=true label='HTTP Method'
            description='HTTP method: GET, POST, PUT, PATCH, DELETE')
        public String httpMethod;

        @InvocableVariable(label='Named Credential Name'
            description='Developer name of a Named Credential (secure mode)')
        public String namedCredentialName;

        @InvocableVariable(label='Endpoint URL'
            description='Full URL for direct mode (requires Remote Site Setting)')
        public String endpointUrl;

        @InvocableVariable(label='Path'
            description='Path appended to endpoint (e.g., /api/v1/users)')
        public String path;

        @InvocableVariable(label='Headers'
            description='Collection of KeyValuePair records for request headers')
        public List<KeyValuePair> headers;

        @InvocableVariable(label='Body'
            description='Request body for POST/PUT/PATCH')
        public String body;

        @InvocableVariable(label='Query Parameters'
            description='Collection of KeyValuePair records for URL query parameters')
        public List<KeyValuePair> queryParameters;

        @InvocableVariable(label='Timeout (ms)'
            description='Timeout in milliseconds (default: 30000, max: 120000)')
        public Integer timeout;
    }

    public class CalloutOutput {
        @InvocableVariable(label='Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Response Body')
        public String responseBody;

        @InvocableVariable(label='Response Headers')
        public List<KeyValuePair> responseHeaders;

        @InvocableVariable(label='Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        public CalloutOutput() {
            this.isSuccess = false;
            this.errorMessage = '';
            this.responseHeaders = new List<KeyValuePair>();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INVOCABLE METHOD
    // ─────────────────────────────────────────────────────────────────────────

    @InvocableMethod(
        label='HTTP Callout'
        description='Perform an HTTP callout with Named Credential or direct URL'
        category='Integration'
    )
    public static List<CalloutOutput> executeCallout(List<CalloutInput> inputs) {
        List<CalloutOutput> outputs = new List<CalloutOutput>();
        for (CalloutInput input : inputs) {
            outputs.add(processCallout(input));
        }
        return outputs;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE METHODS
    // ─────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static CalloutOutput processCallout(CalloutInput input) {
        // Validate input
        String validationError = validateInput(input);
        if (validationError != null) {
            return buildErrorOutput(validationError);
        }

        try {
            // Build the request
            HttpRequest req = new HttpRequest();

            // Set endpoint
            String endpoint = buildEndpoint(input);
            String queryString = buildQueryString(input.queryParameters);
            req.setEndpoint(endpoint + queryString);

            // Set method
            req.setMethod(input.httpMethod.toUpperCase());

            // Set timeout
            Integer timeoutMs = (input.timeout != null && input.timeout > 0 && input.timeout <= MAX_TIMEOUT)
                ? input.timeout
                : DEFAULT_TIMEOUT;
            req.setTimeout(timeoutMs);

            // Apply headers
            applyHeaders(req, input.headers, String.isNotBlank(input.body));

            // Set body for applicable methods
            if (String.isNotBlank(input.body) && BODY_METHODS.contains(input.httpMethod.toUpperCase())) {
                req.setBody(input.body);
            }

            // Execute callout
            HttpResponse res = new Http().send(req);

            // Build output from response
            return buildOutput(res);

        } catch (System.CalloutException e) {
            return buildErrorOutput('Callout failed: ' + e.getMessage());
        } catch (Exception e) {
            return buildErrorOutput('Unexpected error: ' + e.getMessage());
        }
    }

    @TestVisible
    private static String validateInput(CalloutInput input) {
        if (String.isBlank(input.httpMethod)) {
            return 'HTTP Method is required';
        }

        String method = input.httpMethod.toUpperCase();
        if (!VALID_METHODS.contains(method)) {
            return 'Invalid HTTP method: ' + input.httpMethod +
                '. Valid methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS';
        }

        if (String.isBlank(input.namedCredentialName) && String.isBlank(input.endpointUrl)) {
            return 'Either Named Credential Name or Endpoint URL is required';
        }

        return null;
    }

    @TestVisible
    private static String buildEndpoint(CalloutInput input) {
        String endpoint;

        if (String.isNotBlank(input.namedCredentialName)) {
            String ncName = input.namedCredentialName.trim();
            endpoint = ncName.startsWithIgnoreCase('callout:') ? ncName : 'callout:' + ncName;
        } else {
            endpoint = input.endpointUrl.trim();
        }

        // Append path if provided
        if (String.isNotBlank(input.path)) {
            String pathToAppend = input.path.trim();
            if (!pathToAppend.startsWith('/')) {
                pathToAppend = '/' + pathToAppend;
            }
            // Remove trailing slash from endpoint to avoid double slashes
            if (endpoint.endsWith('/')) {
                endpoint = endpoint.substring(0, endpoint.length() - 1);
            }
            endpoint += pathToAppend;
        }

        return endpoint;
    }

    @TestVisible
    private static String buildQueryString(List<KeyValuePair> queryParams) {
        if (queryParams == null || queryParams.isEmpty()) {
            return '';
        }

        List<String> parts = new List<String>();
        for (KeyValuePair param : queryParams) {
            if (String.isNotBlank(param.key)) {
                String encodedKey = EncodingUtil.urlEncode(param.key, 'UTF-8');
                String encodedValue = EncodingUtil.urlEncode(
                    param.value != null ? param.value : '', 'UTF-8'
                );
                parts.add(encodedKey + '=' + encodedValue);
            }
        }

        return parts.isEmpty() ? '' : '?' + String.join(parts, '&');
    }

    @TestVisible
    private static void applyHeaders(HttpRequest req, List<KeyValuePair> headers, Boolean hasBody) {
        Boolean contentTypeSet = false;

        if (headers != null && !headers.isEmpty()) {
            for (KeyValuePair header : headers) {
                if (String.isNotBlank(header.key)) {
                    req.setHeader(header.key, header.value != null ? header.value : '');
                    if (header.key.equalsIgnoreCase('Content-Type')) {
                        contentTypeSet = true;
                    }
                }
            }
        }

        // Default Content-Type for requests with a body
        if (hasBody && !contentTypeSet) {
            req.setHeader('Content-Type', DEFAULT_CONTENT_TYPE);
        }
    }

    @TestVisible
    private static CalloutOutput buildOutput(HttpResponse res) {
        CalloutOutput output = new CalloutOutput();
        output.statusCode = res.getStatusCode();
        output.responseBody = res.getBody();
        output.isSuccess = (res.getStatusCode() >= 200 && res.getStatusCode() < 300);
        output.responseHeaders = collectResponseHeaders(res);

        if (!output.isSuccess) {
            output.errorMessage = 'HTTP ' + res.getStatusCode() + ': ' + res.getStatus();
        }

        return output;
    }

    @TestVisible
    private static CalloutOutput buildErrorOutput(String errorMessage) {
        CalloutOutput output = new CalloutOutput();
        output.isSuccess = false;
        output.errorMessage = errorMessage;
        return output;
    }

    @TestVisible
    private static List<KeyValuePair> collectResponseHeaders(HttpResponse res) {
        List<KeyValuePair> headerList = new List<KeyValuePair>();
        try {
            List<String> headerKeys = res.getHeaderKeys();
            if (headerKeys != null) {
                for (String key : headerKeys) {
                    if (key != null) {
                        KeyValuePair kvp = new KeyValuePair();
                        kvp.key = key;
                        kvp.value = res.getHeader(key);
                        headerList.add(kvp);
                    }
                }
            }
        } catch (Exception e) {
            // Return empty list on error
        }
        return headerList;
    }
}
