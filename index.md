---
---
# Posts

{% assign listed_posts = site.posts | where_exp: "item", "item.hidden != true" -%}
{%- for p in listed_posts -%}
[{{ p.title }}]({{ p.url | relative_url }}) -&nbsp;{{ p.date | date_to_string | replace: ' ', '&nbsp;' }} - {{p.hidden}}
{%- endfor %}
{%- assign posts_size = listed_posts | size -%}
{%- if posts_size == 0 -%}
No posts yet!
{%- endif %}