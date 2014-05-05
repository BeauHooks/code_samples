$(document).ready(function() {
  return $("form#edit_hud_1").on("change", "input", function(event) {
    return $.ajax({
      url: "/huds/1.json",
      data: $("form#edit_hud_1").serialize(),
      dataType: "json",
      type: "put",
      success: function(data) {
        var hud_line_field, id, key, line, val, _i, _j, _len, _len1, _ref, _ref1;
        _ref = data.hud_lines;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          line = _ref[_i];
          _ref1 = line.hud_line_fields;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            hud_line_field = _ref1[_j];
            for (key in hud_line_field) {
              val = hud_line_field[key];
              id = "'#" + key + "'";
              console.log(val, id);
              $(id).val(val);
            }
          }
        }
        return $("#hud_total").val(data.total);
      },
      error: function(data) {
        var errors;
        errors = void 0;
        $(event.target).val($(event.target).attr("data-old-value"));
        $(event.target).focus().select();
        errors = JSON.parse(data.responseText);
        return alert(errors.errors["hud_lines.hud_line_field+-s.value"]);
      }
    });
  });
});

$(document).ready().bind('keydown', function(e){
  if (e.which == '192')
  {
    $("div#doc_quickadd").toggle();
    $("input#quickadd_field").val("");
    $("input#quickadd_field").focus();
    return false;
  }
});

function updateCheckedBox(object){
  checked = object.checked;

  $("." + $(object).attr("class")).each(function(){
    if(this.checked == true){
      this.checked = false;
      this.value = this.getAttribute("data-box");
    }
  });

  $("input[name=" + $(object).attr("name") + "]").each(function(){
    this.checked = checked;

    if(this.checked == true){
      this.value = "0";
    }
    else{
      this.value = this.getAttribute("data-box");
    }
  });
}

function checkSplitParent(entity_id){
  var checked = $("#split_notary_" + entity_id).attr("checked");
  var children_checked = true;
  var children_exist = false;

  $("#doc_entity_" + entity_id + "_contents input[type=checkbox]").each(function(){
    if(this.checked == false){
      children_exist = true;
      children_checked = false;
    }
  });

  if(children_checked == true && checked == "checked" && children_exist == true){
    $.ajax({
      url: '/docs/toggle_split_notary?id=' + entity_id + '&type=entity',
      type: "PUT"
    });
    $("#split_notary_" + entity_id).removeAttr("checked");
    $("#split_notary_" + entity_id).attr("disabled", "disabled");
  }
  else if(children_checked == true){
    $("#split_notary_" + entity_id).attr("disabled", "disabled");
  }
  else{
   // $("#split_notary_" + entity_id).removeAttr("disabled");
  }
}

function selectDocRow(object, id){
  var parent = object.parentNode;
  var active = "";

  // document.getElementById("errors").style.display = "none";

  while(parent.tagName.indexOf( "TABLE" ) == -1) {
    parent = parent.parentNode;
  }

  if(parent.parentNode.id.indexOf("all_docs") != -1){
    if(document.getElementById("edit_doc") != undefined){
      document.getElementById("edit_doc").href = "docs/" + id + "/show_editor";
    }
  }

  if(parent.parentNode.id == "docs"){
    document.getElementById("copy_doc").href = "doc_templates/new?copy=" + id;
  }

  if(parent.getElementsByClassName("active_row").length > 0){
    active = parent.getElementsByClassName("active_row")[0];
    $(active).removeClass("active_row");
  }

  $(object).addClass("active_row");
  // object.getElementsByTagName("a")[0].click();
}

function removeClickFunction(object){
	var button = object.parentNode.getElementsByTagName("tr")[0];
	button.onclick = "";
	button.value = "Added";
	button.disabled = "disabled";
}

function collectDocs(object){
  var send = false;
  $("#all_docs input[type=checkbox]").each(function(){
    if(this.checked){
      object.href += "&docs[]=" + this.id.replace("doc", "");
      send = true;
    }
  });

  if(!send){
    $.post('application/flash_notice?notice=You do not have any documents selected.');
    return false;
  }
  else{
    return true;
  }
}

