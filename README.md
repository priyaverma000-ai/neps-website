# New Era Public School, Dwarka: website redesign

A mobile-first redesign of [nepsdwarka.com](https://nepsdwarka.com), built as plain HTML, CSS and JavaScript with no frameworks.

**Status: draft.** Pages marked `DRAFT SLOT` still need facts from the school, such as seats, points, board results, parent reviews and safety details. The full list is in the revamp plan document. Don't point nepsdwarka.com at this site until those slots are filled.

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

## Editing a page

1. Edit the page in `src/tpl` (for example `src/tpl/admissions.html`). Edit `_header.html` or `_footer.html` to change every page at once.
2. Rebuild: `powershell -ExecutionPolicy Bypass -File src\build.ps1`
3. Preview: `powershell -ExecutionPolicy Bypass -File src\serve.ps1`, then open http://localhost:8765
4. Commit and push. GitHub Pages republishes in about a minute.

The first line of each page in `src/tpl` holds its Google title, description, address, share image and breadcrumb name, separated by `||`:

```
<!--META Page title||Meta description||/address||image.jpg||Breadcrumb name-->
```

Add `||noindex` at the end to keep a page out of Google.

## FAQs and parent videos

- **FAQs:** each page's questions live in `src/faqs.json`. Edit the question and answer text there and rebuild. The build adds the FAQ section and Google's FAQ markup to the page.
- **Parent videos:** the three cards on Home and the Reviews page are in `src/tpl/_testimonials.html`. Upload each video to YouTube, then paste its ID (the part after `watch?v=`) into that card's `data-yt=""`. The card then shows the video's thumbnail and plays it when tapped. Until then it shows "Recording pending".

## Forms

Forms check the name, mobile number and class, then open WhatsApp (+91 98705 52633) with the details filled in. Nothing is stored. To also save leads, set `leadEndpoint` at the top of `js/site.js` to an Edunext or Google Sheet web-app URL.

## Before going live on nepsdwarka.com

- Fill every `DRAFT SLOT`
- Change `robots.txt` to allow search engines (it blocks them while this is a draft)
- Set up 301 redirects from the old addresses (listed in the revamp plan)
- Host the tour video on YouTube and embed it, since 82 MB is heavy on phones
