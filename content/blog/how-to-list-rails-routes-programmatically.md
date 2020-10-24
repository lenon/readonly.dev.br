---
title: "How to List Rails Routes Programmatically"
date: 2020-10-08T02:28:29Z
tags: [ruby,rails,TIL]
---

While developing a Rails app you can use the task `bin/rails routes` to list the
available routes and their respective controllers and actions. But in case you
need to list and manipulate them programmatically, you can use the following
snippet:

```ruby
Rails.application.routes.routes.each do |route|
  ...
end
```

The double `.routes` is not a typo as you can see:

```ruby
pry(main)> Rails.application.routes.class
=> ActionDispatch::Routing::RouteSet
pry(main)> Rails.application.routes.routes.class
=> ActionDispatch::Journey::Routes
```

It is possible to replace the second `routes` by `set` like this if you prefer:

```ruby
pry(main)> Rails.application.routes.set.class
=> ActionDispatch::Journey::Routes
```

Each route is an `ActionDispatch::Journey::Route`. Controller name and action
can be obtained by calling route requirements:

```ruby
Rails.application.routes.routes.map do |route|
  route.requirements.slice(:controller, :action)
end
```

To get path specification (`/example/:id(.:format)`):

```ruby
Rails.application.routes.routes.map do |route|
  route.path.spec.to_s
end
```

It is possible to extract more information like verb, constraints, name, etc as
you can [read in the documentation][1].

I learned about this while working on [rails_export_routes][2], a small tool
that I created to export Rails routes to CSV or JSON. With it you can easily
export routes to a file:

```text
$ bundle exec rails-export-routes export --format json-pretty routes.json
$ head -n 20 routes.json
[
  {
    "verb": "GET",
    "path": "/",
    "controller": "dashboard",
    "action": "home",
    "name": "root",
    "constraints": {}
  },
  {
    "verb": "GET",
    "path": "/profile(.:format)",
    "controller": "profile",
    "action": "show",
    "name": "profile",
    "constraints": {}
  },
  {
    "verb": "GET",
    "path": "/profile/edit(.:format)",
    ...
```

And then process them with other tools, like `jq`:

```text
$ jq '.[] | select(.verb=="POST" and (.path | startswith("/admin"))) | .path' routes.json
"/admin/users(.:format)"
"/admin/groups(.:format)"
"/admin/products(.:format)"
...
```

You can read more about this [project on GitHub][2].

[1]:https://www.rubydoc.info/docs/rails/6.0.2.1/ActionDispatch/Journey/Route
[2]:https://github.com/lenon/rails_export_routes
