import { LightningElement, api } from 'lwc';
import generateResponse from '@salesforce/apex/PromptTemplateController.generateResponse';

export default class PromptTemplateRunner extends LightningElement {
    // Provided automatically when the component sits on a record page.
    @api recordId;
    @api objectApiName;

    // App Builder configurable properties.
    @api cardTitle = 'Account Summary';
    @api helpText = 'Generate an AI summary of this record.';
    @api buttonLabel = 'Generate Summary';
    @api iconName = 'standard:account';
    @api templateName = 'Account_Summary';
    @api inputParameterName = 'Input:Account';

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

    get showIntro() {
        return !this.isLoading && !this.hasResult && !this.hasError;
    }

    get formattedResponse() {
        return this.normalizeHtml(this.responseText);
    }

    handleGenerate() {
        this.isLoading = true;
        this.isSuccess = false;
        this.responseText = '';
        this.errorMessage = '';

        generateResponse({
            templateName: this.templateName,
            recordId: this.recordId,
            inputParameterName: this.inputParameterName
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