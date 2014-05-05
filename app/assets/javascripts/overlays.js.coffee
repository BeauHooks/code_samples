$(document).ready ->
  $("div#overlay_list").on "click", "a.add_employee", (event) ->
    regexp = undefined
    time = undefined
    time = new Date().getTime()
    regexp = new RegExp($(this).data("id"), "g")
    $("#new_file_employees tbody").append $(this).data("fields").replace(regexp, time)
    event.preventDefault()

  $("div#overlay_list").on "click", "a.add_property", (event) ->
    regexp = undefined
    time = undefined
    time = new Date().getTime()
    regexp = new RegExp($(this).data("id"), "g")
    $("#new_file_properties tbody").append $(this).data("fields").replace(regexp, time)
    event.preventDefault()

  $("div#overlay_list").on "keyup", ".taxid, .account", (event) ->
    county = undefined
    field = undefined
    object = undefined
    value = undefined
    if event.keyCode isnt 38 and event.keyCode isnt 40 and event.keyCode isnt 13
      object = $(this)
      county = object.parents("tr:first").find("select.county:first").val()
      field = object.data("field")
      value = object.val()
      object.autocomplete
        source: Routes.lookup_property_file_properties_path(
          field: field
          county_id: county
        )
        autoFocus: true
        minLength: 3

      $(".ui-front").css "z-index", "9999"

  $("div#overlay_list").on "change", ".taxid, .account", (event) ->
    county = undefined
    field = undefined
    object = undefined
    row = undefined
    value = undefined
    object = $(this)
    row = object.parents("tr:first")
    county = row.find("select.county:first").val()
    field = object.data("field")
    value = object.val()
    $.ajax
      url: Routes.fill_property_row_file_properties_path(
        field: field
        value: value
        county_id: county
      )
      dataType: "json"
      success: (data) ->
        row.find("input.taxid:first").val data.serialnum
        row.find("input.account:first").val data.accountnum
        row.find("input.address:first").val data.Address1
        row.find("input.city:first").val data.City
        row.find("input.state:first").val data.State
        row.find("input.zip:first").val data.ZipCode
        row.find("input.legal:first").val data.FullLegal
        row.find("input.owner:first").val data.OwnerName
