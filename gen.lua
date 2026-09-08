-- site.lua -- one Pandoc Lua filter for the whole static site.
--
-- Rendering policy:
--   * Pandoc's html5 writer remains the canonical mapping for ordinary Markdown
--     (paragraphs, headings, lists, links, emphasis, notes, definitions, etc.).
--   * This filter adds only the site-specific transformations that are easier to
--     maintain in the AST: metadata normalization, index generation, table/image
--     wrappers, code annotations, and KaTeX placeholders.
--   * The companion site.html template owns shell/layout/CSS/client-side UI.

local stringify = pandoc.utils.stringify

local function text(meta, key, fallback)
  if meta[key] == nil then return fallback or "" end
  local value = stringify(meta[key])
  if value == "" then return fallback or "" end
  return value
end

local function meta_list(meta, key)
  local value = meta[key]
  if value == nil then return {} end
  if pandoc.utils.type(value) == "List" then
    local out = {}
    for _, item in ipairs(value) do
      local s = stringify(item)
      if s ~= "" then table.insert(out, s) end
    end
    return out
  end
  local single = stringify(value)
  return single ~= "" and {single} or {}
end

local function source_slug(path)
  local name = path:gsub("\\", "/"):match("([^/]+)$") or path
  return (name:gsub("%.[Mm][Dd]$", ""))
end

local function read_markdown(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local source = f:read("*a")
  f:close()
  return pandoc.read(source, "markdown")
end

local function tag_inlines(tags)
  local inlines = pandoc.Inlines({})
  for i, tag in ipairs(tags) do
    if i > 1 then inlines:insert(pandoc.Space()) end
    inlines:insert(pandoc.Span(
      {pandoc.Str("#" .. tag)},
      pandoc.Attr("", {"tag"})
    ))
  end
  return inlines
end

local function record_from_file(path, root)
  local doc = read_markdown(path)
  local meta = doc.meta
  local slug = source_slug(path)
  local title = meta.title or pandoc.Inlines({pandoc.Str(slug)})
  local date = meta.date or pandoc.Inlines({})
  local summary = meta.summary or pandoc.Inlines({})
  local tags = meta_list(meta, "tags")

  return {
    slug = slug,
    title = title,
    date = date,
    date_text = stringify(date),
    summary = summary,
    tags = tags,
    href = root .. "/static/" .. slug .. ".html"
  }
end

local function build_index(doc)
  local meta = doc.meta
  local root = text(meta, "root", ".")
  local records = {}

  for _, path in ipairs(PANDOC_STATE.input_files) do
    if path:match("%.[Mm][Dd]$") then
      table.insert(records, record_from_file(path, root))
    end
  end

  table.sort(records, function(a, b)
    if a.date_text == b.date_text then return a.slug < b.slug end
    return a.date_text > b.date_text
  end)

  local blocks = pandoc.Blocks({})
  local all_tags, seen = {}, {}

  for _, r in ipairs(records) do
    for _, tag in ipairs(r.tags) do
      if not seen[tag] then
        seen[tag] = true
        table.insert(all_tags, tag)
      end
    end

    local title_link = pandoc.Link(r.title, r.href)
    local card_blocks = pandoc.Blocks({
      pandoc.Header(2, {title_link}),
      pandoc.Para({pandoc.Span(r.date, pandoc.Attr("", {"post-date"}))}),
      pandoc.Para(r.summary),
      pandoc.Div({pandoc.Plain(tag_inlines(r.tags))}, pandoc.Attr("", {"post-tags"}))
    })

    blocks:insert(pandoc.Div(
      card_blocks,
      pandoc.Attr("", {"post-card"}, {
        ["data-tags"] = table.concat(r.tags, "|"),
        ["data-slug"] = r.slug
      })
    ))
  end

  table.sort(all_tags)
  local tag_meta = pandoc.MetaList({})
  for _, tag in ipairs(all_tags) do tag_meta:insert(pandoc.MetaString(tag)) end
  meta["all-tags"] = tag_meta
  meta.tags = tag_meta
  meta.date = nil
  meta["post-count"] = pandoc.MetaString(tostring(#records))
  meta["is-index"] = pandoc.MetaBool(true)
  meta["is-article"] = pandoc.MetaBool(false)

  doc.meta = meta
  doc.blocks = blocks
  return doc
end

function Meta(meta)
  local kind = text(meta, "page-kind", "article")
  meta["is-index"] = pandoc.MetaBool(kind == "index")
  meta["is-article"] = pandoc.MetaBool(kind ~= "index")
  return meta
end

function Math(el)
  local display = el.mathtype == "DisplayMath"
  local escaped = el.text
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")

  local cls = display and "math math-display" or "math math-inline"
  local flag = display and "true" or "false"
  return pandoc.RawInline(
    "html",
    '<span class="' .. cls .. '" data-display="' .. flag .. '">' .. escaped .. '</span>'
  )
end

function CodeBlock(el)
  if not el.classes:includes("md-code") then el.classes:insert("md-code") end
  if #el.classes > 1 then el.attributes["data-language"] = el.classes[1] end
  return el
end

function Table(el)
  return pandoc.Div({el}, pandoc.Attr("", {"table-wrap"}))
end

function Image(el)
  el.attributes["loading"] = el.attributes["loading"] or "lazy"
  el.attributes["decoding"] = el.attributes["decoding"] or "async"
  return el
end

function Pandoc(doc)
  if text(doc.meta, "page-kind", "article") == "index" then
    return build_index(doc)
  end
  return doc
end