function destroySelected(object, list, file){
  var first = true;
  var destroy = false;
  var post = "docs/destroy?request_type=delete&file_id=" + file;
  var doc_names = "";

  $("#" + list + " input[type=checkbox]").each(function(){
    if(this.checked){
      post += "%26docs[]=" + this.id.replace("doc", "");
      doc_names += "&list[]="+ encodeURIComponent( $(this).closest('tr').find('.name').eq(0).text() );
      destroy = true;
      //$(this).closest("tr.trigger").remove();
      //$("div#all_docs").find("tr").first().click();
    }
  });

  if(destroy){
    var message = "Are you sure you want to remove the selected docs?";
    var confirm = "Yes";
    $.post('application/flash_notice?notice=' + message + '&post=' + post + '&confirm=' + confirm +  doc_names);
  	return false;
  }
  else{
    $.post('application/flash_notice?notice=You need to select at least one document to remove.');
  	return false;
  }
}

function saveSelected(object, list, file){
  var save = false;
  var hud = false;
  var count = 0;

  href = "docs/save?file_id=" + file;
  $("#" + list + " input[type=checkbox]").each(function(){
    if(this.checked){
      count += 1;
      if($(this).data("doc") == "HUD"){
        hud = true;
      }
      href += "&docs[]=" + this.id.replace("doc", "");
      save = true;
    }
  });

  if(save){
    $("#doc_list_tools").hide();
    $("#doc_list_spinner").show();

    if(hud && count == 1){
      $.get("overlays/choose_side?file_id=" + file + "&href=" + href + "&only_hud=true");
      return false;
    }
    else if(hud){
      $.get("overlays/choose_side?file_id=" + file + "&href=" + href);
      return false;
    }
    else{
      $.get(href);
      return true;
    }
  }
  else{
    $.post("application/flash_notice?notice=You need to select at least one document to save.");
    return false;
  }
}

function printSelected(object, list, file){
  var print = false;
  var hud = false;
  //object.href = "docs/print?file_id=" + file;
  href = "docs/print?file_id=" + file;

  $("#" + list + " input[type=checkbox]").each(function(){
    if(this.checked){
      if($(this).data("doc") == "HUD"){
        hud = true;
      }
      href += "&docs[]=" + this.id.replace("doc", "");
      print = true;
    }
  });

  if(print){
    $("#doc_list_tools").hide();
    $("#doc_list_spinner").show();

    if(hud){
      $.get('overlays/choose_side?file_id=' + file + '&href=' + href);
      return false;
    }
    else{
      $.get(href);
      return true;
    }
  }
  else{
    $.post('application/flash_notice?notice=You need to select at least one document to print.');
    return false;
  }
}


function selectDoc(object, select_all){
  var all = document.getElementById(select_all);

  if(all.checked){
    all.checked = false;
  }
}

$("input[type=checkbox]").click(function(event){
  event.stopPropagation();
});

function addDoc(object){
  button = object.parentNode.getElementsByTagName("input")[0];
  button.onclick = null;
  button.value = "Added";
  button.disabled = true;
}

function removeDoc(object){
  var r = confirm("Remove this doc?");
  return r;
  // if(r){
  //   // button = object.parentNode.getElementsByTagName("input")[0];
  //   // button.onclick = null;
  //   // button.value = "Removed";
  //   // button.disabled = true;
  //   return true;
  // }
  // else{
  //   return false;
  // }
}

function countMissingFields(){
  var count = 0;
  var containers = []; //["grantor_contents", "grantee_contents", "property_contents", "special_contents", "doc_specific_contents", "lender_contents"];

  $('div#doc_input_fields').find(".contents").each(function(){
    containers.push($(this).attr('id'));
  });

  for( i=0; i < containers.length; i++){
    if(containers[i] != undefined){
      count = 0;

      $("#" + containers[i] + " input").each(function(){
        if(this.className.indexOf("error") != -1){
          count += 1;
        }
      });

      $("#" + containers[i] + " textarea").each(function(){
        if(this.className.indexOf("error") != -1){
          count += 1;
        }
      });

      if(count > 0){
        if(count == 1){
          document.getElementById(containers[i].replace("contents", "missing")).innerHTML = count + " item";
        }
        else{
          document.getElementById(containers[i].replace("contents", "missing")).innerHTML = count + " items";
        }
      }
      else{
        document.getElementById(containers[i].replace("contents", "missing")).innerHTML = "";
      }
    }
  }
}

