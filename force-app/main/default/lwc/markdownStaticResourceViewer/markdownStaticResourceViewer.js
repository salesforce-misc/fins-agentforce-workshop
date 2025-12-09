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

        // Replace relative image references like ](images/...) or ](./images/...)
        const imageRegex = /\]\(\s*(\.\/)?images\//g;
        const replacementPrefix = `](/resource/${resourceName}/images/`;
        return markdown.replace(imageRegex, replacementPrefix);
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
}


