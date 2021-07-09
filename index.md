---
---

{% assign listed_posts = site.posts | where_exp: "item", "item.hidden != true" -%}
{% for p in listed_posts %}
[{{ p.title }}]({{ p.url | relative_url }})
: <div id="indexdate"><div>{{ p.date | date_to_string | replace: ' ', '&nbsp;' }}</div>{% if p.edit_date %}&#32;<div>(last edited on {{ p.edit_date | date_to_string | replace: ' ', '&nbsp;' }})</div>{% endif %}</div>
{% endfor %}
{%- assign posts_size = listed_posts | size -%}
{%- if posts_size == 0 -%}
Nothing here yet!
{%- endif %}
