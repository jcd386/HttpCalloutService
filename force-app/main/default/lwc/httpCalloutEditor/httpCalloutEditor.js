import { LightningElement, api } from 'lwc';

const HTTP_METHOD_OPTIONS = [
    { label: 'GET', value: 'GET' },
    { label: 'POST', value: 'POST' },
    { label: 'PUT', value: 'PUT' },
    { label: 'PATCH', value: 'PATCH' },
    { label: 'DELETE', value: 'DELETE' },
    { label: 'HEAD', value: 'HEAD' },
    { label: 'OPTIONS', value: 'OPTIONS' }
];

export default class HttpCalloutEditor extends LightningElement {

    // ── Flow Builder CPE API ────────────────────────────────────────
    _inputVariables = [];

    @api
    get inputVariables() {
        return this._inputVariables;
    }
    set inputVariables(variables) {
        this._inputVariables = variables || [];
        this._initFromInputVariables();
    }

    // ── Local state ─────────────────────────────────────────────────
    httpMethod = 'GET';
    namedCredentialName = '';
    endpointUrl = '';
    path = '';
    body = '';
    timeout = null;
    headers = [];
    queryParams = [];

    _nextHeaderId = 1;
    _nextParamId = 1;

    get httpMethodOptions() {
        return HTTP_METHOD_OPTIONS;
    }

    get showBodyField() {
        return ['POST', 'PUT', 'PATCH'].includes(this.httpMethod);
    }

    get hasHeaders() {
        return this.headers.length > 0;
    }

    get hasQueryParams() {
        return this.queryParams.length > 0;
    }

    // ── Initialize from Flow Builder ────────────────────────────────
    _initFromInputVariables() {
        this.httpMethod = this._getInputValue('httpMethod') || 'GET';
        this.namedCredentialName = this._getInputValue('namedCredentialName') || '';
        this.endpointUrl = this._getInputValue('endpointUrl') || '';
        this.path = this._getInputValue('path') || '';
        this.body = this._getInputValue('body') || '';

        const timeoutVal = this._getInputValue('timeout');
        this.timeout = timeoutVal != null && timeoutVal !== '' ? timeoutVal : null;

        const headersJsonVal = this._getInputValue('headersJson');
        if (headersJsonVal) {
            try {
                const parsed = JSON.parse(headersJsonVal);
                this.headers = parsed.map(item => ({
                    id: this._nextHeaderId++,
                    key: item.key || '',
                    value: item.value || ''
                }));
            } catch (e) {
                this.headers = [];
            }
        } else {
            this.headers = [];
        }

        const paramsJsonVal = this._getInputValue('queryParamsJson');
        if (paramsJsonVal) {
            try {
                const parsed = JSON.parse(paramsJsonVal);
                this.queryParams = parsed.map(item => ({
                    id: this._nextParamId++,
                    key: item.key || '',
                    value: item.value || ''
                }));
            } catch (e) {
                this.queryParams = [];
            }
        } else {
            this.queryParams = [];
        }
    }

    _getInputValue(name) {
        const variable = this._inputVariables.find(v => v.name === name);
        return variable ? variable.value : null;
    }

    // ── Dispatch change to Flow Builder ─────────────────────────────
    _dispatchChange(name, newValue, newValueDataType) {
        this.dispatchEvent(new CustomEvent(
            'configuration_editor_input_value_changed',
            {
                bubbles: true,
                cancelable: false,
                composed: true,
                detail: { name, newValue, newValueDataType }
            }
        ));
    }

    // ── Core field handlers ─────────────────────────────────────────
    handleHttpMethodChange(event) {
        this.httpMethod = event.detail.value;
        this._dispatchChange('httpMethod', this.httpMethod, 'String');
    }

    handleNamedCredentialChange(event) {
        this.namedCredentialName = event.detail.value;
        this._dispatchChange('namedCredentialName', this.namedCredentialName, 'String');
    }

    handleEndpointUrlChange(event) {
        this.endpointUrl = event.detail.value;
        this._dispatchChange('endpointUrl', this.endpointUrl, 'String');
    }

    handlePathChange(event) {
        this.path = event.detail.value;
        this._dispatchChange('path', this.path, 'String');
    }

    handleBodyChange(event) {
        this.body = event.detail.value;
        this._dispatchChange('body', this.body, 'String');
    }

    handleTimeoutChange(event) {
        const val = event.detail.value;
        this.timeout = val ? parseInt(val, 10) : null;
        this._dispatchChange('timeout', this.timeout, 'Number');
    }

    // ── Header handlers ─────────────────────────────────────────────
    handleAddHeader() {
        this.headers = [...this.headers, { id: this._nextHeaderId++, key: '', value: '' }];
    }

    handleRemoveHeader(event) {
        const idToRemove = parseInt(event.currentTarget.dataset.id, 10);
        this.headers = this.headers.filter(h => h.id !== idToRemove);
        this._dispatchHeadersJson();
    }

    handleHeaderKeyChange(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        this.headers = this.headers.map(h =>
            h.id === id ? { ...h, key: event.detail.value } : h
        );
        this._dispatchHeadersJson();
    }

    handleHeaderValueChange(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        this.headers = this.headers.map(h =>
            h.id === id ? { ...h, value: event.detail.value } : h
        );
        this._dispatchHeadersJson();
    }

    _dispatchHeadersJson() {
        const filtered = this.headers
            .filter(h => h.key && h.key.trim() !== '')
            .map(h => ({ key: h.key, value: h.value || '' }));
        const json = filtered.length > 0 ? JSON.stringify(filtered) : '';
        this._dispatchChange('headersJson', json, 'String');
    }

    // ── Query param handlers ────────────────────────────────────────
    handleAddQueryParam() {
        this.queryParams = [...this.queryParams, { id: this._nextParamId++, key: '', value: '' }];
    }

    handleRemoveQueryParam(event) {
        const idToRemove = parseInt(event.currentTarget.dataset.id, 10);
        this.queryParams = this.queryParams.filter(p => p.id !== idToRemove);
        this._dispatchQueryParamsJson();
    }

    handleParamKeyChange(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        this.queryParams = this.queryParams.map(p =>
            p.id === id ? { ...p, key: event.detail.value } : p
        );
        this._dispatchQueryParamsJson();
    }

    handleParamValueChange(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        this.queryParams = this.queryParams.map(p =>
            p.id === id ? { ...p, value: event.detail.value } : p
        );
        this._dispatchQueryParamsJson();
    }

    _dispatchQueryParamsJson() {
        const filtered = this.queryParams
            .filter(p => p.key && p.key.trim() !== '')
            .map(p => ({ key: p.key, value: p.value || '' }));
        const json = filtered.length > 0 ? JSON.stringify(filtered) : '';
        this._dispatchChange('queryParamsJson', json, 'String');
    }
}
