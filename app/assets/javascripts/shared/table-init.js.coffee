requests = []
dragTimer = undefined
currentSize = undefined
search_results_down = false

$(document).mousedown(->
  down = true
).mouseup ->
  down = false

$(document).ready ->
  $("#tabs").tabs()
  $("tr.result_row").first().trigger "click"
  $("#search_results").resizable grid: 23
  $("#search_results").resizable "option", "helper", "resizable-helper"
  $(".ui-icon-gripsmall-diagonal-se").remove()
  $(".ui-resizable-e").remove()
  $(".ui-resizable-handle").attr "style", "z-index: 1;"
  $(".ui-resizable-handle").mousedown ->
    $(".ui-resizable-handle").css "background-color", "#ddd"
    currentSize = $("#search_results").height()
    search_results_down = true

  $("body").mouseup ->
    if search_results_down
      $(".ui-resizable-handle").css "background-color", "#fff"
      unless currentSize is $("#search_results").height()
        $.ajax
          url: "/users_preferences/update?name=index_result_count&value=" + $("#search_results").height() / 23
          type: "PUT"

  $("#date_from").datepicker
    defaultDate: "+1w"
    changeMonth: true
    onClose: (selectedDate) ->
      $("#date_to").datepicker "option", "minDate", selectedDate

  $("#date_to").datepicker
    defaultDate: "+1w"
    changeMonth: true
    onClose: (selectedDate) ->
      $("#date_from").datepicker "option", "maxDate", selectedDate

$("#search_button").on "click", ->
  $("#search_results").show()
  $("#search_collapsed").hide()
  $("#search_expanded").show()
  $("#search_box").attr "readonly", true
  $("#search_button").hide()
  $("#include_closed_control").hide()
  $("#spinner").show()
  $("#searching_text").show()
