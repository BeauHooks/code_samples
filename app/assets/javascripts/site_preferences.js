$(".pref").live("click", function() {
  return $.ajax({
    url: "/users_preferences/update?name=" + $(this).attr("name") + "&value=" + $(this).attr("value"),
    type: "PUT"
  });
});