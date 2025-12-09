import { LightningElement, api, track } from 'lwc';
import markdownLib from '@salesforce/resourceUrl/markdownLib';
import bannerImage from '@salesforce/resourceUrl/AF4FINSBanner';
import { loadScript } from 'lightning/platformResourceLoader';

const LIBS = {
    loaded: false,
    loadingPromise: null
};

// Optional setup document that can be shown above the main document when the
// "Show Setup Steps" toggle is enabled.
const SETUP_RESOURCE_NAME = 'SETUP'; 

export default class MarkdownStaticResourceViewer extends LightningElement {
    /**
     * Comma-separated list of static resource names, each representing
     * a markdown+images zip that contains doc.md and an images/ folder.
     * Example: "BWAM,INS,SETUP"
     */
    @api resourceNames;

    /**
     * Optional default static resource name to load on init.
     * If not provided or not found, the first entry from resourceNames is used.
     */
    @api defaultResourceName;

    /**
     * Controls whether the document picker combobox is shown.
     * Note: For Boolean @api properties, avoid initializing to true here to satisfy LWC linting.
     * The effective default is handled in the getter below (and via the meta.xml default).
     */
    @api showDocumentPicker;

    @track currentResourceName;
    @track error;
    @track isLoading = false;
    @track showSetupSteps = true;

    resourceList = [];
    htmlCacheByResource = {};

    // Static banner shown above the document picker to match workshop branding
    bannerUrl = bannerImage;

    // Cached rendered HTML fragments
    _renderedHtml;
    _setupHtml;

    connectedCallback() {
        this.initialiseResources();
    }

    renderedCallback() {
        this.renderHtmlToDom();
    }

    get showPicker() {
        // Always show the selector when requested and there is at least one document
        return !!this.showDocumentPicker && this.resourceList.length > 0;
    }

    get resourceOptions() {
        return this.resourceList.map((name) => ({
            label: name,
            value: name
        }));
    }

    get resourceRadioOptions() {
        // Map specific static resources to friendly labels for this workshop.
        const labelMap = {
            BWAM: 'Banking & Wealth',
            INS: 'Insurance'
        };

        return this.resourceList.map((name) => ({
            label: labelMap[name] || name,
            value: name
        }));
    }

    async initialiseResources() {
        this.error = undefined;

        // Use a sensible default when no resource names are provided via @api.
        // This ensures the workshop docs (BWAM and INS) are available out of the box.
        const rawNames =
            this.resourceNames && this.resourceNames.trim()
                ? this.resourceNames
                : 'BWAM,INS';

        this.resourceList = this.parseResourceNames(rawNames);

        if (!this.resourceList.length) {
            this.error = 'No static resource names provided. Set the resourceNames @api property (comma-separated list).';
            return;
        }

        // Determine the initial resource to load
        if (this.defaultResourceName && this.resourceList.includes(this.defaultResourceName)) {
            this.currentResourceName = this.defaultResourceName;
        } else {
            [this.currentResourceName] = this.resourceList;
        }

        try {
            await this.ensureLibrariesLoaded();
            await this.loadCurrentDocument();
            if (this.showSetupSteps) {
                await this.loadSetupDocument();
            }
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Error initialising markdown viewer', e);
            this.error = 'Unable to initialise markdown viewer.';
        }
    }

    parseResourceNames(names) {
        if (!names) {
            return [];
        }

        return names
            .split(',')
            .map((name) => name.trim())
            .filter((name) => !!name);
    }

    async ensureLibrariesLoaded() {
        if (LIBS.loaded) {
            return;
        }

        if (LIBS.loadingPromise) {
            return LIBS.loadingPromise;
        }

        LIBS.loadingPromise = Promise.all([
            // Markdown parsing & sanitization
            loadScript(this, `${markdownLib}/marked.min.js`),
            loadScript(this, `${markdownLib}/dompurify.min.js`)
        ])
            .then(() => {
                LIBS.loaded = true;
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error('Error loading markdown libraries', e);
                throw new Error('Failed to load markdown libraries from static resource markdownLib.');
            });

        return LIBS.loadingPromise;
    }

    async loadCurrentDocument() {
        if (!this.currentResourceName) {
            return;
        }

        const resourceName = this.currentResourceName;
        this.isLoading = true;
        this.error = undefined;

        try {
            const cachedHtml = this.htmlCacheByResource[resourceName];
            if (cachedHtml) {
                this.setRenderedHtml(resourceName, cachedHtml);
                return;
            }

            const markdown = await this.fetchMarkdown(resourceName);
            const processedMarkdown = this.rewriteImagePaths(markdown, resourceName);
            const html = this.renderMarkdownToHtml(processedMarkdown);
            const safeHtml = this.sanitizeHtml(html);

            this.htmlCacheByResource[resourceName] = safeHtml;
            this.setRenderedHtml(resourceName, safeHtml);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Error loading markdown document for resource', resourceName, e.message);
            this.error = `Unable to load markdown document from static resource ${resourceName}.`;
        } finally {
            this.isLoading = false;
        }
    }