function updateCustomField(object, id, doc, file){
  var submit = document.getElementById("submit" + id);
  var new_id = object.id.replace("global", "custom");
  var functions = ["w9_ssn", "w9_tax_id"];
  var value = "";
  submit.click();

  var parent = object.parentNode;

  while(parent.tagName.indexOf( "SPAN" ) == -1) {
    parent = parent.parentNode;
  }

  if(new_id.indexOf(functions[0]) == -1 && new_id.indexOf(functions[1]) == -1){
    if(object.value == ""){
      html = "<a href='docs/edit_custom_field?file_id=" + file + "&doc_id=" + doc + "&field=" + new_id + "' data-remote='true' class='custom' onclick=\"if($('span.document_focus').html() != undefined){var e = jQuery.Event('keydown'); e.keyCode = 27; $('span.document_focus').children('form:first').children('textarea:first').trigger(e); $('span.document_focus').attr('class', '');} this.parentNode.className = 'document_focus'; \">{{" + new_id.replace("custom_", "").toUpperCase() + "}}</a>";
    }
    else{
      if( new_id.indexOf('full_property_address') != -1 && $("#doc_content .doc").data('doc') == '1099' && object.value.length > 39) {
        value = object.value.slice(0, 39);
        addToQueue('exceeded_character_notice', 'application/flash_notice?notice=Address exceeds character limit on 1099. Truncating to 39 characters.&confirm=Okay');
      }
      else{
        value = object.value;
      }
      html = "<a href='docs/edit_custom_field?file_id=" + file + "&doc_id=" + doc + "&field=" + new_id + "' data-remote='true' class='custom' onclick=\"if($('span.document_focus').html() != undefined){var e = jQuery.Event('keydown'); e.keyCode = 27; $('span.document_focus').children('form:first').children('textarea:first').trigger(e); $('span.document_focus').attr('class', '');} this.parentNode.className = 'document_focus'; \">" + value.replace(/\n/g, "<br>") +"</a>";
    }
  }
  else if(new_id.indexOf(functions[0]) != -1 || new_id.indexOf(functions[1]) != -1){
    $("tr#doc_" + doc).children("td:first").children("a:first").click();
    return false;
  }

  $(document.getElementsByName($(parent).attr("name"))).each(function(){
    $(this).html(html);
    $(this).attr("name", new_id);
    $(this).attr("id", new_id);
  });

  if($("span.document_focus").html() != undefined){
    $("span.document_focus").attr("class", "");
  }

  return true;
}

function revertToGlobal(object, file, doc){
  var id = $(object).attr("id");
  id = id.replace("global_", "");
  id = id.replace("custom_", "");
  id = id.replace("_button", "");
  var parent = $(object).parents("form:first").parents("span:first");
  var value = $("#" + id).val();
  var inner = value;
  var functions = ["w9_ssn", "w9_tax_id"];
  var empty = false;

  if(id.indexOf(functions[0]) != -1 || id.indexOf(functions[1]) != -1){
    $("tr#doc_" + doc).children("td:first").children("a:first").click();
    return false;
  }

  if(inner == ""){
    inner = $(object).attr("id");
    inner = inner.replace("global_", "");
    inner = inner.replace("custom_", "");
    inner = inner.replace("_button", "");
    inner = "{{" + inner.toUpperCase() + "}}";
    empty = true;
  }

  if(id.indexOf('full_property_address') != -1 && !empty && $("#doc_content .doc").data('doc') == '1099'  && inner.length > 39){
    inner = inner.slice(0, 39);
    addToQueue('exceeded_character_notice', 'application/flash_notice?notice=Address exceeds character limit on 1099. Truncating to 39 characters.&confirm=Okay');
  }

  var html = "<a href='docs/edit_custom_field?file_id=" + file + "&doc_id=" + doc + "&field=global_" + id + "' data-remote='true' class='complete' onclick=\"if($('span.document_focus').html() != undefined){var e = jQuery.Event('keydown'); e.keyCode = 27; $('span.document_focus').children('form:first').children('textarea:first').trigger(e); $('span.document_focus').attr('class', '');} this.parentNode.className = 'document_focus'; \">" + inner.replace(/\n/g, "<br>") +"</a>";

  $(document.getElementsByName($(parent).attr("name"))).each(function(){
    $(this).html(html);
    $(this).attr("name", "global_" + id);
    $(this).attr("id", "global_" + id);
  });

  if($("span.document_focus").html() != undefined){
    $("span.document_focus").attr("class", "");
  }

  return true;
}

