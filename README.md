This app gives you the ability to search google for chosen phrases and scrape companies email addresses, that you're interested in.

```bundle```
```ruby main.rb```

You might have to install the newest chrome driver from http://chromedriver.storage.googleapis.com/index.html

Move it to your Desktop and type in your console:
```mv ~/Desktop/chromedriver /usr/local/bin```

After running the script, in the console, you should define:
- a number of pagination pages to scrape in `google.com`
- a number of links within each site
- the searched keywords

Example: `5, 5, italian restaurant`

You'll scrape 5 SERP pages, containing 10 links each. Then 5 links within each site.
You'll scrape 250 sites in total.
