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

        @InvocableVariable(label='Headers (JSON)'
            description='JSON string of headers: {"Authorization": "Bearer xyz"}')
        public String headers;

        @InvocableVariable(label='Body'
            description='Request body for POST/PUT/PATCH')
        public String body;

        @InvocableVariable(label='Query Parameters (JSON)'
            description='JSON string of query params: {"search": "hello", "limit": "10"}')
        public String queryParameters;

        @InvocableVariable(label='Timeout (ms)'
            description='Timeout in milliseconds (default: 30000, max: 120000)')
        public Integer timeout;
    }

    public class CalloutOutput {
        @InvocableVariable(label='Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Response Body')
        public String responseBody;

        @InvocableVariable(label='Response Headers (JSON)')
        public String responseHeaders;

        @InvocableVariable(label='Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        public CalloutOutput() {
            this.isSuccess = false;
            this.errorMessage = '';
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
    private static String buildQueryString(String queryParamsJson) {
        if (String.isBlank(queryParamsJson)) {
            return '';
        }

        try {
            Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(queryParamsJson);
            if (params.isEmpty()) {
                return '';
            }

            List<String> parts = new List<String>();
            for (String key : params.keySet()) {
                Object value = params.get(key);
                String encodedKey = EncodingUtil.urlEncode(key, 'UTF-8');
                String encodedValue = EncodingUtil.urlEncode(
                    value != null ? String.valueOf(value) : '', 'UTF-8'
                );
                parts.add(encodedKey + '=' + encodedValue);
            }

            return '?' + String.join(parts, '&');
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'HttpCalloutService: Failed to parse query parameters JSON: ' + e.getMessage());
            return '';
        }
    }

    @TestVisible
    private static void applyHeaders(HttpRequest req, String headersJson, Boolean hasBody) {
        Boolean contentTypeSet = false;

        if (String.isNotBlank(headersJson)) {
            try {
                Map<String, Object> headerMap = (Map<String, Object>) JSON.deserializeUntyped(headersJson);
                for (String key : headerMap.keySet()) {
                    String value = String.valueOf(headerMap.get(key));
                    req.setHeader(key, value);
                    if (key.equalsIgnoreCase('Content-Type')) {
                        contentTypeSet = true;
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    'HttpCalloutService: Failed to parse headers JSON: ' + e.getMessage());
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
    private static String collectResponseHeaders(HttpResponse res) {
        try {
            Map<String, String> headerMap = new Map<String, String>();
            List<String> headerKeys = res.getHeaderKeys();
            if (headerKeys != null) {
                for (String key : headerKeys) {
                    if (key != null) {
                        headerMap.put(key, res.getHeader(key));
                    }
                }
            }
            return JSON.serialize(headerMap);
        } catch (Exception e) {
            return '{}';
        }
    }
}
