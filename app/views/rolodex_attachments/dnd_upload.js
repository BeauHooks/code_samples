<% if @percent == "100" %>
  $("#<%= @identifier %> #task-content").html("<%= @filename %>-<%= @percent %>%");
  $.ajax({
    url: "/rolodex_attachments/load_process_images?entity_id=<%= @entity.EntityID %>",
    type: "GET"
  });
  $("#<%= @identifier %>").remove();
<% else %>
  $("#<%= @identifier %> #task-content").html("<%= @filename %>-<%= @percent %>%");
<% end %>