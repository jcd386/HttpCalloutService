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
    _builderContext = {};

    @api
    get inputVariables() {
        return this._inputVariables;
    }
    set inputVariables(variables) {
        this._inputVariables = variables || [];
        this._initFromInputVariables();
    }

    @api
    get builderContext() {
        return this._builderContext;
    }
    set builderContext(context) {
        this._builderContext = context || {};
    }

    // ── Local state ─────────────────────────────────────────────────
    httpMethod = 'GET';

    // Resource-capable fields: value + mode
    namedCredentialName = '';
    namedCredentialNameIsResource = false;
    endpointUrl = '';
    endpointUrlIsResource = false;
    path = '';
    pathIsResource = false;
    body = '';
    bodyIsResource = false;
    timeout = null;
    timeoutIsResource = false;

    headers = [];
    queryParams = [];
    _nextHeaderId = 1;
    _nextParamId = 1;

    // ── Getters ─────────────────────────────────────────────────────
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

    // Toggle icon getters
    get namedCredentialNameToggleIcon() {
        return this.namedCredentialNameIsResource ? 'utility:edit' : 'utility:merge_field';
    }
    get endpointUrlToggleIcon() {
        return this.endpointUrlIsResource ? 'utility:edit' : 'utility:merge_field';
    }
    get pathToggleIcon() {
        return this.pathIsResource ? 'utility:edit' : 'utility:merge_field';
    }
    get bodyToggleIcon() {
        return this.bodyIsResource ? 'utility:edit' : 'utility:merge_field';
    }
    get timeoutToggleIcon() {
        return this.timeoutIsResource ? 'utility:edit' : 'utility:merge_field';
    }

    // Available Flow resources filtered by type
    get stringResourceOptions() {
        return this._getResourceOptions('String');
    }

    get numberResourceOptions() {
        return this._getResourceOptions('Number');
    }

    _getResourceOptions(dataType) {
        const options = [];
        const bc = this._builderContext;
        if (!bc) return options;

        // Flow variables
        const variables = bc.variables || [];
        for (const v of variables) {
            if (v.dataType === dataType) {
                options.push({ label: v.name, value: v.name });
            }
        }

        // Text templates (String only)
        if (dataType === 'String') {
            const templates = bc.textTemplates || [];
            for (const t of templates) {
                options.push({ label: t.name, value: t.name });
            }
        }

        // Formulas
        const formulas = bc.formulas || [];
        for (const f of formulas) {
            if (f.dataType === dataType) {
                options.push({ label: f.name, value: f.name });
            }
        }

        // Action call outputs
        const actions = bc.actionCalls || [];
        for (const action of actions) {
            const outputs = action.outputParameters || [];
            for (const o of outputs) {
                if (o.dataType === dataType) {
                    const ref = action.name + '.' + o.name;
                    options.push({ label: ref, value: ref });
                }
            }
        }

        // Sort alphabetically
        options.sort((a, b) => a.label.localeCompare(b.label));
        return options;
    }

    // ── Initialize from Flow Builder ────────────────────────────────
    _initFromInputVariables() {
        this.httpMethod = this._getInputValue('httpMethod') || 'GET';

        // Initialize resource-capable fields
        const fields = ['namedCredentialName', 'endpointUrl', 'path', 'body', 'timeout'];
        for (const field of fields) {
            const variable = this._inputVariables.find(v => v.name === field);
            if (variable) {
                this[field] = variable.value != null ? variable.value : '';
                this[field + 'IsResource'] = variable.valueDataType === 'reference';
            }
        }

        // Headers
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

        // Query params
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

    // ── Generic field handlers (data-field driven) ──────────────────
    toggleFieldMode(event) {
        const field = event.currentTarget.dataset.field;
        const wasResource = this[field + 'IsResource'];
        this[field + 'IsResource'] = !wasResource;
        // Clear value on toggle
        const defaultVal = field === 'timeout' ? null : '';
        this[field] = defaultVal;
        this._dispatchChange(field, defaultVal, field === 'timeout' ? 'Number' : 'String');
    }

    handleFieldLiteral(event) {
        const field = event.currentTarget.dataset.field;
        let value = event.detail.value;
        if (field === 'timeout') {
            value = value ? parseInt(value, 10) : null;
        }
        this[field] = value;
        this._dispatchChange(field, value, field === 'timeout' ? 'Number' : 'String');
    }

    handleFieldResource(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.detail.value;
        this._dispatchChange(field, event.detail.value, 'reference');
    }

    // ── HTTP Method (static picklist) ───────────────────────────────
    handleHttpMethodChange(event) {
        this.httpMethod = event.detail.value;
        this._dispatchChange('httpMethod', this.httpMethod, 'String');
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
        const payload = this.headers.map(h => ({ key: h.key || '', value: h.value || '' }));
        const json = payload.length > 0 ? JSON.stringify(payload) : '';
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
        const payload = this.queryParams.map(p => ({ key: p.key || '', value: p.value || '' }));
        const json = payload.length > 0 ? JSON.stringify(payload) : '';
        this._dispatchChange('queryParamsJson', json, 'String');
    }
}