function updateDocField(object){
  var id = "global_" + object.id;
  var value = object.value;
  var temp = "";
  var inner = value;
  var empty = false;

  if(inner == ""){
    inner = $(object).attr("id");
    inner = inner.replace("global_", "");
    inner = inner.replace("custom_", "");
    inner = inner.replace("_button", "");
    inner = "{{" + inner.toUpperCase() + "}}";
    empty = true;
  }

  if(id.indexOf('full_property_address') != -1 && !empty && $("#doc_content .doc").data('doc') == '1099'  && inner.length > 39){
    inner = inner.slice(0, 39);
    addToQueue('exceeded_character_notice', 'application/flash_notice?notice=Address exceeds character limit on 1099. Truncating to 39 characters.&confirm=Okay');
  }

  if(document.getElementById(id) != undefined){
    $("span#" + id).children("a").html(inner.replace(/\n/g, "<br />"));
  }

  countMissingFields();
}

function verifyNewEntity(){
  var message = "";

  if($("#individual_options").attr("style") == "display: block;"){
    if($("#individual_options #required").val() == ""){
      message = "First name cannot be left blank.";
    }
  }else{
    if($("#other_options #required").val() == ""){
      message = "Name cannot be left blank.";
    }
  }

  if(message == ""){
    return true;
  }else{
    $.post("application/flash_notice?notice=" + message);
    return false;
  }
}

function verifySendDocs(object){
  var count = 0;
  var recipients = false;
  var documents = false;
  var subject = false;
  var message = false;
  var error = document.getElementById("send_docs_form_errors");
  var send = true;

  error.innerHTML = "";

  $("#all_recipients input[type=checkbox]").each(function(){
    if(this.checked === true){
      recipients = true;
    }
  });

  $("#all_docs_to_send input[type=checkbox]").each(function(){
    if(this.checked === true){
      documents = true;
    }
  });

  if(document.getElementById("doc_subject").value !== ""){
    subject = true;
  }

  if(document.getElementById("doc_message").value !== ""){
    message = true;
  }

  if(recipients === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") At least one recipient must be selected.<br />";
    send = false;
  }

  if(documents === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") At least one document must be selected.<br />";
    send = false;
  }

  if(subject === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") Subject line cannot be left blank.<br />";
    send = false;
  }

  if(message === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") Message cannot be left blank.<br />";
    send = false;
  }

  if(send === true){
    closeOverlay('send');
    return true;
  }
  else{
    error.style.display = "";
    return false;
  }
}

function updateName(object){
  var signature = object.id.replace("name", "signature");
  var type = object.id.split("_")[0];
  var test = "";
  var parent_id = $(object).parents("tr:first").attr("id");
  var vesting = "";
  var vesting_value = "";

  $("#add_" + type + "_entities").show();

  if($("#" + signature).val() == "" ){
    test = $("#" + signature).attr("onchange");
    if(test.indexOf("create") != -1){
      $("#" + signature).val(object.value).change();
    }else{
      $("#" + signature).attr("onchange", $("#" + signature).attr("onchange").replace("create", "update"));
      $("#" + signature).val(object.value).change();
    }
  }

  if(parent_id == undefined){
    parent_id = $(object).parents("tbody:first").attr("id");
  }

  if(parent_id.indexOf("manage_") != -1){
    type = "manage_" + type;
  }

  var vesting = type + "_names";
  var vesting_value = $("#" + vesting).val();
  if(vesting_value != ""){
    vesting_value += " and ";
  }

  vesting_value += object.value;
  $("#" + vesting).val(vesting_value).change();

  img = $(object).parents("tbody:first").attr("id");
  $("#add_entity_to_" + img).show();
}

function removeEntityRow(object){
  var table = $(object).parents("table");
  var tbody = $(object).parents("tbody");

  $(table).find(tbody).remove();
}

function removeSignatureRow(object){
  var tbody = $(object).parents("tbody");
  var tr = $(object).parents("tr");
  var row = $(object).parents("tr:first");
  row.parents("tbody:first").children("tr:first").children("td:first").children("a:last").show();

  $(tbody).find(tr).remove();
}

