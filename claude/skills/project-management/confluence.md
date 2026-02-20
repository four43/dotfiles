# Confluence API Reference

REST API v2 at `https://vaisala.atlassian.net/wiki/api/v2/`
REST API v1 at `https://vaisala.atlassian.net/wiki/rest/api/` (fallback for labels, attachments)

Auth: Build a base64 header — do NOT use curl's `-u` flag (breaks with special chars in env vars):

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
# Then on every request:
-H "Authorization: Basic ${AUTH}" -H "Content-Type: application/json"
```

V2 is preferred. Fall back to v1 when v2 doesn't cover an operation.

## Pages

### Get page by ID

```
GET /wiki/api/v2/pages/{id}
```

Query params:
- `body-format` - `storage` (XHTML) or `atlas_doc_format` (ADF JSON). Required to include body.
- `version` - specific version number

### List pages in a space

```
GET /wiki/api/v2/pages?space-id={spaceId}&status=current&sort=modified-date
```

Query params:
- `space-id` - space ID (required unless using other filters)
- `title` - exact title match
- `status` - `current`, `trashed`, `draft`
- `sort` - `id`, `title`, `created-date`, `-created-date`, `modified-date`, `-modified-date`
- `limit` - max results (default 25)
- `cursor` - pagination cursor from `_links.next`

### Create page

```
POST /wiki/api/v2/pages
```

```json
{
  "spaceId": "12345",
  "status": "current",
  "title": "Page Title",
  "parentId": "67890",
  "body": {
    "representation": "storage",
    "value": "<p>Page content in XHTML storage format</p>"
  }
}
```

`parentId` is optional - omit to create at the space root.

### Update page

```
PUT /wiki/api/v2/pages/{id}
```

```json
{
  "id": "12345",
  "status": "current",
  "title": "Updated Title",
  "body": {
    "representation": "storage",
    "value": "<p>Updated content</p>"
  },
  "version": {
    "number": 2,
    "message": "Updated via API"
  }
}
```

Version number must increment from the current version. Get the page first to find the current version number.

### Delete page

```
DELETE /wiki/api/v2/pages/{id}
```

Moves to trash. Use `?purge=true` to permanently delete (admin only).

### Get page children

```
GET /wiki/api/v2/pages/{id}/children
```

## Spaces

### List spaces

```
GET /wiki/api/v2/spaces
```

Query params:
- `keys` - comma-separated space keys (e.g. `DEV,TEAM`)
- `type` - `global` or `personal`
- `status` - `current` or `archived`
- `sort` - `id`, `key`, `name`, `-id`, `-key`, `-name`
- `limit` - max results

### Get space by ID

```
GET /wiki/api/v2/spaces/{id}
```

## Search

### Search with CQL (v1)

The v1 search endpoint is more powerful for full-text search.

```
GET /wiki/rest/api/search?cql={cql}&limit=10
```

CQL examples:
- `type = page AND space = "DEV" AND title ~ "search term"` - Search page titles in space
- `type = page AND text ~ "search term"` - Full text search
- `type = page AND label = "my-label"` - Pages with label
- `type = page AND ancestor = 12345` - Pages under a parent
- `type = page AND space = "DEV" AND lastModified > now("-7d")` - Recently modified

Query params:
- `cql` - Confluence Query Language string (URL-encoded)
- `limit` - max results
- `start` - offset for pagination
- `expand` - `content.body.storage` to include body content
- `excerpt` - `highlight` or `none`

Response includes `results[].content.id`, `results[].title`, `results[].url`, `results[].excerpt`.

### Search pages (v2)

Simpler but less flexible:

```
GET /wiki/api/v2/pages?title=Exact+Title&space-id=12345
```

Only supports exact title match. Use v1 CQL search for fuzzy/full-text.

## Comments

### Get page footer comments

```
GET /wiki/api/v2/pages/{id}/footer-comments
```

Query params:
- `body-format` - `storage` or `atlas_doc_format`
- `sort` - `created-date` or `-created-date`
- `limit` - max results

### Create footer comment

```
POST /wiki/api/v2/footer-comments
```

```json
{
  "pageId": "12345",
  "body": {
    "representation": "storage",
    "value": "<p>Comment text</p>"
  }
}
```

### Create inline comment

```
POST /wiki/api/v2/inline-comments
```

```json
{
  "pageId": "12345",
  "body": {
    "representation": "storage",
    "value": "<p>Inline comment text</p>"
  },
  "inlineCommentProperties": {
    "textSelection": "text to annotate",
    "textSelectionMatchCount": 1,
    "textSelectionMatchIndex": 0
  }
}
```

### Get inline comments

```
GET /wiki/api/v2/pages/{id}/inline-comments
```

### Update comment

```
PUT /wiki/api/v2/footer-comments/{comment-id}
PUT /wiki/api/v2/inline-comments/{comment-id}
```

```json
{
  "version": { "number": 2 },
  "body": {
    "representation": "storage",
    "value": "<p>Updated comment</p>"
  }
}
```

### Delete comment

```
DELETE /wiki/api/v2/footer-comments/{comment-id}
DELETE /wiki/api/v2/inline-comments/{comment-id}
```

## Labels (v1 only)

V2 only supports reading labels. Use v1 for add/remove.

### Get labels

```
GET /wiki/rest/api/content/{id}/label
```

### Add labels

```
POST /wiki/rest/api/content/{id}/label
```

```json
[
  { "prefix": "global", "name": "my-label" },
  { "prefix": "global", "name": "another-label" }
]
```

### Remove label

```
DELETE /wiki/rest/api/content/{id}/label/{label}
```

## Attachments

### List attachments (v2)

```
GET /wiki/api/v2/pages/{id}/attachments
```

### Upload attachment (v1)

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
curl -s \
  -H "Authorization: Basic ${AUTH}" \
  -X POST \
  -H "X-Atlassian-Token: nocheck" \
  -F "file=@path/to/file.pdf" \
  -F "comment=Uploaded via API" \
  "https://vaisala.atlassian.net/wiki/rest/api/content/{id}/child/attachment"
```

