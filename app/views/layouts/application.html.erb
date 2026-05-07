<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "ShipRight" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <% if authenticated? %>
      <header class="topbar">
        <div class="topbar-inner">
          <h1 class="brand"><%= link_to "ShipRight", root_path %></h1>
          <nav>
            <span class="user"><%= current_user.display_name %></span>
            <%= button_to "Sign out", session_path, method: :delete, form: { class: "inline" }, class: "btn btn-link" %>
          </nav>
        </div>
      </header>
    <% end %>

    <main class="container">
      <% if flash.any? %>
        <div class="flashes">
          <% flash.each do |type, message| %>
            <div class="flash flash-<%= type %>"><%= message %></div>
          <% end %>
        </div>
      <% end %>

      <%= yield %>
    </main>
  </body>
</html>
