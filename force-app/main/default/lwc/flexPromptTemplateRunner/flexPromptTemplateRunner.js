import { LightningElement, api } from 'lwc';
import generateResponse from '@salesforce/apex/FlexPromptTemplateController.generateResponse';

export default class FlexPromptTemplateRunner extends LightningElement {
    // Provided automatically when the component sits on a record page.
    @api recordId;
    @api objectApiName;

    // App Builder configurable properties.
    @api cardTitle = 'Account Outreach Assistant';
    @api helpText =
        'Describe your outreach goal, then generate a tailored email grounded in this account.';
    @api buttonLabel = 'Generate Email';
    @api iconName = 'standard:email';
    @api inputLabel = 'Outreach goal';
    @api inputPlaceholder =
        'e.g. Introduce our onboarding services and request a 15-minute intro call';
    @api templateName = 'Draft_Account_Outreach';
    @api recordInputName = 'Input:Account';
    @api freeTextInputName = 'Input:Outreach_Goal';

    freeText = '';
    isLoading = false;
    isSuccess = false;
    responseText = '';
    errorMessage = '';

    get hasResult() {
        return this.isSuccess && !!this.responseText && !this.isLoading;
    }

    get hasError() {
        return !!this.errorMessage && !this.isLoading;
    }

    get formattedResponse() {
        return this.normalizeHtml(this.responseText);
    }

    handleTextChange(event) {
        this.freeText = event.target.value;
    }

    handleGenerate() {
        this.isLoading = true;
        this.isSuccess = false;
        this.responseText = '';
        this.errorMessage = '';

        generateResponse({
            templateName: this.templateName,
            recordId: this.recordId,
            recordInputName: this.recordInputName,
            freeTextValue: this.freeText,
            freeTextInputName: this.freeTextInputName
        })
            .then((result) => {
                if (result && result.isSuccess) {
                    this.isSuccess = true;
                    this.responseText = result.responseText;
                } else {
                    this.errorMessage =
                        (result && result.errorMessage) ||
                        'No response was generated.';
                }
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * The prompt template returns rich-text HTML, so it is rendered as-is by
     * lightning-formatted-rich-text (which sanitizes a safe subset of HTML).
     * We only strip a Markdown code-fence wrapper (```html ... ```) in case the
     * model wraps the markup, which would otherwise render as literal text.
     */
    normalizeHtml(text) {
        if (!text) {
            return '';
        }

        return text
            .replace(/^\s*```(?:html)?\s*/i, '')
            .replace(/\s*```\s*$/, '')
            .trim();
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        if (typeof error?.message === 'string') {
            return error.message;
        }
        return 'An unexpected error occurred while generating the response.';
    }
}