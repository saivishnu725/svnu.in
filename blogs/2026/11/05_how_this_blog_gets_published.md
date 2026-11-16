<!-- series: about this site -->

# how this blog gets published

## abstract

someone asked me if the "auto-generated" at the bottom of the [blogs page](/blogs/) meant that the posts were auto-generated. fair question. i knew what i meant, but apparently i forgot that other people can't read my mind. yet.

what i meant was that the *index* is generated automatically. i write the posts in markdown, and a few scripts turn them into pages and put the links in the right place. so here's what happens between me typing in obsidian and a post showing up on the site.

## 00 - writing in obsidian

i write the post in [obsidian](https://obsidian.md/), in markdown. headings, links, code blocks, images, the usual stuff. when i'm happy with it, i copy the `.md` file into the appropriate year and month under `blogs/` in the website repo.

for a post that's part of a series, i add a comment like this:

```html
<!-- series: arduino -->
```

the index script uses that name to group the posts together. if there isn't a series comment, the post goes under `uncategorised`. the comment doesn't show up as text in the post itself.

## 01 - markdown to html

the browser needs a page, so `md_to_html.sh` uses pandoc to convert the markdown into html. it wraps the result in the site's layout and styles, and turns obsidian-style links and image embeds into html links and images.

```sh
pandoc --from=markdown --to=html --no-highlight --wrap=none post.md
```

that's the conversion part in a nutshell. the script also keeps timestamps in `.md_stamps/` so it can check which markdown files are new or have changed since the last conversion. the generated html sits next to the markdown file.

this can run on a schedule on my machine, or i can run it myself with `./md_to_html.sh`. after conversion it also regenerates the local indexes. i commit and push the markdown and the generated html to github. yes, i still have to push it myself. the scripts haven't learned to read my mind either.

## 02 - pulling it onto the site

the website lives on my home server, served by nginx. a scheduled job runs `pull_and_index.sh` there. it pulls the repo with `git pull --ff-only`, then checks if the commit changed. if it did, it regenerates the indexes. it also does that if an index is missing.

```sh
before="$(git rev-parse HEAD)"
git pull --ff-only --quiet
after="$(git rev-parse HEAD)"
```

the script uses `flock` so another run doesn't start while the previous one is still going. the checked-in cron example runs every five minutes; the actual interval depends on the server's cron configuration. either way, the scheduled job is just checking for updates. it doesn't rewrite every post each time.

## 03 - finding the posts

`generate_indexes.sh` scans the html files under `blogs/` and `notes/`, takes the title from each page, and writes the links into their respective index pages. for blogs it checks the corresponding markdown for that series comment, then groups the links accordingly. notes get a flat list.

the index files themselves aren't tracked in git; the server builds them after pulling. so when i add a post, i don't have to remember to manually add a link to the blogs page too. i already have enough things to forget.

so the flow is: write in obsidian, copy the markdown into the repo, convert it, commit and push. the server pulls the update and builds the index. the conversion can be scheduled, which leaves me with the writing, copying and pushing.

i've changed the label at the bottom of the indexes to say what is actually generated. turns out two extra words can save an entire explanation. i wrote the explanation anyway.

laters!
svnu©️ 16-November-2026