function updatePosition(object, type, direction){
  if(type == 'signature'){
    var tbody = $(object).parents("tbody:first");
    var row = $(object).parents("tr:first");

    if(direction == "up" && tbody.children().index(row) > 1){
      row.insertBefore(row.prev());
    }
    else if(direction == "down" && tbody.children().index(row) < tbody.children().length - 1){
      row.insertAfter(row.next());
    }
    else{
    }
  }
  else if(type == 'entity'){
    var table = $(object).parents("table:first");
    var tbody = $(object).parents("tbody:first");

    if(direction == "up" && table.children().index(tbody) > 0){
      tbody.insertBefore(tbody.prev());
    }
    else if(direction == "down" && table.children().index(tbody) < table.children().length - 1){
      tbody.insertAfter(tbody.next());
    }
    else{
    }
  }
}

function toggleGlobal(object, type, doc_id){
  var row = $(object).parents("tr:first");
  var label = row.children("td:first");
  var element = "";
  var temp = "";
  var toggle = "";

  label_class = label.attr("class");
  if(label_class.indexOf("global") != -1){
    toggle = label.attr("class");
    toggle = toggle.replace("global", "custom");
    $(label).attr("class", toggle);
  }
  else{
    toggle = label.attr("class");
    toggle = toggle.replace("custom", "global");
    $(label).attr("class", toggle);
  }

  if(type == 'textarea'){
    element = row.children("td:last").children("textarea");
    if(label_class.indexOf("global") != -1){
      temp = element.attr("onchange");
      temp = temp.replace(/global/g, "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=" + doc_id);
      $(element).attr("onchange", temp);
    }
    else{
      temp = element.attr("onchange");
      temp = temp.replace(/custom/g, "global");
      temp = temp.replace("global", "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=0");
      $(element).attr("onchange", temp);
    }
  }
  else if(type == 'input'){
    element = row.children("td:last").children("input");
    if(label_class.indexOf("global") != -1){
      temp = element.attr("onchange");
      temp = temp.replace(/global/g, "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=" + doc_id);
      $(element).attr("onchange", temp);
    }
    else{
      temp = element.attr("onchange");
      temp = temp.replace(/custom/g, "global");
      temp = temp.replace("global", "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=0");
      $(element).attr("onchange", temp);
    }
  }
  else if(type == 'multiple'){
      $(row).children("td").each(function(i){
        if($(this).children("input").length > 0){
          element = $(this).children("input");
          if(label_class.indexOf("global") != -1){
            temp = element.attr("onchange");
            temp = temp.replace(/global/g, "custom");
            temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=" + doc_id);
            $(element).attr("onchange", temp);
          }
          else{
            temp = element.attr("onchange");
            temp = temp.replace(/custom/g, "global");
            temp = temp.replace("global", "custom");
            temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=0");
            $(element).attr("onchange", temp);
          }
        }
    });
  }
}

function changeFormatOptions(object){
  if(object.value == "both"){
    $("#signature_format").html("<option value='grantorfirst' selected='selected'>Grantor First</option><option value='granteefirst'>Grantee First</option>");
    $("#signature_format").change();
  }
  else{
    $("#signature_format").html("<option value='left' selected='selected'>Left</option><option value='right'>Right</option><option value='both'>Both</option>");
    $("#signature_format").change();
  }
}

function toUSD(object) {
  if(object.value != ""){
    var number = object.value.toString().replace(/,/g, ''),
    dollars = number.split('.')[0],
    cents = (number.split('.')[1] || '') +'00';
    dollars = dollars.split('').reverse().join('')
        .replace(/(\d{3}(?!$))/g, '$1,')
        .split('').reverse().join('');
    object.value = dollars + '.' + cents.slice(0, 2);
  }
}

function amountToUSD(value) {
  if(value != ""){
    var number = value.toString().replace(/,/g, ''),
    dollars = number.split('.')[0],
    cents = (number.split('.')[1] || '') +'00';
    dollars = dollars.split('').reverse().join('')
        .replace(/(\d{3}(?!$))/g, '$1,')
        .split('').reverse().join('');
    return dollars + '.' + cents.slice(0, 2);
  }
}
