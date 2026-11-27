# New Era Public School, Dwarka: website redesign

A mobile-first redesign of [nepsdwarka.com](https://nepsdwarka.com), built as plain HTML, CSS and JavaScript with no frameworks.

**Deploying it?** Read [DEPLOY.md](DEPLOY.md): hosting options, the go-live checklist, the blog and news editor, and the content still to come.

Unfilled sections are marked `DRAFT SLOT` in `src/tpl` and are hidden on the site. Add `?drafts=1` to a page address to see them.

## What's here

| Path | What it is |
|---|---|
| `*.html` | The finished pages. These are built files, so edit `src/tpl` instead |
| `css/site.css` | All styles (design tokens are at the top) |
| `js/site.js` | Menu, forms, age calculator, fee finder, tour video, blog filters |
| `images/` | Real school photos, each with a full size and a `-sm` phone size |
| `video/school-tour.mp4` | The 60-second campus tour (loads only when tapped) |
| `docs/` | The DoE circular on age of admission |
| `src/tpl/` | Page sources. Files starting with `_` are shared parts: head, header, footer, enquiry band, admissions tabs, age calculator |
| `src/build.ps1` | Builds every page from `src/tpl` into the site root and writes `sitemap.xml` |
| `src/serve.ps1` | Local preview at http://localhost:8765 |
| `content/blog`, `content/news` | Blog posts and news items in Markdown, edited at `/admin/` (Decap CMS) |
| `admin/` | The blog and news editor and its settings |
| `.github/workflows/build.yml` | Rebuilds the pages when a post is published |
| `.htaccess`, `deploy/` | Server rules (Apache and Nginx) and the production robots.txt |

## Editing a page

1. Edit the page in `src/tpl` (for example `src/tpl/admissions.html`). Edit `_header.html` or `_footer.html` to change every page at once.
2. Rebuild: `powershell -ExecutionPolicy Bypass -File src/build.ps1` (or `pwsh src/build.ps1` on Linux and macOS)
3. Preview: `powershell -ExecutionPolicy Bypass -File src\serve.ps1`, then open http://localhost:8765
4. Commit and push. GitHub Pages republishes in about a minute.

The first line of each page in `src/tpl` holds its Google title, description, address, share image and breadcrumb name, separated by `||`:

```
<!--META Page title||Meta description||/address||image.jpg||Breadcrumb name-->
```

Add `||noindex` at the end to keep a page out of Google.

## FAQs and parent videos

- **FAQs:** each page's questions live in `src/faqs.json`. Edit the question and answer text there and rebuild. The build adds the FAQ section and Google's FAQ markup to the page.
- **Parent videos:** the seven parent videos on Home and the Reviews page are in `src/tpl/_testimonials.html`. Each card plays `video/parent-review-N.mp4` (540x960, about 1 Mbps) with the cover image `images/parent-review-N.jpg`, and the section carries Google VideoObject data. To add one, copy a card, add the files, and add a matching VideoObject entry.

## Forms

Forms check the name, mobile number and class, then open WhatsApp (+91 98705 52633) with the details filled in. Nothing is stored. To also save leads, set `leadEndpoint` at the top of `js/site.js` to an Edunext or Google Sheet web-app URL.

## Before going live on nepsdwarka.com

- Fill every `DRAFT SLOT`
- Change `robots.txt` to allow search engines (it blocks them while this is a draft)
- Set up 301 redirects from the old addresses (listed in the revamp plan)
- Host the tour video on YouTube and embed it, since 82 MB is heavy on phones
