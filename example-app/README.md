# poli_page-rails example app

A Rails 8 app that renders the `welcome` template of the `getting-started`
project with [`poli_page-rails`](../README.md), behind a single-page demo at `/`.

```sh
bundle install
export POLI_PAGE_API_KEY=pp_sandbox_...           # a sandbox key
# export POLI_PAGE_BASE_URL=https://api.poli.page  # optional
bin/rails server
```

| Route | What it does |
| --- | --- |
| `GET /render/pdf` | `render.pdf`, answered as `application/pdf` |
| `GET /render/stream` | `render.pdf_stream`, streamed |
| `POST /render/file` | `render_to_file` into `tmp/poli-page/welcome.pdf` |
| `POST /documents` | `render.document`, the descriptor as JSON |
| `GET /documents/:id` | `documents.get`, a `302` to the presigned PDF URL |
| `GET /documents/:id/preview` | `documents.preview`, the HTML |
| `GET /documents/:id/thumbnails` | `documents.thumbnails`, as JSON |
| `DELETE /documents/:id` | `documents.delete`, `204` |
| `GET /errors/not-found` | renders the template `does-not-exist`: `404 TEMPLATE_NOT_FOUND` through the gem's default error handler |

Errors reach the gem's default error handler, which answers
`{ code, message, status, requestId }` as JSON. `bin/rake demo:render_to_file`
runs `render_to_file` from the command line. If your organization renamed or
removed `getting-started` from `sandbox`, use a fresh organization.

The gem's specs run the Poli Page API contract's integration cases against
this app's controllers, routes and initializer (see the root README).
