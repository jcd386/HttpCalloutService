/**
 * @description Generic HTTP callout service for Flow and Apex consumption.
 *              Supports both Named Credentials (recommended) and direct URLs.
 *              Headers and query parameters are passed as JSON arrays.
 *              Includes a Custom Property Editor (httpCalloutEditor) for
 *              a clean Flow Builder experience with dynamic add/remove rows.
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
    // INNER CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Simple key-value pair for JSON deserialization of headers
     *              and query parameters.
     */
    public class KeyValuePair {
        public String key;
        public String value;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INNER CLASSES - Input/Output Wrappers
    // ─────────────────────────────────────────────────────────────────────────

    public class CalloutInput {
        @InvocableVariable(required=true label='HTTP Method'
            description='HTTP method: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS')
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

        @InvocableVariable(label='Body'
            description='Request body for POST/PUT/PATCH')
        public String body;

        @InvocableVariable(label='Timeout (ms)'
            description='Timeout in milliseconds (default: 30000, max: 120000)')
        public Integer timeout;

        @InvocableVariable(label='Headers JSON'
            description='JSON array of key-value pairs: [{"key":"Authorization","value":"Bearer xyz"}]')
        public String headersJson;

        @InvocableVariable(label='Query Params JSON'
            description='JSON array of key-value pairs: [{"key":"status","value":"active"}]')
        public String queryParamsJson;
    }

    public class CalloutOutput {
        @InvocableVariable(label='Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Response Body')
        public String responseBody;

        @InvocableVariable(label='Response Headers JSON')
        public String responseHeaders;

        @InvocableVariable(label='Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        public CalloutOutput() {
            this.isSuccess = false;
            this.errorMessage = '';
            this.responseHeaders = '{}';
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INVOCABLE METHOD
    // ─────────────────────────────────────────────────────────────────────────

    @InvocableMethod(
        label='HTTP Callout'
        description='Perform an HTTP callout with Named Credential or direct URL'
        category='Integration'
        configurationEditor='c-http-callout-editor'
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
        String validationError = validateInput(input);
        if (validationError != null) {
            return buildErrorOutput(validationError);
        }

        try {
            HttpRequest req = new HttpRequest();

            // Set endpoint
            String endpoint = buildEndpoint(input);
            String queryString = buildQueryString(collectQueryParams(input));
            req.setEndpoint(endpoint + queryString);

            // Set method
            req.setMethod(input.httpMethod.toUpperCase());

            // Set timeout
            Integer timeoutMs = (input.timeout != null && input.timeout > 0 && input.timeout <= MAX_TIMEOUT)
                ? input.timeout
                : DEFAULT_TIMEOUT;
            req.setTimeout(timeoutMs);

            // Apply headers
            Map<String, String> headers = collectHeaders(input);
            applyHeaders(req, headers, String.isNotBlank(input.body));

            // Set body for applicable methods
            if (String.isNotBlank(input.body) && BODY_METHODS.contains(input.httpMethod.toUpperCase())) {
                req.setBody(input.body);
            }

            // Execute callout
            HttpResponse res = new Http().send(req);

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
            if (endpoint.endsWith('/')) {
                endpoint = endpoint.substring(0, endpoint.length() - 1);
            }
            endpoint += pathToAppend;
        }

        return endpoint;
    }

    @TestVisible
    private static Map<String, String> collectHeaders(CalloutInput input) {
        Map<String, String> headers = new Map<String, String>();
        if (String.isNotBlank(input.headersJson)) {
            try {
                List<KeyValuePair> pairs = (List<KeyValuePair>) JSON.deserialize(
                    input.headersJson, List<KeyValuePair>.class
                );
                for (KeyValuePair pair : pairs) {
                    if (String.isNotBlank(pair.key)) {
                        headers.put(pair.key, pair.value != null ? pair.value : '');
                    }
                }
            } catch (Exception e) {
                // Invalid JSON — return empty headers rather than failing
            }
        }
        return headers;
    }

    @TestVisible
    private static Map<String, String> collectQueryParams(CalloutInput input) {
        Map<String, String> params = new Map<String, String>();
        if (String.isNotBlank(input.queryParamsJson)) {
            try {
                List<KeyValuePair> pairs = (List<KeyValuePair>) JSON.deserialize(
                    input.queryParamsJson, List<KeyValuePair>.class
                );
                for (KeyValuePair pair : pairs) {
                    if (String.isNotBlank(pair.key)) {
                        params.put(pair.key, pair.value != null ? pair.value : '');
                    }
                }
            } catch (Exception e) {
                // Invalid JSON — return empty params rather than failing
            }
        }
        return params;
    }

    @TestVisible
    private static String buildQueryString(Map<String, String> queryParams) {
        if (queryParams == null || queryParams.isEmpty()) {
            return '';
        }

        List<String> parts = new List<String>();
        for (String key : queryParams.keySet()) {
            String encodedKey = EncodingUtil.urlEncode(key, 'UTF-8');
            String encodedValue = EncodingUtil.urlEncode(queryParams.get(key), 'UTF-8');
            parts.add(encodedKey + '=' + encodedValue);
        }

        return parts.isEmpty() ? '' : '?' + String.join(parts, '&');
    }

    @TestVisible
    private static void applyHeaders(HttpRequest req, Map<String, String> headers, Boolean hasBody) {
        Boolean contentTypeSet = false;

        if (headers != null && !headers.isEmpty()) {
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
                if (key.equalsIgnoreCase('Content-Type')) {
                    contentTypeSet = true;
                }
            }
        }

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
        output.responseHeaders = serializeResponseHeaders(res);

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
    private static String serializeResponseHeaders(HttpResponse res) {
        Map<String, String> headerMap = new Map<String, String>();
        try {
            List<String> headerKeys = res.getHeaderKeys();
            if (headerKeys != null) {
                for (String key : headerKeys) {
                    if (key != null) {
                        headerMap.put(key, res.getHeader(key));
                    }
                }
            }
        } catch (Exception e) {
            // Return empty JSON on error
        }
        return JSON.serialize(headerMap);
    }
}