    async fetchMarkdown(resourceName) {
        // Use same-origin static resource URL to avoid CORS issues.
        // Add a cache-buster query param so that browser/CDN caches don't serve
        // an outdated version of the static resource after it has been updated.
        const cacheBuster = Date.now();
        const url = `/resource/${resourceName}/doc.md?cb=${cacheBuster}`;
        const response = await fetch(url);

        if (!response.ok) {
            throw new Error(`Failed to load markdown from ${url} (status ${response.status})`);
        }
        return response.text();
    }

    rewriteImagePaths(markdown, resourceName) {
        if (!markdown || !resourceName) {
            return markdown;
        }

        // Replace relative markdown image references like ](images/...) or ](./images/...)
        const markdownImageRegex = /\]\(\s*(\.\/)?images\//g;
        const markdownReplacementPrefix = `](/resource/${resourceName}/images/`;

        let result = markdown.replace(markdownImageRegex, markdownReplacementPrefix);

        // Also rewrite raw HTML <img src="images/..."> or <img src="./images/...">
        const htmlImgRegex = /<img([^>]*?)src=(["'])\s*(\.\/)?images\//gi;
        const htmlReplacement = `<img$1src=$2/resource/${resourceName}/images/`;
        result = result.replace(htmlImgRegex, htmlReplacement);

        return result;
    }

    // This returns raw HTML; caller must sanitize before injecting into DOM
    // eslint-disable-next-line class-methods-use-this
    renderMarkdownToHtml(markdown) {
        if (!markdown) {
            return '';
        }

        // In newer versions of marked, the global may be either a function or an
        // object with a .parse() function. Support both shapes.
        const markedGlobal = window.marked;

        if (typeof markedGlobal === 'function') {
            return markedGlobal(markdown);
        }

        if (markedGlobal && typeof markedGlobal.parse === 'function') {
            return markedGlobal.parse(markdown);
        }

        // eslint-disable-next-line no-console
        console.error('Unexpected shape for window.marked global:', markedGlobal);
        throw new Error('Markdown library (marked) is not available or has an unexpected shape.');
    }

    // eslint-disable-next-line class-methods-use-this
    sanitizeHtml(html) {
        if (!html) {
            return '';
        }

        // eslint-disable-next-line no-undef
        if (window.DOMPurify) {
            // eslint-disable-next-line no-undef
            return window.DOMPurify.sanitize(html, { USE_PROFILES: { html: true } });
        }

        // If DOMPurify is not available for some reason, fall back to the raw HTML,
        // but log an error so this can be diagnosed.
        // eslint-disable-next-line no-console
        console.error('DOMPurify is not available; returning unsanitized HTML.');
        return html;
    }

    setRenderedHtml(resourceName, html) {
        this.currentResourceName = resourceName;
        this._renderedHtml = html;
        this.renderHtmlToDom();
    }

    async loadSetupDocument() {
        const resourceName = SETUP_RESOURCE_NAME;

        try {
            await this.ensureLibrariesLoaded();

            const cachedHtml = this.htmlCacheByResource[resourceName];
            if (cachedHtml) {
                this._setupHtml = cachedHtml;
                this.renderHtmlToDom();
                return;
            }

            const markdown = await this.fetchMarkdown(resourceName);
            const processedMarkdown = this.rewriteImagePaths(markdown, resourceName);
            const html = this.renderMarkdownToHtml(processedMarkdown);
            const safeHtml = this.sanitizeHtml(html);

            this.htmlCacheByResource[resourceName] = safeHtml;
            this._setupHtml = safeHtml;
            this.renderHtmlToDom();
        } catch (e) {
            // Setup markdown is optional; fail silently if it isn't available.
            // eslint-disable-next-line no-console
            console.warn('Optional SETUP markdown document could not be loaded', e.message);
        }
    }

    renderHtmlToDom() {
        // Render optional setup document (if any) into its container.
        const setupContainer = this.template.querySelector('.setup-body');
        if (setupContainer) {
            // eslint-disable-next-line lwc/no-inner-html
            setupContainer.innerHTML = this._setupHtml || '';
        }

        if (this._renderedHtml) {
            const container = this.template.querySelector('.main-body');
            if (container) {
                // Directly set innerHTML because we have sanitized via DOMPurify
                // eslint-disable-next-line lwc/no-inner-html
                container.innerHTML = this._renderedHtml;
            }
        }
    }

    handleResourceChange(event) {
        const newResource = event.detail.value;
        if (newResource && newResource !== this.currentResourceName) {
            this.currentResourceName = newResource;
            this.loadCurrentDocument();
        }
    }

    handleShowSetupChange(event) {
        this.showSetupSteps = event.target.checked;

        if (this.showSetupSteps) {
            this.loadSetupDocument();
        } else {
            this._setupHtml = '';
            this.renderHtmlToDom();
        }
    }

    /**
     * Returns a human-friendly label for the currently selected resource,
     * matching the labels used in the radio group where possible.
     */
    get currentResourceLabel() {
        const labelMap = {
            BWAM: 'Banking & Wealth',
            INS: 'Insurance'
        };

        if (!this.currentResourceName) {
            return '';
        }

        return labelMap[this.currentResourceName] || this.currentResourceName;
    }

    /**
     * Build a minimal, print-friendly HTML document string that contains the
     * already-rendered markdown HTML for the current guide (and optional setup
     * steps). This is written directly into a new browser window or tab.
     */
    getPrintableHtml() {
        const hasSetup = this.showSetupSteps && this._setupHtml;
        const hasMain = this._renderedHtml;

        if (!hasSetup && !hasMain) {
            return '';
        }

        const titleParts = ['Workshop Guide'];
        if (this.currentResourceLabel) {
            titleParts.push(this.currentResourceLabel);
        }
        const title = titleParts.join(' - ');

        const styles = `
            :root {
                color-scheme: light;
            }

            body {
                margin: 1.25rem;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                font-size: 14px;
                line-height: 1.5;
                color: #080707;
            }

            .print-header {
                margin-bottom: 1rem;
                border-bottom: 1px solid #d8dde6;
                padding-bottom: 0.5rem;
            }

            .print-header h1 {
                font-size: 1.6rem;
                margin: 0;
            }

            .setup-section {
                margin-bottom: 1rem;
            }

            h1, h2, h3, h4, h5, h6 {
                font-weight: 600;
                margin-top: 1.25rem;
                margin-bottom: 0.5rem;
                color: #181818;
            }

            h1 { font-size: 1.7rem; }
            h2 { font-size: 1.5rem; }
            h3, h4, h5, h6 { font-size: 1rem; }

            p {
                margin: 0 0 0.5rem;
            }

            ul, ol {
                margin: 0.25rem 0 0.75rem 1.25rem;
                padding-left: 1rem;
            }

            ul { list-style-type: disc; }
            ol { list-style-type: decimal; }

            li {
                margin: 0.125rem 0;
            }

            a {
                color: #0070d2;
                text-decoration: underline;
            }

            img {
                display: block;
                margin: 1rem auto;
                max-width: 100%;
                height: auto;
            }

            code {
                font-family: SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
                font-size: 0.8rem;
                background-color: #f3f2f2;
                padding: 0.1rem 0.25rem;
                border-radius: 0.25rem;
            }

            pre {
                font-family: SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
                font-size: 0.8rem;
                background-color: #f3f2f2;
                padding: 0.75rem;
                border-radius: 0.25rem;
                overflow: auto;
            }

            pre code {
                background-color: transparent;
                padding: 0;
            }

            blockquote {
                margin: 0.75rem 0;
                padding: 0.5rem 0.75rem;
                border-left: 4px solid #d8dde6;
                color: #3e3e3c;
                background-color: #f3f2f2;
            }

            hr {
                border: 0;
                border-top: 1px solid #d8dde6;
                margin: 1rem 0;
            }

            table {
                border-collapse: collapse;
                border-spacing: 0;
                margin: 0.75rem 0 1rem;
                width: 100%;
            }

            th {
                padding: 5pt;
                border-width: 1pt;
                border-style: solid;
                border-color: rgb(204, 204, 204);
                background-color: rgb(109, 52, 183);
                color: #ffffff;
                font-weight: 600;
                text-align: left;
            }

            td {
                padding: 5pt;
                border-width: 1pt;
                border-style: solid;
                border-color: rgb(204, 204, 204);
                vertical-align: top;
            }

            @page {
                margin: 16mm;
            }

            @media print {
                body {
                    margin: 0;
                }
            }
        `;

        const setupSection = hasSetup
            ? `<section class="setup-section">${this._setupHtml}</section><hr />`
            : '';
        const mainSection = hasMain
            ? `<section class="main-section">${this._renderedHtml}</section>`
            : '';

        return `
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <title>${title}</title>
    <style>${styles}</style>
</head>
<body>
    <header class="print-header">
        <h1>${title}</h1>
    </header>
    ${setupSection}
    ${mainSection}
</body>
</html>
        `;
    }

    /**
     * Open a Visualforce page that renders the current guide content in a
     * print-friendly layout. The VF page re-fetches the markdown using the same
     * static resources, keyed by the current resource name and setup toggle.
     */
    handlePrintClick() {
        if (!this.currentResourceName) {
            return;
        }

        const showSetup = this.showSetupSteps ? '1' : '0';
        const resourceParam = encodeURIComponent(this.currentResourceName);
        const url = `/apex/MarkdownGuidePrint?resource=${resourceParam}&showSetup=${showSetup}`;
        window.open(url, '_blank');
    }
}


