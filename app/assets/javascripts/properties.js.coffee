$(document).on "click", "#search_results tbody tr", ->
  $("tr.active_row").removeClass("active_row")
  $(this).toggleClass "active_row"
  $.get $(this).attr("controller") + "/" + $(this).attr("id") + "/result_detail.js"
