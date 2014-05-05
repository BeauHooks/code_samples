requests = []
window.dragTimer = null

$ ->
  # Submit search if search box has anything in it
  if $("#search_box") != ""
    $("#search_button").click()

  # Setup drag and drop functions on document
  $('body').attr("ondragover", "onDragOver(event);");
  $('body').attr("ondragleave", "onDragLeave(event);");
  $('body').attr("ondrop", "onDragDrop(event);");
  $("#search_box").focus();

$(document).on "click", "#search_results tbody tr", ->
  $("tr.active_row").removeClass("active_row")
  $(this).toggleClass "active_row"
  $.get $(this).attr("controller") + "/" + $(this).attr("id")

# Update table data when changed
window.bindRowUpdater = () ->
  blurredFrom = null
  blurredInput = null
  currentEl = null
  previousEl = null
  changed_elements = {}
  params = ""

  $("tr.update_row").on "change", "input", (event) ->
    blurredFrom = event.delegateTarget
    blurredInput = event.target
    changed_elements[$(blurredInput).attr("name")] = $(blurredInput).val()

  $("tr.update_row").on "focus", "input", (event) ->
    console.log changed_elements
    if event.delegateTarget != currentEl && Object.keys(changed_elements).length > 0
      Object.keys(changed_elements).forEach (key) ->
        params += ("&" + key + "=" + encodeURIComponent(changed_elements[key]))
      $.ajaxq "updater",
        url: $(blurredFrom).data("url") + params
        type: "put"
      changed_elements = {}
    currentEl = $(event.target).closest("tr")[0]

window.onDragOver = (e) ->
  dt = e.dataTransfer
  if dt.types != null && (dt.types.contains('application/x-moz-file')) || dt.types != null && dt.types.indexOf("Files") isnt -1
    e.preventDefault()
    $("div#filebin_overlay").addClass("dragenter")
    $("h1#filebin_overlay_text").show()
    $("h1#filebin_overlay_text").html("<center>Upload Attachment To<br />" + $(".active_row td.name").html() + "</center>")
    clearTimeout(dragTimer)
  return

window.onDragLeave = () ->
  dragTimer = setTimeout ->
    $("div#filebin_overlay").removeClass("dragenter")
    $("h1#filebin_overlay_text").hide()
  , 25
  return

uploadFile = (blobFile, fileName, filePart, totalChunks, identifier) ->
  entity_id = $(".active_row").attr("id")
  csrf_token = $('meta[name=csrf-token]').attr('content')
  csrf_param = $('meta[name=csrf-param]').attr('content')
  formData = new FormData()
  formData.append('file', blobFile)

  # Now post a new XHR request
  params = null
  if csrf_param is not undefined && csrf_token is not undefined
    params = csrf_param + "=" + encodeURIComponents(csrf_token)
  params = params + "&entity_id" + entity_id + "&filename=" + fileName + "&filepart=" + filePart + "&totalchunks=" + totalChunks + "&identifier=" + identifier

  $.ajax identifier,
    url: "/rolodex_attachments/dnd_upload?" + params
    type: "POST"
    xhr: ->
      myXhr = $.ajaxSettings.xhr()
      return myXhr
    data: formData
    cache: false
    contentType: false
    processData: false
  return

window.onDragDrop = (e) ->
  entity_id = $(".active_row").attr("id")
  files = e.dataTransfer.files

  if files.length > 5
    alert "Can only upload up to 5 files at a time."
    $("div#filebin_overlay").removeClass("dragenter")
    $("h1#filebin_overlay_text").hide()
    e.preventDefault()
  else
    i = 0

    while i < files.length
      if files[i].type is ""
        alert "No file type detected, file must have an extension!"
        $("div#filebin_overlay").removeClass "dragenter"
        $("h1#filebin_overlay_text").hide()
        e.preventDefault()
      else if $("span#display_file_id").html() is "undefined"
        alert "File not finished loading yet"
      else
        $("div#filebin_overlay").removeClass "dragenter"
        $("h1#filebin_overlay_text").hide()
        e.preventDefault()
        @className = ""

        # Add task to taskbar
        identifier = "task-" + files[i].name + "-" + makeId()
        $.ajaxq identifier,
          url: "/application/add_task?title=" + files[i].name + "-0%25&identifier=" + identifier + "&type=file&id=" + file_id
          type: "get"


        # ASYNC File Upload
        file = files[i]
        blobs = []
        blob = file
        originalFileName = blob.name
        filePart = 0
        BYTES_PER_CHUNK = 5242880 # 5MB chunk sizes.
        SIZE = blob.size
        start = 0
        end = BYTES_PER_CHUNK
        totalChunks = Math.ceil(SIZE / BYTES_PER_CHUNK)
        while start < SIZE
          chunk = blob.slice(start, end)
          uploadFile chunk, originalFileName, filePart, totalChunks, identifier
          filePart++
          start = end
          end = start + BYTES_PER_CHUNK
      i++
  return

# Does not support people over 120 years old ;)
# $( "#info_focus" ).datepicker({
#   yearRange: "1900:+0",
#   changeMonth: true,
#   changeYear: true,
#   showOn: "button",
#   buttonImage: "/assets/calendar.png",
#   buttonImageOnly: true
# });

# choices = county_choices

# updateAddressPosition("BLANK");

# var counties = [
# <%= choices %>
# ];

# $( "input.county" ).autocomplete({
#   source: counties,
# });

# var states = [
#   'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'
# ];

# $( "input.state" ).autocomplete({
#   source: states,
# });
