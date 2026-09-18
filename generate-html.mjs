import fs from "node:fs";
import path from "node:path";
import { marked } from "file:///C:/Users/konta/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/marked/lib/marked.esm.js";

const root = "C:\\Users\\konta\\Desktop\\knowledge.ralf-peter-kleinert\\final-projekt";
const files = fs.readdirSync(root).filter((name) => name.toLowerCase().endsWith(".md"));
const indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");
const siteStyles = indexHtml.match(/<style>([\s\S]*?)<\/style>/i)?.[1] ?? "";
const siteNavigation = indexHtml.match(/<nav class="main-nav"[\s\S]*?<\/nav>/i)?.[0] ?? "";
marked.setOptions({ gfm: true, breaks: false });

for (const file of files) {
  const sourcePath = path.join(root, file);
  const targetName = file.replace(/\.md$/i, ".html");
  const targetPath = path.join(root, targetName);
  let markdown = fs.readFileSync(sourcePath, "utf8");

  const titleMatch = markdown.match(/^#\s+(.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : file.replace(/\.md$/i, "");
  const styleMatch = markdown.match(/<style>[\s\S]*?<\/style>/i);
  if (styleMatch) {
    markdown = markdown.replace(styleMatch[0], "");
  }
  markdown = markdown.replace(/<nav class="main-nav"[\s\S]*?<\/nav>/i, "");

  let body = await marked.parse(markdown);
  if (siteNavigation) {
    const logoParagraph = /(<p align="center"><img[^>]+computerralle-Logo-Final-2026[^>]*><\/p>)/i;
    body = logoParagraph.test(body)
      ? body.replace(logoParagraph, `$1\n${siteNavigation}`)
      : `${siteNavigation}\n${body}`;
  }
  const canonical = "https://knowledge.ralf-peter-kleinert.de/" + encodeURIComponent(targetName).replace(/%2F/gi, "/");
  const markdownUrl = "https://knowledge.ralf-peter-kleinert.de/" + encodeURIComponent(file).replace(/%2F/gi, "/");
  const description = "Informationsseite der Knowledge Base von Ralf-Peter Kleinert / ComputerRalle / DIGITAL-easy.";

  const html = `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="index, follow">
  <title>${escapeHtml(title)} – Ralf-Peter Kleinert / ComputerRalle</title>
  <meta name="description" content="${escapeHtml(description)}">
  <link rel="canonical" href="${canonical}">
  <link rel="alternate" type="text/markdown" href="${markdownUrl}" title="Markdown-Quelle">
  <link rel="alternate" type="text/plain" href="/llms.txt" title="LLM information">
  <style>
${siteStyles}
    main {
      display: block;
    }

    footer {
      margin-top: 3rem;
      padding-top: 1rem;
      border-top: 1px solid color-mix(in srgb, currentColor 25%, transparent);
      color: GrayText;
      font-size: 0.9rem;
    }
  </style>
</head>
<body>
  <main>
${body.trim()}
  </main>
  <footer>
    <p>Ralf-Peter Kleinert / ComputerRalle / DIGITAL-easy · <a href="${markdownUrl}">Markdown-Quelle</a></p>
  </footer>
</body>
</html>
`;
  fs.writeFileSync(targetPath, html, { encoding: "utf8" });
  process.stdout.write(`Erzeugt: ${targetName}\n`);
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
