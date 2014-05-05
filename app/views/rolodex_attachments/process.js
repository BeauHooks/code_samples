$('#overlay_process_user_images').html("<%= j render 'rolodex_attachments/process' %>");
setTimeout('openOverlay("process_user_images")', 1000);

<% if @success %>
  $('div#notice').html('Image queued for processing successfully!'); $('div#notice').show(); $('div#notice').delay(2000).fadeOut(3000);
<% end %>