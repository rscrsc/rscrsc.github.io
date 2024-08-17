"""
Generate static pages from the database
"""

import csv
from bs4 import BeautifulSoup
import markdown

DIR_DATA = 'data/'
DIR_BUILD = 'build/'
DIR_STYLE = 'stylesheet/'

def parse_index(file_path):
    """
    Parse the database
    """
    # Construct data object list
    data_objs = []
    # Open the CSV file
    with open(file_path, newline='') as csvfile:
        reader = csv.reader(csvfile, delimiter=',')
        # Read the header line
        headings = next(reader)
        # Iterate over each row in the CSV file
        for row in reader:
            # Print each row
            data_objs.append({field: value 
                for field, value in zip(headings, row)})
    return data_objs

def construct_homepage(database):
    """
    Build the structure of index.html
    """
    # Init BeatifulSoup
    bs = BeautifulSoup(features='html.parser')
    # Build the structure
    html = bs.new_tag('html')
    # - head
    css0 = bs.new_tag('link', rel="stylesheet", 
        href='../' + DIR_STYLE + "style.css")
    css1 = bs.new_tag('link', rel="stylesheet", 
        href='../' + DIR_STYLE + "index.css")
    title = bs.new_tag('title')
    title.string = "Arcie's Studio | Blog"
    #   append
    head = bs.new_tag('head')
    head.append(css0)
    head.append(css1)
    head.append(title)
    html.append(head)
    # - body
    #   - header
    header = bs.new_tag('div', attrs={"class": "header"})
    header_title = bs.new_tag('h1')
    header_title.string = "Arcie's Studio"
    header_subtitle = bs.new_tag('h3')
    header_subtitle.string = "Drafting the Cosmos"
    header.append(header_title)
    header.append(header_subtitle)
    #   - tableOfContent
    tableOfContent = bs.new_tag('table', attrs={"class": "toc"})
    for e in database:
        tableOfContent_entry = bs.new_tag('tr')
        tableOfContent_entry_title = bs.new_tag('td')
        tableOfContent_entry_title_link = bs.new_tag('a', 
            attrs={"class": "toc-title"}, 
            href=DIR_BUILD + 'articles/' + e['filename'] + '.html')
        tableOfContent_entry_title_link.string = e['display_title']
        tableOfContent_entry_title.append(tableOfContent_entry_title_link)
        tableOfContent_entry_datetime = bs.new_tag('td', 
            attrs={"class": "toc-dt"})
        tableOfContent_entry_datetime.string = e['creation_date'] \
            + " " + e['creation_time']
        # append
        tableOfContent_entry.append(tableOfContent_entry_title)
        tableOfContent_entry.append(tableOfContent_entry_datetime)

        tableOfContent.append(tableOfContent_entry)

    #   append
    body = bs.new_tag('body')
    body.append(header)
    body.append(tableOfContent)
    html.append(body)
    # Write to the file
    with open(DIR_BUILD + 'index.html', 'w') as f:
        f.write(str(html))

def construct_articles(database):
    """
    Build all the articles in the database (TODO:Implement increamental update)
    """
    for e in database:
        with open(DIR_DATA + e['filename'] + '.txt', 'r') as f:
            raw_content = f.read()
            raw_content = "<div class=\"content\">\n" \
                + markdown.markdown(raw_content) + "</div>"
            parsed_div = BeautifulSoup(raw_content, features='html.parser')
            # Create article htmls
            bs = BeautifulSoup(features='html.parser')
            # Build the structure
            html = bs.new_tag('html')
            # - head
            css0 = bs.new_tag('link', rel="stylesheet", 
                href='../../' + DIR_STYLE + "style.css")
            css1 = bs.new_tag('link', rel="stylesheet", 
                href='../../' + DIR_STYLE + "article.css")
            title = bs.new_tag('title')
            title.string = e["display_title"]
            #   append
            head = bs.new_tag('head')
            head.append(css0)
            head.append(css1)
            head.append(title)
            html.append(head)
            # - body
            #   - header (Universal across pages)
            header = bs.new_tag('div', attrs={"class": "header"})
            header_title = bs.new_tag('h1')
            header_title.string = "Arcie's Studio"
            header_subtitle = bs.new_tag('h3')
            header_subtitle.string = "Drafting the Cosmos"
            header.append(header_title)
            header.append(header_subtitle)
            #   - content
            content = parsed_div
            #   append
            body = bs.new_tag('body', lang="en-US") # Specify attr `lang` to enable automatic hyphenating
            body.append(header)
            body.append(content)
            html.append(body)
            # Write to the file
            with open(DIR_BUILD + 'articles/' + e['filename']+ '.html', 'w') \
                as f:
                f.write(str(html))
            

if __name__ == '__main__':
    database = parse_index(DIR_DATA + 'index.csv') # id, creation_date, creation_time, filename, display_title
    construct_homepage(database)
    construct_articles(database)