function updateTemplate(object){
  var field = document.getElementById(object.name);
  field.value = object.value;

  if(object.value != ""){
    object.className = "";
  }

  if(object.id.indexOf("form_category") != -1){
    updateSubCategory();
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

function verifyDoc(object){
  var save = true;
  var field_array = ["form_description", "form_short_name", "form_note"];
  var error = "";
  var count = 0;

  for( i=0; i < field_array.length; i++){
    if(document.getElementById(field_array[i]).value == ""){
      save = false;
      document.getElementById(field_array[i]).className = "error";
      count += 1;
      switch(i){
        case 0:
          error += "&list[]=Name cannot be left blank.";
          break;
        case 1:
          error += "&list[]=Short Description cannot be left blank.";
          break;
        case 2:
          error += "&list[]=Notes cannot be left blank.";
          break;
      }
    }
    else{
      document.getElementById(field_array[i]).className = "";
    }
  }

  if(save){
    $("#editor_form").attr("action", $("#editor_form").attr("action") + "?filter_state=" + $("#doc_template_state").val() );
    return true;
  }
  else{
    $.post('application/flash_notice?notice=Please correct the following:' + error);
    return false;
  }
}

function clearActive(){
  var parent = document.getElementById("docs");
  var active = "";

  if(parent.getElementsByClassName("active_row").length > 0){
    active = parent.getElementsByClassName("active_row")[0];
    active.className = "trigger";
  }

  //document.getElementById("errors").style.display = "none";
}

function updateSubCategory(){
  var category = document.getElementById("form_category").value;
  var sub_category = document.getElementById("form_sub_category");

  switch(category){
    case "Title":
      sub_category.innerHTML = "<option value='Commitment'>Commitment</option><option value='Policy'>Policy</option><option value='Report'>Report</option>";
      break;
    case "Escrow":
      sub_category.innerHTML = "<option value='Clearing'>Clearing</option><option value='Recording'>Recording</option>";
      break;
    case "Other":
      sub_category.innerHTML = "<option value='Other'>Other</option>";
      break;
  }

  updateTemplate(sub_category);
}

function selectTemplateRow(object, id){
  var parent = object.parentNode;
  var active = "";

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

  if($("#doc_list").find(".active_row").length > 0){
    $("#doc_list .active_row").removeClass("active_row");
  }

  $(object).addClass("active_row");
}

function toggleDocGroup(object){
   if($('.open').attr('class') != undefined && $(object).next().attr('class') != 'open'){
    $('.open').removeClass('open').addClass('closed');
    } 
    
    if($(object).next().attr('class') != 'open'){
      $(object).next().attr('class', 'open');
      if($(object).next().children("tr").length > 7){
        addWidth('groups', 90);
      }
    }else{
      $(object).next().removeClass('open').addClass('closed');
      fixWidth('groups', 90);
    }
}