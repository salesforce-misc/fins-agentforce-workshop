## Markdown Static Resource Viewer (LWC)

This project contains a Lightning Web Component, `markdownStaticResourceViewer`, that renders workshop-style documentation from zipped static resources.  
Each static resource represents a mini documentation site with a `doc.md` file and an `images/` folder, which are converted to safe HTML at runtime using the `markdownLib` static resource (Marked + DOMPurify).

The repo also includes a small build pipeline for generating zip-based static resources from expanded folders under `src-static/`.

---

## Project Structure

- **LWC component**
  - `force-app/main/default/lwc/markdownStaticResourceViewer/`
    - `markdownStaticResourceViewer.js` – Loads markdown from static resources, rewrites image URLs, sanitizes HTML, and renders content.
    - `markdownStaticResourceViewer.html` – UI layout with banner, document selector, and setup-toggle.
    - `markdownStaticResourceViewer.css` – Styling for viewer, banner, and markdown body.

- **Static resources**
  - `force-app/main/default/staticresources/`
    - `BWAM.resource`, `INS.resource`, `SETUP.resource` – Workshop docs (zipped `doc.md` + `images/`).
    - `markdownLib.zip` / `markdownLib.resource-meta.xml` – Bundled `marked.min.js` and `dompurify.min.js`.

- **Source for docs (unpacked)**
  - `src-static/`
    - `BWAM/`, `INS/`, `SETUP/` – Each contains `doc.md` and an `images/` folder.

- **Utility scripts**
  - `scripts/build-staticresources.sh` – Zips each directory under `src-static/` into a `<Name>.resource` file and generates default metadata if missing.

---

## Prerequisites

- Node.js and npm (LTS recommended).
- Salesforce CLI (`sf`) installed and authenticated.
- A Salesforce org (scratch org, sandbox, or dev org) where you can deploy this project.

---

## Installation

From the project root:

```bash
npm install
```

---

## Building Static Resources from `src-static/`

When you update any markdown or images under `src-static/`, regenerate the zip-based static resources:

```bash
npm run build:staticresources
```

This will:

- Zip each folder under `src-static/` into `force-app/main/default/staticresources/<Name>.resource`.
- Create a matching `<Name>.resource-meta.xml` if it does not already exist.

Commit the updated `.resource` and `.resource-meta.xml` files if you intend to deploy them to another org.

---

## Deploying to a Salesforce Org (sf CLI)

1. **Authenticate to your target org (once per machine/user):**

   ```bash
   sf org login web --set-default --alias markdown-lwc
   ```

2. **(Optional but recommended) Rebuild static resources after making doc changes:**

   ```bash
   npm run build:staticresources
   ```

3. **Deploy the metadata:**

   ```bash
   sf project deploy start --source-dir force-app --target-org markdown-lwc
   ```

---

## Using `markdownStaticResourceViewer` in the Org

`markdownStaticResourceViewer` is designed to be used on Lightning App Builder pages (e.g., a Utility Bar item, a Home page, or a custom app page).

### Key `@api` Properties

- **`resourceNames`**  
  Comma-separated list of static resource names that each contain:
  - `doc.md` – Markdown content.
  - `images/` – Any referenced images.
  - Example: `"BWAM,INS,SETUP"`.

- **`defaultResourceName`**  
  Optional static resource name to load initially.  
  If not provided or not found, the first entry in `resourceNames` is used.

- **`showDocumentPicker`**  
  Boolean flag that controls whether the document picker (radio group) is shown.  
  When enabled and at least one resource is available, the component renders a radio-based selector with friendly labels for known resources (e.g., BWAM → “Banking & Wealth”, INS → “Insurance”).

### Setup Document Toggle

- The component can display an optional setup guide above the selected document by loading a static resource named `SETUP`.
- The “Show Setup Steps” toggle lets the user show or hide this content at runtime.

### Image and Markdown Handling

- Markdown is fetched at runtime from `/resource/<StaticResourceName>/doc.md` with a cache-busting query parameter to avoid stale content.
- Relative image references such as:

  ```markdown
  ![Screenshot](images/example.png)
  ```

  are automatically rewritten to:

  ```text
  /resource/<StaticResourceName>/images/example.png
  ```

- Markdown is converted to HTML using Marked and sanitized with DOMPurify before being injected into the DOM.

---

## Adding or Updating Documentation Bundles

To add a new documentation bundle:

1. Create a new folder under `src-static/` named after the static resource you want, for example:

   ```text
   src-static/NEWGUIDE/
     doc.md
     images/
       screenshot-1.png
   ```

2. Write your content in `doc.md`, using standard Markdown and relative image paths like `images/...`.

3. Build the static resources:

   ```bash
   npm run build:staticresources
   ```

4. Deploy to your org:

   ```bash
   sf project deploy start --source-dir force-app --target-org markdown-lwc
   ```

5. Configure the component in Lightning App Builder and include `NEWGUIDE` in the `resourceNames` property.

---

## Local Development, Linting, and Tests

- **Run Jest unit tests for LWC:**

  ```bash
  npm test
  ```

- **Run linting:**

  ```bash
  npm run lint
  ```

- **Format code (Prettier):**

  ```bash
  npm run prettier
  ```

Husky and `lint-staged` are configured to help keep commits formatted and linted when using Git hooks.

---

## Notes

- The project uses API version `65.0` (see `sfdx-project.json`).
- The `markdownLib` static resource must contain `marked.min.js` and `dompurify.min.js` at its root for the component to load the libraries correctly.
