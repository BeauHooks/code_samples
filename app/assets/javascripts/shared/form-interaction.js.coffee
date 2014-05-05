## lockContent = ->
##   $("#overlay_content").find(":input").prop "disabled", true

## deliverCPL = ->
##   closeOverlay "cpl"
##   $("#attachments_tab a").click()

$(document).ready ->
  $(document).on "click", ".cpl_error", ->
    document.getElementById($(this).attr("cpl_name")).focus()