The `X-Atlassian-Token: nocheck` header is required for multipart uploads.

### Download attachment

Attachment download URLs are returned in the attachment metadata as `_links.download`. Prepend the base URL:

```
GET https://vaisala.atlassian.net/wiki{downloadPath}
```

## Storage Format (XHTML)

Confluence storage format is XHTML. Common elements:

```html
<!-- Paragraph -->
<p>Text content</p>

<!-- Headings -->
<h1>Heading 1</h1>
<h2>Heading 2</h2>

<!-- Bold and italic -->
<strong>bold</strong>
<em>italic</em>

<!-- Lists -->
<ul><li>Unordered item</li></ul>
<ol><li>Ordered item</li></ol>

<!-- Link -->
<a href="https://example.com">Link text</a>

<!-- Code block -->
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">python</ac:parameter>
  <ac:plain-text-body><![CDATA[print("hello")]]></ac:plain-text-body>
</ac:structured-macro>

<!-- Info panel -->
<ac:structured-macro ac:name="info">
  <ac:rich-text-body><p>Info message</p></ac:rich-text-body>
</ac:structured-macro>

<!-- Table -->
<table>
  <tr><th>Header</th><th>Header</th></tr>
  <tr><td>Cell</td><td>Cell</td></tr>
</table>

<!-- Link to another Confluence page -->
<ac:link><ri:page ri:content-title="Page Title" ri:space-key="DEV" /></ac:link>

<!-- JIRA issue macro -->
<ac:structured-macro ac:name="jira">
  <ac:parameter ac:name="key">WEAT-123</ac:parameter>
</ac:structured-macro>
```

## Links

- View page: `https://vaisala.atlassian.net/wiki/spaces/{spaceKey}/pages/{pageId}`
- Space home: `https://vaisala.atlassian.net/wiki/spaces/{spaceKey}`
